/**
 * pawSpotRoutes — v23.1.353 (refonte PawSpot, Daniel).
 *
 * PawSpot = spots pet-friendly communautaires sur la PawMap (remplace les
 * anciens halos "map boost"). Voir models/PawSpot.js + pawPointsService.js.
 *
 * Gratuit : voir les spots publics + créer jusqu'à 3 spots.
 * Abonnés PawSpot (4,99 €/mois · 39,99 €/an · essai 7 j) : tag ILLIMITÉ,
 * meilleurs PawSpots, récompenses à points (mise en avant 7 j, couleur de
 * badge, cadre doré profil...).
 */

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const PawSpot = require('../models/PawSpot');
const { PAWSPOT_TYPES } = require('../models/PawSpot');
const UserSubscription = require('../models/UserSubscription');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const airwallex = require('../services/airwallexService');
const { normalizeCurrency } = require('../utils/currency');
const pricingService = require('../services/pricingService');
const pawPoints = require('../services/pawPointsService');
const logger = require('../utils/logger');

const router = express.Router();
const PROVIDER = (process.env.PAYMENT_PROVIDER || 'airwallex').toLowerCase();
const ROLE_TO_MODEL_NAME = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };
const userModelFromRole = (role) => ROLE_TO_MODEL_NAME[role] || 'Owner';
const modelForRole = (role) =>
  role === 'walker' ? Walker : role === 'sitter' ? Sitter : Owner;

const FREE_SPOT_LIMIT = 3;
// v23.1.357 — Daniel : "spot validé par la communauté au bout de 10 likes".
const LIKES_FOR_VALIDATION = 10;
const PAWSPOT_PLAN_DAYS = { monthly: 30, yearly: 365 };
const TRIAL_DAYS = 7;
const REWARD_COSTS = Object.freeze({
  feature_spot: 50,   // mettre un spot en avant 7 jours
  badge_color: 100,   // changer la couleur de son badge
  banner: 150,        // bannière personnalisée
  gold_frame: 200,    // cadre doré autour du profil
});

// ── Pricing (fallback doc Daniel : 4,99 €/mois · 39,99 €/an) ────────────────
function getPawSpotPricing(plan, currency = 'EUR') {
  const days = PAWSPOT_PLAN_DAYS[plan];
  if (!days) return null;
  let table = null;
  try { table = pricingService.get('pawspot'); } catch (_) {/* defaults below */}
  const cur = normalizeCurrency(currency);
  const row = (table && (table[cur] || table.EUR)) || { monthly: 4.99, yearly: 39.99 };
  const amount = Number(row[plan]);
  if (!Number.isFinite(amount) || amount <= 0) return null;
  return { plan, days, amount, currency: cur };
}

// ── Abonnement PawSpot actif ? (payé OU essai 7 j OU bundle Paw Premium OU
// staff) ───────────────────────────────────────────────────────────────────
// v426 — Premium Staff + bundle Paw Premium. Avant, ce helper ne lisait que
// pawspotExpiry → un staff (abos gratuits) ou un abonné Paw Premium (bundle =
// premiumExpiry) était bloqué sur /directions et /rewards/redeem alors que le
// gate de création POST / le laissait passer. On aligne : staff OU premiumExpiry
// futur OU pawspotExpiry futur. 100 % additif.
async function hasActivePawSpot(userId, role) {
  try {
    const Model = modelForRole(role);
    const me = await Model.findById(userId).select('isStaff').lean();
    if (me && me.isStaff === true) return true;
    const sub = await UserSubscription.findOne({
      userId,
      userModel: userModelFromRole(role),
    }).select('pawspotExpiry premiumExpiry').lean();
    if (!sub) return false;
    const now = new Date();
    if (sub.pawspotExpiry && new Date(sub.pawspotExpiry) > now) return true;
    if (sub.premiumExpiry && new Date(sub.premiumExpiry) > now) return true;
    return false;
  } catch (_) {
    return false;
  }
}

// ── Itinéraire "Y aller" : inclus dans PawFollow / PawFamily ───────────────
// v426 — Premium Staff : le staff a tous les abos gratuits → accès tracking.
async function hasTrackingSubscription(userId, role) {
  try {
    const Model = modelForRole(role);
    const me = await Model.findById(userId).select('isStaff').lean();
    if (me && me.isStaff === true) return true;
    const sub = await UserSubscription.findOne({
      userId,
      userModel: userModelFromRole(role),
      status: 'active',
    }).lean();
    if (!sub) return false;
    const now = new Date();
    const expiry = sub.currentPeriodEnd || sub.expiresAt;
    if (expiry && new Date(expiry) > now) return true;
    if (sub.familyExpiry && new Date(sub.familyExpiry) > now) return true;
    return false;
  } catch (_) {
    return false;
  }
}

