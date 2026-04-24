/**
 * MapPOI seed service — extracted from scripts/seedMapPois.js so the same
 * logic can be triggered from an admin endpoint (admin dashboard → PawMap
 * tab → "Seed country" button) without spawning a CLI process.
 *
 * Overpass API can be slow (60-120s per country), so the admin endpoint
 * calls `runSeed(...)` with await-less / background semantics and tracks
 * job status in a simple in-memory registry exposed via getJobStatus().
 *
 * Covers the 27 EU members + Switzerland + United Kingdom = 29 countries,
 * which is "toute l'Europe" in practical terms for a pet-sitting app.
 */

const axios = require('axios').default;
const MapPOI = require('../models/MapPOI');
const logger = require('../utils/logger');

// ─── Overpass tag filters per category ──────────────────────────────────────
// v19.1.5 — widened filters so beach + trainer return something.
//   beach  : natural=beach + dog=yes  (plus courant que leisure=beach_resort)
//   trainer: shop=dog_training OU match de nom multi-langues (FR/EN/DE/IT/ES/PT)
//            (car il n'y a pas de tag OSM standard pour les éducateurs canins).
// v20.0.19 — widened filters again : les filtres stricts `["dog"="yes"]`
// sur beach/hotel/restaurant renvoyaient ~zéro POI parce que ce tag est
// très rare dans OSM. On relâche :
//   beach      : toutes les plages naturelles (la plupart acceptent les
//                chiens ou signalent l'interdiction sur place)
//   hotel      : tous les hôtels (user peut check pet-friendly lui-même)
//   restaurant : tous les restaurants (idem)
//   groomer    : aussi `shop=pet` (certaines toiletteurs sont taggés ainsi)
//   trainer    : shop=dog_training + club_sport ∈ {dog_training, agility}
// Avant ce fix, Daniel voyait "Batch done 0 POIs" sur les 29 pays pour
// toutes les nouvelles catégories.
const CATEGORY_TAGS = {
  vet: '["amenity"="veterinary"]',
  shop: '["shop"~"pet"]',
  groomer: '["shop"="pet_grooming"]',
  park: '["leisure"="dog_park"]',
  beach: '["natural"="beach"]',
  water: '["amenity"="drinking_water"]',
  trainer: '["shop"="dog_training"]',
  trainerByName: '["name"~"dog trainer|educateur canin|éducateur canin|hundetrainer|addestratore cani|adiestrador canino|treinador canino",i]',
  hotel: '["tourism"="hotel"]',
  restaurant: '["amenity"="restaurant"]',
};

// ─── Country bboxes — [south, west, north, east] ────────────────────────────
// Approximate bounding boxes for every EU member + CH + GB. Islands that
// are far from the mainland (e.g. La Réunion, Canaries) are intentionally
// excluded to keep Overpass queries fast.
const COUNTRY_BBOX = {
  FR: [41.3, -5.4, 51.2, 9.6],
  DE: [47.3, 5.9, 55.1, 15.0],
  ES: [36.0, -9.3, 43.8, 4.3],
  IT: [35.5, 6.6, 47.1, 18.5],
  PT: [37.0, -9.5, 42.2, -6.2],
  NL: [50.7, 3.3, 53.6, 7.2],
  BE: [49.5, 2.5, 51.6, 6.4],
  LU: [49.4, 5.7, 50.2, 6.5],
  AT: [46.3, 9.5, 49.0, 17.2],
  CH: [45.8, 5.9, 47.9, 10.6],
  GB: [49.9, -8.6, 58.7, 1.8],
  IE: [51.4, -10.6, 55.4, -5.9],
  DK: [54.5, 8.0, 57.8, 12.7],
  SE: [55.3, 10.9, 69.1, 24.2],
  NO: [57.9, 4.4, 71.2, 31.3],
  FI: [59.7, 20.5, 70.1, 31.6],
  PL: [49.0, 14.1, 54.8, 24.2],
  CZ: [48.5, 12.1, 51.1, 18.9],
  SK: [47.7, 16.8, 49.6, 22.6],
  HU: [45.7, 16.1, 48.6, 22.9],
  RO: [43.6, 20.3, 48.3, 29.7],
  GR: [34.8, 19.4, 41.7, 28.2],
  HR: [42.4, 13.5, 46.5, 19.4],
  SI: [45.4, 13.4, 46.9, 16.6],
  BG: [41.2, 22.4, 44.2, 28.6],
  EE: [57.5, 21.8, 59.7, 28.2],
  LV: [55.7, 21.0, 58.1, 28.2],
  LT: [53.9, 20.9, 56.4, 26.9],
  MT: [35.8, 14.2, 36.1, 14.6],
  CY: [34.6, 32.3, 35.7, 34.6],
};

