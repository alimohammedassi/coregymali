// @ts-nocheck
// suggest-meal — AI Complete Meal Suggestion (owner brief 2026-09-24).
// Authenticated caller gets ONE balanced meal (2-4 real items from the foods
// catalog) sized to their REMAINING calories/macros for today. Provider is
// Gemini — the SAME client + retry pattern as analyze-food / log-food-voice /
// log-food-text / lookup-barcode (shared ~20 RPM free-tier quota; the client
// button disables itself while a request is in flight). No persistence, no
// new tables: stateless compute + validate + respond. No fallback model exists
// (PROJECT_MASTER §5) — validation failures retry the SAME call once.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')!;
const GEMINI_MODEL = 'gemini-3.6-flash';

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return Response.json(body, { status, headers: { 'Access-Control-Allow-Origin': '*' } });
}

// The app keys summaries by the DEVICE-local date and its whole market is
// Egypt (meal cron + water reminders both use Africa/Cairo), so "today" here
// is the Cairo calendar date — matching daily_summary rows for real users.
function todayCairo(): string {
  return new Date().toLocaleDateString('en-CA', { timeZone: 'Africa/Cairo' });
}

// Candidate pool: deterministic per-category slices, ≤100 items total, so the
// model sees a small curated menu instead of all ~430 catalog rows.
const CATEGORY_LIMITS: Record<string, number> = {
  protein: 25,
  dairy: 8,
  carbs: 22,
  vegetables: 18,
  fruits: 8,
  fats: 8,
  arabic: 10,
};

interface CatalogFood {
  id: string;
  name: string;
  name_ar: string | null;
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  serving_size: number | null;
  serving_unit: string | null;
  category: string;
  image_url: string | null;
}

// ── Gemini call — verbatim retry ladder from log-food-text (one shared ──────
// ~20 RPM quota with the other 4 AI functions; 429/502/503/504 get 5 attempts
// with growing backoff so a burst must not kill a single request).
async function generateContentWithRetry(body: unknown): Promise<Response> {
  let lastRes: Response | null = null;
  for (let attempt = 1; attempt <= 5; attempt++) {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) },
    );
    if (res.ok || ![429, 502, 503, 504].includes(res.status)) return res;
    lastRes = res;
    if (attempt < 5) await new Promise((r) => setTimeout(r, 1500 * attempt));
  }
  return lastRes!;
}

async function callGemini(
  system: string,
  user: string,
): Promise<{ ok: true; content: string } | { ok: false; reason: string }> {
  try {
    const res = await generateContentWithRetry({
      contents: [{ parts: [{ text: system }, { text: user }] }],
      generationConfig: { temperature: 0.2, responseMimeType: 'application/json' },
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => '');
      console.error('Gemini error:', res.status, detail.slice(0, 400));
      return { ok: false, reason: `gemini_status_${res.status}` };
    }
    const data = await res.json();
    const content = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!content) return { ok: false, reason: 'empty_gemini_response' };
    return { ok: true, content };
  } catch (err) {
    console.error('gemini fetch failed:', err);
    return {
      ok: false,
      reason: `gemini_network: ${err instanceof Error ? err.message : String(err)}`,
    };
  }
}

// Models wrap JSON in prose/fences despite instructions — extract the object.
function extractJsonObject(raw: string): any | null {
  const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
  const text = fenced ? fenced[1] : raw;
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return null;
  }
}