/**
 * v23.1.360 — Daniel : "les emoji pawspot dorés n'apparaissent pas".
 * Recalcule creatorIsGold à la LECTURE pour les spots existants : créateur
 * staff OU >= 1 000 PawPoints → empreinte dorée, même pour les spots créés
 * avant ce changement. Batch (3 requêtes max) sur les creatorIds distincts.
 */
async function enrichGoldenCreators(spots) {
  try {
    const ids = [...new Set(spots.map((s) => String(s.creatorId)))];
    if (!ids.length) return;
    const goldIds = new Set();
    for (const Model of [Owner, Sitter, Walker]) {
      const docs = await Model.find({
        _id: { $in: ids },
        $or: [{ isStaff: true }, { pawPoints: { $gte: 1000 } }],
      }).select('_id').lean();
      for (const d of docs) goldIds.add(String(d._id));
    }
    for (const s of spots) {
      if (goldIds.has(String(s.creatorId))) s.creatorIsGold = true;
    }
  } catch (e) {
    logger.warn(`[pawspots] enrichGoldenCreators failed: ${e?.message || e}`);
  }
}

// v465 — Daniel : « PawSpot censure des mots innocents (étoiles) ». La
// modération est désormais NON DESTRUCTIVE : on stocke le texte BRUT et on
// censure À LA LECTURE (ici) avec les règles à jour. Avantage : un correctif
// de modération s'applique RÉTROACTIVEMENT à tous les spots, et le texte
// original n'est jamais perdu. (Les anciens spots déjà stockés censurés
// restent tels quels — il faut les recréer.)
const { moderateText: _moderateSpot } = require('../services/textModerationService');
const spotJson = (s) => ({
  id: String(s._id),
  type: s.type,
  name: _moderateSpot(s.name || '').clean,
  description: _moderateSpot(s.description || '').clean,
  photoUrl: s.photoUrl || '',
  lat: Array.isArray(s.location?.coordinates) ? Number(s.location.coordinates[1]) : null,
  lng: Array.isArray(s.location?.coordinates) ? Number(s.location.coordinates[0]) : null,
  city: s.location?.city || '',
  creatorId: String(s.creatorId),
  creatorName: s.creatorName || '',
  likesCount: s.likesCount || 0,
  validationsCount: s.validationsCount || 0,
  visitsCount: s.visitsCount || 0,
  commentsCount: Array.isArray(s.comments) ? s.comments.length : 0,
  communityValidated: s.communityValidated === true,
  // Empreinte DORÉE 🐾 : validé communauté OU 50+ likes OU créateur Gold.
  isGolden:
    s.communityValidated === true || (s.likesCount || 0) >= 50 || s.creatorIsGold === true,
  featured: !!(s.featuredUntil && new Date(s.featuredUntil) > new Date()),
  // ⭐ qualité (système de confiance) : 3.0 base, +0.5/validation, cap 5.
  quality: Math.min(5, Math.round((3 + (s.validationsCount || 0) * 0.5) * 10) / 10),
  createdAt: s.createdAt,
});

// ════════════════════════════════════════════════════════════════════════════
// LECTURE
// ════════════════════════════════════════════════════════════════════════════

// GET /pawspots/nearby?lat&lng&radius — spots autour (tous publics).
router.get('/nearby', requireAuth, async (req, res) => {
  try {
    const lat = Number(req.query.lat);
    const lng = Number(req.query.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return res.status(400).json({ error: 'lat & lng required.' });
    }
    const maxDistance = Math.min(Number(req.query.radius) || 25000, 100000);
    const spots = await PawSpot.find({
      hidden: false,
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: [lng, lat] },
          $maxDistance: maxDistance,
        },
      },
    }).limit(200).lean();
    // Les spots "mis en avant" remontent en premier.
    spots.sort((a, b) => {
      const fa = a.featuredUntil && new Date(a.featuredUntil) > new Date() ? 1 : 0;
      const fb = b.featuredUntil && new Date(b.featuredUntil) > new Date() ? 1 : 0;
      return fb - fa;
    });
    await enrichGoldenCreators(spots);
    res.json({ spots: spots.map(spotJson) });
  } catch (e) {
    logger.error('[pawspots/nearby]', e);
    res.status(500).json({ error: e.message });
  }
});

// GET /pawspots/top — meilleurs PawSpots (abonnés uniquement).
router.get('/top', requireAuth, async (req, res) => {
  try {
    const subscribed = await hasActivePawSpot(req.user.id, req.user.role);
    if (!subscribed) {
      return res.status(402).json({
        error: 'PawSpot subscription required to see the best PawSpots.',
        code: 'PAWSPOT_REQUIRED',
      });
    }
    const spots = await PawSpot.find({ hidden: false })
      .sort({ likesCount: -1, validationsCount: -1 })
      .limit(50)
      .lean();
    await enrichGoldenCreators(spots);
    res.json({ spots: spots.map(spotJson) });
  } catch (e) {
    logger.error('[pawspots/top]', e);
    res.status(500).json({ error: e.message });
  }
});