const ALL_EU_COUNTRIES = Object.keys(COUNTRY_BBOX);

// ─── Job registry — simple in-memory tracker ────────────────────────────────
// Resets on every server restart (Render redeploys), which is acceptable:
// the POI data is persisted in Mongo so a restart doesn't lose anything,
// and the admin can just re-trigger the seed if it was interrupted.
const jobs = new Map();

function buildOverpassQuery(bbox, tagFilters, { limit } = {}) {
  const bboxStr = bbox.join(',');
  const unions = tagFilters
    .map((tf) => `node${tf}(${bboxStr});way${tf}(${bboxStr});`)
    .join('');
  // v20.0.19 — syntaxe Overpass stricte : ordre documenté est
  // `out [limit] [verbosity] [geometry];`. Avant ce fix on avait
  // `out center tags 2000;` que certains parsers Overpass rejettent
  // silencieusement → retourne {} au lieu de {elements:[...]} →
  // elements array undefined → seed 0 POI (avec status:done).
  // On ajoute aussi maxsize pour éviter le rejet sur grosse bbox.
  const outClause = (Number.isFinite(Number(limit)) && Number(limit) > 0)
    ? `out ${Number(limit)} center;`
    : 'out center;';
  return `[out:json][timeout:90][maxsize:536870912];(${unions});${outClause}`;
}

// v20.0.19 — Liste d'endpoints Overpass publics à essayer dans l'ordre.
// `overpass-api.de` rejetait nos POST en 406 (politique fair-use stricte).
// On utilise GET avec `?data=...` (format officiel documenté) + on bascule
// vers des mirrors si le premier rate-limit/refuse.
const OVERPASS_ENDPOINTS = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://lz4.overpass-api.de/api/interpreter',
  'https://z.overpass-api.de/api/interpreter',
];

async function fetchOverpass(query) {
  // v20.0.19 — CRITICAL FIX : on passe en GET (format documenté Overpass),
  // le serveur attend exactement `?data=<query>`. Axios POST string body
  // était interprété bizarrement → HTTP 406 sur toutes les requêtes. On
  // ajoute aussi un User-Agent identifiant + Accept JSON.
  let lastErr = null;
  for (const url of OVERPASS_ENDPOINTS) {
    try {
      const res = await axios.get(url, {
        params: { data: query },
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'HoPetSit/1.0 (admin seed; contact: hopetsit@gmail.com)',
        },
        timeout: 120000,
      });
      if (!res.data || !Array.isArray(res.data.elements)) {
        const preview = typeof res.data === 'string'
          ? res.data.slice(0, 300)
          : JSON.stringify(res.data || {}).slice(0, 300);
        logger.warn?.(`[seed] Overpass ${url} réponse inattendue: ${preview}`);
        lastErr = new Error('no elements');
        continue; // try next endpoint
      }
      return res.data.elements;
    } catch (e) {
      lastErr = e;
      // 429 (rate limit) ou 503 → bascule sur mirror suivant sans log
      // 4xx autres → log pour diag
      const code = e?.response?.status;
      if (code && code !== 429 && code !== 503 && code !== 504) {
        logger.warn?.(`[seed] Overpass ${url} HTTP ${code} — tente mirror suivant`);
      }
      continue;
    }
  }
  throw lastErr || new Error('All Overpass endpoints failed');
}

