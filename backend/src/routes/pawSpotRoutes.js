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
// v568 — cartes enregistrées : UN client Airwallex par personne (partagé par
// les profils owner / sitter / walker) + branchement unique du client sur
// l'intention de paiement. Cf. utils/airwallexCustomer.js.
const {
  ensureAirwallexCustomer,
  intentCustomerFields,
} = require('../utils/airwallexCustomer');
const { normalizeCurrency } = require('../utils/currency');
const pricingService = require('../services/pricingService');
const pawPoints = require('../services/pawPointsService');
const logger = require('../utils/logger');
// v532 — verification du paiement avant toute activation boutique.
const { assertPaidIntent, PaymentNotVerifiedError } = require('../utils/assertPaidIntent');
// v566 — plateforme d'origine de l'achat (ios | android | web).
const { platformFromRequest } = require('../utils/purchasePlatform');
// v576 — PawSpot appartient à la PERSONNE (ses 3 profils), pas au rôle actif.
const { personIds } = require('../utils/personScope');

const router = express.Router();
const PROVIDER = (process.env.PAYMENT_PROVIDER || 'airwallex').toLowerCase();
const ROLE_TO_MODEL_NAME = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };
const userModelFromRole = (role) => ROLE_TO_MODEL_NAME[role] || 'Owner';
const modelForRole = (role) =>
  role === 'walker' ? Walker : role === 'sitter' ? Sitter : Owner;