function buildPrompt(
  target: { calories: number; protein: number; carbs: number; fat: number },
  foods: CatalogFood[],
  mealType?: string,
  style?: string,
  fraction?: number,
): { system: string; user: string } {
  const menu = foods
    .map(
      (f) =>
        `${f.id} | ${f.name} (${f.name_ar ?? '-'}) | ${f.calories} kcal | P ${f.protein_g}g C ${f.carbs_g}g F ${f.fat_g}g | serving ${f.serving_size ?? 1} ${f.serving_unit ?? 'g'}`,
    )
    .join('\n');

  const system = `You are a nutrition expert building ONE complete balanced meal for a fitness-app user.

Return ONLY a raw JSON object — no markdown fences, no prose before or after. Exact shape:
{
  "items": [{"food_id": "<id from the menu>", "quantity_multiplier": 1.0}],
  "explanation_en": "...",
  "explanation_ar": "...",
  "total_calories": 0,
  "total_protein": 0,
  "total_carbs": 0,
  "total_fat": 0
}

Hard rules:
- Build ONE meal with a protein component + a carb component + a fat and/or vegetable component: 2 to 4 items total.
- Use ONLY food_ids copied EXACTLY from the menu below. Never invent, modify or reformat an id.
- quantity_multiplier is in SERVINGS of that item (1.0 = one listed serving; 0.5 = half serving). Plain numbers only.
- The meal's calories (sum of item calories x multiplier) must land within +/-10% of the remaining calorie target.
- Prefer the meal also covering a good share of the remaining protein/carbs/fat, but calories are the hard constraint.
- explanation_en: 1-2 short English sentences about the meal. explanation_ar: the same in Egyptian Arabic.
- total_* fields are your computed sums (plain numbers, no units).`;

  const preference = [
    mealType
      ? `The user is logging this meal as ${mealType.toUpperCase()} — pick foods that fit that time of day.`
      : '',
    style === 'high_protein'
      ? 'Preference: HIGH PROTEIN — lean on protein/dairy items so the meal covers a large share of the remaining protein.'
      : '',
    style === 'light'
      ? 'Preference: LIGHT — favor vegetables, fruits and dairy; keep the meal airy, not calorie-dense.'
      : '',
    style === 'home'
      ? 'Preference: EGYPTIAN HOME-STYLE — prefer the arabic-category dishes and everyday staples the user knows.'
      : '',
  ]
    .filter(Boolean)
    .join('\n');

  const user = `Remaining targets for today: calories ${Math.round(target.calories)} kcal, protein ${Math.round(target.protein)} g, carbs ${Math.round(target.carbs)} g, fat ${Math.round(target.fat)} g.
${preference ? preference + '\n' : ''}Menu (id | name | kcal per serving | macros per serving | serving size):
${menu}`;

  return { system, user };
}

