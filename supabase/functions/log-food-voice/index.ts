// @ts-nocheck
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

const ANALYSIS_PROMPT = `You are a nutrition expert listening to a voice recording for a fitness app food diary.
Transcribe the speech and determine whether the speaker is actually describing food or drink they ate/are about to eat.

Return ONLY a JSON object with exactly this shape:
{
  "transcript": string,
  "is_food": boolean,
  "confidence": "low" | "medium" | "high",
  "notes": string,
  "items": [
    {
      "name": string,            // English name of the food item
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
- transcript is the verbatim transcription of the speech (keep the original language, usually Arabic).
- If the recording does not describe edible food/drink: set is_food to false, items to [], and explain briefly in notes.
- If it is food: identify each distinct item mentioned, estimate its portion weight in grams (from any cues like cups, spoons, pieces), then estimate calories and macros for THAT estimated portion.
- The micro-nutrient fields are for THAT estimated portion too.
- fiber_g, sugars_g and sodium_mg power the user's daily tracker, so ALWAYS give your best estimate for them from the typical composition of the food (fiber from grain/vegetable/fruit content, sugars from sweet ingredients and dairy, sodium from salt, cheese and processed items). Return null ONLY when the item is genuinely free of that nutrient (e.g. water, black coffee); otherwise a reasonable estimate beats null — the app must show a number. Never guess wildly. If the speaker names a packaged product, use its known label values.
- For the remaining micro-nutrients (potassium, calcium, iron, cholesterol, caffeine): estimate when reasonably confident, otherwise null.
- confidence reflects how sure you are about the transcription AND the identification AND portion estimates overall.
- notes should be one short sentence in English about the meal or any caveats.
- Numbers must be plain numbers, no units or ranges.`;

// Gemini intermittently answers 502/503/504 under load (measured ~40% of
// calls during an overload burst); one bad roll must not kill the log the
// user just recorded, so retry up to 5 attempts with growing backoff.
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

const AUDIO_EXTENSIONS: Record<string, string> = {
  'audio/mp4': '.m4a',
  'audio/aac': '.m4a',
  'audio/x-m4a': '.m4a',
  'audio/mpeg': '.mp3',
  'audio/mp3': '.mp3',
  'audio/wav': '.wav',
  'audio/x-wav': '.wav',
  'audio/ogg': '.ogg',
  'audio/flac': '.flac',
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
    const user = userData.user;

    // ── Input ───────────────────────────────────────────────────────────────
    const { audioBase64, mimeType } = await req.json().catch(() => ({}));
    if (!audioBase64 || typeof audioBase64 !== 'string') {
      return json({ error: 'bad_request' }, 400);
    }
    // Strip data-URL prefix if the client sent one.
    const base64Data = audioBase64.includes(',') ? audioBase64.split(',')[1] : audioBase64;
    const mime =
      typeof mimeType === 'string' && mimeType.startsWith('audio/')
        ? mimeType
        : 'audio/mp4';
    const ext = AUDIO_EXTENSIONS[mime] ?? '.m4a';

    // ── Gemini audio analysis ───────────────────────────────────────────────
    let analysis: {
      transcript: string;
      is_food: boolean;
      confidence: string;
      notes: string | null;
      items: any[];
    };
    try {
      const geminiRes = await generateContentWithRetry(GEMINI_MODEL, GEMINI_API_KEY, {
        contents: [
          {
            parts: [
              { text: ANALYSIS_PROMPT },
              { inline_data: { mime_type: mime, data: base64Data } },
            ],
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
      const text = geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!text) throw new Error('empty_gemini_response');

      analysis = JSON.parse(text);
      analysis.transcript =
        typeof analysis.transcript === 'string' ? analysis.transcript.trim() : '';
      analysis.is_food = analysis.is_food === true;
      analysis.confidence = ['low', 'medium', 'high'].includes(analysis.confidence)
        ? analysis.confidence
        : 'medium';
      analysis.items = Array.isArray(analysis.items)
        ? analysis.items.filter(
            (i: any) => i && typeof i.name === 'string' && i.name.trim().length > 0,
          )
        : [];
      if (!analysis.is_food) analysis.items = [];
    } catch (err) {
      console.error('analysis_failed:', err);
      return json({ error: 'analysis_failed' }, 502);
    }

    // ── Persist: storage upload + DB rows ───────────────────────────────────
    const logId = crypto.randomUUID();
    const audioPath = `${user.id}/${logId}${ext}`;

    try {
      const bytes = Uint8Array.from(atob(base64Data), (c) => c.charCodeAt(0));
      const { error: uploadError } = await admin.storage
        .from('voice-food-logs')
        .upload(audioPath, bytes, { contentType: mime, upsert: false });
      if (uploadError) throw new Error(`storage: ${uploadError.message}`);

      const { error: logInsertError } = await admin.from('voice_food_logs').insert({
        id: logId,
        user_id: user.id,
        audio_path: audioPath,
        transcript: analysis.transcript || null,
        is_food: analysis.is_food,
        confidence: analysis.confidence,
        notes: analysis.notes ?? null,
      });
      if (logInsertError) throw new Error(`voice_food_logs: ${logInsertError.message}`);

      let itemRows: any[] = [];
      if (analysis.items.length > 0) {
        const itemPayload = analysis.items.map((i: any) => ({
          log_id: logId,
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
        }));

        // Strip the micro-nutrient keys and retry once if the deployment
        // predates the additional-nutrients migration (missing column).
        const insertItems = async (payload: any[]) => {
          const { data, error } = await admin
            .from('voice_food_log_items')
            .insert(payload)
            .select();
          if (error && error.code === 'PGRST204') {
            const legacy = payload.map((row) => {
              const { fiber_g, sugars_g, sodium_mg, potassium_mg, calcium_mg,
                iron_mg, cholesterol_mg, caffeine_mg, ...rest } = row;
              return rest;
            });
            const retry = await admin.from('voice_food_log_items').insert(legacy).select();
            if (retry.error) throw new Error(`voice_food_log_items: ${retry.error.message}`);
            return retry.data ?? [];
          }
          if (error) throw new Error(`voice_food_log_items: ${error.message}`);
          return data ?? [];
        };
        itemRows = await insertItems(itemPayload);
      }

      return json({
        log_id: logId,
        audio_path: audioPath,
        transcript: analysis.transcript || null,
        is_food: analysis.is_food,
        confidence: analysis.confidence,
        notes: analysis.notes ?? null,
        items: itemRows.map((i: any) => ({
          id: i.id,
          name: i.name,
          name_ar: i.name_ar,
          estimated_weight_g: Number(i.estimated_weight_g),
          calories: Number(i.calories),
          protein_g: Number(i.protein_g),
          carbs_g: Number(i.carbs_g),
          fat_g: Number(i.fat_g),
          fiber_g: i.fiber_g ?? null,
          sugars_g: i.sugars_g ?? null,
          sodium_mg: i.sodium_mg ?? null,
          potassium_mg: i.potassium_mg ?? null,
          calcium_mg: i.calcium_mg ?? null,
          iron_mg: i.iron_mg ?? null,
          cholesterol_mg: i.cholesterol_mg ?? null,
          caffeine_mg: i.caffeine_mg ?? null,
        })),
      });
    } catch (err) {
      // Gemini succeeded but saving failed — surface a distinct code so the
      // client can tell the user the analysis worked but nothing was stored.
      console.error('persist_failed:', err);
      return json({ error: 'persist_failed' }, 500);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('log-food-voice unexpected error:', message);
    return json({ error: message }, 400);
  }
});
