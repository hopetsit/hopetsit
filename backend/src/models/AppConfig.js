const mongoose = require('mongoose');

/**
 * v565 §5 — configuration applicative pilotée depuis l'admin.
 *
 * Singleton (`key: 'singleton'`). Aujourd'hui : drapeaux des fonctions du chat
 * (médias, vocal, réponses) — l'admin peut couper une fonction sans rebuild ;
 * les routes correspondantes répondent alors 403 FEATURE_DISABLED et les
 * clients cachent les boutons (GET /app-config/chat-features).
 */
const ChatFeaturesSchema = new mongoose.Schema(
  {
    media: { type: Boolean, default: true },
    voice: { type: Boolean, default: true },
    reply: { type: Boolean, default: true },
  },
  { _id: false },
);

// v565 — « code du moment » : affiché PRÉ-REMPLI dans le pop-up promo de l'app
// (Daniel : « préremplir le code, il a juste à appuyer sur Appliquer »).
// HOPDALIOS = code créé pour être valable sur iOS, Android et web.
const PublicPromoSchema = new mongoose.Schema(
  {
    code: { type: String, default: 'HOPDALIOS', trim: true, uppercase: true },
    enabled: { type: Boolean, default: true },
    message: { type: String, default: '', trim: true, maxlength: 140 },
  },
  { _id: false },
);

const AppConfigSchema = new mongoose.Schema(
  {
    key: { type: String, default: 'singleton', unique: true },
    chatFeatures: { type: ChatFeaturesSchema, default: () => ({}) },
    publicPromo: { type: PublicPromoSchema, default: () => ({}) },
  },
  { timestamps: true },
);

const CHAT_FEATURE_KEYS = ['media', 'voice', 'reply'];
const DEFAULT_CHAT_FEATURES = Object.freeze({ media: true, voice: true, reply: true });

AppConfigSchema.statics.getSingleton = async function getSingleton() {
  let doc = await this.findOne({ key: 'singleton' });
  if (!doc) {
    try {
      doc = await this.create({ key: 'singleton' });
    } catch (_) {
      doc = await this.findOne({ key: 'singleton' });
    }
  }
  return doc;
};

// Cache court (30 s) : lu à chaque envoi de message, écrit rarement.
let _chatCache = { at: 0, value: null };
const CHAT_CACHE_MS = 30 * 1000;

AppConfigSchema.statics.getChatFeatures = async function getChatFeatures() {
  const now = Date.now();
  if (_chatCache.value && now - _chatCache.at < CHAT_CACHE_MS) return _chatCache.value;
  try {
    const doc = await this.findOne({ key: 'singleton' }).select('chatFeatures').lean();
    const raw = (doc && doc.chatFeatures) || {};
    const value = {};
    for (const k of CHAT_FEATURE_KEYS) value[k] = raw[k] !== false;
    _chatCache = { at: now, value };
    return value;
  } catch (_) {
    // En cas de doute (Mongo indisponible), on n'éteint rien.
    return _chatCache.value || { ...DEFAULT_CHAT_FEATURES };
  }
};

AppConfigSchema.statics.setChatFeatures = async function setChatFeatures(partial = {}) {
  const $set = {};
  for (const k of CHAT_FEATURE_KEYS) {
    if (Object.prototype.hasOwnProperty.call(partial, k)) {
      const v = partial[k];
      const bool = v === true || v === 'true' || v === 1 || v === '1';
      const isFalse = v === false || v === 'false' || v === 0 || v === '0';
      if (!bool && !isFalse) {
        const err = new Error(`chatFeatures.${k} must be a boolean.`);
        err.status = 400;
        throw err;
      }
      $set[`chatFeatures.${k}`] = bool;
    }
  }
  if (Object.keys($set).length) {
    await this.updateOne({ key: 'singleton' }, { $set, $setOnInsert: { key: 'singleton' } }, { upsert: true });
  }
  _chatCache = { at: 0, value: null };
  return this.getChatFeatures();
};

const DEFAULT_PUBLIC_PROMO = Object.freeze({ code: 'HOPDALIOS', enabled: true, message: '' });
let _promoCache = { at: 0, value: null };

AppConfigSchema.statics.getPublicPromo = async function getPublicPromo() {
  const now = Date.now();
  if (_promoCache.value && now - _promoCache.at < CHAT_CACHE_MS) return _promoCache.value;
  try {
    const doc = await this.findOne({ key: 'singleton' }).select('publicPromo').lean();
    const raw = (doc && doc.publicPromo) || {};
    const value = {
      code: String(raw.code || DEFAULT_PUBLIC_PROMO.code).toUpperCase(),
      enabled: raw.enabled !== false,
      message: String(raw.message || ''),
    };
    _promoCache = { at: now, value };
    return value;
  } catch (_) {
    return _promoCache.value || { ...DEFAULT_PUBLIC_PROMO };
  }
};

AppConfigSchema.statics.setPublicPromo = async function setPublicPromo(partial = {}) {
  const $set = {};
  if (Object.prototype.hasOwnProperty.call(partial, 'code')) {
    const code = String(partial.code || '').trim().toUpperCase();
    if (code && !/^[A-Z0-9-]{4,24}$/.test(code)) {
      const err = new Error('Code invalide (4-24 caractères, lettres/chiffres/tirets).');
      err.status = 400;
      throw err;
    }
    $set['publicPromo.code'] = code;
  }
  if (Object.prototype.hasOwnProperty.call(partial, 'enabled')) {
    const v = partial.enabled;
    $set['publicPromo.enabled'] = v === true || v === 'true' || v === 1 || v === '1';
  }
  if (Object.prototype.hasOwnProperty.call(partial, 'message')) {
    $set['publicPromo.message'] = String(partial.message || '').slice(0, 140);
  }
  if (Object.keys($set).length) {
    await this.updateOne({ key: 'singleton' }, { $set, $setOnInsert: { key: 'singleton' } }, { upsert: true });
  }
  _promoCache = { at: 0, value: null };
  return this.getPublicPromo();
};

/** Vide le cache (tests / après écriture directe). */
AppConfigSchema.statics.clearCache = function clearCache() {
  _chatCache = { at: 0, value: null };
  _promoCache = { at: 0, value: null };
};

const AppConfig = mongoose.model('AppConfig', AppConfigSchema);
AppConfig.CHAT_FEATURE_KEYS = CHAT_FEATURE_KEYS;
AppConfig.DEFAULT_CHAT_FEATURES = DEFAULT_CHAT_FEATURES;

module.exports = AppConfig;
