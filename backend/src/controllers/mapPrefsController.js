/**
 * v584 (lot C du chantier du 24/09) — PRÉFÉRENCES DE LA PAWMAP SUR LE COMPTE.
 *
 * Daniel : « tout lié entre appareils » — position, zoom, calques, rail de
 * boutons, mode nuit, « je cherche »… sont enregistrés sur le COMPTE (pas
 * seulement sur le téléphone) et suivis sur les 3 profils (owner / sitter /
 * walker) et le site. Même endroit que « visible par mes amis seulement »
 * (`preferences.hideFromMap`), pour que la pastille de la carte et le réglage
 * du profil disent toujours la même chose.
 *
 *   GET   /users/me/map-prefs  → { mapVisibility, hideFromMap, pawMap: {...}, updatedAt }
 *   PATCH /users/me/map-prefs  { mapVisibility?, hideFromMap?, pawMap?: {…partiel…} }
 *
 * v586 — `mapVisibility` ('all' | 'friends' | 'hidden') est LA vérité
 * (utils/mapVisibility.js) ; `hideFromMap` reste lu et écrit pour les
 * anciennes versions (true → 'friends', false → 'all').
 *
 * `pawMap` est un petit objet libre mais VALIDÉ (`normalizeMapPrefs`) :
 * jamais plus de quelques centaines d'octets, jamais autre chose que ce que
 * la carte sait relire. Fusion partielle : on ne perd pas les clés absentes
 * du corps. Fonction pure exportée pour les tests.
 */
const logger = require('../utils/logger');

const MAX_RAIL = 24;
const RAIL_ID = /^[a-z_]{2,32}$/;
const LOOKING_FOR = ['all', 'sitters', 'walkers', 'places', 'friends'];

function num(v, min, max, { strict = false } = {}) {
  const n = typeof v === 'number' ? v : parseFloat(v);
  if (!Number.isFinite(n)) return undefined;
  if (strict && (n < min || n > max)) return undefined;
  return Math.min(max, Math.max(min, n));
}

/**
 * Fusionne `patch` dans `existing` et renvoie un objet propre.
 * @param {object|undefined} existing  pawMap déjà enregistré
 * @param {object|undefined} patch     corps partiel envoyé par l'app / le site
 */
function normalizeMapPrefs(existing, patch) {
  const base = existing && typeof existing === 'object' ? existing : {};
  const p = patch && typeof patch === 'object' ? patch : {};
  const out = {};

  // Caméra retenue : centre + zoom.
  const camSrc = p.camera !== undefined ? p.camera : base.camera;
  if (camSrc && typeof camSrc === 'object') {
    // Une coordonnée hors du globe = corps corrompu → caméra ignorée.
    const lat = num(camSrc.lat, -90, 90, { strict: true });
    const lng = num(camSrc.lng, -180, 180, { strict: true });
    const zoom = num(camSrc.zoom, 2, 21);
    if (lat !== undefined && lng !== undefined && !(lat === 0 && lng === 0)) {
      out.camera = { lat, lng, zoom: zoom === undefined ? 14 : zoom };
    }
  }

  // Calques (booléens seulement, clés connues).
  const LAYER_KEYS = ['places', 'reports', 'members', 'pawspots', 'live', 'requests', 'friends', 'premium'];
  const layersSrc = { ...(base.layers || {}), ...(p.layers || {}) };
  const layers = {};
  for (const k of LAYER_KEYS) {
    if (typeof layersSrc[k] === 'boolean') layers[k] = layersSrc[k];
  }
  if (Object.keys(layers).length) out.layers = layers;

  // Rôles de membres affichés.
  const rolesSrc = p.memberRoles !== undefined ? p.memberRoles : base.memberRoles;
  if (Array.isArray(rolesSrc)) {
    const roles = [...new Set(rolesSrc.map(String).filter((r) => ['owner', 'sitter', 'walker'].includes(r)))];
    out.memberRoles = roles;
  }

  // Rail personnalisable : ordre ET choix (ids courts connus de l'app).
  const railSrc = p.rail !== undefined ? p.rail : base.rail;
  if (Array.isArray(railSrc)) {
    const rail = [];
    for (const id of railSrc) {
      const s = String(id);
      if (RAIL_ID.test(s) && !rail.includes(s)) rail.push(s);
      if (rail.length >= MAX_RAIL) break;
    }
    out.rail = rail;
  }

  const lookingSrc = p.lookingFor !== undefined ? p.lookingFor : base.lookingFor;
  if (typeof lookingSrc === 'string' && LOOKING_FOR.includes(lookingSrc)) {
    out.lookingFor = lookingSrc;
  }

  const nightSrc = p.nightMode !== undefined ? p.nightMode : base.nightMode;
  if (typeof nightSrc === 'boolean') out.nightMode = nightSrc;

  const availSrc = p.availableTodayOnly !== undefined ? p.availableTodayOnly : base.availableTodayOnly;
  if (typeof availSrc === 'boolean') out.availableTodayOnly = availSrc;

  const radiusSrc = p.aroundRadiusKm !== undefined ? p.aroundRadiusKm : base.aroundRadiusKm;
  const radius = num(radiusSrc, 1, 50);
  if (radius !== undefined) out.aroundRadiusKm = radius;

  // Lot D (25/09/2026) — rayon des listes « Autour de moi » retenu PAR RÔLE
  // (curseur des 3 accueils, 10–500 km, entier). Fusion clé par clé : le
  // gardien qui choisit 70 km ne touche pas au rayon du propriétaire.
  const HOME_ROLES = ['owner', 'sitter', 'walker'];
  const homeSrc = { ...(base.homeRadiusKm || {}), ...(p.homeRadiusKm || {}) };
  const homeRadius = {};
  for (const role of HOME_ROLES) {
    const km = num(homeSrc[role], 10, 500);
    if (km !== undefined) homeRadius[role] = Math.round(km);
  }
  if (Object.keys(homeRadius).length) out.homeRadiusKm = homeRadius;

  const modeSrc = p.routeMode !== undefined ? p.routeMode : base.routeMode;
  if (['walk', 'bike', 'car'].includes(modeSrc)) out.routeMode = modeSrc;

  const coachSrc = p.coachShown !== undefined ? p.coachShown : base.coachShown;
  const coach = num(coachSrc, 0, 99);
  if (coach !== undefined) out.coachShown = Math.round(coach);

  const panelSrc = p.panelCollapsed !== undefined ? p.panelCollapsed : base.panelCollapsed;
  if (typeof panelSrc === 'boolean') out.panelCollapsed = panelSrc;

  // v587 (point 3) — barres repliables : rail gauche et capsule droite
  // rangées hors écran (languette), retenues sur le compte (app + site).
  for (const k of ['railCollapsed', 'capsuleCollapsed']) {
    const v = typeof p[k] === 'boolean' ? p[k] : base[k];
    if (typeof v === 'boolean') out[k] = v;
  }

  out.updatedAt = new Date().toISOString();
  return out;
}