const FREE_SPOT_LIMIT = 3;
// v567 — anti-ferme à points : au-delà de ce nombre de spots créés en 24 h par
// un même compte, les tags supplémentaires ne rapportent plus de PawPoints.
const SPOT_POINTS_DAILY_CAP = 10;
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
// v567 — CROSS-RÔLE. Un compte HoPetSit = jusqu'à TROIS documents (owner /
// sitter / walker) reliés par l'email, et l'abonnement est stocké sur le
// document du rôle avec lequel il a été acheté. Ce helper ne lisait que le rôle
// ACTIF : un utilisateur ayant payé PawSpot (ou Paw Premium) en propriétaire
// était traité comme non-abonné depuis son profil promeneur — bloqué au 4e tag
// et renvoyé à la boutique alors qu'il paie déjà. On résout donc aussi sur les
// profils frères, comme friendRoutes le fait pour le badge Premium.
async function hasActivePawSpot(userId, role) {
  try {
    const now = new Date();
    const Model = modelForRole(role);
    const me = await Model.findById(userId).select('isStaff email').lean();
    if (me && me.isStaff === true) return true;
    const sub = await UserSubscription.findOne({
      userId,
      userModel: userModelFromRole(role),
    }).select('pawspotExpiry premiumExpiry').lean();
    if (sub) {
      if (sub.pawspotExpiry && new Date(sub.pawspotExpiry) > now) return true;
      if (sub.premiumExpiry && new Date(sub.premiumExpiry) > now) return true;
    }
    const email = String(me?.email || '').toLowerCase().trim();
    if (!email) return false;
    const sibIds = [];
    for (const M of [Owner, Sitter, Walker]) {
      const d = await M.findOne({ email }).select('_id isStaff').lean();
      if (!d) continue;
      if (d.isStaff === true) return true;
      if (String(d._id) !== String(userId)) sibIds.push(d._id);
    }
    if (!sibIds.length) return false;
    const sibSub = await UserSubscription.findOne({
      userId: { $in: sibIds },
      $or: [
        { pawspotExpiry: { $gt: now } },
        { premiumExpiry: { $gt: now } },
      ],
    }).select('_id').lean();
    return !!sibSub;
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
// v567 — `viewerId` : l'app affichait TOUJOURS le cœur vide et le trophée
// actif, parce que le serveur ne disait jamais si la personne avait déjà aimé /
// validé / visité ce spot. Rouvrir la fiche puis retaper le cœur RETIRAIT donc
// son like sans prévenir. On renvoie l'état réel du lecteur.
// v576 — Daniel : « les PawSpot doivent être synchro » entre les 3 profils.
// `viewerId` désignait le document du rôle ACTIF : un spot créé, aimé ou
// validé depuis le profil propriétaire revenait « pas le mien / pas aimé »
// depuis le profil gardien — et retaper le cœur le likait une SECONDE fois
// sous un autre identifiant. On accepte désormais un Set d'identifiants (les
// 3 profils de la personne) ; une chaîne reste acceptée pour compatibilité.
const _viewerSet = (viewer) => {
  if (!viewer) return null;
  if (viewer instanceof Set) return viewer.size ? viewer : null;
  if (Array.isArray(viewer)) return viewer.length ? new Set(viewer.map(String)) : null;
  return new Set([String(viewer)]);
};
const _hasAny = (list, set) =>
  !!set && (list || []).some((u) => set.has(String(u)));

const spotJson = (s, viewer = '') => {
  const vs = _viewerSet(viewer);
  return _spotJsonInner(s, vs);
};

const _spotJsonInner = (s, vs) => ({
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
  // v567 — état du lecteur (cœur plein / trophée grisé / visite déjà marquée).
  // v576 — évalué sur les 3 profils de la personne.
  likedByMe: _hasAny(s.likedBy, vs),
  validatedByMe: _hasAny(s.validatedBy, vs),
  visitedByMe: _hasAny(s.visitedBy, vs),
  isMine: !!vs && vs.has(String(s.creatorId)),
  createdAt: s.createdAt,
});

// v567 — un spot supprimé reste en base (corbeille) pour que le quota gratuit
// compte les créations cumulées : TOUTES les lectures doivent donc l'exclure.
const VISIBLE = { hidden: false, deletedAt: null };

/**
 * v567 — les identifiants des TROIS documents de rôle du compte (owner /
 * sitter / walker, reliés par l'email). Les spots, le quota gratuit et la
 * reprise de points doivent raisonner sur le COMPTE, pas sur le profil actif.
 */
// v576 — délégué à `utils/personScope` (lui-même bâti sur `identityGroup`) :
// même définition de « la personne » partout (e-mail ET `oldId`, alors qu'ici
// seul l'e-mail était pris en compte) et 6 requêtes au lieu de 4 séquentielles.
async function accountRoleIds(userId, role) { // eslint-disable-line no-unused-vars
  try {
    const ids = await personIds(userId);
    return ids.length ? ids : [userId];
  } catch (_) {
    return [userId];
  }
}

/** v576 — les mêmes identifiants, en Set de chaînes (tests O(1)). */
async function accountRoleIdSet(userId, role) {
  return new Set((await accountRoleIds(userId, role)).map(String));
}

/**
 * v567 — palier de récompense (spot validé par la communauté, spot très
 * populaire) crédité UNE SEULE FOIS, même si deux ❤️ arrivent en même temps.
 *
 * Avant : `if (!spot.popularAwarded) { spot.popularAwarded = true; award(); }`
 * sur un document lu en mémoire — deux requêtes concurrentes passaient toutes
 * les deux le test et créditaient le créateur DEUX fois. Ici le drapeau est
 * posé par un findOneAndUpdate conditionnel : seule la requête qui a réellement
 * modifié le document crédite les points.
 *
 * Crédite aussi `pointsAwarded` (ce que le spot a rapporté, repris si le spot
 * est supprimé) et prévient l'auteur (notification + push traduits).
 */
async function creditMilestone(spot, flagField, { points, reason, notifyType, alsoSet = {} }) {
  try {
    const claimed = await PawSpot.findOneAndUpdate(
      { _id: spot._id, [flagField]: { $ne: true } },
      { $set: { [flagField]: true, ...alsoSet } },
      { new: true },
    );
    if (!claimed) return null; // déjà crédité par une autre requête
    const role = String(spot.creatorModel || 'Owner').toLowerCase();
    const got = await pawPoints.awardPointsDetailed({
      userId: spot.creatorId, role, points, reason,
    });
    const credited = got?.credited ?? points;
    await PawSpot.updateOne(
      { _id: spot._id },
      { $inc: { pointsAwarded: credited } },
    ).catch(() => {});
    if (notifyType) {
      // v567 — Daniel : l'auteur n'était JAMAIS prévenu que son spot avait été
      // validé par la communauté ni qu'il était devenu doré ; il découvrait ses
      // points par hasard en ouvrant la boutique. Push + notification in-app
      // traduits dans les 9 langues (locales/*/notifications.json).
      try {
        const { sendNotification } = require('../services/notificationSender');
        await sendNotification({
          userId: spot.creatorId,
          role,
          type: notifyType,
          data: {
            spotId: String(spot._id),
            spotName: _moderateSpot(spot.name || '').clean,
            points: String(credited),
          },
        });
      } catch (e) {
        logger.warn(`[pawspots] notif ${notifyType} failed: ${e?.message || e}`);
      }
    }
    return credited;
  } catch (e) {
    logger.warn(`[pawspots] milestone ${flagField} failed: ${e?.message || e}`);
    return null;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LECTURE
// ════════════════════════════════════════════════════════════════════════════

// v532 — GET /pawspots/public/:id — fiche PUBLIQUE d'un spot, SANS
// authentification.
//
// Daniel : « améliore le partage de la carte entre amis sur WhatsApp, Insta
// etc. pour faire de l'auto-pub ». Un lien partagé ne fait de la publicité que
// s'il affiche un vrai aperçu (photo + nom + ville) dans la conversation ;
// sinon c'est une URL nue que personne n'ouvre. La page /spot/[id] du site est
// rendue côté SERVEUR et a besoin de ces données sans jeton — d'où cet
// endpoint.
//
// On n'expose QUE ce qui est déjà public sur la carte communautaire : nom,
// type, description, photo, ville et compteurs. Ni l'identifiant du créateur,
// ni les listes de likes/visites, ni les commentaires.
router.get('/public/:id', async (req, res) => {
  try {
    const mongoose = require('mongoose');
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(404).json({ error: 'Spot not found.' });
    }
    const s = await PawSpot.findOne({ _id: req.params.id, ...VISIBLE })
      .select('type name description photoUrl location likesCount validationsCount communityValidated creatorName createdAt')
      .lean();
    if (!s) return res.status(404).json({ error: 'Spot not found.' });
    const coords = Array.isArray(s.location?.coordinates) ? s.location.coordinates : [];
    return res.json({
      id: String(s._id),
      type: s.type,
      name: s.name || '',
      description: s.description || '',
      photoUrl: s.photoUrl || '',
      city: s.location?.city || '',
      lat: coords.length >= 2 ? Number(coords[1]) : null,
      lng: coords.length >= 2 ? Number(coords[0]) : null,
      likesCount: Number(s.likesCount) || 0,
      validationsCount: Number(s.validationsCount) || 0,
      communityValidated: s.communityValidated === true,
      creatorName: s.creatorName || '',
      createdAt: s.createdAt,
    });
  } catch (e) {
    logger.error('[pawspots/public]', e);
    return res.status(500).json({ error: 'Erreur spot.' });
  }
});

// GET /pawspots/nearby?lat&lng&radius — spots autour (tous publics).
router.get('/nearby', requireAuth, async (req, res) => {
  try {
    const lat = Number(req.query.lat);
    const lng = Number(req.query.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return res.status(400).json({ error: 'lat & lng required.' });
    }
    // v591 — l'app demande désormais la zone visible (jusqu'à 300 km) pour que
    // les PawSpots restent visibles au dézoom ; les 200 plus proches ($near).
    const maxDistance = Math.min(Number(req.query.radius) || 25000, 300000);
    const spots = await PawSpot.find({
      ...VISIBLE,
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
    const vs = await accountRoleIdSet(req.user.id, req.user.role);
    res.json({ spots: spots.map((s) => spotJson(s, vs)) });
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
    const spots = await PawSpot.find({ ...VISIBLE })
      .sort({ likesCount: -1, validationsCount: -1 })
      .limit(50)
      .lean();
    await enrichGoldenCreators(spots);
    const vs = await accountRoleIdSet(req.user.id, req.user.role);
    res.json({ spots: spots.map((s) => spotJson(s, vs)) });
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
        .select('name avatar email pawPoints pawBadgeColor pawGoldFrame location.city countryCode')
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
          _email: String(d.email || '').toLowerCase().trim(),
        });
      }
    }
    // v567 — UNE personne = UNE ligne. Les PawPoints sont recopiés sur les
    // trois documents de rôle du compte (syncPointsAcrossRoles) et on balaie
    // les trois collections : un compte à trois profils occupait donc les
    // places 1, 2 ET 3 du classement avec le même nom et le même score. On
    // déduplique par email (repli : identifiant) en gardant la meilleure ligne.
    const byPerson = new Map();
    for (const r of rows) {
      const key = r._email || `id:${r.userId}`;
      const prev = byPerson.get(key);
      if (!prev || r.points > prev.points || (r.points === prev.points && r.avatar && !prev.avatar)) {
        byPerson.set(key, r);
      }
    }
    const deduped = [...byPerson.values()];
    for (const r of deduped) delete r._email;
    rows.length = 0;
    rows.push(...deduped);
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

// v566 — GET /pawspots/plans?currency=EUR|GBP|CHF|USD|KRW|JPY (public, lecture
// seule). Audit boutique : l'app et le site affichaient « 4,99 € / 39,99 € » EN
// DUR alors que /pawspots/subscribe facture dans la devise choisie (ex. 5,49 $)
// et que l'admin peut changer ces prix. Même source que /subscribe
// (getPawSpotPricing) → prix affiché = prix facturé. 100 % additif.
router.get('/plans', (req, res) => {
  try {
    const plans = Object.keys(PAWSPOT_PLAN_DAYS)
      .map((key) => {
        const p = getPawSpotPricing(key, req.query.currency);
        if (!p) return null;
        return { plan: key, amount: p.amount, currency: p.currency, intervalDays: p.days };
      })
      .filter(Boolean);
    res.json({ plans, trialDays: TRIAL_DAYS, freeSpotLimit: FREE_SPOT_LIMIT });
  } catch (e) {
    logger.error('[pawspots/plans]', e);
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
    // v567 — comptés sur les TROIS profils du compte (comme le quota).
    const myIds = await accountRoleIds(req.user.id, req.user.role);
    const mySpots = await PawSpot.countDocuments({
      creatorId: { $in: myIds }, deletedAt: null,
    });
    const createdTotal = await PawSpot.countDocuments({ creatorId: { $in: myIds } });
    const subscribed = await hasActivePawSpot(req.user.id, req.user.role);
    // v576 — l'abonnement PawSpot a pu être acheté depuis un autre profil : on
    // lit la date d'expiration la plus lointaine du compte, sinon l'écran
    // affichait « aucun abonnement » à un abonné qui avait changé de rôle.
    const sub = (await UserSubscription.find({ userId: { $in: myIds } })
      .select('pawspotExpiry pawspotTrialUsedAt').lean())
      .sort((a, b) => new Date(b.pawspotExpiry || 0) - new Date(a.pawspotExpiry || 0))[0]
      || null;
    res.json({
      points,
      spendable: st.spendable,
      // v567 — ALIAS. La boutique (coin_shop_screen) lit `pawPointsSpendable`
      // et retombait sur `points` (le total À VIE) quand la clé n'existait
      // pas : elle affichait « 1 200 pts » à quelqu'un qui n'avait plus que
      // 200 points dépensables, et l'échange répondait ensuite « pas assez de
      // PawPoints ». Même valeur que `spendable`.
      pawPointsSpendable: st.spendable,
      lifetime: st.lifetime,
      badge: pawPoints.badgeFor(points),
      nextBadge: pawPoints.nextBadgeFor(points),
      isGoldCreator: pawPoints.isGoldCreator(points),
      mySpotsCount: mySpots,
      spotsCreatedTotal: createdTotal,
      freeSpotLimit: FREE_SPOT_LIMIT,
      // v567 — « il te reste N tags gratuits » : la valeur existait côté
      // serveur mais n'était jamais calculée ni affichée. null = illimité.
      freeSpotsLeft: subscribed ? null : Math.max(0, FREE_SPOT_LIMIT - createdTotal),
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
// v559 — langues d'instructions supportées par Valhalla (sinon anglais).
const VALHALLA_LANG = {
  fr: 'fr-FR', en: 'en-US', es: 'es-ES', de: 'de-DE', it: 'it-IT', pt: 'pt-PT',
  ja: 'ja-JP', pl: 'pl-PL', nl: 'nl-NL', ru: 'ru-RU', tr: 'tr-TR', sv: 'sv-SE',
};

// v559 — décodage du tracé Valhalla (polyline Google, précision 1e-6).
function decodePolyline6(str) {
  const points = [];
  let index = 0;
  let lat = 0;
  let lng = 0;
  while (index < str.length) {
    let shift = 0;
    let result = 0;
    let byte;
    do {
      byte = str.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    lat += result & 1 ? ~(result >> 1) : result >> 1;
    shift = 0;
    result = 0;
    do {
      byte = str.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    lng += result & 1 ? ~(result >> 1) : result >> 1;
    points.push({ lat: lat / 1e6, lng: lng / 1e6 });
  }
  return points;
}

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
    // v559 — Daniel (retour testeur) : itinéraire à pied / vélo / voiture.
    // ⚠️ Vérifié le 08/09 : le serveur OSRM public (router.project-osrm.org)
    // IGNORE le profil — foot, bike et driving renvoient le MÊME trajet
    // (13 234 m / 1 188 s) : l'ancien « itinéraire piéton » (v509) était en
    // fait un trajet VOITURE avec une durée recalculée à 4,8 km/h. On passe
    // sur le serveur Valhalla public (FOSSGIS), qui distingue vraiment les
    // modes (même paire : 12,8 km à pied, 13,3 km à vélo, 14,7 km en voiture)
    // et renvoie une durée réelle. OSRM reste en secours, puis ligne droite.
    const MODES = { walk: 'pedestrian', bike: 'bicycle', car: 'auto' };
    const mode = MODES[String(req.query.mode || '')] ? String(req.query.mode) : 'walk';
    const withTimeout = async (url, init, ms) => {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), ms);
      try {
        return await fetch(url, { ...init, signal: controller.signal });
      } finally {
        clearTimeout(timer);
      }
    };
    try {
      const resp = await withTimeout(
        'https://valhalla1.openstreetmap.de/route',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'HoPetSit/1.0 (contact@hopetsit.com)',
          },
          body: JSON.stringify({
            locations: [{ lat: fromLat, lon: fromLng }, { lat: toLat, lon: toLng }],
            costing: MODES[mode],
            units: 'kilometers',
            // v559 — Daniel : « mini indications de virage ». Valhalla rend
            // les manœuvres traduites (`instruction`) dans la langue demandée.
            language: VALHALLA_LANG[String(req.query.lang || '').slice(0, 2).toLowerCase()] || 'en-US',
          }),
        },
        7000,
      );
      const data = await resp.json();
      const legs = data?.trip?.legs;
      const summary = data?.trip?.summary;
      if (Array.isArray(legs) && legs.length && summary) {
        const points = [];
        const steps = [];
        for (const leg of legs) {
          const shape = decodePolyline6(leg.shape || '');
          const offset = points.length;
          points.push(...shape);
          for (const m of leg.maneuvers || []) {
            const p = shape[Math.min(m.begin_shape_index || 0, shape.length - 1)];
            if (!p) continue;
            steps.push({
              type: Number(m.type) || 0,
              instruction: String(m.instruction || '').slice(0, 160),
              distanceMeters: Math.round((m.length || 0) * 1000),
              durationSeconds: Math.round(m.time || 0),
              lat: p.lat,
              lng: p.lng,
              index: offset + (m.begin_shape_index || 0),
            });
          }
        }
        if (points.length > 1) {
          return res.json({
            points,
            steps,
            distanceMeters: Math.round((summary.length || 0) * 1000),
            durationSeconds: Math.round(summary.time || 0),
            mode,
            source: 'valhalla',
          });
        }
      }
      logger.warn(`[pawspots/directions] Valhalla empty (${mode}): ${String(data?.error || '').slice(0, 120)}`);
    } catch (valErr) {
      logger.warn(`[pawspots/directions] Valhalla failed: ${valErr?.message || valErr}`);
    }
    try {
      const profile = mode === 'car' ? 'driving' : mode === 'bike' ? 'bike' : 'foot';
      const url =
        `https://router.project-osrm.org/route/v1/${profile}/${fromLng},${fromLat};${toLng},${toLat}` +
        `?overview=full&geometries=geojson`;
      const resp = await withTimeout(url, {}, 6000);
      const data = await resp.json();
      const coords = data?.routes?.[0]?.geometry?.coordinates;
      if (Array.isArray(coords) && coords.length > 1) {
        const distanceMeters = Math.round(data.routes[0].distance || 0);
        // OSRM public = données voiture : durée recalculée pour pied/vélo.
        const SPEED_MPS = { walk: 4.8 / 3.6, bike: 15 / 3.6, car: null }[mode];
        return res.json({
          points: coords.map((c) => ({ lat: c[1], lng: c[0] })),
          distanceMeters,
          durationSeconds: SPEED_MPS
            ? Math.round(distanceMeters / SPEED_MPS)
            : Math.round(data.routes[0].duration || 0),
          mode,
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
      mode,
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
    // v567 — les spots sont comptés sur les TROIS profils du compte. Avant, le
    // quota gratuit portait sur le seul document de rôle : 3 spots en
    // propriétaire + 3 en gardien + 3 en promeneur = 9 tags gratuits au lieu
    // de 3 (il suffisait de changer de profil pour repartir à zéro).
    const myIds = await accountRoleIds(req.user.id, req.user.role);
    // v567 — le quota porte sur les CRÉATIONS CUMULÉES (corbeille comprise) :
    // supprimer un spot ne rend plus un tag gratuit.
    const createdTotal = await PawSpot.countDocuments({ creatorId: { $in: myIds } });
    if (!subscribed && meDoc?.isStaff !== true) {
      if (createdTotal >= FREE_SPOT_LIMIT) {
        return res.status(402).json({
          error: `Free accounts can create up to ${FREE_SPOT_LIMIT} PawSpots. Subscribe to PawSpot for unlimited tagging.`,
          code: 'PAWSPOT_REQUIRED',
          freeSpotLimit: FREE_SPOT_LIMIT,
          spotsCreatedTotal: createdTotal,
          freeSpotsLeft: 0,
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
    // v567 — on renvoie les points RÉELLEMENT crédités (le ×2 Paw Premium et
    // le bonus de niveau étaient appliqués en base mais l'app annonçait
    // toujours « +10 » : l'abonné Premium ne voyait jamais son doublement).
    // v567 — 2e garde-fou anti-ferme : au-delà de SPOT_POINTS_DAILY_CAP spots
    // créés en 24 h, le spot est bien publié mais ne rapporte plus de points
    // (un abonné « illimité » ne peut donc pas scripter 1 000 tags par jour).
    const since = new Date(Date.now() - 86400000);
    const createdToday = await PawSpot.countDocuments({
      creatorId: { $in: myIds },
      createdAt: { $gte: since },
    });
    const overDailyCap = createdToday > SPOT_POINTS_DAILY_CAP;
    let earned = 0;
    if (!overDailyCap) {
      const gotCreate = await pawPoints.awardPointsDetailed({
        userId: req.user.id, role: req.user.role,
        points: pawPoints.POINTS.spotCreated, reason: 'spot created',
      });
      earned += gotCreate?.credited ?? pawPoints.POINTS.spotCreated;
      if (spot.photoUrl) {
        const gotPhoto = await pawPoints.awardPointsDetailed({
          userId: req.user.id, role: req.user.role,
          points: pawPoints.POINTS.photoAdded, reason: 'spot photo',
        });
        earned += gotPhoto?.credited ?? pawPoints.POINTS.photoAdded;
      }
    } else {
      logger.info(
        `[pawspots] plafond quotidien atteint (${createdToday} spots/24 h) → 0 point pour ${req.user.role}:${req.user.id}`,
      );
    }
    // Mémorise ce que ce spot a rapporté : repris si le spot est supprimé.
    try {
      spot.pointsAwarded = earned;
      await spot.save();
    } catch (_) { /* best-effort */ }

    const unlimited = subscribed || meDoc?.isStaff === true;
    res.status(201).json({
      spot: spotJson(spot, new Set(myIds.map(String))),
      pointsEarned: earned,
      dailyCapReached: overDailyCap,
      mySpotsCount: await PawSpot.countDocuments({ creatorId: { $in: myIds }, deletedAt: null }),
      spotsCreatedTotal: createdTotal + 1,
      freeSpotLimit: FREE_SPOT_LIMIT,
      // Illimité pour les abonnés / le staff → null.
      freeSpotsLeft: unlimited ? null : Math.max(0, FREE_SPOT_LIMIT - (createdTotal + 1)),
    });
  } catch (e) {
    logger.error('[pawspots POST]', e);
    res.status(500).json({ error: e.message });
  }
});

// POST /pawspots/:id/like — toggle ❤️ (+25 pts créateur à 50 likes, 1 fois).
router.post('/:id/like', requireAuth, async (req, res) => {
  try {
    const uid = String(req.user.id);
    const current = await PawSpot.findOne({ _id: req.params.id, ...VISIBLE })
      .select('likedBy creatorId')
      .lean();
    if (!current) return res.status(404).json({ error: 'Spot not found.' });
    // v567 — anti-triche : on ne peut pas aimer son propre spot (la route
    // /validate l'interdisait déjà, pas /like). Sans ça, l'auteur comptait
    // pour l'un des 10 ❤️ qui déclenchent SES propres +10 points.
    // v576 — sur les 3 profils : sinon il suffisait de changer de rôle pour
    // aimer son propre spot, et pour l'aimer une DEUXIÈME fois.
    const mine = await accountRoleIdSet(req.user.id, req.user.role);
    if (mine.has(String(current.creatorId))) {
      return res.status(400).json({
        error: 'You cannot like your own spot.',
        code: 'SELF_LIKE',
      });
    }
    const wasLiked = (current.likedBy || []).some((u) => mine.has(String(u)));
    // v567 — $addToSet / $pull : atomique. L'ancien push/splice + save
    // permettait à deux requêtes simultanées d'inscrire DEUX fois le même
    // utilisateur dans likedBy (compteur de likes gonflé).
    const spot = await PawSpot.findOneAndUpdate(
      { _id: req.params.id, ...VISIBLE },
      wasLiked
        // v576 — le ❤️ a pu être posé sous un AUTRE de mes profils : on retire
        // toutes mes traces, sinon le retrait ne faisait rien et le compteur
        // restait bloqué.
        ? { $pull: { likedBy: { $in: [...mine] } } }
        : { $addToSet: { likedBy: uid } },
      { new: true },
    );
    if (!spot) return res.status(404).json({ error: 'Spot not found.' });
    spot.likesCount = spot.likedBy.length;
    await spot.save();

    // v23.1.357 — validé par la communauté à 10 ❤️ : +10 pts créateur (1 fois).
    if (spot.likesCount >= LIKES_FOR_VALIDATION && !spot.communityValidated) {
      await creditMilestone(spot, 'validationAwarded', {
        points: pawPoints.POINTS.spotValidated,
        reason: 'spot validated (10 likes)',
        notifyType: 'pawspot_validated',
        alsoSet: { communityValidated: true },
      });
    }
    // Très populaire : 50 likes → +25 pts créateur (une seule fois).
    if (spot.likesCount >= 50 && !spot.popularAwarded) {
      await creditMilestone(spot, 'popularAwarded', {
        points: pawPoints.POINTS.spotPopular,
        reason: 'spot popular (50 likes)',
        notifyType: 'pawspot_popular',
      });
    }
    const fresh = await PawSpot.findById(spot._id)
      .select('likesCount communityValidated').lean();
    res.json({
      liked: !wasLiked,
      likesCount: fresh?.likesCount ?? spot.likesCount,
      communityValidated: fresh?.communityValidated === true,
    });
  } catch (e) {
    logger.error('[pawspots like]', e);
    res.status(500).json({ error: e.message });
  }
});

// POST /pawspots/:id/validate — 🏆 valider (3 validations = validé, +10 créateur).
router.post('/:id/validate', requireAuth, async (req, res) => {
  try {
    const uid = String(req.user.id);
    const current = await PawSpot.findOne({ _id: req.params.id, ...VISIBLE })
      .select('creatorId validatedBy communityValidated validationsCount')
      .lean();
    if (!current) return res.status(404).json({ error: 'Spot not found.' });
    // v576 — auteur et validateur sont jugés sur les 3 profils de la personne.
    const mine = await accountRoleIdSet(req.user.id, req.user.role);
    if (mine.has(String(current.creatorId))) {
      return res.status(400).json({
        error: 'You cannot validate your own spot.',
        code: 'SELF_VALIDATE',
      });
    }
    if ((current.validatedBy || []).some((u) => mine.has(String(u)))) {
      return res.json({
        validated: current.communityValidated === true,
        validationsCount: current.validationsCount || 0,
        already: true,
      });
    }
    // v567 — atomique : une double requête ne peut plus inscrire deux fois le
    // même validateur (le compteur de validations ne se gonfle plus tout seul).
    const spot = await PawSpot.findOneAndUpdate(
      { _id: req.params.id, ...VISIBLE, validatedBy: { $nin: [...mine] } },
      { $addToSet: { validatedBy: uid } },
      { new: true },
    );
    if (!spot) {
      return res.json({
        validated: current.communityValidated === true,
        validationsCount: current.validationsCount || 0,
        already: true,
      });
    }
    spot.validationsCount = spot.validatedBy.length;
    await spot.save();
    if (spot.validationsCount >= 3 && !spot.communityValidated) {
      await creditMilestone(spot, 'validationAwarded', {
        points: pawPoints.POINTS.spotValidated,
        reason: 'spot community-validated',
        notifyType: 'pawspot_validated',
        alsoSet: { communityValidated: true },
      });
      spot.communityValidated = true;
    }
    res.json({ validated: spot.communityValidated === true, validationsCount: spot.validationsCount });
  } catch (e) {
    logger.error('[pawspots validate]', e);
    res.status(500).json({ error: e.message });
  }
});

// POST /pawspots/:id/visit — 👣 marquer une visite (1 fois par user).
router.post('/:id/visit', requireAuth, async (req, res) => {
  try {
    const uid = String(req.user.id);
    // v576 — une visite par PERSONNE (pas une par profil).
    const mine = await accountRoleIdSet(req.user.id, req.user.role);
    const spot = await PawSpot.findOneAndUpdate(
      { _id: req.params.id, ...VISIBLE, visitedBy: { $nin: [...mine] } },
      { $addToSet: { visitedBy: uid }, $inc: { visitsCount: 1 } },
      { new: true },
    );
    if (!spot) {
      const existing = await PawSpot.findOne({ _id: req.params.id, ...VISIBLE })
        .select('visitsCount').lean();
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
    const spot = await PawSpot.findOne({ _id: req.params.id, ...VISIBLE });
    if (!spot) return res.status(404).json({ error: 'Spot not found.' });
    const Model = modelForRole(req.user.role);
    const meDoc = await Model.findById(req.user.id).select('name').lean();
    const uid = String(req.user.id);
    spot.comments.push({
      authorId: req.user.id,
      authorModel: userModelFromRole(req.user.role),
      authorName: meDoc?.name || '',
      // v465 — texte BRUT stocké, censuré à la lecture (GET comments).
      text: text.slice(0, 300),
    });
    // v567 — anti-triche : le +2 « commentaire utile » n'est crédité qu'une
    // fois par personne ET par spot. Avant, écrire 50 fois « ok » sur le même
    // spot rapportait 100 PawPoints — le classement et les récompenses à
    // points n'avaient plus aucun sens.
    // v576 — une seule prime « commentaire utile » par PERSONNE et par spot :
    // sinon le même humain pouvait la toucher trois fois (une par profil).
    const mineC = await accountRoleIdSet(req.user.id, req.user.role);
    const firstComment = !(spot.commentAwardedBy || []).some((u) => mineC.has(String(u)));
    if (firstComment) spot.commentAwardedBy.push(uid);
    await spot.save();
    let pointsEarned = 0;
    if (firstComment) {
      const got = await pawPoints.awardPointsDetailed({
        userId: req.user.id, role: req.user.role,
        points: pawPoints.POINTS.usefulComment, reason: 'spot comment',
      });
      pointsEarned = got?.credited ?? pawPoints.POINTS.usefulComment;
    }
    res.json({ commentsCount: spot.comments.length, pointsEarned });
  } catch (e) {
    logger.error('[pawspots comment]', e);
    res.status(500).json({ error: e.message });
  }
});

// GET /pawspots/:id/comments — liste des commentaires (récents d'abord).
router.get('/:id/comments', requireAuth, async (req, res) => {
  try {
    const spot = await PawSpot.findOne({ _id: req.params.id, ...VISIBLE })
      .select('comments').lean();
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
//
// v567 — MESURÉ EN PROD : créer 4 spots donnait 80 points, les supprimer tous
// les quatre renvoyait 200 et laissait `points: 80, mySpotsCount: 0` → créer et
// supprimer en boucle fabriquait des PawPoints à l'infini, et remettait à zéro
// le quota de 3 tags gratuits. Désormais :
//   • le spot part à la CORBEILLE (deletedAt) : invisible partout, mais toujours
//     compté dans les créations cumulées → la limite gratuite tient ;
//   • les points que ce spot avait rapportés sont REPRIS (à vie + dépensables,
//     plancher 0, sur les trois profils du compte).
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const spot = await PawSpot.findOne({ _id: req.params.id, deletedAt: null });
    if (!spot) return res.status(404).json({ error: 'Spot not found.' });
    // v576 — je peux supprimer MON spot depuis n'importe lequel de mes profils
    // (avant : 403 dès qu'on avait changé de rôle depuis la création).
    const mine = await accountRoleIdSet(req.user.id, req.user.role);
    if (!mine.has(String(spot.creatorId))) {
      return res.status(403).json({ error: 'Only the creator can delete this spot.' });
    }
    // Verrou : seule la requête qui pose deletedAt reprend les points (une
    // double suppression ne peut pas les reprendre deux fois).
    const claimed = await PawSpot.findOneAndUpdate(
      { _id: spot._id, deletedAt: null },
      { $set: { deletedAt: new Date(), hidden: true, featuredUntil: null, pointsAwarded: 0 } },
      { new: false },
    );
    if (!claimed) return res.status(404).json({ error: 'Spot not found.' });
    const toRevoke = Number(claimed.pointsAwarded) || 0;
    let pointsRevoked = 0;
    if (toRevoke > 0) {
      await pawPoints.revokePoints({
        userId: claimed.creatorId,
        role: String(claimed.creatorModel || 'Owner').toLowerCase(),
        points: toRevoke,
        reason: 'spot deleted',
      });
      pointsRevoked = toRevoke;
    }
    res.json({ deleted: true, pointsRevoked });
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
    // v576 — LE DÉBIT DOIT TOUCHER LES 3 PROFILS. Il ne portait que sur le
    // document du rôle actif ; comme la synchronisation des points prend le
    // MAXIMUM des trois profils (pawPointsService.syncPointsAcrossRoles), les
    // points repartaient chez le frère et revenaient à la lecture suivante :
    // la récompense était gratuite. On aligne explicitement les trois soldes
    // sur la valeur débitée, exactement comme pawPointsRoutes.spendPoints.
    const myIds = await accountRoleIds(req.user.id, req.user.role);
    const _alignSpendable = async (value) => {
      try {
        await Promise.all([Owner, Sitter, Walker].map((M) => M.updateOne(
          { _id: { $in: myIds } },
          { $set: { pawPointsSpendable: Number(value) || 0 } },
        ).catch(() => {})));
      } catch (_) { /* best-effort : le débit principal a déjà eu lieu */ }
    };
    const _refund = async () => {
      const back = await Model.findByIdAndUpdate(
        req.user.id,
        { $inc: { pawPointsSpendable: cost } },
        { new: true },
      ).select('pawPointsSpendable').catch(() => null);
      await _alignSpendable(back?.pawPointsSpendable ?? 0);
    };
    await _alignSpendable(updated.pawPointsSpendable);

    if (reward === 'feature_spot') {
      // v576 — mon spot, quel que soit le profil qui l'a créé.
      const spot = await PawSpot.findOne({
        _id: req.body?.spotId, creatorId: { $in: myIds },
      });
      if (!spot) {
        // Rembourse si le spot n'existe pas / pas à lui.
        await _refund();
        return res.status(404).json({ error: 'Spot not found (or not yours).' });
      }
      spot.featuredUntil = new Date(Date.now() + 7 * 86400000);
      await spot.save();
    } else if (reward === 'badge_color') {
      const color = String(req.body?.color || '').trim();
      if (!/^#?[0-9a-fA-F]{6}$/.test(color)) {
        await _refund();
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
    // dans snapshot.plans).
    // v566 — CHOISIE ici sans rien écrire, RÉSERVÉE sur l'intention créée,
    // CONSOMMÉE seulement à la réussite du paiement (avant : consommée dès la
    // création → perdue si l'utilisateur fermait la feuille de paiement).
    const discounts = require('../services/discountReservationService');
    const picked = await discounts.pickDiscounts({
      userId, plan, baseAmount: pricing.amount, scope: 'pawspot',
    });
    pricing.amount = picked.amount;
    const discountRefs = discounts.encodeRefs(picked.applied);

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
          // v566 — wallet = payé tout de suite → l'activation consomme la réduction.
          metadata: {
            userId: String(userId), role, plan,
            days: String(pricing.days), currency: pricing.currency,
            provider: 'wallet',
            paidAmount: String(pricing.amount),
            platform: platformFromRequest(req),
            ...(discountRefs ? { discountRefs } : {}),
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
        // v568 — utilitaire partagé (client commun aux 3 profils).
        let airwallexCustomerId = null;
        let defaultConsentId = null;
        try {
          const ensured = await ensureAirwallexCustomer({
            userId: String(userId),
            role,
            logTag: 'pawspots',
          });
          airwallexCustomerId = ensured.customerId;
          defaultConsentId = ensured.defaultConsentId;
        } catch (custErr) {
          logger.warn(`[pawspots] customer ensure failed: ${custErr?.message || custErr}`);
        }

        const intent = await airwallex.createPlatformPaymentIntent({
          amount: amountCents,
          currency: pricing.currency,
          ...intentCustomerFields({ customerId: airwallexCustomerId }),
          metadata: {
            type: 'pawspot_purchase',
            kind: 'pawspot',
            userId: String(userId), role, plan,
            days: String(pricing.days),
            currency: pricing.currency,
            paidAmount: String(pricing.amount),
            ...(discountRefs ? { discountRefs } : {}),
            ...(platformFromRequest(req) ? { platform: platformFromRequest(req) } : {}),
          },
        });
        // v566 — réserve (30 min) liée à CETTE intention, non consommée.
        if (picked.applied.length) {
          await discounts.reserveDiscounts({ applied: picked.applied, piId: intent.id });
        }
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
          // v568 — requis pour que la page Airwallex liste les cartes.
          customerId: airwallexCustomerId,
          defaultConsentId,
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
    // v532 — FAILLE : cet endpoint activait le produit sans jamais verifier
    // le paiement aupres d Airwallex. On exige desormais un PaymentIntent
    // reellement SUCCEEDED, appartenant a l appelant, et non deja consomme.
    let paidIntent = null;
    try {
      paidIntent = await assertPaidIntent({
        paymentIntentId: req.body?.paymentIntentId,
        userId: req.user.id,
        purpose: 'pawspot',
      });
    } catch (guardErr) {
      if (guardErr instanceof PaymentNotVerifiedError) {
        // Deja consomme = le webhook Airwallex a active l achat avant nous.
        // Ce n est pas une erreur : sans ce cas, l utilisateur verrait un
        // message d echec alors qu il a paye ET que le produit est actif.
        // C est aussi ce qui empeche la DOUBLE activation (1 paiement qui
        // donnait 2 mois d abonnement).
        if (guardErr.code === 'PAYMENT_INTENT_ALREADY_USED') {
          return res.json({ success: true, alreadyActivated: true });
        }
        return res.status(guardErr.status).json({
          error: guardErr.message,
          code: guardErr.code,
        });
      }
      throw guardErr;
    }
    const plan = String(req.body?.plan || 'monthly');
    const pricing = getPawSpotPricing(plan, req.body?.currency);
    if (!pricing) return res.status(400).json({ error: 'Invalid plan.' });
    const { activatePawSpotFromWebhook } = require('../controllers/purchaseActivationController');
    const result = await activatePawSpotFromWebhook({
      piId: String(req.body?.paymentIntentId || `sync_${Date.now()}_pawspot`),
      // v566 — assertPaidIntent vient de poser le verrou `purchase:<piId>` :
      // sans alreadyClaimed l'activation se croyait « déjà faite » et PawSpot
      // n'était JAMAIS activé quand /confirm arrivait avant le webhook.
      alreadyClaimed: true,
      metadata: {
        userId: String(req.user.id), role: req.user.role, plan,
        days: String(pricing.days), currency: pricing.currency,
        // v566 — montant et devise RÉELLEMENT débités (intention vérifiée).
        ...(paidIntent && paidIntent.amount !== undefined && paidIntent.amount !== null
          ? { providerAmount: String(paidIntent.amount) } : {}),
        ...(paidIntent?.currency ? { providerCurrency: String(paidIntent.currency).toUpperCase() } : {}),
        ...(paidIntent?.metadata?.paidAmount ? { paidAmount: paidIntent.metadata.paidAmount } : {}),
        platform: paidIntent?.metadata?.platform || platformFromRequest(req),
        ...(paidIntent?.metadata?.discountRefs
          ? { discountRefs: paidIntent.metadata.discountRefs }
          : {}),
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
