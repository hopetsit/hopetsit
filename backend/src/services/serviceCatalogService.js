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
  // 620 (ZOE, 24/10/2026) — garde à domicile et visite à domicile.
  house_sitting: {
    active: true,
    icon: '🏠',
    labelOverride: { fr: '', en: '', de: '', es: '', it: '', pt: '' },
    descOverride: { fr: '', en: '', de: '', es: '', it: '', pt: '' },
  },
  home_visit: {
    active: true,
    icon: '🚪',
    labelOverride: { fr: '', en: '', de: '', es: '', it: '', pt: '' },
    descOverride: { fr: '', en: '', de: '', es: '', it: '', pt: '' },
  },
  promenadeMinutes: [30, 60, 90, 120],
  longOutingMinutes: [180, 240, 300],
});

const SERVICE_KEYS = ['dog_walking', 'day_care', 'pet_sitting', 'house_sitting', 'home_visit']; // 620 — + house_sitting, home_visit
const SUPPORTED_LANGS = ['fr', 'en', 'de', 'es', 'it', 'pt', 'ko', 'ja', 'pl']; // 620 — 9 langues

// 620 (ZOE) — unité de facturation et options de chaque service (figées dans le
// code : le site, l'app et le moteur de prix s'y fient). Libellés dans les 9 langues.
const SERVICE_META = Object.freeze({
  house_sitting: {
    unit: 'day',
    order: 1,
    venues: ['owners_home', 'sitters_home'],
    label: { fr: 'Garde à domicile', en: 'House sitting', es: 'Cuidado a domicilio', de: 'Betreuung zu Hause', it: 'Custodia a domicilio', pt: 'Cuidado ao domicílio', ko: '방문 돌봄', ja: '在宅ペットシッティング', pl: 'Opieka w domu' },
    desc: { fr: 'Un gardien chez vous ou chez lui, par jour (par nuit chez le gardien).', en: 'A sitter at your home or theirs, per day (per night at the sitter\'s).', es: 'Un cuidador en tu casa o en la suya, por día (por noche en casa del cuidador).', de: 'Betreuung bei dir oder beim Sitter, pro Tag (pro Nacht beim Sitter).', it: 'Un pet sitter a casa tua o a casa sua, al giorno (a notte da lui).', pt: 'Um cuidador em sua casa ou na dele, por dia (por noite em casa do cuidador).', ko: '보호자 집 또는 펫시터 집에서 돌봄, 1일 단위(펫시터 집은 1박 단위).', ja: '自宅またはシッター宅でのお世話、1日単位（シッター宅は1泊単位）。', pl: 'Opiekun u ciebie lub u siebie, za dzień (za noc u opiekuna).' },
    unitLabel: { fr: 'jour', en: 'day', es: 'día', de: 'Tag', it: 'giorno', pt: 'dia', ko: '일', ja: '日', pl: 'dzień' },
  },
  home_visit: {
    unit: 'visit',
    order: 2,
    durations: [30, 60],
    visitsPerDay: [1, 2],
    label: { fr: 'Visite à domicile', en: 'Home visit', es: 'Visita a domicilio', de: 'Hausbesuch', it: 'Visita a domicilio', pt: 'Visita ao domicílio', ko: '방문 서비스', ja: '訪問ケア', pl: 'Wizyta domowa' },
    desc: { fr: 'Le gardien passe chez vous, 1 ou 2 fois par jour, 30 ou 60 min. Prix par visite.', en: 'The sitter drops in at your place, once or twice a day, 30 or 60 min. Price per visit.', es: 'El cuidador pasa por tu casa, 1 o 2 veces al día, 30 o 60 min. Precio por visita.', de: 'Der Sitter kommt 1- oder 2-mal täglich vorbei, 30 oder 60 Min. Preis pro Besuch.', it: 'Il pet sitter passa da te 1 o 2 volte al giorno, 30 o 60 min. Prezzo a visita.', pt: 'O cuidador passa por sua casa 1 ou 2 vezes por dia, 30 ou 60 min. Preço por visita.', ko: '펫시터가 하루 1~2회, 30분 또는 60분 방문합니다. 방문당 요금.', ja: 'シッターが1日1〜2回、30分または60分訪問します。訪問ごとの料金。', pl: 'Opiekun przychodzi 1 lub 2 razy dziennie, 30 lub 60 min. Cena za wizytę.' },
    unitLabel: { fr: 'visite', en: 'visit', es: 'visita', de: 'Besuch', it: 'visita', pt: 'visita', ko: '회', ja: '回', pl: 'wizyta' },
  },
  day_care: {
    unit: 'day',
    order: 3,
    label: { fr: 'Garderie de jour', en: 'Day care', es: 'Guardería de día', de: 'Tagesbetreuung', it: 'Asilo diurno', pt: 'Creche de dia', ko: '주간 돌봄', ja: '日中のお預かり', pl: 'Opieka dzienna' },
    desc: { fr: 'Votre animal est gardé en journée. Prix par jour.', en: 'Your pet is looked after during the day. Price per day.', es: 'Tu mascota está cuidada durante el día. Precio por día.', de: 'Dein Tier wird tagsüber betreut. Preis pro Tag.', it: 'Il tuo animale è accudito di giorno. Prezzo al giorno.', pt: 'O seu animal fica guardado durante o dia. Preço por dia.', ko: '낮 시간 동안 반려동물을 돌봅니다. 1일 단위 요금.', ja: '日中にペットをお預かりします。1日単位の料金。', pl: 'Opieka nad zwierzakiem w ciągu dnia. Cena za dzień.' },
    unitLabel: { fr: 'jour', en: 'day', es: 'día', de: 'Tag', it: 'giorno', pt: 'dia', ko: '일', ja: '日', pl: 'dzień' },
  },
  dog_walking: {
    unit: 'walk',
    order: 4,
    label: { fr: 'Promenade de chien', en: 'Dog walking', es: 'Paseo de perros', de: 'Gassi gehen', it: 'Passeggiata con il cane', pt: 'Passeio de cães', ko: '반려견 산책', ja: '犬のお散歩', pl: 'Spacer z psem' },
    desc: { fr: 'Un promeneur sort votre chien. Prix par balade, selon la durée.', en: 'A walker takes your dog out. Price per walk, by duration.', es: 'Un paseador saca a tu perro. Precio por paseo, según la duración.', de: 'Ein Gassigeher geht mit deinem Hund raus. Preis pro Spaziergang, je nach Dauer.', it: 'Un dog walker porta fuori il tuo cane. Prezzo a passeggiata, in base alla durata.', pt: 'Um passeador leva o seu cão a passear. Preço por passeio, conforme a duração.', ko: '도그워커가 반려견을 산책시킵니다. 산책당 요금(시간에 따라).', ja: 'ドッグウォーカーが犬を散歩させます。散歩ごとの料金（時間による）。', pl: 'Wyprowadzacz wychodzi z twoim psem. Cena za spacer, zależnie od czasu.' },
    unitLabel: { fr: 'balade', en: 'walk', es: 'paseo', de: 'Spaziergang', it: 'passeggiata', pt: 'passeio', ko: '회', ja: '回', pl: 'spacer' },
  },
});
const PUBLIC_SERVICE_KEYS = ['house_sitting', 'home_visit', 'day_care', 'dog_walking'];

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
  const out = {};
  for (const k of SERVICE_KEYS) out[k] = cache[k] || DEFAULTS[k];
  out.promenadeMinutes = cache.promenadeMinutes;
  out.longOutingMinutes = cache.longOutingMinutes;
  return out;
}