// GET /pawspots/leaderboard?scope=city|country|europe — classements.
// v23.1.365 — Daniel : "dans Pays rien n'apparaît, les pays ne sont pas
// configurés". Le PAYS est désormais DÉRIVÉ de l'indicatif téléphonique
// (countryCode "+34" → 🇪🇸 España) : le scope 'country' matche tous les
// formats ("+34"/"34"/"+34 ") via regex sur les chiffres, et chaque ligne
// embarque { flag, name } pour l'affichage.
router.get('/leaderboard', requireAuth, async (req, res) => {
  try {
    const { countryFromPhone } = require('../utils/countryFromPhone');
    const scope = String(req.query.scope || 'europe').toLowerCase();
    // Ville/pays du demandeur (best-effort sur les champs profil existants).
    let myCity = '';
    let myCountryDigits = '';
    try {
      const Model = modelForRole(req.user.role);
      const meDoc = await Model.findById(req.user.id)
        .select('location countryCode address').lean();
      myCity = (meDoc?.location?.city || '').trim();
      myCountryDigits = String(meDoc?.countryCode || '').replace(/[^0-9]/g, '');
    } catch (_) {/* */}
    const myCountry = countryFromPhone(myCountryDigits);

    const rows = [];
    for (const [Model, role] of [[Owner, 'owner'], [Sitter, 'sitter'], [Walker, 'walker']]) {
      const filter = { pawPoints: { $gt: 0 } };
      if (scope === 'city' && myCity) filter['location.city'] = myCity;
      if (scope === 'country' && myCountryDigits) {
        // "+34", "34", "+34 " → même pays. Regex tolérante aux formats.
        filter.countryCode = new RegExp(`^\\s*\\+?\\s*${myCountryDigits}\\s*$`);
      }
      const docs = await Model.find(filter)
        .sort({ pawPoints: -1 })
        .limit(50)
        .select('name avatar pawPoints pawBadgeColor pawGoldFrame location.city countryCode')
        .lean();
      for (const d of docs) {
        const c = countryFromPhone(d.countryCode);
        rows.push({
          userId: String(d._id),
          role,
          name: d.name || '',
          avatar: d.avatar?.url || '',
          points: d.pawPoints || 0,
          badge: pawPoints.badgeFor(d.pawPoints),
          badgeColor: d.pawBadgeColor || '',
          goldFrame: d.pawGoldFrame === true,
          city: d.location?.city || '',
          countryFlag: c?.flag || '',
          countryName: c?.name || '',
        });
      }
    }
    rows.sort((a, b) => b.points - a.points);
    res.json({
      scope,
      city: myCity,
      country: myCountry?.iso || '',
      countryFlag: myCountry?.flag || '',
      countryName: myCountry?.name || '',
      leaderboard: rows.slice(0, 50),
    });
  } catch (e) {
    logger.error('[pawspots/leaderboard]', e);
    res.status(500).json({ error: e.message });
  }
});

// GET /pawspots/me/points — mes points + badge + statut abo + compteur spots.
router.get('/me/points', requireAuth, async (req, res) => {
  try {
    // v426 — expose aussi le solde DÉPENSABLE (spendable) : depuis le split
    // lifetime/spendable, les récompenses cosmétiques se débitent sur le solde
    // dépensable, pas sur le total à vie. `points` reste le total à vie (niveau).
    const st = await pawPoints.getPawState(req.user.id, req.user.role);
    const points = st.lifetime;
    const mySpots = await PawSpot.countDocuments({ creatorId: req.user.id });
    const subscribed = await hasActivePawSpot(req.user.id, req.user.role);
    const sub = await UserSubscription.findOne({
      userId: req.user.id,
      userModel: userModelFromRole(req.user.role),
    }).select('pawspotExpiry pawspotTrialUsedAt').lean();
    res.json({
      points,
      spendable: st.spendable,
      lifetime: st.lifetime,
      badge: pawPoints.badgeFor(points),
      nextBadge: pawPoints.nextBadgeFor(points),
      isGoldCreator: pawPoints.isGoldCreator(points),
      mySpotsCount: mySpots,
      freeSpotLimit: FREE_SPOT_LIMIT,
      subscribed,
      pawspotExpiry: sub?.pawspotExpiry || null,
      trialUsed: !!sub?.pawspotTrialUsedAt,
      rewardCosts: REWARD_COSTS,
    });
  } catch (e) {
    logger.error('[pawspots/me/points]', e);
    res.status(500).json({ error: e.message });
  }
});

