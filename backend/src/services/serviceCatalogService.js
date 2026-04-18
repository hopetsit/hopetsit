const ServiceCatalog = require('../models/ServiceCatalog');
const logger = require('../utils/logger');

/**
 * Service catalog cache — mirrors pricingService (see that file for pattern
 * rationale). Loaded from DB on boot, mutated in place on admin PATCH so
 * consumers that captured a reference still see fresh values.
 */

const DEFAULTS = Object.freeze({
  dog_walking: {
    active: true,
    icon: '🐾',
    labelOverride: { fr: '', en: '', de: '', es: '', it: '', pt: '' },
    descOverride: { fr: '', en: '', de: '', es: '', it: '', pt: '' },
  },
  day_care: {
    active: true,
    icon: '☀️',
    labelOverride: { fr: '', en: '', de: '', es: '', it: '', pt: '' },
    descOverride: { fr: '', en: '', de: '', es: '', it: '', pt: '' },
  },
  pet_sitting: {
    active: true,
    icon: '🏡',
    labelOverride: { fr: '', en: '', de: '', es: '', it: '', pt: '' },
    descOverride: { fr: '', en: '', de: '', es: '', it: '', pt: '' },
  },
  promenadeMinutes: [30, 60, 90, 120],
  longOutingMinutes: [180, 240, 300],
});

const SERVICE_KEYS = ['dog_walking', 'day_care', 'pet_sitting'];
const SUPPORTED_LANGS = ['fr', 'en', 'de', 'es', 'it', 'pt'];

let cache = JSON.parse(JSON.stringify(DEFAULTS));

function mergeInto(target, patch) {
  for (const key of SERVICE_KEYS) {
    if (patch[key] && typeof patch[key] === 'object') {
      target[key] = target[key] || {};
      if (typeof patch[key].active === 'boolean') {
        target[key].active = patch[key].active;
      }
      if (typeof patch[key].icon === 'string') {
        target[key].icon = patch[key].icon;
      }
      for (const field of ['labelOverride', 'descOverride']) {
        if (patch[key][field] && typeof patch[key][field] === 'object') {
          target[key][field] = target[key][field] || {};
          for (const lang of SUPPORTED_LANGS) {
            if (typeof patch[key][field][lang] === 'string') {
              target[key][field][lang] = patch[key][field][lang];
            }
          }
        }
      }
    }
  }
  if (Array.isArray(patch.promenadeMinutes)) {
    target.promenadeMinutes = patch.promenadeMinutes
      .map((x) => Number(x))
      .filter((n) => Number.isFinite(n) && n > 0)
      .sort((a, b) => a - b);
  }
  if (Array.isArray(patch.longOutingMinutes)) {
    target.longOutingMinutes = patch.longOutingMinutes
      .map((x) => Number(x))
      .filter((n) => Number.isFinite(n) && n > 0)
      .sort((a, b) => a - b);
  }
  return target;
}

async function init() {
  try {
    const doc = await ServiceCatalog.findOne({ key: 'singleton' }).lean();
    if (doc) {
      for (const key of SERVICE_KEYS) {
        if (doc[key]) cache[key] = doc[key];
      }
      if (Array.isArray(doc.promenadeMinutes)) {
        cache.promenadeMinutes = doc.promenadeMinutes;
      }
      if (Array.isArray(doc.longOutingMinutes)) {
        cache.longOutingMinutes = doc.longOutingMinutes;
      }
      logger.info?.('[serviceCatalogService] loaded from DB');
    } else {
      await ServiceCatalog.create({ key: 'singleton', ...DEFAULTS });
      logger.info?.('[serviceCatalogService] seeded DB with defaults');
    }
  } catch (e) {
    logger.error?.('[serviceCatalogService] init failed, using defaults', e);
  }
}

function getAll() {
  return {
    dog_walking: cache.dog_walking,
    day_care: cache.day_care,
    pet_sitting: cache.pet_sitting,
    promenadeMinutes: cache.promenadeMinutes,
    longOutingMinutes: cache.longOutingMinutes,
  };
}

/** Public snapshot consumed by the Flutter app. */
function getPublicCatalog() {
  return {
    services: SERVICE_KEYS
      .filter((k) => cache[k]?.active !== false)
      .map((k) => ({
        key: k,
        icon: cache[k]?.icon || DEFAULTS[k].icon,
        labelOverride: cache[k]?.labelOverride || {},
        descOverride: cache[k]?.descOverride || {},
      })),
    promenadeMinutes: cache.promenadeMinutes,
    longOutingMinutes: cache.longOutingMinutes,
  };
}

async function update(patch) {
  if (!patch || typeof patch !== 'object') {
    throw new Error('serviceCatalogService.update: patch must be an object');
  }
  mergeInto(cache, patch);
  await ServiceCatalog.findOneAndUpdate(
    { key: 'singleton' },
    {
      $set: {
        dog_walking: cache.dog_walking,
        day_care: cache.day_care,
        pet_sitting: cache.pet_sitting,
        promenadeMinutes: cache.promenadeMinutes,
        longOutingMinutes: cache.longOutingMinutes,
      },
    },
    { upsert: true, new: true },
  );
  return getAll();
}

async function resetToDefaults() {
  cache = JSON.parse(JSON.stringify(DEFAULTS));
  await ServiceCatalog.findOneAndUpdate(
    { key: 'singleton' },
    { $set: { ...DEFAULTS } },
    { upsert: true, new: true },
  );
  return getAll();
}

module.exports = {
  init,
  getAll,
  getPublicCatalog,
  update,
  resetToDefaults,
  DEFAULTS,
  SERVICE_KEYS,
  SUPPORTED_LANGS,
};
