// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')!;
const GEMINI_MODEL = 'gemini-3.6-flash';
const OFF_PRODUCT_URL = 'https://world.openfoodfacts.org/api/v2/product';

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const GEMINI_ESTIMATE_PROMPT = `You are a nutrition database expert for a fitness app.
A user scanned a product barcode that was not found in Open Food Facts.
Estimate the standard per-100g nutrition facts for this packaged product.

Return ONLY a JSON object with exactly this shape:
{
  "product_name": string,
  "product_name_ar": string | null,
  "brand": string | null,
  "calories": number,      // kcal per 100g
  "protein_g": number,
  "carbs_g": number,
  "fat_g": number,
  "confidence": "low" | "medium" | "high"
}

Rules:
- Base the estimate on what this product typically contains per 100g.
- Numbers must be plain numbers, no units or ranges.
- confidence reflects how sure you are about the identification and estimates.`;

function json(body: unknown, status = 200) {
  return Response.json(body, { status, headers: { 'Access-Control-Allow-Origin': '*' } });
}

function isValidBarcode(barcode: string): boolean {
  return /^\d{6,14}$/.test(barcode);
}

// ── Tier 2: Open Food Facts ──────────────────────────────────────────────────
async function fetchFromOpenFoodFacts(barcode: string) {
  try {
    const res = await fetch(`${OFF_PRODUCT_URL}/${barcode}.json`, {
      headers: {
        'User-Agent': 'CoreGym - CoreGym Android App - v1.0',
        Accept: 'application/json',
      },
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) return null;
    const data = await res.json();
    if (data?.status !== 1 || !data?.product) return null;

    const p = data.product;
    const n = p.nutriments ?? {};

    const kcal = Number(n['energy-kcal_100g']) || 0;
    const protein = Number(n['proteins_100g']) || 0;
    const carbs = Number(n['carbohydrates_100g']) || 0;
    const fat = Number(n['fat_100g']) || 0;

    // Usable only if we at least got real calorie data.
    if (kcal <= 0 && protein <= 0 && carbs <= 0 && fat <= 0) return null;

    const brandRaw = typeof p.brands === 'string' ? p.brands.split(',')[0]?.trim() : null;
    const servingQty = Number(p.serving_quantity);

    return {
      product_name:
        (typeof p.product_name === 'string' && p.product_name.trim()) ||
        (typeof p.generic_name === 'string' && p.generic_name.trim()) ||
        `Product ${barcode}`,
      product_name_ar:
        typeof p.product_name_ar === 'string' && p.product_name_ar.trim()
          ? p.product_name_ar.trim()
          : null,
      brand: brandRaw || null,
      serving_size_g: Number.isFinite(servingQty) && servingQty > 0 ? servingQty : 100,
      calories: kcal,
      protein_g: protein,
      carbs_g: carbs,
      fat_g: fat,
      source: 'openfoodfacts' as const,
      confidence: kcal > 0 ? 'high' : 'medium',
    };
  } catch (_) {
    // Network/timeout — treat as "no match", caller decides whether to continue.
    throw new Error('off_unreachable');
  }
}

// ── Tier 3: Gemini text-only estimate ────────────────────────────────────────
async function estimateWithGemini(barcode: string, productNameHint?: string, partial?: any) {
  const contextLines = [
    `Barcode: ${barcode}`,
    productNameHint ? `User-provided product name: "${productNameHint}"` : null,
    partial?.product_name ? `Open Food Facts name: "${partial.product_name}"` : null,
    partial?.brand ? `Brand: "${partial.brand}"` : null,
    partial
      ? `Partial nutrition per 100g from Open Food Facts: calories=${partial.calories}, protein=${partial.protein_g}g, carbs=${partial.carbs_g}g, fat=${partial.fat_g}g`
      : null,
  ]
    .filter(Boolean)
    .join('\n');

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: `${GEMINI_ESTIMATE_PROMPT}\n\n${contextLines}` }] }],
        generationConfig: {
          temperature: 0.2,
          responseMimeType: 'application/json',
        },
      }),
    },
  );

  if (!res.ok) {
    const detail = await res.text();
    console.error('Gemini error:', res.status, detail);
    throw new Error(`gemini_status_${res.status}`);
  }

  const geminiJson = await res.json();
  const text = geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error('empty_gemini_response');

  const parsed = JSON.parse(text);
  return {
    product_name:
      (typeof parsed.product_name === 'string' && parsed.product_name.trim()) ||
      (productNameHint?.trim() || `Product ${barcode}`),
    product_name_ar:
      typeof parsed.product_name_ar === 'string' && parsed.product_name_ar.trim()
        ? parsed.product_name_ar.trim()
        : null,
    brand:
      (typeof parsed.brand === 'string' && parsed.brand.trim()) || partial?.brand || null,
    serving_size_g: 100,
    calories: Number(parsed.calories) || 0,
    protein_g: Number(parsed.protein_g) || 0,
    carbs_g: Number(parsed.carbs_g) || 0,
    fat_g: Number(parsed.fat_g) || 0,
    source: 'gemini_estimate' as const,
    confidence: ['low', 'medium', 'high'].includes(parsed.confidence)
      ? parsed.confidence
      : 'low',
  };
}

