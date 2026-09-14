// Backfill real food images for the `foods` catalog.
//
// For every foods row whose image_url is NULL or still points at the old
// emoji placeholders/, search Pexels by the English name, download the best
// match, re-upload it to CoreGym's own `food-images` Storage bucket as
// foods/{id}.jpg, and store the public Storage URL in image_url.
//
// - Re-runnable: the pending set is derived from the DB, so a partial run
//   resumes where it stopped.
// - Search cache: normalized names share one Pexels call.
// - Curated terms: Egyptian/regional dishes + brand names that Pexels'
//   English search won't match (كشري, فول, Bisco, Chipsy, ...).
// - Rate limiting: searches are paced; HTTP 429 pauses per Retry-After.
// - Never guesses: zero results → image_url stays null (logged).
//
// Usage: node backfill_food_images.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ── config ──────────────────────────────────────────────────────────────────
const env = Object.fromEntries(
  fs
    .readFileSync(path.join(__dirname, ".env"), "utf8")
    .replace(/^\uFEFF/, "")
    .split(/\r?\n/)
    .filter((l) => l.includes("=") && !l.trim().startsWith("#"))
    .map((l) => [
      l.slice(0, l.indexOf("=")).trim(),
      l.slice(l.indexOf("=") + 1).trim().replace(/^"|"$/g, ""),
    ]),
);

const SUPABASE_URL = env.SUPABASE_URL;
const PEXELS_KEY = env.PEXELS_API_KEY;
const BUCKET = "food-images";
const SEARCH_PAUSE_MS = 1200; // pace Pexels searches
const SEARCH_ERR_PAUSE_MS = 60_000; // backoff on 429 / transient errors
const LOG_PATH = path.join(__dirname, "backfill_log.jsonl");
const SUMMARY_PATH = path.join(__dirname, "backfill_summary.json");

const supabase = createClient(SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

// ── curated search terms (normalized food name → Pexels query) ─────────────
// Pexels' search is English-oriented; Egyptian dishes and local brands need
// a hand-picked query or they return junk/zero results.
const CURATED = {
  // Egyptian / regional dishes
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
  "feteer with honey & cream": "feteer pastry",
  "feteer with nutella": "chocolate pastry",
  kunafa: "kunafa dessert",
  "konafa bel ashta": "kunafa dessert",
  basbousa: "basbousa dessert",
  "om ali": "om ali egyptian dessert",
  "mahshi warak enab": "stuffed grape leaves",
  "mahshi kousa": "stuffed zucchini",
  "bamia with meat": "okra stew with meat",
  fattah: "egyptian fattah",
  "macarona bechamel": "baked pasta bechamel",
  "roz bel laban": "rice pudding",
  muhallabia: "muhallabia pudding",
  "lokmet el qady": "loukoumades",
  "moussaka egyptian": "musaka",
  shakshuka: "shakshuka",
  karkade: "hibiscus tea",
  sobia: "sobia drink",
  "erk sous": "licorice drink",
  sahlab: "sahlab drink",
  termis: "lupini beans",
  dukkah: "dukkah spice mix",
  ishta: "clotted cream",
  "halawa tahiniya": "halva",
  // breads & cheeses
  "baladi bread": "egyptian baladi bread",
  "egyptian bread": "aish baladi egyptian bread",
  "shami bread": "pita bread",
  "fino bread": "baguette",
  "baladi butter": "ghee",
  "baladi ghee": "ghee",
  "baladi eggs": "brown eggs",
  "roumy cheese": "pecorino cheese wedge",
  "white cheese light": "feta cheese",
  "qareesh cheese": "cottage cheese bowl",
  // meats
  "liver sandwich": "fried liver sandwich",
  "sogok sausage": "sujuk sausage",
  "beef luncheon": "luncheon meat slices",
  "beef liver": "cooked beef liver",
  // brands / local products
  "bisco misr biscuits": "chocolate sandwich biscuits",
  "chipsy chips": "potato chips",
  "lays chips": "potato chips bag",
  doritos: "tortilla chips",
  pringles: "potato chips can",
  "molto wafer": "chocolate wafer",
  "corona chocolate": "chocolate bar",
  "juhayna fresh juice": "fruit juice",
  "rani mango juice": "mango juice",
  fayrouz: "malt beverage",
  "pita chips": "pita chips",
  // common drinks that need the cup/glass context
  ayran: "ayran yogurt drink",
  "black tea": "black tea cup",
  "turkish coffee": "turkish coffee cup",
  "black coffee": "black coffee cup",
  "fresh lemonade": "lemonade glass",
  "mango juice": "mango juice",
  "sugarcane juice": "sugarcane juice",
  "bubble tea": "bubble milk tea",
  frappuccino: "caramel frappuccino",
  "whole milk latte": "latte art",
  "protein shake": "protein shake glass",
  "whey protein shake": "protein shake glass",
  "whey protein": "protein powder scoop",
  "casein protein": "protein powder scoop",
  "high protein overnight oats": "overnight oats jar",
};

// ── normalization ───────────────────────────────────────────────────────────
// "chicken breast (grilled 150g)" → "chicken breast"; "banana" ×3 → one call.
function toSearchTerm(rawName) {
  let t = (rawName ?? "").toLowerCase();
  t = t.replace(/\([^)]*\)/g, " "); // parenthetical detail (qty, prep)
  t = t.replace(/\bx\s?\d+\b/g, " "); // "boiled eggs x3"
  t = t.replace(
    /\b\d+(\.\d+)?\s*(g|gr|gram|grams|kg|ml|l|oz|pcs|pieces|piece|slice|slices|cup|cups|scoop|scoops|tbsp|tsp|loaf|loaves|bottle|can|cans)\b/g,
    " ",
  );
  t = t.replace(/[^a-z&\s]/g, " ");
  t = t.replace(/\s+/g, " ").trim();
  return t;
}