// GET /pawspots/directions — itinéraire "Y aller" (inclus PawFollow/PawFamily).
// Proxy OSRM (profil piéton) → liste de points [lat,lng] à dessiner sur la
// PawMap. Fallback : ligne droite si le service externe échoue.
router.get('/directions', requireAuth, async (req, res) => {
  try {
    const fromLat = Number(req.query.fromLat);
    const fromLng = Number(req.query.fromLng);
    const toLat = Number(req.query.toLat);
    const toLng = Number(req.query.toLng);
    if (![fromLat, fromLng, toLat, toLng].every(Number.isFinite)) {
      return res.status(400).json({ error: 'fromLat/fromLng/toLat/toLng required.' });
    }
    // v23.1.361 — décision Daniel : l'itinéraire n'est PAS gratuit mais il
    // est inclus dans les TROIS abonnements (PawFollow, PawFamily ET
    // PawSpot) — chaque produit carte y donne droit.
    const allowed =
      (await hasTrackingSubscription(req.user.id, req.user.role)) ||
      (await hasActivePawSpot(req.user.id, req.user.role));
    if (!allowed) {
      return res.status(402).json({
        error: 'PawFollow / PawFamily / PawSpot subscription required for directions.',
        code: 'PAWFOLLOW_REQUIRED',
      });
    }
    try {
      const url =
        `https://router.project-osrm.org/route/v1/foot/${fromLng},${fromLat};${toLng},${toLat}` +
        `?overview=full&geometries=geojson`;
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 6000);
      const resp = await fetch(url, { signal: controller.signal });
      clearTimeout(timer);
      const data = await resp.json();
      const coords = data?.routes?.[0]?.geometry?.coordinates;
      if (Array.isArray(coords) && coords.length > 1) {
        return res.json({
          points: coords.map((c) => ({ lat: c[1], lng: c[0] })),
          distanceMeters: Math.round(data.routes[0].distance || 0),
          durationSeconds: Math.round(data.routes[0].duration || 0),
          source: 'osrm',
        });
      }
    } catch (osrmErr) {
      logger.warn(`[pawspots/directions] OSRM failed: ${osrmErr?.message || osrmErr}`);
    }
    // Fallback ligne droite.
    return res.json({
      points: [
        { lat: fromLat, lng: fromLng },
        { lat: toLat, lng: toLng },
      ],
      distanceMeters: null,
      durationSeconds: null,
      source: 'straight',
    });
  } catch (e) {
    logger.error('[pawspots/directions]', e);
    res.status(500).json({ error: e.message });
  }
});

// ════════════════════════════════════════════════════════════════════════════
// CRÉATION & INTERACTIONS
// ════════════════════════════════════════════════════════════════════════════

// POST /pawspots — créer un spot (+10 pts, +5 si photo). Gratuit : 3 max.
router.post('/', requireAuth, async (req, res) => {
  try {
    const { type, name, description, photoUrl, lat, lng, city } = req.body || {};
    if (!PAWSPOT_TYPES.includes(type)) {
      return res.status(400).json({ error: 'Invalid spot type.', types: PAWSPOT_TYPES });
    }
    if (!name || !String(name).trim()) {
      return res.status(400).json({ error: 'Spot name required.' });
    }
    const nLat = Number(lat);
    const nLng = Number(lng);
    if (!Number.isFinite(nLat) || !Number.isFinite(nLng)) {
      return res.status(400).json({ error: 'lat & lng required.' });
    }

    // Limite gratuite : 3 spots (abonnés + staff = illimité).
    const Model = modelForRole(req.user.role);
    const meDoc = await Model.findById(req.user.id)
      .select('name isStaff pawPoints').lean();
    const subscribed = await hasActivePawSpot(req.user.id, req.user.role);
    if (!subscribed && meDoc?.isStaff !== true) {
      const count = await PawSpot.countDocuments({ creatorId: req.user.id });
      if (count >= FREE_SPOT_LIMIT) {
        return res.status(402).json({
          error: `Free accounts can create up to ${FREE_SPOT_LIMIT} PawSpots. Subscribe to PawSpot for unlimited tagging.`,
          code: 'PAWSPOT_REQUIRED',
        });
      }
    }

    // v465 — modération NON DESTRUCTIVE : on stocke le texte BRUT (tronqué)
    // et la censure se fait à la LECTURE dans spotJson (règles à jour,
    // rétroactif, pas de perte de l'original).
    const rawName = String(name).trim();
    const rawDesc = String(description || '').trim();

    const spot = await PawSpot.create({
      creatorId: req.user.id,
      creatorModel: userModelFromRole(req.user.role),
      creatorName: meDoc?.name || '',
      type,
      name: rawName.slice(0, 80),
      description: rawDesc.slice(0, 500),
      photoUrl: String(photoUrl || '').slice(0, 500),
      location: {
        type: 'Point',
        coordinates: [nLng, nLat],
        city: String(city || '').slice(0, 80),
      },
      // v23.1.360 — Daniel : "les emoji pawspot dorés n'apparaissent pas".
      // Le STAFF est Gold Creator d'office (démo/marketing : ses spots
      // portent l'empreinte dorée), en plus du seuil 1 000 PawPoints.
      creatorIsGold:
        pawPoints.isGoldCreator(meDoc?.pawPoints) || meDoc?.isStaff === true,
    });

    // Points : +10 création, +5 photo.
    let earned = pawPoints.POINTS.spotCreated;
    await pawPoints.awardPoints({
      userId: req.user.id, role: req.user.role,
      points: pawPoints.POINTS.spotCreated, reason: 'spot created',
    });
    if (spot.photoUrl) {
      earned += pawPoints.POINTS.photoAdded;
      await pawPoints.awardPoints({
        userId: req.user.id, role: req.user.role,
        points: pawPoints.POINTS.photoAdded, reason: 'spot photo',
      });
    }

    res.status(201).json({ spot: spotJson(spot), pointsEarned: earned });
  } catch (e) {
    logger.error('[pawspots POST]', e);
    res.status(500).json({ error: e.message });
  }
});

