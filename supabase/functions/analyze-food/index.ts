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

const ANALYSIS_PROMPT = `You are a nutrition expert analyzing a photo for a fitness app.
Look at the image and determine whether it clearly shows food or drink.

Return ONLY a JSON object with exactly this shape:
{
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
      "fat_g": number
    }
  ]
}

Rules:
- If the image does not clearly contain edible food/drink: set is_food to false, items to [], and explain briefly in notes.
- If it is food: identify each distinct item on the plate/in the frame, estimate its portion weight in grams from visual cues (plate size, utensils, packaging), then estimate calories and macros for THAT estimated portion.
- confidence reflects how sure you are about the identification AND portion estimates overall.
- notes should be one short sentence in English about the meal or any caveats.
- Numbers must be plain numbers, no units or ranges.`;

function json(body: unknown, status = 200) {
  return Response.json(body, { status, headers: { 'Access-Control-Allow-Origin': '*' } });
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
    const user = userData.user;

    // ── Input ───────────────────────────────────────────────────────────────
    const { imageBase64, mimeType } = await req.json().catch(() => ({}));
    if (!imageBase64 || typeof imageBase64 !== 'string') {
      return json({ error: 'bad_request' }, 400);
    }
    // Strip data-URL prefix if the client sent one.
    const base64Data = imageBase64.includes(',') ? imageBase64.split(',')[1] : imageBase64;
    const mime = typeof mimeType === 'string' && mimeType.startsWith('image/') ? mimeType : 'image/jpeg';

    // ── Gemini Vision analysis ──────────────────────────────────────────────
    let analysis: { is_food: boolean; confidence: string; notes: string | null; items: any[] };
    try {
      const geminiRes = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
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
          }),
        },
      );

      if (!geminiRes.ok) {
        const detail = await geminiRes.text();
        console.error('Gemini error:', geminiRes.status, detail);
        throw new Error(`gemini_status_${geminiRes.status}`);
      }

      const geminiJson = await geminiRes.json();
      const text = geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!text) throw new Error('empty_gemini_response');

      analysis = JSON.parse(text);
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
    const scanId = crypto.randomUUID();
    const imagePath = `${user.id}/${scanId}.jpg`;

    try {
      const bytes = Uint8Array.from(atob(base64Data), (c) => c.charCodeAt(0));
      const { error: uploadError } = await admin.storage
        .from('food-scans')
        .upload(imagePath, bytes, { contentType: mime, upsert: false });
      if (uploadError) throw new Error(`storage: ${uploadError.message}`);

      const { error: scanInsertError } = await admin.from('food_scans').insert({
        id: scanId,
        user_id: user.id,
        image_path: imagePath,
        is_food: analysis.is_food,
        confidence: analysis.confidence,
        notes: analysis.notes ?? null,
      });
      if (scanInsertError) throw new Error(`food_scans: ${scanInsertError.message}`);

      let itemRows: any[] = [];
      if (analysis.items.length > 0) {
        const itemPayload = analysis.items.map((i: any) => ({
          scan_id: scanId,
          name: String(i.name).trim(),
          name_ar: i.name_ar ? String(i.name_ar).trim() : null,
          estimated_weight_g: Number(i.estimated_weight_g) || 0,
          calories: Number(i.calories) || 0,
          protein_g: Number(i.protein_g) || 0,
          carbs_g: Number(i.carbs_g) || 0,
          fat_g: Number(i.fat_g) || 0,
        }));

        const { data, error: itemsInsertError } = await admin
          .from('food_scan_items')
          .insert(itemPayload)
          .select();
        if (itemsInsertError) throw new Error(`food_scan_items: ${itemsInsertError.message}`);
        itemRows = data ?? [];
      }

      return json({
        scan_id: scanId,
        image_path: imagePath,
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
    console.error('analyze-food unexpected error:', message);
    return json({ error: message }, 400);
  }
});