/**
 * 620 (ZOE) — catalogue PUBLIC des 4 services réservables avec leur unité, leurs
 * options et leurs libellés (9 langues, surcharge admin appliquée). Servi par
 * `GET /app-config/services` (public, cache 60 s). `active:false` (admin) retire
 * le service de la liste `services` mais il reste dans `all` pour les anciennes demandes.
 */
function getServices620() {
  const services = PUBLIC_SERVICE_KEYS.map((key) => {
    const meta = SERVICE_META[key];
    const entry = cache[key] || DEFAULTS[key] || {};
    const label = { ...meta.label };
    const desc = { ...meta.desc };
    for (const lang of SUPPORTED_LANGS) {
      if (entry.labelOverride && entry.labelOverride[lang]) label[lang] = entry.labelOverride[lang];
      if (entry.descOverride && entry.descOverride[lang]) desc[lang] = entry.descOverride[lang];
    }
    return {
      key,
      unit: meta.unit,
      active: entry.active !== false,
      icon: entry.icon || (DEFAULTS[key] && DEFAULTS[key].icon) || '',
      label,
      desc,
      unitLabel: { ...meta.unitLabel },
      ...(meta.venues ? { venues: meta.venues.slice() } : {}),
      ...(meta.durations ? { durations: meta.durations.slice() } : {}),
      ...(meta.visitsPerDay ? { visitsPerDay: meta.visitsPerDay.slice() } : {}),
      ...(key === 'dog_walking' ? { walkDurations: cache.promenadeMinutes.slice() } : {}),
    };
  });
  return {
    services: services.filter((s) => s.active),
    all: services,
    dateModes: ['exact', 'approx', 'tbd'],
    languages: SUPPORTED_LANGS.slice(),
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
  const $set = { promenadeMinutes: cache.promenadeMinutes, longOutingMinutes: cache.longOutingMinutes };
  for (const k of SERVICE_KEYS) $set[k] = cache[k];
  await ServiceCatalog.findOneAndUpdate({ key: 'singleton' }, { $set }, { upsert: true, new: true });
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
  getServices620, // 620
  SERVICE_META, // 620
  PUBLIC_SERVICE_KEYS, // 620
  update,
  resetToDefaults,
  DEFAULTS,
  SERVICE_KEYS,
  SUPPORTED_LANGS,
};