// POST /pawspots/:id/like — toggle ❤️ (+25 pts créateur à 50 likes, 1 fois).
router.post('/:id/like', requireAuth, async (req, res) => {
  try {
    const spot = await PawSpot.findById(req.params.id);
    if (!spot || spot.hidden) return res.status(404).json({ error: 'Spot not found.' });
    const uid = String(req.user.id);
    const idx = spot.likedBy.indexOf(uid);
    if (idx >= 0) {
      spot.likedBy.splice(idx, 1);
    } else {
      spot.likedBy.push(uid);
    }
    spot.likesCount = spot.likedBy.length;
    // v23.1.357 — validé par la communauté à 10 ❤️ : +10 pts créateur (1 fois).
    if (spot.likesCount >= LIKES_FOR_VALIDATION && !spot.communityValidated) {
      spot.communityValidated = true;
      if (!spot.validationAwarded) {
        spot.validationAwarded = true;
        await pawPoints.awardPoints({
          userId: spot.creatorId, role: spot.creatorModel.toLowerCase(),
          points: pawPoints.POINTS.spotValidated, reason: 'spot validated (10 likes)',
        });
      }
    }
    // Très populaire : 50 likes → +25 pts créateur (une seule fois).
    if (spot.likesCount >= 50 && !spot.popularAwarded) {
      spot.popularAwarded = true;
      await pawPoints.awardPoints({
        userId: spot.creatorId, role: spot.creatorModel.toLowerCase(),
        points: pawPoints.POINTS.spotPopular, reason: 'spot popular (50 likes)',
      });
    }
    await spot.save();
    res.json({ liked: idx < 0, likesCount: spot.likesCount });
  } catch (e) {
    logger.error('[pawspots like]', e);
    res.status(500).json({ error: e.message });
  }
});

// POST /pawspots/:id/validate — 🏆 valider (3 validations = validé, +10 créateur).
router.post('/:id/validate', requireAuth, async (req, res) => {
  try {
    const spot = await PawSpot.findById(req.params.id);
    if (!spot || spot.hidden) return res.status(404).json({ error: 'Spot not found.' });
    const uid = String(req.user.id);
    if (uid === String(spot.creatorId)) {
      return res.status(400).json({ error: 'You cannot validate your own spot.' });
    }
    if (spot.validatedBy.includes(uid)) {
      return res.json({ validated: spot.communityValidated, validationsCount: spot.validationsCount, already: true });
    }
    spot.validatedBy.push(uid);
    spot.validationsCount = spot.validatedBy.length;
    if (spot.validationsCount >= 3 && !spot.communityValidated) {
      spot.communityValidated = true;
      if (!spot.validationAwarded) {
        spot.validationAwarded = true;
        await pawPoints.awardPoints({
          userId: spot.creatorId, role: spot.creatorModel.toLowerCase(),
          points: pawPoints.POINTS.spotValidated, reason: 'spot community-validated',
        });
      }
    }
    await spot.save();
    res.json({ validated: spot.communityValidated, validationsCount: spot.validationsCount });
  } catch (e) {
    logger.error('[pawspots validate]', e);
    res.status(500).json({ error: e.message });
  }
});

// POST /pawspots/:id/visit — 👣 marquer une visite (1 fois par user).
router.post('/:id/visit', requireAuth, async (req, res) => {
  try {
    const uid = String(req.user.id);
    const spot = await PawSpot.findOneAndUpdate(
      { _id: req.params.id, hidden: false, visitedBy: { $ne: uid } },
      { $push: { visitedBy: uid }, $inc: { visitsCount: 1 } },
      { new: true },
    );
    if (!spot) {
      const existing = await PawSpot.findById(req.params.id).select('visitsCount').lean();
      return res.json({ visitsCount: existing?.visitsCount || 0, already: true });
    }
    res.json({ visitsCount: spot.visitsCount });
  } catch (e) {
    logger.error('[pawspots visit]', e);
    res.status(500).json({ error: e.message });
  }
});