// Validate strictly: real ids only, sane multipliers, recomputed calories
// within ±10% of target. Totals are ALWAYS recomputed from the catalog —
// a model's declared numbers are never trusted or forwarded.
function validateAndEnrich(
  parsed: any,
  byId: Map<string, CatalogFood>,
  targetCalories: number,
): { ok: true; payload: any } | { ok: false; reason: string } {
  if (!parsed || !Array.isArray(parsed.items)) return { ok: false, reason: 'missing items array' };
  const items = parsed.items;
  if (items.length < 2 || items.length > 4) return { ok: false, reason: `item count ${items.length} not in 2..4` };

  const seen = new Set<string>();
  const enriched: any[] = [];
  let kcal = 0, protein = 0, carbs = 0, fat = 0;
  for (const it of items) {
    const id = typeof it?.food_id === 'string' ? it.food_id.trim() : '';
    const food = byId.get(id);
    if (!food) return { ok: false, reason: `unknown food_id "${id}" (not in the menu)` };
    if (seen.has(id)) return { ok: false, reason: `duplicate food_id "${id}"` };
    seen.add(id);
    const mult = Number(it?.quantity_multiplier);
    if (!Number.isFinite(mult) || mult <= 0 || mult > 5) {
      return { ok: false, reason: `bad quantity_multiplier ${it?.quantity_multiplier} for "${id}" (need 0 < m <= 5)` };
    }
    kcal += food.calories * mult;
    protein += food.protein_g * mult;
    carbs += food.carbs_g * mult;
    fat += food.fat_g * mult;
    enriched.push({
      food_id: food.id,
      name: food.name,
      name_ar: food.name_ar,
      category: food.category,
      image_url: food.image_url,
      quantity_multiplier: Math.round(mult * 100) / 100,
      serving_size: food.serving_size,
      serving_unit: food.serving_unit,
      calories: Math.round(food.calories * mult),
      protein_g: Math.round(food.protein_g * mult * 10) / 10,
      carbs_g: Math.round(food.carbs_g * mult * 10) / 10,
      fat_g: Math.round(food.fat_g * mult * 10) / 10,
    });
  }

  if (targetCalories > 0 && Math.abs(kcal - targetCalories) > targetCalories * 0.1) {
    return {
      ok: false,
      reason: `meal totals ${Math.round(kcal)} kcal, outside +/-10% of target ${Math.round(targetCalories)} kcal`,
    };
  }

  return {
    ok: true,
    payload: {
      items: enriched,
      explanation_en: typeof parsed.explanation_en === 'string' && parsed.explanation_en.trim()
        ? parsed.explanation_en.trim()
        : 'A balanced meal sized to your remaining calories for today.',
      explanation_ar: typeof parsed.explanation_ar === 'string' && parsed.explanation_ar.trim()
        ? parsed.explanation_ar.trim()
        : 'وجبة متوازنة بمقاس الكالوريز المتبقية ليك النهاردة.',
      total_calories: Math.round(kcal),
      total_protein: Math.round(protein * 10) / 10,
      total_carbs: Math.round(carbs * 10) / 10,
      total_fat: Math.round(fat * 10) / 10,
    },
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }

  try {
    // ── Auth ────────────────────────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return json({ error: 'unauthorized' }, 401);
    const token = authHeader.replace('Bearer ', '');
    const { data: userData, error: authError } = await admin.auth.getUser(token);
    if (authError || !userData?.user) return json({ error: 'unauthorized' }, 401);
    const uid = userData.user.id;

    // Optional zero-input preferences (owner v2 flow): the sheet sends the
    // chosen meal slot + style + what share of the remaining budget this
    // meal should cover. Absent/unknown values just mean "no hint".
    const body = await req.json().catch(() => ({}));
    const mealType = ['breakfast', 'lunch', 'dinner', 'snack'].includes(body?.meal_type)
      ? body.meal_type as string
      : undefined;
    const style = ['balanced', 'high_protein', 'light', 'home'].includes(body?.style)
      ? body.style as string
      : undefined;
    const rawFraction = Number(body?.calorie_fraction);
    const fraction = Number.isFinite(rawFraction) && rawFraction >= 0.2 && rawFraction <= 1
      ? rawFraction
      : 1;

    // NEW: user-typed calorie target (finish field: "put his CAL"). When
    // present, this overrides the remaining-budget calculation entirely so the
    // AI sizes the meal to exactly what the user asked for.
    // Accepts 80..5000 kcal. Also accepts legacy aliases for robustness.
    const rawCustomTarget = Number(
      body?.target_calories ?? body?.targetCalories ?? body?.custom_calories ?? body?.calories,
    );
    const hasCustomTarget =
      Number.isFinite(rawCustomTarget) && rawCustomTarget >= 80 && rawCustomTarget <= 5000;
    const customTargetCalories = hasCustomTarget ? Math.round(rawCustomTarget) : null;

    // ── Remaining calories + macro targets for today ───────────────────────
    const day = todayCairo();
    const [summaryRes, goalsRes] = await Promise.all([
      admin.from('daily_summary').select('calories_consumed, protein_g, carbs_g, fat_g').eq('user_id', uid)
        .eq('summary_date', day).maybeSingle(),
      admin.from('user_goals').select('daily_calories, daily_protein_g, daily_carbs_g, daily_fat_g')
        .eq('user_id', uid).maybeSingle(),
    ]);

    const goalCalories = (goalsRes.data?.daily_calories as number) ?? 0;
    const consumed = (summaryRes.data?.calories_consumed as number) ?? 0;
    const remainingCalories = Math.max(0, goalCalories - consumed);

    // Target calories: custom input wins. Fallback = remaining * fraction.
    // Custom mode works even when remaining==0 or goals are missing — the
    // user explicitly asked for N kcal. Rejects only impossibly small targets.
    let targetCalories: number;
    let fractionForMacros: number;
    if (customTargetCalories != null) {
      targetCalories = customTargetCalories;
      if (targetCalories < 80) return json({ error: 'no_remaining' }, 409);
      // Derive macro fraction from remaining if available, else from goal ratios.
      if (remainingCalories > 0) {
        fractionForMacros = targetCalories / remainingCalories;
      } else if (goalCalories > 0) {
        fractionForMacros = targetCalories / goalCalories;
      } else {
        fractionForMacros = 1;
      }
    } else {
      targetCalories = remainingCalories * fraction;
      if (goalCalories <= 0 || targetCalories < 80) {
        return json({ error: 'no_remaining' }, 409);
      }
      fractionForMacros = fraction;
    }

    // Build remaining macro budgets (Cairo daily_summary).
    const remainingProtein = Math.max(
      0,
      ((goalsRes.data?.daily_protein_g as number) ?? 0) -
        ((summaryRes.data?.protein_g as number) ?? 0),
    );
    const remainingCarbs = Math.max(
      0,
      ((goalsRes.data?.daily_carbs_g as number) ?? 0) -
        ((summaryRes.data?.carbs_g as number) ?? 0),
    );
    const remainingFat = Math.max(
      0,
      ((goalsRes.data?.daily_fat_g as number) ?? 0) -
        ((summaryRes.data?.fat_g as number) ?? 0),
    );

    // When custom target is used but caller has no remaining macros (already
    // hit goal), base macros on goal proportions instead of zero remaining so
    // the AI still gets a sensible protein/carb/fat hint.
    let targetProtein: number, targetCarbs: number, targetFat: number;
    if (customTargetCalories != null && remainingCalories <= 0 && goalCalories > 0) {
      const goalProtein = (goalsRes.data?.daily_protein_g as number) ?? 0;
      const goalCarbs = (goalsRes.data?.daily_carbs_g as number) ?? 0;
      const goalFat = (goalsRes.data?.daily_fat_g as number) ?? 0;
      targetProtein = goalProtein * fractionForMacros;
      targetCarbs = goalCarbs * fractionForMacros;
      targetFat = goalFat * fractionForMacros;
    } else {
      targetProtein = remainingProtein * fractionForMacros;
      targetCarbs = remainingCarbs * fractionForMacros;
      targetFat = remainingFat * fractionForMacros;
    }

    const target = {
      calories: targetCalories,
      protein: targetProtein,
      carbs: targetCarbs,
      fat: targetFat,
    };

    // ── Candidate menu (deterministic slices, ≤100 rows) ────────────────────
    const { data: rows, error: foodsError } = await admin
      .from('foods')
      .select('id, name, name_ar, calories, protein_g, carbs_g, fat_g, serving_size, serving_unit, category, image_url')
      .eq('is_custom', false)
      .in('category', Object.keys(CATEGORY_LIMITS))
      .order('category')
      .order('name');
    if (foodsError || !rows?.length) {
      console.error('foods query failed:', foodsError);
      return json({ error: 'foods_unavailable' }, 500);
    }
    const perCategory = new Map<string, number>();
    const menu: CatalogFood[] = [];
    const byId = new Map<string, CatalogFood>();
    for (const r of rows as CatalogFood[]) {
      const used = perCategory.get(r.category) ?? 0;
      if (used >= (CATEGORY_LIMITS[r.category] ?? 0)) continue;
      perCategory.set(r.category, used + 1);
      menu.push(r);
      byId.set(r.id, r);
    }

    // ── Gemini → validate → ONE corrective retry of the SAME call ───────────
    // No fallback model exists (PROJECT_MASTER §5): after one failed
    // validation the same prompt reruns with the correction note, then the
    // feature honestly reports it could not build a fitting meal.
    const { system, user } = buildPrompt(target, menu, mealType, style, fraction);
    const first = await callGemini(system, user);
    if (first.ok) {
      const verdict = validateAndEnrich(extractJsonObject(first.content), byId, targetCalories);
      if (verdict.ok) return json(verdict.payload);
      console.warn('gemini validation failed:', verdict.reason);

      const retry = await callGemini(
        system,
        `${user}\n\nIMPORTANT — your previous answer failed validation: ${verdict.reason}\nFix exactly that and return the corrected raw JSON object only.`,
      );
      if (retry.ok) {
        const retryVerdict = validateAndEnrich(extractJsonObject(retry.content), byId, targetCalories);
        if (retryVerdict.ok) return json(retryVerdict.payload);
        console.warn('gemini retry validation failed:', retryVerdict.reason);
      }
      return json({ error: 'no_match' }, 422);
    }
    return json({ error: 'ai_unavailable' }, 502);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('suggest-meal unexpected error:', message);
    return json({ error: message }, 400);
  }
});
