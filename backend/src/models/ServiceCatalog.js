const mongoose = require('mongoose');

/**
 * ServiceCatalog — singleton doc holding the bookable service grid.
 *
 * The 3 service keys (dog_walking / day_care / pet_sitting) are hardcoded in
 * backend and frontend business logic (e.g. the walker-exclusive filter on
 * `getRequestPosts`), so this catalog does NOT let admin add or rename the
 * keys. What it *does* expose is:
 *
 *   • `active`    — show/hide a service in the owner publish flow
 *   • `minutes`   — the 2 duration preset arrays for Promenade + Sortie longue
 *   • `labelOverride` / `descOverride` — optional per-language string override;
 *                  when empty, the client falls back to the i18n translation
 *                  key of the same name (backwards compatible).
 *
 * Kept as a singleton document (key: 'singleton') so one admin patch updates
 * the whole catalog — mirrors the pricingService pattern.
 */

const LocalizedStringSchema = new mongoose.Schema(
  {
    fr: { type: String, default: '' },
    en: { type: String, default: '' },
    de: { type: String, default: '' },
    es: { type: String, default: '' },
    it: { type: String, default: '' },
    pt: { type: String, default: '' },
    // 620 (ZOE) — les 9 langues de l'app.
    ko: { type: String, default: '' },
    ja: { type: String, default: '' },
    pl: { type: String, default: '' },
  },
  { _id: false },
);

const ServiceEntrySchema = new mongoose.Schema(
  {
    active: { type: Boolean, default: true },
    icon: { type: String, default: '' },
    labelOverride: { type: LocalizedStringSchema, default: () => ({}) },
    descOverride: { type: LocalizedStringSchema, default: () => ({}) },
  },
  { _id: false },
);

const ServiceCatalogSchema = new mongoose.Schema(
  {
    key: {
      type: String,
      default: 'singleton',
      unique: true,
      required: true,
    },
    // Service entries — keyed by the stable internal IDs.
    dog_walking: { type: ServiceEntrySchema, default: () => ({}) },
    day_care: { type: ServiceEntrySchema, default: () => ({}) },
    pet_sitting: { type: ServiceEntrySchema, default: () => ({}) },
    // 620 (ZOE, 24/10/2026) — garde à domicile (unité jour / nuit) et VISITE À
    // DOMICILE (unité visite, 30|60 min, 1|2 visites par jour). Les unités et
    // options sont figées dans serviceCatalogService.SERVICE_META ; l'admin ne
    // règle ici que active / icon / libellés.
    house_sitting: { type: ServiceEntrySchema, default: () => ({}) },
    home_visit: { type: ServiceEntrySchema, default: () => ({}) },

    // Duration presets for Promenade (short walks) and Sortie longue
    // (half-day outings). Stored as arrays of minutes.
    promenadeMinutes: { type: [Number], default: [30, 60, 90, 120] },
    longOutingMinutes: { type: [Number], default: [180, 240, 300] },
  },
  { timestamps: true },
);

module.exports = mongoose.model('ServiceCatalog', ServiceCatalogSchema);