function elementToPoi(el, category, country) {
  const tags = el.tags || {};
  const lat = el.lat || (el.center && el.center.lat);
  const lon = el.lon || (el.center && el.center.lon);
  if (lat == null || lon == null) return null;
  return {
    title: tags.name || tags['name:fr'] || tags['name:en'] || 'Unnamed',
    description: tags.description || '',
    category,
    location: {
      type: 'Point',
      coordinates: [lon, lat],
      city: tags['addr:city'] || '',
      country: country || tags['addr:country'] || '',
    },
    address: [
      tags['addr:housenumber'],
      tags['addr:street'],
      tags['addr:postcode'],
      tags['addr:city'],
    ]
      .filter(Boolean)
      .join(', '),
    phone: tags.phone || tags['contact:phone'] || '',
    website: tags.website || tags['contact:website'] || '',
    openingHours: tags.opening_hours || '',
    source: 'seed',
    osmId: `${el.type}/${el.id}`,
    status: 'active',
  };
}

// v20.0.19 — per-category safety caps to prevent Overpass timeouts on
// categories that have millions of entries in OSM (hotels, restaurants,
// beaches). Previous widened filters removed the `["dog"="yes"]` gate so
// the result counts explode → timeout → 0 POI inserted.
const CATEGORY_DEFAULT_LIMITS = {
  vet: 2000,
  shop: 2000,
  groomer: 2000,
  park: 2000,
  beach: 500,
  water: 2000,
  trainer: 500,
  hotel: 1500,
  restaurant: 2000,
};

async function seedCategory({ category, bbox, country, limit }) {
  const tag = CATEGORY_TAGS[category];
  if (!tag) return { inserted: 0, skipped: 0 };
  // v19.1.5 — some categories merge multiple tag filters (e.g. trainer uses
  // BOTH shop=dog_training AND a multilingual name regex).
  const extraTags = [];
  if (category === 'trainer' && CATEGORY_TAGS.trainerByName) {
    extraTags.push(CATEGORY_TAGS.trainerByName);
  }
  // v20.0.19 — applique un cap même si le caller n'a pas passé de limit.
  const effectiveLimit = (Number.isFinite(Number(limit)) && Number(limit) > 0)
    ? Number(limit)
    : (CATEGORY_DEFAULT_LIMITS[category] || 2000);
  const query = buildOverpassQuery(bbox, [tag, ...extraTags], {
    limit: effectiveLimit,
  });
  let elements;
  try {
    elements = await fetchOverpass(query);
  } catch (e) {
    logger.warn?.(`[seed] Overpass error ${country}/${category}: ${e.message}`);
    return { inserted: 0, skipped: 0, error: e.message };
  }
  if (limit) elements = elements.slice(0, limit);

  let inserted = 0;
  let skipped = 0;
  for (const el of elements) {
    const poi = elementToPoi(el, category, country);
    if (!poi || !poi.title) {
      skipped += 1;
      continue;
    }
    try {
      await MapPOI.updateOne(
        { osmId: poi.osmId },
        { $setOnInsert: poi },
        { upsert: true },
      );
      inserted += 1;
    } catch {
      skipped += 1;
    }
  }
  return { inserted, skipped };
}

/**
 * Run a seed job for a single country (all categories or a subset).
 * Returns the jobId immediately; actual work happens in background.
 * Progress can be polled via getJobStatus(jobId).
 */