// POST /pawspots/:id/comment — 💬 commenter (+2 pts, modéré).
router.post('/:id/comment', requireAuth, async (req, res) => {
  try {
    const text = String(req.body?.text || '').trim();
    if (!text) return res.status(400).json({ error: 'Comment text required.' });
    const spot = await PawSpot.findById(req.params.id);
    if (!spot || spot.hidden) return res.status(404).json({ error: 'Spot not found.' });
    const Model = modelForRole(req.user.role);
    const meDoc = await Model.findById(req.user.id).select('name').lean();
    spot.comments.push({
      authorId: req.user.id,
      authorModel: userModelFromRole(req.user.role),
      authorName: meDoc?.name || '',
      // v465 — texte BRUT stocké, censuré à la lecture (GET comments).
      text: text.slice(0, 300),
    });
    await spot.save();
    await pawPoints.awardPoints({
      userId: req.user.id, role: req.user.role,
      points: pawPoints.POINTS.usefulComment, reason: 'spot comment',
    });
    res.json({ commentsCount: spot.comments.length });
  } catch (e) {
    logger.error('[pawspots comment]', e);
    res.status(500).json({ error: e.message });
  }
});

// GET /pawspots/:id/comments — liste des commentaires (récents d'abord).
router.get('/:id/comments', requireAuth, async (req, res) => {
  try {
    const spot = await PawSpot.findById(req.params.id).select('comments').lean();
    if (!spot) return res.status(404).json({ error: 'Spot not found.' });
    const comments = [...(spot.comments || [])]
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
      .slice(0, 50)
      .map((c) => ({
        id: String(c._id),
        authorName: c.authorName || '',
        // v465 — censure à la lecture (non destructif, rétroactif).
        text: _moderateSpot(c.text || '').clean,
        createdAt: c.createdAt,
      }));
    res.json({ comments });
  } catch (e) {
    logger.error('[pawspots comments]', e);
    res.status(500).json({ error: e.message });
  }
});

// DELETE /pawspots/:id — créateur uniquement (admin via route admin).
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const spot = await PawSpot.findById(req.params.id);
    if (!spot) return res.status(404).json({ error: 'Spot not found.' });
    if (String(spot.creatorId) !== String(req.user.id)) {
      return res.status(403).json({ error: 'Only the creator can delete this spot.' });
    }
    await spot.deleteOne();
    res.json({ deleted: true });
  } catch (e) {
    logger.error('[pawspots delete]', e);
    res.status(500).json({ error: e.message });
  }
});

// ════════════════════════════════════════════════════════════════════════════
// RÉCOMPENSES PREMIUM (dépense de PawPoints — abonnés uniquement)
// ════════════════════════════════════════════════════════════════════════════

// POST /pawspots/rewards/redeem { reward, spotId?, color?, bannerUrl? }
router.post('/rewards/redeem', requireAuth, async (req, res) => {
  try {
    const reward = String(req.body?.reward || '');
    const cost = REWARD_COSTS[reward];
    if (!cost) {
      return res.status(400).json({ error: 'Unknown reward.', rewards: REWARD_COSTS });
    }
    const subscribed = await hasActivePawSpot(req.user.id, req.user.role);
    if (!subscribed) {
      return res.status(402).json({
        error: 'PawSpot subscription required to redeem rewards.',
        code: 'PAWSPOT_REQUIRED',
      });
    }
    const Model = modelForRole(req.user.role);
    // v426 — débit sur le solde DÉPENSABLE (pawPointsSpendable), PAS sur le
    // total à vie (pawPoints) qui détermine le niveau/badge et ne doit JAMAIS
    // baisser (cf pawPointsService). Avant, dépenser une récompense cosmétique
    // faisait perdre des points à vie → rétrogradation de niveau possible.
    // Backfill paresseux : si pawPointsSpendable absent (anciens comptes), on
    // l'initialise au total à vie (ils n'ont encore rien dépensé).
    await Model.updateOne(
      { _id: req.user.id, pawPointsSpendable: { $exists: false } },
      [{ $set: { pawPointsSpendable: { $ifNull: ['$pawPoints', 0] } } }],
    ).catch(() => {});
    // Débit atomique : seulement si solde dépensable suffisant.
    const updated = await Model.findOneAndUpdate(
      { _id: req.user.id, pawPointsSpendable: { $gte: cost } },
      { $inc: { pawPointsSpendable: -cost } },
      { new: true },
    ).select('pawPointsSpendable');
    if (!updated) {
      return res.status(402).json({ error: 'Not enough PawPoints.', code: 'INSUFFICIENT_POINTS' });
    }

    if (reward === 'feature_spot') {
      const spot = await PawSpot.findOne({ _id: req.body?.spotId, creatorId: req.user.id });
      if (!spot) {
        // Rembourse si le spot n'existe pas / pas à lui.
        await Model.findByIdAndUpdate(req.user.id, { $inc: { pawPointsSpendable: cost } });
        return res.status(404).json({ error: 'Spot not found (or not yours).' });
      }
      spot.featuredUntil = new Date(Date.now() + 7 * 86400000);
      await spot.save();
    } else if (reward === 'badge_color') {
      const color = String(req.body?.color || '').trim();
      if (!/^#?[0-9a-fA-F]{6}$/.test(color)) {
        await Model.findByIdAndUpdate(req.user.id, { $inc: { pawPointsSpendable: cost } });
        return res.status(400).json({ error: 'color must be a hex like #FFAA00.' });
      }
      await Model.findByIdAndUpdate(req.user.id, {
        pawBadgeColor: color.startsWith('#') ? color : `#${color}`,
      });
    } else if (reward === 'banner') {
      const bannerUrl = String(req.body?.bannerUrl || '').trim().slice(0, 500);
      await Model.findByIdAndUpdate(req.user.id, { pawBannerUrl: bannerUrl });
    } else if (reward === 'gold_frame') {
      await Model.findByIdAndUpdate(req.user.id, { pawGoldFrame: true });
    }

    res.json({ redeemed: reward, cost, pointsLeft: updated.pawPointsSpendable });
  } catch (e) {
    logger.error('[pawspots redeem]', e);
    res.status(500).json({ error: e.message });
  }
});

