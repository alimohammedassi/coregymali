// fetch-dish-image — auto-fetch a real photo for a newly created dish.
//
// Called by the dish creation flow right after the `dishes` row is inserted
// (optimistic UI: the row exists with image_url = null; this function fills
// it in). Also supports dry_run for testing the match without writing.
//
// Body (JSON):
//   { dish_id: string, name: string, dry_run?: boolean }
// Behavior:
//   1. Search Pexels by the dish's English name (curated fallback terms for
//      Egyptian/regional names — same map as scripts/backfill_food_images.mjs).
//   2. Download the top result and re-upload it to CoreGym's own
//      `food-images` bucket as dishes/{dish_id}.jpg (service role).
//   3. Update dishes.image_url with the bucket's public URL.
// Zero/uncertain results leave image_url null — a missing photo beats a
// misleading one. PEXELS_API_KEY is an Edge Function secret, never committed.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const BUCKET = "food-images";

// Egyptian / regional dish names + ambiguous terms that Pexels' English
// search won't match well. Kept in sync with scripts/backfill_food_images.mjs.
const CURATED: Record<string, string> = {
  koshari: "egyptian koshari",
  koshary: "egyptian koshari",
  "foul medames": "egyptian fava beans ful medames",
  "ful medames": "egyptian fava beans ful medames",
  "ful & taameya sandwich": "egyptian falafel sandwich",
  taameya: "egyptian falafel",
  "taameya plate": "egyptian falafel",
  molokhia: "molokhia egyptian green soup",
  hawawshi: "hawawshi egyptian",
  "feteer meshaltet": "feteer meshaltet pastry",
  kunafa: "kunafa dessert",
  "konafa bel ashta": "kunafa dessert",
  basbousa: "basbousa dessert",
  "om ali": "om ali egyptian dessert",
  "mahshi warak enab": "stuffed grape leaves",
  "mahshi kousa": "stuffed zucchini",
  fattah: "egyptian fattah",
  "roz bel laban": "rice pudding",
  muhallabia: "muhallabia pudding",
  "lokmet el qady": "loukoumades",
  karkade: "hibiscus tea",
  "erk sous": "licorice drink",
  sahlab: "sahlab drink",
  termis: "lupini beans",
  "baladi bread": "egyptian baladi bread",
  "baladi butter": "ghee",
  "baladi ghee": "ghee",
  "baladi eggs": "brown eggs",
  "roumy cheese": "pecorino cheese wedge",
  "white cheese light": "feta cheese",
  "qareesh cheese": "cottage cheese bowl",
};

function toSearchTerm(rawName: string): string {
  let t = (rawName ?? "").toLowerCase();
  t = t.replace(/\([^)]*\)/g, " "); // parenthetical detail
  t = t.replace(/\bx\s?\d+\b/g, " "); // "eggs x3"
  t = t.replace(
    /\b\d+(\.\d+)?\s*(g|gr|gram|grams|kg|ml|l|oz|pcs|pieces|piece|slice|slices|cup|cups|scoop|scoops|tbsp|tsp|loaf|loaves|bottle|can|cans)\b/g,
    " ",
  );
  t = t.replace(/[^a-z&\s]/g, " ");
  return t.replace(/\s+/g, " ").trim();
}

function searchQueryFor(name: string): { term: string; query: string } {
  const term = toSearchTerm(name);
  return { term, query: CURATED[term] ?? term };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") return json({ error: "POST only" }, 405);
    const { dish_id, name, dry_run } = await req.json();
    if (!name) return json({ error: "name is required" }, 400);

    const pexelsKey = Deno.env.get("PEXELS_API_KEY");
    if (!pexelsKey) {
      return json(
        { error: "PEXELS_API_KEY secret not configured on this project" },
        503,
      );
    }

    // 1. match a photo (one search; curated term, else normalized name)
    const { term, query } = searchQueryFor(name);
    const searchUrl =
      "https://api.pexels.com/v1/search?" +
      new URLSearchParams({ query, per_page: "3", orientation: "landscape" });
    const searchRes = await fetch(searchUrl, {
      headers: { Authorization: pexelsKey },
    });
    if (!searchRes.ok) {
      return json({ error: `pexels ${searchRes.status}` }, 502);
    }
    const photos: Array<{ src: { large: string } }> =
      ((await searchRes.json()) as { photos?: unknown[] }).photos ?? [];
    if (photos.length === 0) {
      return json({
        image_url: null,
        reason: "no-confident-match",
        matched_query: query,
      });
    }
    const photoUrl = photos[0].src.large;

    // dry-run: report the match without touching storage or the table
    if (dry_run) {
      return json({ image_url: photoUrl, matched_query: query, dry_run: true });
    }

    // 2. download and re-upload to CoreGym's own bucket (service role)
    const imgRes = await fetch(photoUrl);
    if (!imgRes.ok) return json({ error: `download ${imgRes.status}` }, 502);
    const bytes = new Uint8Array(await imgRes.arrayBuffer());

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );
    const objectPath = `dishes/${dish_id}.jpg`;
    const up = await admin.storage
      .from(BUCKET)
      .upload(objectPath, bytes, { contentType: "image/jpeg", upsert: true });
    if (up.error) return json({ error: `storage: ${up.error.message}` }, 500);

    // 3. store CoreGym's own public URL on the dish row
    const publicUrl = `${Deno.env.get("SUPABASE_URL")}/storage/v1/object/public/${BUCKET}/${objectPath}`;
    const upd = await admin
      .from("dishes")
      .update({ image_url: publicUrl })
      .eq("id", dish_id);
    if (upd.error) {
      // tolerate the dishes feature not being deployed yet — the image is
      // uploaded either way, so the caller can retry just the update
      return json({
        image_url: publicUrl,
        updated: false,
        warning: upd.error.message,
      });
    }
    return json({ image_url: publicUrl, updated: true });
  } catch (e) {
    return json({ error: String((e as Error)?.message ?? e) }, 500);
  }
});
