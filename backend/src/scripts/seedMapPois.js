#!/usr/bin/env node

/**
 * OSM → MapPOI seed script.
 *
 * Fetches points of interest from OpenStreetMap via the Overpass API and
 * bulk-inserts them into the `mappois` collection (MapPOI model). Supports
 * incremental re-runs via `osmId` (dedup) and filters by bbox + category.
 *
 * Usage:
 *   node src/scripts/seedMapPois.js --country FR --category vet
 *   node src/scripts/seedMapPois.js --bbox 48.8,2.3,48.9,2.4 --category park,shop
 *
 * Default bbox covers Metropolitan France (approximate).
 * Overpass query timeout is 60s; heavy queries may fail. Split by sub-region.
 *
 * Dependencies: axios, mongoose (already in package.json).
 */

/* eslint-disable no-console */
require('dotenv').config();

const axios = require('axios').default;
const mongoose = require('mongoose');
const MapPOI = require('../models/MapPOI');

// ─── Overpass tag filters per category ──────────────────────────────────────
const CATEGORY_TAGS = {
  vet: '["amenity"="veterinary"]',
  shop: '["shop"~"pet"]',
  groomer: '["shop"="pet_grooming"]',
  park: '["leisure"="dog_park"]',
  beach: '["leisure"="beach_resort"]["dog"="yes"]', // approximate
  water: '["amenity"="drinking_water"]',
  trainer: '["shop"="dog_training"]',
  hotel: '["tourism"="hotel"]["dog"="yes"]',
  restaurant: '["amenity"="restaurant"]["dog"="yes"]',
};

// ─── Country bbox defaults (approximate) ────────────────────────────────────
const COUNTRY_BBOX = {
  FR: [41.3, -5.4, 51.2, 9.6],      // Metropolitan France
  CH: [45.8, 5.9, 47.9, 10.6],      // Switzerland
  GB: [49.9, -8.6, 58.7, 1.8],      // Great Britain
  BE: [49.5, 2.5, 51.6, 6.4],       // Belgium
  IT: [35.5, 6.6, 47.1, 18.5],      // Italy
  DE: [47.3, 5.9, 55.1, 15.0],      // Germany
  ES: [36.0, -9.3, 43.8, 4.3],      // Spain
  PT: [37.0, -9.5, 42.2, -6.2],     // Portugal
};

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = { categories: Object.keys(CATEGORY_TAGS), bbox: COUNTRY_BBOX.FR };
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i];
    const value = args[i + 1];
    if (key === '--country') {
      opts.bbox = COUNTRY_BBOX[value.toUpperCase()] || opts.bbox;
      opts.country = value.toUpperCase();
    } else if (key === '--bbox') {
      opts.bbox = value.split(',').map((n) => parseFloat(n.trim()));
    } else if (key === '--category') {
      opts.categories = value.split(',').map((s) => s.trim());
    } else if (key === '--limit') {
      opts.limit = parseInt(value, 10);
    }
  }
  return opts;
}

function buildOverpassQuery(bbox, tagFilters) {
  const bboxStr = bbox.join(',');
  const unions = tagFilters
    .map((tf) => `node${tf}(${bboxStr});way${tf}(${bboxStr});`)
    .join('');
  return `[out:json][timeout:60];(${unions});out center tags;`;
}

async function fetchOverpass(query) {
  const res = await axios.post(
    'https://overpass-api.de/api/interpreter',
    `data=${encodeURIComponent(query)}`,
    {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      timeout: 120000,
    },
  );
  return res.data.elements || [];
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
      country: country || (tags['addr:country'] || ''),
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

async function seedCategory(category, bbox, country, limit) {
  const tag = CATEGORY_TAGS[category];
  if (!tag) {
    console.log(`⚠️  Skipping unknown category "${category}"`);
    return { inserted: 0, skipped: 0 };
  }
  console.log(`🔎 Fetching ${category} in bbox ${bbox.join(',')}…`);
  const query = buildOverpassQuery(bbox, [tag]);
  let elements = [];
  try {
    elements = await fetchOverpass(query);
  } catch (e) {
    console.error(`❌ Overpass error for ${category}:`, e.message);
    return { inserted: 0, skipped: 0 };
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
    } catch (err) {
      skipped += 1;
    }
  }

  console.log(`   ↳ ${category}: ${inserted} inserted/found, ${skipped} skipped`);
  return { inserted, skipped };
}

async function main() {
  const opts = parseArgs();
  console.log('🌱 Seeding MapPOIs from OpenStreetMap');
  console.log(`   bbox: ${opts.bbox.join(',')}`);
  console.log(`   categories: ${opts.categories.join(', ')}`);
  console.log(`   country: ${opts.country || '(bbox-only)'}`);

  if (!process.env.MONGODB_URI) {
    console.error('❌ MONGODB_URI is not set.');
    process.exit(1);
  }

  await mongoose.connect(process.env.MONGODB_URI);
  console.log('✅ Connected to MongoDB');

  let grandTotal = 0;
  for (const cat of opts.categories) {
    const { inserted } = await seedCategory(cat, opts.bbox, opts.country, opts.limit);
    grandTotal += inserted;
  }

  console.log(`✨ Done. ${grandTotal} POI docs inserted/upserted.`);
  await mongoose.disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