// ════════════════════════════════════════════════════════════════════════════
// ABONNEMENT PAWSPOT (4,99 €/mois · 39,99 €/an · essai gratuit 7 jours)
// ════════════════════════════════════════════════════════════════════════════

// POST /pawspots/trial — essai gratuit 7 jours (une seule fois).
router.post('/trial', requireAuth, async (req, res) => {
  try {
    const userModel = userModelFromRole(req.user.role);
    let sub = await UserSubscription.findOne({ userId: req.user.id, userModel });
    if (sub?.pawspotTrialUsedAt) {
      return res.status(409).json({ error: 'Free trial already used.', code: 'TRIAL_USED' });
    }
    if (!sub) sub = new UserSubscription({ userId: req.user.id, userModel });
    const now = new Date();
    const base = sub.pawspotExpiry && new Date(sub.pawspotExpiry) > now
      ? new Date(sub.pawspotExpiry) : now;
    sub.pawspotExpiry = new Date(base.getTime() + TRIAL_DAYS * 86400000);
    sub.pawspotTrialUsedAt = now;
    await sub.save();
    res.json({ activated: true, trialDays: TRIAL_DAYS, pawspotExpiry: sub.pawspotExpiry });
  } catch (e) {
    logger.error('[pawspots/trial]', e);
    res.status(500).json({ error: e.message });
  }
});