function resolveModel(role) {
  if (role === 'owner') return require('../models/Owner');
  if (role === 'sitter') return require('../models/Sitter');
  if (role === 'walker') return require('../models/Walker');
  return null;
}

const MODEL_BY_NAME = () => ({
  Owner: require('../models/Owner'),
  Sitter: require('../models/Sitter'),
  Walker: require('../models/Walker'),
});

function present(doc) {
  const prefs = (doc && doc.preferences) || {};
  const { mapVisibilityOf } = require('../utils/mapVisibility');
  const mapVisibility = mapVisibilityOf(doc);
  return {
    mapVisibility,
    hideFromMap: mapVisibility !== 'all',
    pawMap: prefs.pawMap && typeof prefs.pawMap === 'object' ? prefs.pawMap : {},
    updatedAt: (prefs.pawMap && prefs.pawMap.updatedAt) || null,
  };
}

const getMapPrefs = async (req, res) => {
  try {
    const Model = resolveModel(req.user?.role);
    if (!Model) return res.status(403).json({ error: 'Unsupported role.' });
    const doc = await Model.findById(req.user.id).select('preferences').lean();
    if (!doc) return res.status(404).json({ error: 'User not found.' });
    return res.json(present(doc));
  } catch (e) {
    logger.error('getMapPrefs error', e);
    return res.status(500).json({ error: 'Unable to load map preferences.' });
  }
};

const updateMapPrefs = async (req, res) => {
  try {
    const Model = resolveModel(req.user?.role);
    if (!Model) return res.status(403).json({ error: 'Unsupported role.' });
    const body = req.body && typeof req.body === 'object' ? req.body : {};
    if (body.hideFromMap !== undefined && typeof body.hideFromMap !== 'boolean') {
      return res.status(400).json({ error: 'hideFromMap must be a boolean.' });
    }
    const { MAP_VISIBILITY, mapVisibilitySet } = require('../utils/mapVisibility');
    if (body.mapVisibility !== undefined && !MAP_VISIBILITY.includes(body.mapVisibility)) {
      return res.status(400).json({ error: 'mapVisibility must be all, friends or hidden.' });
    }
    if (body.pawMap !== undefined && (typeof body.pawMap !== 'object' || body.pawMap === null)) {
      return res.status(400).json({ error: 'pawMap must be an object.' });
    }
    const doc = await Model.findById(req.user.id).select('preferences').lean();
    if (!doc) return res.status(404).json({ error: 'User not found.' });

    const set = {};
    if (body.mapVisibility !== undefined) {
      Object.assign(set, mapVisibilitySet(body.mapVisibility));
    } else if (body.hideFromMap !== undefined) {
      // Ancienne app / ancien site : l'interrupteur « amis seulement ».
      Object.assign(set, mapVisibilitySet(body.hideFromMap ? 'friends' : 'all'));
    }
    if (body.pawMap !== undefined) {
      set['preferences.pawMap'] = normalizeMapPrefs(doc.preferences && doc.preferences.pawMap, body.pawMap);
    }
    if (!Object.keys(set).length) return res.json(present(doc));

    // Synchro sur les 3 documents de la personne (même règle que les
    // préférences de notification).
    const { identityGroup } = require('../utils/identityGroup');
    const g = await identityGroup(req.user.id);
    const models = MODEL_BY_NAME();
    await Promise.all(g.docs.map((d) => {
      const M = models[d.model];
      return M ? M.updateOne({ _id: d.id }, { $set: set }).catch(() => null) : null;
    }));
    const fresh = await Model.findById(req.user.id).select('preferences').lean();
    return res.json(present(fresh || { preferences: { ...doc.preferences, ...set } }));
  } catch (e) {
    logger.error('updateMapPrefs error', e);
    return res.status(500).json({ error: 'Unable to update map preferences.' });
  }
};

module.exports = { getMapPrefs, updateMapPrefs, normalizeMapPrefs, present };
