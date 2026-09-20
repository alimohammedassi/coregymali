1// @ts-nocheck
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

const MAX_TEXT_LENGTH = 1000;

const ANALYSIS_PROMPT = `You are a nutrition expert reading a short text written by a fitness-app user
describing food or drink they ate or are about to eat.
The text may be in English or Arabic (including Egyptian dialect), possibly mixing
scripts and numerals in the same sentence.

Return ONLY a JSON object with exactly this shape:
{
  "is_food": boolean,
  "confidence": "low" | "medium" | "high",
  "notes": string,
  "items": [
    {
      "name": string,            // concise English name of the food item
      "name_ar": string | null,  // Arabic name (Egyptian dialect preferred), null if unknown
      "estimated_weight_g": number,
      "calories": number,
      "protein_g": number,
      "carbs_g": number,
      "fat_g": number,
      "fiber_g": number | null,        // REQUIRED best estimate — null only for plain water/black coffee
      "sugars_g": number | null,       // REQUIRED best estimate
      "sodium_mg": number | null,      // REQUIRED best estimate, milligrams
      "potassium_mg": number | null,   // milligrams
      "calcium_mg": number | null,     // milligrams
      "iron_mg": number | null,        // milligrams
      "cholesterol_mg": number | null, // milligrams
      "caffeine_mg": number | null     // milligrams
    }
  ]
}

Rules:
- If the text does not describe edible food/drink: set is_food to false, items to [], and explain briefly in notes.
- If it is food: identify each DISTINCT item mentioned ("2 eggs and toast" -> one object for eggs, one for toast).
- Estimate each item's portion weight in grams from any cues (numbers mean piece counts; cups, spoons, loaves);
  use a typical Egyptian portion when nothing is specified.
- calories and macros are estimates for THAT estimated portion.
- The micro-nutrient fields are for THAT estimated portion too.
- fiber_g, sugars_g and sodium_mg power the user's daily tracker, so ALWAYS give your best estimate for them from the typical composition of the food (fiber from grain/vegetable/fruit content, sugars from sweet ingredients and dairy, sodium from salt, cheese and processed items). Return null ONLY when the item is genuinely free of that nutrient (e.g. water, black coffee); otherwise a reasonable estimate beats null — the app must show a number. Never guess wildly. If the user names a packaged product, use its known label values.
- For the remaining micro-nutrients (potassium, calcium, iron, cholesterol, caffeine): estimate when reasonably confident, otherwise null.
- confidence reflects your certainty about identification AND portion estimates overall.
- notes should be one short sentence in English about the meal or any caveats.
- Numbers must be plain numbers, no units or ranges.`;

// Gemini intermittently answers 502/503/504 under load (measured ~40% of
// calls during an overload burst); one bad roll must not kill the log the
// user just typed, so retry up to 5 attempts with growing backoff.
async function generateContentWithRetry(model: string, apiKey: string, body: unknown): Promise<Response> {
  let lastRes: Response | null = null;
  for (let attempt = 1; attempt <= 5; attempt++) {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) },
    );
    if (res.ok || ![429, 502, 503, 504].includes(res.status)) return res;
    lastRes = res;
    // 429 says "retry in ~22s" (free-tier 20 RPM) — the growing waits reach
    // 22.5s total so the final attempt lands after the quota window rolls.
    if (attempt < 5) await new Promise((r) => setTimeout(r, 1500 * attempt));
  }
  return lastRes!;
}

function json(body: unknown, status = 200) {
  return Response.json(body, { status, headers: { 'Access-Control-Allow-Origin': '*' } });
}

// Micro-nutrient fields may be absent/null from Gemini — keep them NULL
// end-to-end instead of forcing 0 (0 means "measured zero").
const numOrNull = (v: any): number | null => {
  if (v == null) return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

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

    // ── Input ───────────────────────────────────────────────────────────────
    const { text } = await req.json().catch(() => ({}));
    if (!text || typeof text !== 'string' || text.trim().length === 0) {
      return json({ error: 'bad_request' }, 400);
    }
    const trimmed = text.trim().slice(0, MAX_TEXT_LENGTH);

    // ── Gemini text analysis (stateless — no persistence) ───────────────────
    try {
      const geminiRes = await generateContentWithRetry(GEMINI_MODEL, GEMINI_API_KEY, {
        contents: [
          {
            parts: [{ text: ANALYSIS_PROMPT }, { text: 'User input:\n' + trimmed }],
          },
        ],
        generationConfig: {
          temperature: 0.2,
          responseMimeType: 'application/json',
        },
      });

      if (!geminiRes.ok) {
        const detail = await geminiRes.text();
        console.error('Gemini error:', geminiRes.status, detail);
        throw new Error(`gemini_status_${geminiRes.status}`);
      }

      const geminiJson = await geminiRes.json();
      const raw = geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!raw) throw new Error('empty_gemini_response');

      const analysis = JSON.parse(raw);
      const isFood = analysis.is_food === true;
      const confidence = ['low', 'medium', 'high'].includes(analysis.confidence)
        ? analysis.confidence
        : 'medium';
      let items = Array.isArray(analysis.items)
        ? analysis.items.filter(
          (i: any) => i && typeof i.name === 'string' && i.name.trim().length > 0,
        )
        : [];
      if (!isFood) items = [];

      return json({
        is_food: isFood,
        confidence,
        notes: typeof analysis.notes === 'string' && analysis.notes.trim().length > 0 ? analysis.notes.trim() : null,
        items: items.map((i: any) => ({
          name: String(i.name).trim(),
          name_ar: i.name_ar ? String(i.name_ar).trim() : null,
          estimated_weight_g: Number(i.estimated_weight_g) || 0,
          calories: Number(i.calories) || 0,
          protein_g: Number(i.protein_g) || 0,
          carbs_g: Number(i.carbs_g) || 0,
          fat_g: Number(i.fat_g) || 0,
          fiber_g: numOrNull(i.fiber_g),
          sugars_g: numOrNull(i.sugars_g),
          sodium_mg: numOrNull(i.sodium_mg),
          potassium_mg: numOrNull(i.potassium_mg),
          calcium_mg: numOrNull(i.calcium_mg),
          iron_mg: numOrNull(i.iron_mg),
          cholesterol_mg: numOrNull(i.cholesterol_mg),
          caffeine_mg: numOrNull(i.caffeine_mg),
        })),
      });
    } catch (err) {
      console.error('analysis_failed:', err);
      return json({ error: 'analysis_failed' }, 502);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('log-food-text unexpected error:', message);
    return json({ error: message }, 400);
  }
});