// POST /pawspots/subscribe { plan: 'monthly'|'yearly', currency?, payWithWallet? }
router.post('/subscribe', requireAuth, async (req, res) => {
  try {
    const plan = String(req.body?.plan || 'monthly');
    const pricing = getPawSpotPricing(plan, req.body?.currency);
    if (!pricing) return res.status(400).json({ error: 'Invalid plan (monthly|yearly).' });

    const userId = req.user.id;
    const role = req.user.role;

    // v416 — réduction PawPoints applicable à PawSpot (sentinelle 'pawspot'
    // dans snapshot.plans). Consomme la 1re réduction en attente, 1×/user.
    try {
      const PawRewardRedemption = require('../models/PawRewardRedemption');
      const pending = await PawRewardRedemption.find({
        userId, rewardKey: { $regex: '^sub_disc_' }, status: 'pending',
      }).sort({ createdAt: 1 });
      const match = pending.find((r) => {
        const plans = (r.snapshot && r.snapshot.plans) || [];
        return Array.isArray(plans) && plans.includes('pawspot');
      });
      if (match) {
        const pct = Number(match.snapshot.percent) || 0;
        if (pct > 0) {
          pricing.amount = Math.round(pricing.amount * (1 - pct / 100) * 100) / 100;
          match.status = 'fulfilled';
          await match.save();
          logger.info(`[pawspots] réduction PawPoints -${pct}% appliquée pour ${role} ${userId} → ${pricing.amount}`);
        }
      }
    } catch (e) {
      logger.warn(`[pawspots] pawpoints discount check failed: ${e.message}`);
    }

    const amountCents = Math.round(pricing.amount * 100);

    // Staff = gratuit (aligné boost / subscriptions / map-boost / chat).
    try {
      const Model = modelForRole(role);
      const staffUser = await Model.findById(userId).select('isStaff').lean();
      if (staffUser && staffUser.isStaff) {
        const { activatePawSpotFromWebhook } = require('../controllers/purchaseActivationController');
        await activatePawSpotFromWebhook({
          piId: `staff_free_${Date.now()}_pawspot`,
          metadata: {
            userId: String(userId), role, plan,
            days: String(pricing.days), currency: pricing.currency,
          },
        });
        return res.json({ activated: true, staffFree: true, plan, amount: 0, currency: pricing.currency });
      }
    } catch (e) {
      logger.warn('[pawspots] staff bypass check failed (continuing paid flow)', e);
    }

    // Wallet (sitter/walker) — débit instantané.
    const payWithWallet = req.body?.payWithWallet === true;
    if (payWithWallet && (role === 'walker' || role === 'sitter')) {
      try {
        const { payFromWallet } = require('../services/walletService');
        await payFromWallet({
          userId: String(userId), userRole: role,
          amount: pricing.amount, currency: pricing.currency,
          type: 'debit_purchase', reference: 'pawspot',
          meta: { kind: 'pawspot', plan, days: pricing.days },
        });
        const { activatePawSpotFromWebhook } = require('../controllers/purchaseActivationController');
        await activatePawSpotFromWebhook({
          piId: `wallet_${Date.now()}_pawspot`,
          metadata: {
            userId: String(userId), role, plan,
            days: String(pricing.days), currency: pricing.currency,
          },
        });
        return res.json({
          activated: true, paidFromWallet: true, plan,
          amount: pricing.amount, currency: pricing.currency,
        });
      } catch (e) {
        if (e.code === 'INSUFFICIENT_BALANCE') {
          return res.status(402).json({ error: 'Solde wallet insuffisant.', code: 'INSUFFICIENT_BALANCE' });
        }
        logger.error('[pawspots] payWithWallet failed', e);
        return res.status(500).json({ error: e.message });
      }
    }

    // Airwallex (HPP).
    if (PROVIDER === 'airwallex') {
      try {
        let airwallexCustomerId = null;
        try {
          const Model = modelForRole(role);
          const userDoc = await Model.findById(userId).select('email name').lean();
          if (userDoc && userDoc.email) {
            const customer = await airwallex.findOrCreateCustomer({
              userId: String(userId),
              email: userDoc.email,
              firstName: (userDoc.name || '').split(' ')[0] || userDoc.name || '',
              lastName: (userDoc.name || '').split(' ').slice(1).join(' ') || '',
            });
            airwallexCustomerId = customer?.id || null;
          }
        } catch (custErr) {
          logger.warn(`[pawspots] customer ensure failed: ${custErr?.message || custErr}`);
        }

        const intent = await airwallex.createPlatformPaymentIntent({
          amount: amountCents,
          currency: pricing.currency,
          ...(airwallexCustomerId ? { customer_id: airwallexCustomerId } : {}),
          metadata: {
            type: 'pawspot_purchase',
            kind: 'pawspot',
            userId: String(userId), role, plan,
            days: String(pricing.days),
            currency: pricing.currency,
          },
        });
        logger.info(
          `[pawspots] airwallex PI ${intent.id} ${pricing.amount} ${pricing.currency} plan=${plan} by ${role} ${userId}`,
        );
        return res.json({
          clientSecret: intent.client_secret,
          paymentIntentId: intent.id,
          provider: 'airwallex',
          plan,
          amount: pricing.amount,
          currency: pricing.currency,
        });
      } catch (e) {
        logger.error('[pawspots] airwallex create-intent failed', e);
        return res.status(502).json({ error: 'Unable to start PawSpot purchase right now.' });
      }
    }
    return res.status(502).json({ error: 'Stripe payment disabled — Airwallex only' });
  } catch (e) {
    logger.error('[pawspots/subscribe]', e);
    res.status(500).json({ error: e.message });
  }
});

// POST /pawspots/confirm { paymentIntentId, plan } — activation sync (fallback
// webhook), même rôle que /chat-addon/confirm.
router.post('/confirm', requireAuth, async (req, res) => {
  try {
    const plan = String(req.body?.plan || 'monthly');
    const pricing = getPawSpotPricing(plan, req.body?.currency);
    if (!pricing) return res.status(400).json({ error: 'Invalid plan.' });
    const { activatePawSpotFromWebhook } = require('../controllers/purchaseActivationController');
    const result = await activatePawSpotFromWebhook({
      piId: String(req.body?.paymentIntentId || `sync_${Date.now()}_pawspot`),
      metadata: {
        userId: String(req.user.id), role: req.user.role, plan,
        days: String(pricing.days), currency: pricing.currency,
      },
    });
    res.json({ activated: true, pawspotExpiry: result?.pawspotExpiry || null });
  } catch (e) {
    logger.error('[pawspots/confirm]', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
module.exports.hasActivePawSpot = hasActivePawSpot;