// ── Cache write (never blocks the response on failure) ───────────────────────
async function cacheProduct(product: any): Promise<boolean> {
  try {
    const { error } = await admin.from('barcode_products').upsert(product, {
      onConflict: 'barcode',
    });
    if (error) throw new Error(error.message);
    return true;
  } catch (err) {
    console.error('persist_failed (cache write):', err);
    return false;
  }
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

    // ── Input ───────────────────────────────────────────────────────────────
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== 'object') return json({ error: 'invalid_request_body' }, 400);

    const barcode = typeof body.barcode === 'string' ? body.barcode.trim() : '';
    const productNameHint =
      typeof body.productNameHint === 'string' && body.productNameHint.trim()
        ? body.productNameHint.trim()
        : undefined;

    if (!isValidBarcode(barcode)) return json({ error: 'invalid_request_body' }, 400);

    // ── Tier 1: shared cache ────────────────────────────────────────────────
    const { data: cached } = await admin
      .from('barcode_products')
      .select('*')
      .eq('barcode', barcode)
      .maybeSingle();

    if (cached) {
      // Fire-and-forget counter bump; never block or fail on this.
      admin
        .from('barcode_products')
        .update({ lookup_count: (cached.lookup_count ?? 1) + 1 })
        .eq('barcode', barcode)
        .then(({ error }) => {
          if (error) console.error('lookup_count bump failed:', error.message);
        });

      return json({
        result: {
          barcode: cached.barcode,
          product_name: cached.product_name,
          product_name_ar: cached.product_name_ar,
          brand: cached.brand,
          serving_size_g: cached.serving_size_g != null
            ? Number(cached.serving_size_g)
            : 100,
          calories: Number(cached.calories),
          protein_g: Number(cached.protein_g),
          carbs_g: Number(cached.carbs_g),
          fat_g: Number(cached.fat_g),
          source: 'cache',
          confidence: cached.confidence,
          needs_name_hint: false,
        },
      });
    }

    // ── Tier 2: Open Food Facts ─────────────────────────────────────────────
    let offResult: any = null;
    try {
      offResult = await fetchFromOpenFoodFacts(barcode);
    } catch (_) {
      // Network/timeout — surface as upstream_unreachable per convention.
      return json({ error: 'upstream_unreachable' }, 502);
    }

    const hasCompleteData =
      offResult != null &&
      offResult.calories > 0 &&
      (offResult.protein_g > 0 || offResult.carbs_g > 0 || offResult.fat_g > 0);

    if (offResult != null && hasCompleteData) {
      const cachedOk = await cacheProduct(offResult);
      return json({
        result: { ...offResult, needs_name_hint: false },
        ...(cachedOk ? {} : { warning: 'persist_failed' }),
      });
    }

    // Tier 2 gave us nothing usable. If we don't even have partial info
    // (name/brand) to feed the estimator, ask the user for a product name
    // first — an expected UX branch, not an error.
    if (offResult == null && !productNameHint) {
      return json({
        result: {
          barcode,
          needs_name_hint: true,
        },
      });
    }

    // ── Tier 3: Gemini text-only estimate ───────────────────────────────────
    try {
      const estimate = await estimateWithGemini(barcode, productNameHint, offResult ?? undefined);
      const cachedOk = await cacheProduct(estimate);
      return json({
        result: { ...estimate, needs_name_hint: false },
        ...(cachedOk ? {} : { warning: 'persist_failed' }),
      });
    } catch (geminiErr) {
      console.error('analysis_failed:', geminiErr);
      return json({ error: 'analysis_failed' }, 502);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    if (message.includes('fetch') || message.includes('timeout')) {
      return json({ error: 'upstream_unreachable' }, 502);
    }
    console.error('lookup-barcode unexpected error:', message);
    return json({ error: 'invalid_request_body' }, 400);
  }
});