function searchQueryFor(name) {
  const term = toSearchTerm(name);
  return { term, query: CURATED[term] ?? term };
}

// ── pexels ──────────────────────────────────────────────────────────────────
async function pexelsSearch(query) {
  const url =
    "https://api.pexels.com/v1/search?" +
    new URLSearchParams({ query, per_page: "3", orientation: "landscape" });
  for (let attempt = 1; attempt <= 2; attempt++) {
    const res = await fetch(url, { headers: { Authorization: PEXELS_KEY } });
    if (res.status === 429) {
      const wait = Number(res.headers.get("retry-after")) || 65;
      log(`rate-limited — pausing ${wait}s`);
      await sleep(wait * 1000);
      continue;
    }
    if (!res.ok) throw new Error(`pexels ${res.status}`);
    const json = await res.json();
    return json.photos ?? [];
  }
  throw new Error("pexels retries exhausted");
}

// ── helpers ─────────────────────────────────────────────────────────────────
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function logLine(obj) {
  fs.appendFileSync(LOG_PATH, JSON.stringify(obj) + "\n");
}
function log(msg) {
  console.log(`[${new Date().toISOString()}] ${msg}`);
}

// ── main ────────────────────────────────────────────────────────────────────
async function main() {
  log("loading pending foods (image_url null or placeholders/)…");
  const { data: pending, error } = await supabase
    .from("foods")
    .select("id, name, image_url")
    .or("image_url.is.null,image_url.like.%/placeholders/%")
    .order("name");
  if (error) throw new Error(`pending query failed: ${error.message}`);

  const stats = { processed: 0, matched: 0, noMatch: 0, errors: 0, cached: 0 };
  const searchCache = new Map(); // term → { status: 'ok'|'none', photoUrl? }

  log(`pending: ${pending.length} foods`);
  for (const food of pending) {
    const { term, query } = searchQueryFor(food.name);
    try {
      // 1. find a photo (with cache; one search per normalized term)
      let cached = searchCache.get(term);
      if (!cached) {
        const photos = await pexelsSearch(query);
        if (photos.length === 0 && CURATED[term]) {
          // curated term also empty → one generic retry with the bare term
          const retry = await pexelsSearch(term);
          cached = retry.length
            ? { status: "ok", photoUrl: retry[0].src.large }
            : { status: "none" };
        } else {
          cached = photos.length
            ? { status: "ok", photoUrl: photos[0].src.large }
            : { status: "none" };
        }
        searchCache.set(term, cached);
        await sleep(SEARCH_PAUSE_MS);
      } else {
        stats.cached++;
      }

      if (cached.status === "none") {
        stats.noMatch++;
        logLine({ id: food.id, name: food.name, term, query, status: "no-match" });
        continue; // image_url stays null — a missing photo beats a wrong one
      }

      // 2. download the photo
      const imgRes = await fetch(cached.photoUrl);
      if (!imgRes.ok) throw new Error(`download ${imgRes.status}`);
      const bytes = new Uint8Array(await imgRes.arrayBuffer());

      // 3. re-upload to CoreGym's bucket (service role — RLS-agnostic)
      const path = `foods/${food.id}.jpg`;
      const up = await supabase.storage.from(BUCKET).upload(path, bytes, {
        contentType: "image/jpeg",
        upsert: true,
      });
      if (up.error) throw new Error(`storage ${up.error.message}`);

      // 4. store CoreGym's own public URL
      const publicUrl = `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${path}`;
      const upd = await supabase
        .from("foods")
        .update({ image_url: publicUrl })
        .eq("id", food.id);
      if (upd.error) throw new Error(`update ${upd.error.message}`);

      stats.matched++;
      logLine({ id: food.id, name: food.name, term, status: "ok", image_url: publicUrl });
    } catch (e) {
      stats.errors++;
      logLine({ id: food.id, name: food.name, term, status: "error", error: String(e.message) });
      log(`ERROR ${food.name}: ${e.message} — pausing ${SEARCH_ERR_PAUSE_MS / 1000}s`);
      await sleep(SEARCH_ERR_PAUSE_MS);
    }
    stats.processed++;
    if (stats.processed % 25 === 0) {
      log(`progress ${stats.processed}/${pending.length} — matched ${stats.matched}, no-match ${stats.noMatch}, errors ${stats.errors}`);
    }
  }

  // 5. drop the old emoji placeholders once nothing references them
  const { count } = await supabase
    .from("foods")
    .select("id", { count: "exact", head: true })
    .like("image_url", "%/placeholders/%");
  if (count === 0) {
    const listed = await supabase.storage.from(BUCKET).list("placeholders", { limit: 100 });
    const paths = (listed.data ?? []).map((o) => `placeholders/${o.name}`);
    if (paths.length) {
      const del = await supabase.storage.from(BUCKET).remove(paths);
      log(`placeholders cleanup: removed ${paths.length} objects (errors: ${del.error?.message ?? "none"})`);
    }
  } else {
    log(`placeholders cleanup skipped: ${count} rows still reference them`);
  }

  const summary = { ...stats, pendingTotal: pending.length, finishedAt: new Date().toISOString() };
  fs.writeFileSync(SUMMARY_PATH, JSON.stringify(summary, null, 2));
  log(`DONE ${JSON.stringify(summary)}`);
}

main().catch((e) => {
  log(`FATAL: ${e.message}`);
  process.exit(1);
});