function runSeed({ country, categories, limit }) {
  const upperCountry = String(country || '').toUpperCase();
  const bbox = COUNTRY_BBOX[upperCountry];
  if (!bbox) {
    throw new Error(`Unknown country: ${country}`);
  }
  // v20.0.4 — excluded `trainerByName` (it's a helper tag for `trainer`,
  // not a real category). Without this filter the auto-iterate seeds POIs
  // with category='trainerByName' which pollutes the DB and breaks analytics.
  const cats = categories && categories.length > 0
    ? categories
    : Object.keys(CATEGORY_TAGS).filter((k) => k !== 'trainerByName');

  const jobId = `${upperCountry}-${Date.now()}`;
  const job = {
    id: jobId,
    country: upperCountry,
    categories: cats,
    status: 'running',
    startedAt: new Date(),
    finishedAt: null,
    totalInserted: 0,
    byCategory: {},
    error: null,
  };
  jobs.set(jobId, job);

  // Fire and forget — do NOT await. Render has a 30s request timeout.
  (async () => {
    try {
      for (const cat of cats) {
        job.byCategory[cat] = { status: 'running' };
        const res = await seedCategory({
          category: cat,
          bbox,
          country: upperCountry,
          limit,
        });
        job.byCategory[cat] = {
          status: res.error ? 'error' : 'done',
          inserted: res.inserted,
          skipped: res.skipped,
          error: res.error || null,
        };
        job.totalInserted += res.inserted;
      }
      job.status = 'done';
      job.finishedAt = new Date();
      logger.info?.(
        `[seed] ${upperCountry} done — ${job.totalInserted} POIs inserted`,
      );
    } catch (e) {
      job.status = 'error';
      job.error = e.message;
      job.finishedAt = new Date();
      logger.error?.(`[seed] ${upperCountry} failed:`, e);
    }
  })();

  return jobId;
}

/**
 * Queue seeds for many countries in sequence — one Overpass query at a time
 * to respect the public Overpass instance's fair-use policy. Returns the
 * job id of the parent batch; individual per-country jobs are spawned
 * lazily inside.
 */
function runSeedBatch({ countries, categories, limit }) {
  const countryList = (countries && countries.length > 0)
    ? countries
    : ALL_EU_COUNTRIES;
  const batchId = `batch-${Date.now()}`;
  const batch = {
    id: batchId,
    type: 'batch',
    countries: countryList,
    status: 'running',
    startedAt: new Date(),
    finishedAt: null,
    perCountry: {},
    totalInserted: 0,
  };
  jobs.set(batchId, batch);

  (async () => {
    for (const c of countryList) {
      const upper = c.toUpperCase();
      if (!COUNTRY_BBOX[upper]) {
        batch.perCountry[upper] = { status: 'error', error: 'unknown country' };
        continue;
      }
      batch.perCountry[upper] = { status: 'running', inserted: 0 };
      try {
        // v20.0.15 — same fix as runSeed : exclude `trainerByName` which is a
        // helper tag for the `trainer` category, not a real category itself.
        const cats = categories && categories.length > 0
          ? categories
          : Object.keys(CATEGORY_TAGS).filter((k) => k !== 'trainerByName');
        let inserted = 0;
        for (const cat of cats) {
          const res = await seedCategory({
            category: cat,
            bbox: COUNTRY_BBOX[upper],
            country: upper,
            limit,
          });
          inserted += res.inserted;
        }
        batch.perCountry[upper] = { status: 'done', inserted };
        batch.totalInserted += inserted;
        logger.info?.(
          `[seed:batch] ${upper} done - ${inserted} POIs`,
        );
      } catch (e) {
        batch.perCountry[upper] = {
          status: 'error',
          error: e.message,
          inserted: 0,
        };
        logger.error?.(`[seed:batch] ${upper} failed:`, e);
      }
    }
    batch.status = 'done';
    batch.finishedAt = new Date();
    return batch;
  })();

  // v20.0.15 — fix: return the batch id (string) like runSeed does, so
  // adminRoutes can put it in the response as { jobId }. Previously we
  // returned { jobId: undefined } (the `jobId` var didn't exist in this
  // scope, only `batchId`), causing the admin button to show 400 "X" toast.
  return batchId;
}

function getSeedJob(jobId) {
  // v20.0.15 — fix: the Map is named `jobs` (line 79), not `SEED_JOBS`.
  return jobs.get(jobId) || null;
}

function listSeedJobs() {
  return Array.from(jobs.values()).sort(
    (a, b) => (b.startedAt || 0) - (a.startedAt || 0),
  );
}

module.exports = {
  // Public API used by adminRoutes.js.
  runSeed,
  runSeedBatch,
  getJobStatus: getSeedJob,
  listJobs: listSeedJobs,
  // Internal helpers also re-exported for tests / reuse.
  seedCategory,
  COUNTRY_BBOX,
  CATEGORY_TAGS,
  ALL_EU_COUNTRIES,
};
