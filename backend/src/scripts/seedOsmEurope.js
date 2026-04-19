/**
 * seedOsmEurope.js — Populates the MapPOI collection with European POIs
 * fetched from the Overpass API (OpenStreetMap).
 *
 * Categories imported per country:
 *   - vet  : amenity=veterinary
 *   - shop : shop=pet
 *   - park : leisure=dog_park + leisure=park (dog-relevant)
 *
 * Run:
 *   node src/scripts/seedOsmEurope.js              # all default countries
 *   node src/scripts/seedOsmEurope.js --country FR # one country only
 *   node src/scripts/seedOsmEurope.js --dry-run    # print count, don't write
 *
 * Safe to re-run: uses `osmId` as unique key, upserts without duplicates.
 *
 * Overpass is free but rate-limited. We throttle one request every 5 s and
 * chunk by country to avoid 429. Expect 10–30 minutes to ingest Western Europe.
 */

require('dotenv').config();
const mongoose = require('mongoose');
const MapPOI = require('../models/MapPOI');

const OVERPASS_ENDPOINT = 'https://overpass-api.de/api/interpreter';
const REQUEST_DELAY_MS = 5000; // Be nice to Overpass.

// ISO country bounding boxes (roughly). Overpass accepts [south, west, north, east].
const COUNTRIES = {
  FR: { name: 'France',      bbox: [41.3, -5.2, 51.1,  9.6] },
  BE: { name: 'Belgium',     bbox: [49.5,  2.5, 51.5,  6.4] },
  CH: { name: 'Switzerland', bbox: [45.8,  5.9, 47.8, 10.5] },
  LU: { name: 'Luxembourg',  bbox: [49.4,  5.7, 50.2,  6.5] },
  DE: { name: 'Germany',     bbox: [47.3,  5.9, 55.1, 15.0] },
  IT: { name: 'Italy',       bbox: [35.5,  6.6, 47.1, 18.5] },
  ES: { name: 'Spain',       bbox: [35.2, -9.3, 43.8,  4.3] },
  PT: { name: 'Portugal',    bbox: [36.8, -9.5, 42.2, -6.2] },
  NL: { name: 'Netherlands', bbox: [50.7,  3.3, 53.6,  7.2] },
  AT: { name: 'Austria',     bbox: [46.3,  9.5, 49.0, 17.2] },
  GB: { name: 'United Kingdom', bbox: [49.8, -8.7, 60.9,  1.8] },
};

// Overpass query fragments — one per category.
const QUERIES = {
  vet:  '["amenity"="veterinary"]',
  shop: '["shop"="pet"]',
  park: '["leisure"~"^(dog_park|park)$"]',
};

const CATEGORY_TO_TITLE_FALLBACK = {
  vet:  'Veterinary clinic',
  shop: 'Pet shop',
  park: 'Park',
};

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

function parseArgs() {
  const args = process.argv.slice(2);
  const out = { country: null, dryRun: false };
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--country' && args[i + 1]) {
      out.country = args[i + 1].toUpperCase();
      i++;
    } else if (args[i] === '--dry-run') {
      out.dryRun = true;
    }
  }
  return out;
}

async function overpassQuery({ bbox, filter, category }) {
  const [s, w, n, e] = bbox;
  // nwr = node+way+relation, out center so ways get a representative lat/lng.
  const query = `
    [out:json][timeout:120];
    (
      nwr${filter}(${s},${w},${n},${e});
    );
    out center tags;
  `;
  const body = new URLSearchParams({ data: query });
  const res = await fetch(OVERPASS_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      // Overpass returns 406 "Not Acceptable" for unidentified clients.
      // The User-Agent is required by their fair-use policy.
      'User-Agent': 'HopeTSIT-POI-Seed/1.0 (contact: dadaciao84@gmail.com)',
      'Accept': 'application/json',
    },
    body: body.toString(),
  });
  if (!res.ok) {
    throw new Error(`Overpass ${res.status} for ${category}: ${res.statusText}`);
  }
  const json = await res.json();
  return json.elements || [];
}

function elementToPoi(el, category, countryCode) {
  const tags = el.tags || {};
  const title = (tags.name || tags['name:en'] || tags.operator ||
                 CATEGORY_TO_TITLE_FALLBACK[category] || 'POI').slice(0, 120);

  let lat = null, lng = null;
  if (typeof el.lat === 'number' && typeof el.lon === 'number') {
    lat = el.lat; lng = el.lon;
  } else if (el.center && typeof el.center.lat === 'number') {
    lat = el.center.lat; lng = el.center.lon;
  }
  if (lat === null || lng === null) return null;

  return {
    title,
    description: tags.description || '',
    category,
    location: {
      type: 'Point',
      coordinates: [lng, lat],
      city: tags['addr:city'] || '',
      country: countryCode,
    },
    address: [
      tags['addr:housenumber'], tags['addr:street'], tags['addr:postcode'], tags['addr:city'],
    ].filter(Boolean).join(' '),
    phone: tags.phone || tags['contact:phone'] || '',
    website: tags.website || tags['contact:website'] || '',
    openingHours: tags.opening_hours || '',
    source: 'seed',
    osmId: `${el.type}/${el.id}`,
    status: 'active',
  };
}

async function upsertPoi(doc) {
  await MapPOI.updateOne(
    { osmId: doc.osmId },
    { $set: doc, $setOnInsert: { createdAt: new Date() } },
    { upsert: true }
  );
}

async function main() {
  const args = parseArgs();
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    console.error('[seed] MONGODB_URI is not set in env.');
    process.exit(1);
  }

  const countries = args.country
    ? { [args.country]: COUNTRIES[args.country] }
    : COUNTRIES;

  if (args.country && !countries[args.country]) {
    console.error(`[seed] Unknown country code: ${args.country}`);
    process.exit(1);
  }

  console.log(`[seed] Connecting to MongoDB…`);
  await mongoose.connect(uri);
  console.log(`[seed] Connected. Dry-run=${args.dryRun}`);

  let totalFetched = 0;
  let totalUpserted = 0;

  try {
    for (const [code, info] of Object.entries(countries)) {
      if (!info) continue;
      console.log(`\n[seed] ${code} — ${info.name}`);
      for (const [category, filter] of Object.entries(QUERIES)) {
        process.stdout.write(`  · ${category} … `);
        try {
          const elements = await overpassQuery({ bbox: info.bbox, filter, category });
          totalFetched += elements.length;
          process.stdout.write(`${elements.length} elements`);

          if (!args.dryRun) {
            let wrote = 0;
            for (const el of elements) {
              const poi = elementToPoi(el, category, code);
              if (!poi) continue;
              try {
                await upsertPoi(poi);
                wrote++;
              } catch (e) {
                // Swallow duplicates / malformed coords, keep going.
              }
            }
            totalUpserted += wrote;
            process.stdout.write(` → ${wrote} written`);
          }
          process.stdout.write('\n');
        } catch (e) {
          console.log(`ERROR: ${e.message}`);
        }
        await wait(REQUEST_DELAY_MS);
      }
    }
  } finally {
    await mongoose.connection.close();
    console.log(`\n[seed] Done. Fetched=${totalFetched} Upserted=${totalUpserted}`);
  }
}

main().catch((e) => {
  console.error('[seed] fatal:', e);
  process.exit(1);
});
