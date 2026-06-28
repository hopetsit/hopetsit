/**
 * Friend Routes — Phase 4 (Social).
 *
 * Endpoints:
 *   GET    /              → list my accepted friends
 *   GET    /requests      → list pending requests (incoming + outgoing)
 *   POST   /request       → send a friend request to { targetId, targetRole }
 *   POST   /:id/accept    → accept a pending request addressed to me
 *   POST   /:id/decline   → decline a pending request addressed to me
 *   DELETE /:id           → unfriend (works in either direction)
 *   POST   /:id/share     → toggle my position-sharing flag for this friend
 *
 * All endpoints require auth. Per-side sharing flag lets each user control
 * whether the other can see their live location (Phase 4.3 sockets).
 */
const express = require('express');
const { requireAuth } = require('../middleware/auth');
const Friendship = require('../models/Friendship');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const logger = require('../utils/logger');

const router = express.Router();

const ROLE_TO_MODEL_NAME = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };
const MODEL_BY_NAME = { Owner, Sitter, Walker };

function me(req) {
  return {
    id: req.user.id,
    role: req.user.role,
    model: ROLE_TO_MODEL_NAME[req.user.role] || 'Owner',
  };
}

// v416 — Daniel : "le suivi en direct doit rester allumé même quand l'app est
// fermée de force". Le SERVICE DE FOND Android (isolate séparé qui survit au
// swipe-kill) ne peut pas tenir une connexion socket → il POST sa position ici
// toutes les ~15 s avec son Bearer token. On relaie aux amis/famille via la
// MÊME logique que le handler socket (relayLivePosition). { lat, lng, city?,
// offline? }. offline:true = je coupe le partage (équiv. map:go-offline).
router.post('/live-position', requireAuth, async (req, res) => {
  try {
    const { relayLivePosition } = require('../sockets/mapSocket');
    const u = me(req);
    const { lat, lng, city, offline } = req.body || {};
    if (offline === true) {
      await relayLivePosition({ userId: u.id, role: u.role, offline: true });
      return res.json({ ok: true, offline: true });
    }
    const la = Number(lat);
    const ln = Number(lng);
    if (!Number.isFinite(la) || !Number.isFinite(ln) || (la === 0 && ln === 0)) {
      return res.status(400).json({ error: 'lat and lng are required.' });
    }
    const listeners = await relayLivePosition({
      userId: u.id, role: u.role, lat: la, lng: ln, city,
    });
    return res.json({ ok: true, listeners });
  } catch (e) {
    logger.error('[friends/live-position]', e);
    return res.status(500).json({ error: 'Unable to relay live position.' });
  }
});

// v497 — Daniel : « icône rose = membres PawMap proches, TOUS RÔLES ». Choix
// produit retenu : n'importe quel membre voit les autres membres ABONNÉS
// (PawSpot / Premium / PawFollow / staff) proches — owners INCLUS — gated côté
// app sur l'abo du VIEWER. (Avant, seul un owner voyait les sitters/walkers via
// /sitters|walkers/nearby → ne couvrait pas owner↔owner.) Confidentialité : on
// n'expose QUE les membres ayant eux-mêmes un abo actif (pas tout le monde).
//   GET /friends/members/nearby?lat=&lng=&radiusInMeters=
// Placé AVANT les routes /:id pour ne pas être éclipsé par un param.
router.get('/members/nearby', requireAuth, async (req, res) => {
  try {
    const lat = parseFloat(req.query.lat);
    const lng = parseFloat(req.query.lng);
    const radius = Math.min(
      parseInt(req.query.radiusInMeters, 10) || 25000,
      50000,
    );
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return res.status(400).json({ error: 'lat and lng are required.' });
    }
    const now = new Date();
    const u = me(req);
    const UserSubscription = require('../models/UserSubscription');

    // Identités du VIEWER (pour s'exclure soi-même sur les 3 rôles).
    const ViewerModel = MODEL_BY_NAME[u.model] || Owner;
    const viewer = await ViewerModel.findById(u.id)
      .select('email oldId')
      .lean();
    const selfEmail = viewer?.email || null;
    const selfOldId = viewer?.oldId != null ? String(viewer.oldId) : null;

    const geo = {
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: [lng, lat] },
          $maxDistance: radius,
        },
      },
    };
    const sel =
      'name avatar profilePicture location mapBoostExpiry mapBoostTier ' +
      'isStaff isOnline oldId email';
    const [owners, sitters, walkers] = await Promise.all([
      Owner.find(geo).select(sel).limit(80).lean(),
      Sitter.find(geo).select(sel).limit(80).lean(),
      Walker.find(geo).select(sel).limit(80).lean(),
    ]);
    const tagged = [
      ...owners.map((d) => ({ d, role: 'owner' })),
      ...sitters.map((d) => ({ d, role: 'sitter' })),
      ...walkers.map((d) => ({ d, role: 'walker' })),
    ];

    // Premium via abonnement (Premium / PawFollow individuel / Famille) — batch.
    const ids = tagged.map((t) => t.d._id);
    let subSet = new Set();
    try {
      const subs = await UserSubscription.find({
        userId: { $in: ids },
        $or: [
          { premiumExpiry: { $gt: now } },
          { currentPeriodEnd: { $gt: now } },
          { familyExpiry: { $gt: now } },
        ],
      })
        .select('userId')
        .lean();
      subSet = new Set(subs.map((s) => String(s.userId)));
    } catch (subErr) {
      logger.warn(`[friends/members/nearby] sub lookup failed : ${subErr?.message || subErr}`);
    }

    // v500 — Daniel : couronne staff absente sur la carte. `staff` ne lisait que
    // d.isStaff du doc courant ; isStaff peut être sur un AUTRE rôle (même
    // email/oldId). Batch léger (3 requêtes pour tous les candidats) → couronne
    // cohérente avec /me/benefits et fetchUserMini.
    let staffEmails = new Set();
    let staffOldIds = new Set();
    try {
      const emails = [...new Set(tagged.map((t) => t.d.email).filter(Boolean))];
      const oldIds = [...new Set(
        tagged.map((t) => t.d.oldId).filter((v) => v != null).map(String),
      )];
      const orMatch = [];
      if (emails.length) orMatch.push({ email: { $in: emails } });
      if (oldIds.length) orMatch.push({ oldId: { $in: oldIds } });
      if (orMatch.length) {
        const staffDocs = (await Promise.all([
          Owner.find({ $or: orMatch, isStaff: true }).select('email oldId').lean(),
          Sitter.find({ $or: orMatch, isStaff: true }).select('email oldId').lean(),
          Walker.find({ $or: orMatch, isStaff: true }).select('email oldId').lean(),
        ])).flat();
        for (const sd of staffDocs) {
          if (sd.email) staffEmails.add(sd.email);
          if (sd.oldId != null) staffOldIds.add(String(sd.oldId));
        }
      }
    } catch (stErr) {
      logger.warn(`[friends/members/nearby] staff cross-role lookup failed : ${stErr?.message || stErr}`);
    }

    const avatarUrl = (a) =>
      (a && (typeof a === 'object' ? a.url : a)) || '';
    const members = [];
    const seen = new Set();
    for (const { d, role } of tagged) {
      const idStr = String(d._id);
      if (seen.has(idStr)) continue;
      // S'exclure soi-même (mêmes _id / email / oldId sur les 3 rôles).
      if (idStr === String(u.id)) continue;
      if (selfEmail && d.email && d.email === selfEmail) continue;
      if (selfOldId && d.oldId != null && String(d.oldId) === selfOldId) continue;

      const pawspot = d.mapBoostExpiry && new Date(d.mapBoostExpiry) > now;
      const premiumSub = subSet.has(idStr);
      const staff = d.isStaff === true
        || (d.email && staffEmails.has(d.email))
        || (d.oldId != null && staffOldIds.has(String(d.oldId)));
      // Membre actif = abonné PawSpot / Premium / PawFollow / staff. Sinon exclu.
      if (!pawspot && !premiumSub && !staff) continue;

      const coords = d.location?.coordinates;
      if (!Array.isArray(coords) || coords.length < 2) continue;

      seen.add(idStr);
      members.push({
        id: idStr,
        role,
        name: d.name || '',
        avatar: avatarUrl(d.avatar) || avatarUrl(d.profilePicture),
        location: { coordinates: coords },
        // couronne 👑 si Premium/staff ; anneau/halo rose pour tous les membres.
        isPremium: premiumSub || staff,
        isPawSpot: !!pawspot,
        isOnline: d.isOnline !== false,
      });
    }
    return res.json({ members, count: members.length });
  } catch (e) {
    logger.error('[friends/members/nearby]', e);
    return res.status(500).json({ error: 'Unable to fetch nearby members.' });
  }
});

/**
 * v23.1.266 — Résout l'abonnement PawFollow Famille DONT L'UTILISATEUR EST
 * TITULAIRE, avec SELF-HEAL.
 *
 * Daniel : "FAMILY_PLAN_REQUIRED alors que j'ai le PawFollow Famille". Cause :
 * avant le fix de migration (v23.1.266), switchRole ne déplaçait pas la sub →
 * après un changement de rôle, l'abonnement restait rattaché à l'ANCIEN doc
 * (supprimé) → findOne({ userId: user.id }) ne le trouvait plus.
 *
 * Ce helper :
 *   1. cherche la sub sous l'id COURANT (cas normal) ;
 *   2. sinon, rassemble toutes les identités de l'utilisateur (oldId + tous
 *      les docs de rôle partageant le même email) et retrouve la sub orpheline ;
 *   3. la REPOINTE sur le doc courant (réparation définitive).
 *
 * Accepte plan 'famille' ET 'family' (au cas où une sub aurait été écrite sans
 * passer par le hook pre-save qui normalise en 'famille').
 *
 * @returns {Promise<Object|null>} document sub hydraté (.save()-able) ou null.
 */
async function resolveOwnFamilySub(user) {
  const UserSubscription = require('../models/UserSubscription');
  const {
    familyActiveMatch,
    migrateLegacyFamily,
  } = require('../models/UserSubscription');
  const now = new Date();

  let sub = await UserSubscription.findOne({
    userId: user.id,
    ...familyActiveMatch(now),
  });

  // v426 — Premium Staff : le staff a TOUS les abos gratuits (PawFollow,
  // PawFamily, PawSpot…). S'il n'a aucune sub Famille active, on lui en
  // provisionne une (familyExpiry très lointain) pour qu'il puisse être
  // titulaire et inviter des membres, comme le fait /subscriptions/subscribe
  // pour les abos individuels. Additif, idempotent.
  if (!sub) {
    try {
      const Model = MODEL_BY_NAME[user.model];
      const meDoc = Model
        ? await Model.findById(user.id).select('isStaff').lean()
        : null;
      if (meDoc && meDoc.isStaff === true) {
        let staffSub = await UserSubscription.findOne({
          userId: user.id,
          userModel: user.model,
        });
        if (!staffSub) {
          staffSub = new UserSubscription({
            userId: user.id,
            userModel: user.model,
          });
        }
        staffSub.familyExpiry = new Date('2099-12-31');
        staffSub.status = 'active';
        staffSub.familyMembers = staffSub.familyMembers || [];
        await staffSub.save();
        logger.info(
          `[resolveOwnFamilySub] staff family self-provision → ${user.model}:${user.id}`,
        );
        return staffSub;
      }
    } catch (e) {
      logger.warn('[resolveOwnFamilySub] staff self-provision failed', e);
    }
  }

  if (sub) {
    // v23.1.284 — migration-à-la-lecture : normalise une ancienne sub famille
    // (plan='famille'+currentPeriodEnd) vers familyExpiry pour que /me/benefits
    // (et la boutique) la détectent de façon cohérente.
    if (
      !sub.familyExpiry &&
      (sub.plan === 'famille' || sub.plan === 'family') &&
      sub.currentPeriodEnd &&
      new Date(sub.currentPeriodEnd) > now
    ) {
      migrateLegacyFamily(sub, now);
      try {
        await sub.save();
      } catch (_) {/* best-effort */}
    }
    return sub;
  }

  // Self-heal : rassembler toutes les identités possibles.
  const candidateIds = new Set([String(user.id)]);
  let myEmail = null;
  try {
    const Model = MODEL_BY_NAME[user.model];
    const meDoc = Model
      ? await Model.findById(user.id).select('email oldId').lean()
      : null;
    if (meDoc && meDoc.oldId) candidateIds.add(String(meDoc.oldId));
    myEmail = meDoc && meDoc.email ? String(meDoc.email).toLowerCase() : null;
    if (myEmail) {
      const [owners, sitters, walkers] = await Promise.all([
        Owner.find({ email: meDoc.email }).select('_id oldId').lean(),
        Sitter.find({ email: meDoc.email }).select('_id oldId').lean(),
        Walker.find({ email: meDoc.email }).select('_id oldId').lean(),
      ]);
      for (const d of [...owners, ...sitters, ...walkers]) {
        candidateIds.add(String(d._id));
        if (d.oldId) candidateIds.add(String(d.oldId));
      }
    }
  } catch (e) {
    logger.warn('[resolveOwnFamilySub] self-heal lookup failed', e);
  }

  sub = await UserSubscription.findOne({
    userId: { $in: Array.from(candidateIds) },
    ...familyActiveMatch(now),
  });

  // v23.1.281 — Daniel : "je n'arrive TJR pas à ajouter/enlever un membre
  // famille". Dernier recours quand la sub titulaire est rattachée à un doc
  // de rôle introuvable via oldId/email-docs (ex : ancien doc supprimé après
  // un switchRole) : on balaie les subs Famille actives et on retient celle
  // dont le TITULAIRE partage MON email. Couvre le cas "j'ai créé la famille
  // sur un autre de mes rôles" sans dépendre d'une chaîne oldId intacte.
  if (!sub && myEmail) {
    try {
      const famSubs = await UserSubscription.find(
        familyActiveMatch(now),
      ).limit(100);
      for (const cand of famSubs) {
        const HolderModel =
          MODEL_BY_NAME[cand.userModel] ||
          MODEL_BY_NAME[ROLE_TO_MODEL_NAME[String(cand.userModel).toLowerCase()]];
        if (!HolderModel) continue;
        let holderDoc = null;
        try {
          holderDoc = await HolderModel.findById(cand.userId)
            .select('email')
            .lean();
        } catch (_) {/* defensive */}
        if (
          holderDoc &&
          holderDoc.email &&
          String(holderDoc.email).toLowerCase() === myEmail
        ) {
          sub = cand;
          break;
        }
      }
    } catch (e) {
      logger.warn('[resolveOwnFamilySub] email-holder recovery failed', e);
    }
  }

  if (!sub) {
    logger.warn(
      `[resolveOwnFamilySub] AUCUNE sub Famille titulaire trouvée pour ${user.model}:${user.id} (email=${myEmail || 'n/a'}, candidats=${candidateIds.size})`,
    );
  }
  if (sub && String(sub.userId) !== String(user.id)) {
    // v23.1.267 — re-point COLLISION-SAFE. Si une sub existe DÉJÀ sous
    // l'identité courante (ex : un doc 'none'/pawpass), un save() direct
    // violerait l'index unique {userId,userModel} (E11000) → la réparation
    // ne persistait jamais. On FUSIONNE alors les données Famille dans le
    // doc existant et on supprime l'orpheline.
    let existing = null;
    try {
      existing = await UserSubscription.findOne({
        userId: user.id,
        userModel: user.model,
      });
    } catch (_) {/* defensive */}
    if (existing && String(existing._id) !== String(sub._id)) {
      // v23.1.283 — découplage : on fusionne la FAMILLE dans familyExpiry
      // (sans écraser l'abo individuel plan/currentPeriodEnd du doc existant).
      const { familyExpiryOf } = require('../models/UserSubscription');
      existing.familyExpiry = familyExpiryOf(sub) || existing.familyExpiry;
      existing.status = 'active';
      existing.familyMembers = sub.familyMembers || [];
      try {
        await existing.save();
        await UserSubscription.deleteOne({ _id: sub._id });
        logger.info(
          `[resolveOwnFamilySub] sub Famille fusionnée → ${user.model}:${user.id}`,
        );
        return existing;
      } catch (e) {
        logger.warn('[resolveOwnFamilySub] merge failed', e);
        return sub; // au pire on opère sur l'orpheline (l'invite marchera).
      }
    }
    sub.userId = user.id;
    sub.userModel = user.model;
    try {
      await sub.save();
      logger.info(
        `[resolveOwnFamilySub] sub Famille réparée → ${user.model}:${user.id}`,
      );
    } catch (e) {
      logger.warn('[resolveOwnFamilySub] re-point save failed', e);
    }
  }
  return sub || null;
}

/** Fetch a minimal user profile regardless of role, for enriching friend lists. */
async function fetchUserMini(id, modelName) {
  const Model = MODEL_BY_NAME[modelName];
  if (!Model) return null;
  const u = await Model.findById(id)
    .select('firstName lastName profilePicture location city avatar email oldId mapBoostExpiry mapBoostTier isStaff')
    .lean();
  if (!u) return null;
  // v23.1.280 — Daniel : "si l'ami a l'option PawSpot, anneau doré/bleu selon
  // l'option". On expose le tier PawSpot (mapBoost) ACTIF pour que l'UI dessine
  // un anneau coloré sur l'avatar (bronze/silver/gold/platinum), sinon null.
  // v23.1.281 — Daniel : "les utilisateurs PawSpot NORMAL, ça ne fait rien".
  // CAUSE : un PawSpot de base a mapBoostExpiry actif MAIS mapBoostTier=null →
  // pawSpotTier devenait null → aucun anneau. On retombe sur 'bronze' (tier de
  // base) dès que le boost est ACTIF, pour qu'il y ait TOUJOURS un anneau.
  let pawSpotTier = null;
  try {
    if (u.mapBoostExpiry && new Date(u.mapBoostExpiry) > new Date()) {
      pawSpotTier = (u.mapBoostTier || '').toString().toLowerCase() || 'bronze';
    }
  } catch (_) {/* defensive */}
  // v23.1 part 222 — Daniel : "lorsque mes amis sont ajoutes si ils ont
  // un plan PawFollow le chat se debloque et on peux se partager la
  // position, de plus je dois les voir ds les personnes en live qd y
  // sont co et partagent leur position".
  // On enrichit avec hasPawFollow : true si l'autre user a une
  // subscription active. Frontend l'utilise pour 2 choses :
  //   1) Forcer affichage dans "Personnes en live" tab meme si
  //      theirSharePosition n'est pas explicitement set.
  //   2) Indiquer cote UI que ce contact est PawFollow-actif.
  let hasPawFollow = false;
  try {
    // v23.1.317 — Daniel (audit) : AVANT, ce calcul ne regardait que la sub
    // PROPRE du user (status + currentPeriodEnd) et IGNORAIT familyExpiry +
    // l'appartenance à une famille comme MEMBRE. Résultat : un membre/titulaire
    // famille partageait bien sa position (le socket utilise hasActivePawFollow)
    // mais apparaissait "non-PawFollow" dans la liste d'amis / "Personnes en
    // live". On utilise désormais le MÊME helper que le socket → cohérent.
    const { hasActivePawFollow } = require('../models/UserSubscription');
    hasPawFollow = await hasActivePawFollow(u._id);
    // v494 — un ami « premium STAFF » a TOUS les abos gratuits (dont PawFollow)
    // → forcé dans « Personnes en live » + partage position, comme les autres.
    if (!hasPawFollow && u.isStaff === true) hasPawFollow = true;
  } catch (_) {/* defensive — on continue sans le flag */}
  // v469 — Daniel : « quand un profil est Paw Premium, qu'on se voie TOUS avec
  // la couronne ». On expose isPremium pour CHAQUE contact (pas seulement la
  // famille) → le frontend met la couronne 👑 sur la carte pour tout ami premium.
  let isPremium = false;
  try {
    const UserSubscription = require('../models/UserSubscription');
    const sub = await UserSubscription.findOne({
      userId: u._id,
      premiumExpiry: { $gt: new Date() },
    }).select('_id').lean();
    isPremium = !!sub;
    // v494 — Daniel : un ami « premium STAFF » (premium offert via isStaff,
    // SANS abonnement payant → pas de premiumExpiry) n'avait ni couronne ni
    // badge. Le staff = premium gratuit illimité → on le compte comme premium.
    if (!isPremium && u.isStaff === true) isPremium = true;
    // v500 — Daniel : « 2 anciens profils premium ne montrent pas la couronne
    // aux autres ». CAUSE : ici on ne regardait QUE le doc du rôle de l'amitié
    // (isStaff + sub sur ce userId). Mais une personne = 3 docs (Owner/Sitter/
    // Walker, même email/oldId) ; si le staff/abo est sur un AUTRE rôle, la
    // couronne manquait — alors que /me/benefits (cross-rôle) le voyait premium.
    // FIX : même relecture cross-rôle (email/oldId) sur les 3 docs → couronne
    // cohérente quel que soit le rôle de l'amitié. Ne tourne que si pas déjà
    // premium (cas premium classique court-circuité → léger).
    if (!isPremium && (u.email || u.oldId)) {
      const or = [];
      if (u.email) or.push({ email: u.email });
      if (u.oldId) or.push({ oldId: u.oldId });
      const [o, s2, w] = await Promise.all([
        Owner.findOne({ $or: or, isStaff: true }).select('_id').lean(),
        Sitter.findOne({ $or: or, isStaff: true }).select('_id').lean(),
        Walker.findOne({ $or: or, isStaff: true }).select('_id').lean(),
      ]);
      if (o || s2 || w) {
        isPremium = true;
        hasPawFollow = true; // staff = tous les abos, dont PawFollow
      }
    }
  } catch (_) {/* best-effort : pas de couronne plutôt qu'un 500 */}
  // v23.1 part 220 — Daniel : "juste le nom de l'utilisateur s'affiche
  // pas". Les users n'ont pas leur firstName/lastName populates dans
  // la DB (signup ne forcait pas le remplissage). Resultat : name vide
  // → frontend affichait "Utilisateur" (fallback v218).
  // Fix : fallback intelligent → si firstName/lastName vides, on prend
  // la partie email avant le @ comme handle (Daniel = "dadaciao84",
  // ALLO MOTEUR = "contact"). C'est privacy-safe (l'email complet reste
  // masque) tout en donnant un nom identifiable.
  let name = [u.firstName, u.lastName].filter(Boolean).join(' ').trim();
  if (!name && u.email) {
    const at = String(u.email).indexOf('@');
    if (at > 0) name = String(u.email).slice(0, at);
  }
  // v23.1 part 244 — Daniel : "mettre les photo du profil" sur la liste
  // d'amis. Root cause : avatar dans les models Owner/Sitter/Walker est
  // un objet { url, publicId } (Cloudinary), pas une string. Avant on
  // renvoyait l'objet entier → frontend tentait de le parser comme String
  // URL → echec silencieux → fallback Icon(Person) gris/bleu/vert. Le
  // search route avait deja le fix avec _avatarUrl mais fetchUserMini
  // l'avait rate. Maintenant on aplatit en URL string ici aussi.
  const _avatarUrl = (a) =>
    (a && (typeof a === 'object' ? a.url : a)) || '';
  return {
    id: u._id,
    model: modelName,
    name,
    avatar: _avatarUrl(u.profilePicture || u.avatar),
    city: u.location?.city || u.city || '',
    // v23.1 part 222 — expose PawFollow status pour que le frontend
    // puisse forcer "Personnes en live" + unlock auto chat + share.
    hasPawFollow,
    // v23.1.280 — tier PawSpot actif (anneau coloré sur l'avatar).
    pawSpotTier,
    // v469 — Paw Premium actif → couronne 👑 visible par tous sur la carte.
    isPremium,
  };
}

async function enrichFriendship(friendship, viewerId, viewerHasPawFollow) {
  // v23.1 part 226 — quand viewerHasPawFollow n'est pas explicitement
  // passe (cas des single-call sites apres mutation accept/share/etc),
  // on lookup soi-meme. Pour les bulk-call sites (/friends + /requests),
  // les handlers passent la valeur deja calculee pour eviter N queries.
  if (viewerHasPawFollow === undefined) {
    try {
      const { hasActivePawFollow } = require('../models/UserSubscription');
      viewerHasPawFollow = await hasActivePawFollow(viewerId);
    } catch (_) {
      viewerHasPawFollow = false;
    }
  }
  const isRequester = String(friendship.requesterId) === String(viewerId);
  let other = isRequester
    ? await fetchUserMini(friendship.addresseeId, friendship.addresseeModel)
    : await fetchUserMini(friendship.requesterId, friendship.requesterModel);
  // v23.1.201 — Daniel : "user voyait 'deja amis' mais liste vide".
  // Cause : amitie pointait vers un compte supprime → other = null →
  // filter le supprimait → friendship existait en DB mais fantome cote
  // UI. Fix : on retourne un placeholder "Utilisateur supprimé" plutot
  // que null pour que le frontend voie l'entree et puisse l'unfriend.
  if (!other) {
    other = {
      id: '',
      model: isRequester ? friendship.addresseeModel : friendship.requesterModel,
      name: 'Utilisateur supprimé',
      email: '',
      avatar: '',
      city: '',
      deleted: true,
    };
  }
  const dbMyShare = isRequester
    ? friendship.requesterSharesPosition
    : friendship.addresseeSharesPosition;
  const dbTheirShare = isRequester
    ? friendship.addresseeSharesPosition
    : friendship.requesterSharesPosition;
  // v23.1 part 243 — Daniel : "ds la liste amis et amis famislle le
  // bouton afficher position on off marche pas y reste bloquer sur auto".
  // Cause : v226 forçait mySharePosition=true cote API quand PawFollow
  // actif → le user toggler OFF la switch, le PATCH stockait
  // dbMyShare=false, mais le NEXT GET /friends ecrasait avec true →
  // la switch rebondissait. Bloque sur Auto.
  //
  // Fix : on retourne TOUJOURS la vraie valeur DB. Le flag
  // myShareAutoByPawFollow reste expose pour que l'UI affiche le badge
  // "Auto · PawFollow" en dessous de la switch, mais la valeur de la
  // switch reflete le choix manuel de l'user.
  const mySharePosition = !!dbMyShare;
  const theirSharePosition = !!dbTheirShare;
  return {
    id: friendship._id,
    status: friendship.status,
    initiatedByMe: isRequester,
    other,
    mySharePosition,
    theirSharePosition,
    // v23.1 part 226 — expose le flag pour que l'UI puisse :
    //  - afficher un badge "Auto (PawFollow)" sur la switch
    //  - desactiver le toggle (read-only) tant que la sub est active
    myShareAutoByPawFollow: !!viewerHasPawFollow,
    createdAt: friendship.createdAt,
    acceptedAt: friendship.acceptedAt,
  };
}

// v23.1 part 214 — Daniel : "je ne recois toujours pas la demande d'amis
// sa me met envoyer mais je ne recois rien". Apres 6 tentatives de fix
// blind, on construit un OUTIL DE DIAGNOSTIC pour surfacer la vraie
// cause une fois pour toutes. Ces 2 endpoints exposent ENTIEREMENT l'etat
// des friendships du user courant, ce qui permet de comparer cote sender
// vs cote receiver et trouver l'incompatibilite.
//
// GET /friends/whoami — retourne l'identite EXACTE du user authentifie
//   (id, model, name, email tronque). Daniel peut comparer cet id avec
//   l'addresseeId stocke dans la friendship cree.
router.get('/whoami', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const Model = MODEL_BY_NAME[user.model];
    const doc = Model
      ? await Model.findById(user.id)
          .select('firstName lastName email')
          .lean()
      : null;
    res.json({
      id: String(user.id),
      role: user.role,
      model: user.model,
      jwtRole: req.user?.role,
      name: doc
        ? [doc.firstName, doc.lastName].filter(Boolean).join(' ').trim()
        : null,
      emailHint: doc?.email
        ? `${String(doc.email).slice(0, 3)}***${String(doc.email).slice(-6)}`
        : null,
      docExists: !!doc,
    });
  } catch (e) {
    logger.error('[friends/whoami]', e);
    res.status(500).json({ error: e.message });
  }
});

// GET /friends/diagnose — retourne TOUTES les friendships ou je suis
// impliqué (requesterId=moi OR addresseeId=moi), peu importe le status.
// Pour chaque doc on enrichit avec l'existence reelle de l'autre user
// dans sa collection. Daniel peut comparer cote sender + cote receiver
// et voir si les ids matchent vraiment.
router.get('/diagnose', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const all = await Friendship.find({
      $or: [
        { requesterId: user.id },
        { addresseeId: user.id },
      ],
    }).lean();
    const enriched = await Promise.all(
      all.map(async (f) => {
        const otherId =
          String(f.requesterId) === String(user.id)
            ? f.addresseeId
            : f.requesterId;
        const otherModel =
          String(f.requesterId) === String(user.id)
            ? f.addresseeModel
            : f.requesterModel;
        const OtherModel =
          MODEL_BY_NAME[otherModel] || MODEL_BY_NAME[
            otherModel
              ? otherModel[0].toUpperCase() + otherModel.slice(1).toLowerCase()
              : ''
          ];
        const otherDoc = OtherModel
          ? await OtherModel.findById(otherId)
              .select('firstName lastName email avatar mapBoostExpiry mapBoostTier isStaff oldId')
              .lean()
          : null;
        // v23.1 part 220 — name fallback : firstName+lastName, sinon
        // email-handle avant @ (privacy preservee).
        let otherName = null;
        if (otherDoc) {
          otherName = [otherDoc.firstName, otherDoc.lastName]
              .filter(Boolean).join(' ').trim();
          if (!otherName && otherDoc.email) {
            const at = String(otherDoc.email).indexOf('@');
            if (at > 0) otherName = String(otherDoc.email).slice(0, at);
          }
        }
        // v23.1 part 222 — flag PawFollow actif sur l'ami pour que le
        // frontend l'affiche dans "Personnes en live" + unlock chat auto.
        let otherHasPawFollow = false;
        if (otherDoc && otherModel) {
          try {
            // v23.1.317 — Daniel (audit) : même fix que fetchUserMini. On utilise
            // hasActivePawFollow (date-based, gère familyExpiry + membre famille)
            // au lieu d'un check status/currentPeriodEnd qui ratait les familles.
            const { hasActivePawFollow } = require('../models/UserSubscription');
            otherHasPawFollow = await hasActivePawFollow(otherId);
          } catch (_) {/* defensive */}
        }
        // v23.1.280 — tier PawSpot actif de l'ami (anneau coloré sur l'avatar).
        // v23.1.281 — PawSpot de base (mapBoostTier null mais boost actif) →
        // 'bronze' pour qu'il y ait TOUJOURS un anneau (cf fetchUserMini).
        let otherPawSpotTier = null;
        try {
          if (otherDoc && otherDoc.mapBoostExpiry
              && new Date(otherDoc.mapBoostExpiry) > new Date()) {
            otherPawSpotTier = (otherDoc.mapBoostTier || '')
                .toString().toLowerCase() || 'bronze';
          }
        } catch (_) {/* defensive */}
        // v469 — Daniel : couronne Paw Premium visible par TOUS sur la carte.
        // Flag premium de l'ami (premiumExpiry actif) propagé au frontend.
        let otherIsPremium = false;
        try {
          const UserSubscription = require('../models/UserSubscription');
          const sub = await UserSubscription.findOne({
            userId: otherId,
            premiumExpiry: { $gt: new Date() },
          }).select('_id').lean();
          otherIsPremium = !!sub;
          // v500 — Daniel : couronne absente sur la carte pour les amis « premium
          // STAFF ». Cette route ne comptait QUE l'abo payant (premiumExpiry),
          // jamais isStaff → pas de couronne pour un staff. + relecture cross-rôle
          // (email/oldId) comme fetchUserMini, pour les comptes staff sur un
          // autre rôle (anciens profils).
          if (!otherIsPremium && otherDoc && otherDoc.isStaff === true) {
            otherIsPremium = true;
          }
          if (!otherIsPremium && otherDoc && (otherDoc.email || otherDoc.oldId != null)) {
            const or = [];
            if (otherDoc.email) or.push({ email: otherDoc.email });
            if (otherDoc.oldId != null) or.push({ oldId: otherDoc.oldId });
            const [o2, s3, w2] = await Promise.all([
              Owner.findOne({ $or: or, isStaff: true }).select('_id').lean(),
              Sitter.findOne({ $or: or, isStaff: true }).select('_id').lean(),
              Walker.findOne({ $or: or, isStaff: true }).select('_id').lean(),
            ]);
            if (o2 || s3 || w2) otherIsPremium = true;
          }
        } catch (_) {/* defensive */}
        return {
          friendshipId: String(f._id),
          status: f.status,
          iAmRequester: String(f.requesterId) === String(user.id),
          requesterId: String(f.requesterId),
          requesterModel: f.requesterModel,
          addresseeId: String(f.addresseeId),
          addresseeModel: f.addresseeModel,
          otherId: String(otherId),
          otherModel,
          otherExists: !!otherDoc,
          otherName,
          // v23.1.267 — Daniel : "les photos de profil n'apparaissent pas".
          // /diagnose (source de la liste Mes amis) ne renvoyait pas l'avatar
          // → placeholder gris partout. On aplatit l'objet {url,publicId} en
          // URL string.
          otherAvatar: (otherDoc && otherDoc.avatar && otherDoc.avatar.url) || '',
          otherHasPawFollow,
          otherPawSpotTier,
          otherIsPremium,
          createdAt: f.createdAt,
          acceptedAt: f.acceptedAt,
        };
      }),
    );
    // v23.1 part 226 — Daniel : "debloque le partage si j'ai un abo
    // paw follow". On expose le statut PawFollow du viewer dans la
    // racine du response pour que le frontend (qui utilise /diagnose
    // comme source de verite v218) force mySharePosition=true et
    // myShareAutoByPawFollow=true sur toutes les friendships.
    let viewerHasPawFollow = false;
    try {
      const { hasActivePawFollow } = require('../models/UserSubscription');
      viewerHasPawFollow = await hasActivePawFollow(user.id);
    } catch (_) {/* defensive */}
    res.json({
      me: { id: String(user.id), model: user.model },
      total: enriched.length,
      friendships: enriched,
      viewerHasPawFollow,
    });
  } catch (e) {
    logger.error('[friends/diagnose]', e);
    res.status(500).json({ error: e.message });
  }
});

// v23.1 part 69 — Bug 9 : "Comment sajoute les amis ?". Daniel didn't
// know how to add friends. Added a search-by-email endpoint that the
// frontend's "+ Ajouter un ami" dialog calls.
//
// GET /friends/search?q=<email_or_name>
//   Returns up to 10 users (owner/sitter/walker) whose email contains
//   the query, plus their role and id. Excludes the caller themselves.
router.get('/search', requireAuth, async (req, res) => {
  try {
    const q = (req.query.q || '').toString().trim().toLowerCase();
    if (q.length < 2) {
      return res.json({ users: [] });
    }
    const meId = req.user.id;
    const escape = (s) => s.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
    const re = new RegExp(escape(q), 'i');
    // v23.1 part 212 — Daniel : "jme co sur allomoteur, je mets ajouter
    // je cherche daniel sa marche pas personne trouver". Cause racine :
    //   - Le SEARCH cherchait sur le champ `name` qui n'EXISTE PAS sur
    //     les docs Owner/Sitter/Walker (ils ont firstName + lastName
    //     SEPARES, et profilePicture pas avatar).
    //   - Donc le regex matchait jamais → 0 resultat.
    // Fix : on cherche sur firstName ET lastName (OR email) et on
    // projete les bons champs. La synthese name = firstName + lastName
    // se fait apres au moment du mapping.
    const projection = 'firstName lastName email profilePicture avatar';

    // v23.1 part 243 — Daniel : "difficulute a rajouter amis". Quand on
    // tape un nom complet comme "Daniel Smith", la query precedente
    // matchait juste /Daniel Smith/i sur firstName et lastName SEPARES,
    // mais aucun doc n'a "Daniel Smith" stocke entierement dans un seul
    // champ → 0 resultat alors que le user EST en base.
    //
    // Fix : on split la query en tokens. Chaque token doit matcher au
    // moins UN des champs (firstName | lastName | email) — AND multi-token.
    // Donc "Daniel Smith" trouve un user avec firstName=Daniel + lastName=Smith,
    // ET un user avec firstName=Smith + lastName=Daniel, ET un user avec
    // email=daniel.smith@... etc.
    const tokens = q.split(/\s+/).filter((t) => t.length >= 1);
    const andClauses = tokens.map((t) => {
      const tre = new RegExp(escape(t), 'i');
      return { $or: [{ email: tre }, { firstName: tre }, { lastName: tre }] };
    });
    const matchQuery = andClauses.length > 0
      ? { $and: andClauses }
      : { $or: [{ email: re }, { firstName: re }, { lastName: re }] };

    const [owners, sitters, walkers] = await Promise.all([
      Owner.find(matchQuery).select(projection).limit(10).lean(),
      Sitter.find(matchQuery).select(projection).limit(10).lean(),
      Walker.find(matchQuery).select(projection).limit(10).lean(),
    ]);

    const _avatarUrl = (a) => (a && (a.url || a)) || '';
    // v23.1 part 220 — name fallback intelligent : firstName + lastName,
    // sinon partie email avant @ (privacy : on cache l'email complet
    // mais on garde un handle identifiable).
    const buildName = (u) => {
      let n = [u.firstName, u.lastName].filter(Boolean).join(' ').trim();
      if (!n && u.email) {
        const at = String(u.email).indexOf('@');
        if (at > 0) n = String(u.email).slice(0, at);
      }
      return n;
    };
    const merged = [
      ...owners.map((u) => ({
        id: u._id.toString(),
        role: 'owner',
        name: buildName(u),
        email: u.email || '',
        avatar: _avatarUrl(u.profilePicture || u.avatar),
      })),
      ...sitters.map((u) => ({
        id: u._id.toString(),
        role: 'sitter',
        name: buildName(u),
        email: u.email || '',
        avatar: _avatarUrl(u.profilePicture || u.avatar),
      })),
      ...walkers.map((u) => ({
        id: u._id.toString(),
        role: 'walker',
        name: buildName(u),
        email: u.email || '',
        avatar: _avatarUrl(u.profilePicture || u.avatar),
      })),
    ].filter((u) => u.id !== meId).slice(0, 10);

    logger.info(
      `[friends/search] q="${q}" meId=${meId} found=${merged.length}`,
    );
    res.json({ users: merged });
  } catch (e) {
    logger.error('[friends/search]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── GET /friends — my accepted friends ─────────────────────────────────────
router.get('/', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    // v23.1 part 215 — REWRITE en mode fetch-all + filter-in-JS (comme
    // /requests v215). Le diagnostic Daniel a prouve que la query avec
    // filtre sur model rate des docs valides. On supprime ce filtre :
    // si f.addresseeId OR f.requesterId === user.id, c'est ma friendship
    // peu importe le model.
    const friendships = (await Friendship.find({
      status: 'accepted',
      $or: [
        { requesterId: user.id },
        { addresseeId: user.id },
      ],
    })
      .sort({ acceptedAt: -1 })
      .lean()).filter(
        (f) =>
          String(f.requesterId) === String(user.id) ||
          String(f.addresseeId) === String(user.id),
      );
    // v23.1 part 210 — diagnostic log
    logger.info(
      `[friends/list] user=${user.model}:${user.id} accepted_count=${friendships.length}`,
    );
    if (friendships.length === 0) {
      // Defensive : on vérifie aussi pending pour voir s'il y a une
      // demande zombie en attente que le user n'a jamais accepté de
      // son côté (cas Daniel : friendship en 'pending' ne remonte pas
      // dans /friends mais POST /request retourne 409 "déjà").
      const pendingCount = await Friendship.countDocuments({
        status: 'pending',
        $or: [
          { requesterId: user.id, requesterModel: user.model },
          { addresseeId: user.id, addresseeModel: user.model },
        ],
      });
      const declinedCount = await Friendship.countDocuments({
        status: 'declined',
        $or: [
          { requesterId: user.id, requesterModel: user.model },
          { addresseeId: user.id, addresseeModel: user.model },
        ],
      });
      logger.warn(
        `[friends/list] EMPTY accepted but user has pending=${pendingCount} declined=${declinedCount} — possible zombie state`,
      );
    }

    // v23.1 part 226 — compute viewerHasPawFollow ONCE pour ne pas
    // hammer Mongo dans la boucle map(). Si true, enrichFriendship
    // force mySharePosition=true sur toutes les friendships retournees.
    const { hasActivePawFollow } = require('../models/UserSubscription');
    const viewerHasPawFollow = await hasActivePawFollow(user.id).catch(() => false);
    const enriched = await Promise.all(
      friendships.map((f) => enrichFriendship(f, user.id, viewerHasPawFollow)),
    );
    // v451 — Daniel : « les anciens amis au profil supprimé restaient dans ma
    // liste — quand on supprime un compte, tout doit disparaître ». On NE garde
    // donc plus les orphelins (other.deleted) : on PURGE l'amitié vers un compte
    // supprimé et on l'exclut de la liste (auto-nettoyage, plus besoin
    // d'« unfriend » manuel). [Remplace le placeholder « Utilisateur supprimé »
    // de v23.1.201.]
    const alive = enriched.filter((e) => !(e.other && e.other.deleted === true));
    const orphanIds = enriched
      .filter((e) => e.other && e.other.deleted === true)
      .map((e) => e.id);
    if (orphanIds.length) {
      try {
        await Friendship.deleteMany({ _id: { $in: orphanIds } });
        logger.info(`[friends/list] pruned ${orphanIds.length} orphan friendship(s) (deleted accounts)`);
      } catch (_) {/* best-effort */}
    }
    res.json({ friends: alive });
  } catch (e) {
    logger.error('[friends/list]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /friends/reset-with/:targetId/:targetModel ────────────────────────
// v23.1 part 210 — Daniel : "le bug amis persiste il me dis deja amis
// et jai personne ds la liste, donc corrige ce putain de pb". Escape
// hatch : supprime TOUTES les Friendships entre user courant et target,
// peu importe leur status. Daniel peut ensuite recreer fresh.
// Le frontend appelle cet endpoint quand l'utilisateur recoit "deja
// amis" mais ne voit personne dans sa liste.
router.post('/reset-with/:targetId/:targetModel', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const targetId = req.params.targetId;
    const targetModel = req.params.targetModel; // 'Owner' | 'Sitter' | 'Walker'
    if (!['Owner', 'Sitter', 'Walker'].includes(targetModel)) {
      return res.status(400).json({ error: 'Invalid target model.' });
    }
    const result = await Friendship.deleteMany({
      $or: [
        {
          requesterId: user.id, requesterModel: user.model,
          addresseeId: targetId, addresseeModel: targetModel,
        },
        {
          requesterId: targetId, requesterModel: targetModel,
          addresseeId: user.id, addresseeModel: user.model,
        },
      ],
    });
    logger.info(
      `[friends/reset-with] user=${user.model}:${user.id} target=${targetModel}:${targetId} deleted=${result.deletedCount}`,
    );
    res.json({ deleted: result.deletedCount });
  } catch (e) {
    logger.error('[friends/reset-with]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── GET /friends/requests — pending (incoming + outgoing) ──────────────────
router.get('/requests', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    // v23.1 part 215 — Daniel diagnostic a revele : ALLO MOTEUR.id ===
    // friendship.addresseeId, friendship.addresseeModel === 'Walker',
    // status === 'pending'. /diagnose retournait correctement le doc
    // mais /requests retournait empty. L'unique difference : /diagnose
    // n'a PAS de filtre addresseeModel.
    //
    // Conclusion : la query Mongo $in: ['Walker', 'walker'] ne matche
    // pas pour une raison subtile (peut-etre trim, encodage, ou bug
    // Mongoose). On REWRITE en mode "fetch all + filter in JS" exactement
    // comme /diagnose pour garantir la coherence.
    const all = await Friendship.find({
      status: 'pending',
      $or: [
        { addresseeId: user.id },
        { requesterId: user.id },
      ],
    }).lean();
    const incoming = all.filter(
      (f) => String(f.addresseeId) === String(user.id),
    );
    const outgoing = all.filter(
      (f) => String(f.requesterId) === String(user.id),
    );
    logger.info(
      `[friends/requests] user=${user.model}:${user.id} ` +
      `total=${all.length} incoming=${incoming.length} outgoing=${outgoing.length}`,
    );
    if (all.length > 0 && incoming.length === 0 && outgoing.length === 0) {
      // Diagnostic : on a trouve des docs avec mon id quelque part mais
      // ni en incoming ni en outgoing → impossible logique → log raw.
      logger.warn(
        `[friends/requests] ZOMBIE STATE user=${user.id} raw=${JSON.stringify(all.map(f => ({
          _id: String(f._id),
          status: f.status,
          requesterId: String(f.requesterId),
          addresseeId: String(f.addresseeId),
        })))}`,
      );
    }
    // Backfill on the fly : normalise model casing (anti-zombie)
    for (const f of [...incoming, ...outgoing]) {
      let needsUpdate = false;
      const update = {};
      if (f.addresseeModel && f.addresseeModel !== f.addresseeModel[0].toUpperCase() + f.addresseeModel.slice(1).toLowerCase()) {
        update.addresseeModel = f.addresseeModel[0].toUpperCase() + f.addresseeModel.slice(1).toLowerCase();
        needsUpdate = true;
      }
      if (f.requesterModel && f.requesterModel !== f.requesterModel[0].toUpperCase() + f.requesterModel.slice(1).toLowerCase()) {
        update.requesterModel = f.requesterModel[0].toUpperCase() + f.requesterModel.slice(1).toLowerCase();
        needsUpdate = true;
      }
      if (needsUpdate) {
        try {
          await Friendship.updateOne({ _id: f._id }, { $set: update });
          logger.info(`[friends/requests] normalized model casing on ${f._id}`);
        } catch (e) {/* defensive */}
      }
    }

    // v23.1 part 226 — viewerHasPawFollow calcule once pour les 2 listes.
    const { hasActivePawFollow } = require('../models/UserSubscription');
    const viewerHasPawFollow = await hasActivePawFollow(user.id).catch(() => false);
    const [incomingEnriched, outgoingEnriched] = await Promise.all([
      Promise.all(incoming.map((f) => enrichFriendship(f, user.id, viewerHasPawFollow))),
      Promise.all(outgoing.map((f) => enrichFriendship(f, user.id, viewerHasPawFollow))),
    ]);

    res.json({
      // v23.1.201 — on garde les orphelins pour qu'ils soient visibles
      // et actionnables (refuse/annuler) cote frontend.
      incoming: incomingEnriched,
      outgoing: outgoingEnriched,
    });
  } catch (e) {
    logger.error('[friends/requests]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /friends/request — send a new request ─────────────────────────────
router.post('/request', requireAuth, async (req, res) => {
  try {
    const { targetId, targetRole } = req.body;
    const targetModel = ROLE_TO_MODEL_NAME[targetRole];
    if (!targetId || !targetModel) {
      return res
        .status(400)
        .json({ error: 'targetId and targetRole are required.' });
    }

    const user = me(req);
    if (String(targetId) === String(user.id) && targetModel === user.model) {
      return res.status(400).json({ error: 'Cannot befriend yourself.' });
    }

    // Avoid duplicates in either direction.
    // v23.1.177 — Daniel : "demande amis erreur une demande est deja en
    // attente alors que sa marche pas". Cause : une vieille demande
    // pending (>7 jours) bloque toute nouvelle demande. On considère
    // expirée une demande pending de >7 jours et on la supprime avant
    // de créer la nouvelle.
    // v23.1 part 212 — Daniel : "jme co sur allomoteur aucune demande
    // recu". On rend la detection de doublon case-insensitive sur model
    // pour matcher les vieux docs en lowercase qui sinon createraient
    // des doublons + creent l'illusion "deja amis".
    const userModelVariants = [user.model, user.model.toLowerCase()];
    const targetModelVariants = [targetModel, targetModel.toLowerCase()];
    const existing = await Friendship.findOne({
      $or: [
        {
          requesterId: user.id,
          requesterModel: { $in: userModelVariants },
          addresseeId: targetId,
          addresseeModel: { $in: targetModelVariants },
        },
        {
          requesterId: targetId,
          requesterModel: { $in: targetModelVariants },
          addresseeId: user.id,
          addresseeModel: { $in: userModelVariants },
        },
      ],
    });
    if (existing) {
      const ageDays = existing.createdAt
        ? (Date.now() - new Date(existing.createdAt).getTime()) /
          (1000 * 60 * 60 * 24)
        : 0;
      const iAmRequester =
        String(existing.requesterId) === String(user.id) &&
        existing.requesterModel === user.model;
      // v23.1.178 — Daniel : "demande amis erreur une demande est deja en
      // attente alors que sa marche pas". Cas pratique : Daniel a envoyé
      // une demande à witoulek hier, witoulek n'a jamais reçu de notif
      // (v176 bug), Daniel veut renvoyer aujourd'hui → 409 bloque.
      //
      // Nouvelle logique :
      //   1. Pending >7 jours → cleanup (v177)
      //   2. Pending et JE suis le requester → cleanup (re-send seamless),
      //      ça permet à Daniel de relancer sa demande à witoulek sans
      //      blocage. Le 1er notif a été perdu, on en renvoie un nouveau.
      //   3. Tout autre cas (accepted, blocked, pending de l'autre side) → 409.
      if (
        existing.status === 'pending' &&
        iAmRequester &&
        ageDays <= 7
      ) {
        // v23.1.295 — Daniel : "une demande une fois, pas 15". Une demande
        // pending de MA part existe déjà (< 7j) → réponse idempotente SANS
        // renvoyer une nouvelle notif (anti-spam). Au-delà de 7j (branche
        // suivante) on nettoie + recrée, au cas où la 1re notif aurait été
        // perdue.
        return res.status(200).json({
          ok: true,
          alreadyPending: true,
          friendshipId: String(existing._id),
        });
      } else if (
        existing.status === 'pending' &&
        (ageDays > 7 || iAmRequester)
      ) {
        await Friendship.findByIdAndDelete(existing._id);
        logger.info(
          `[friends/request] cleaned pending ${existing._id} (age=${ageDays.toFixed(1)}d, iAmRequester=${iAmRequester}) — will recreate`,
        );
      } else if (existing.status === 'declined' || existing.status === 'blocked_pending_cleanup') {
        // v23.1 part 207 — Daniel : "je nais tjr aucune demande damis ni
        // damis et losque je demande sa me met erreur deja amis mais
        // regarde les photos" + screen "Pas encore d'amis".
        //   Cause racine : un doc Friendship reste en status='declined'
        //   dans Mongo, le duplicate detector match TOUS les status →
        //   "Déjà amis", mais GET /friends filtre status='accepted' →
        //   liste vide. L'utilisateur est piégé dans un état zombie.
        //   Fix : on supprime le doc declined pour permettre une fresh
        //   re-demande qui passera dans le flux normal (pending →
        //   accept ou auto-accept).
        await Friendship.findByIdAndDelete(existing._id);
        logger.info(
          `[friends/request] cleaned declined ${existing._id} — recreating fresh request`,
        );
      } else if (existing.status === 'accepted') {
        // v23.1 part 209 — Daniel re-rapporte le bug en v208 : "deja amis
        // et ma liste damis et vide". Cas non couvert par v207 : la
        // friendship est en status='accepted' mais l'addressee user a
        // été supprimé (orphan). v201 a un placeholder "Utilisateur
        // supprimé" qui DEVRAIT apparaitre côté UI, mais si le user est
        // référencé par un id dont le doc est sous une autre collection
        // ou simplement disparu sans trace, le placeholder lui-même
        // peut foirer côté rendu (id vide → tile filtrée silencieusement
        // par d'autres branches du widget).
        //   Fix : on vérifie l'EXISTENCE du user en face. S'il existe
        //   réellement → 409 "déjà amis" normal. Sinon → on cleanup le
        //   doc orphan pour débloquer Daniel.
        try {
          const otherId = String(existing.requesterId) === String(user.id)
            ? existing.addresseeId
            : existing.requesterId;
          const otherModel = String(existing.requesterId) === String(user.id)
            ? existing.addresseeModel
            : existing.requesterModel;
          const OtherModel = otherModel === 'Walker' ? Walker
            : otherModel === 'Sitter' ? Sitter
            : Owner;
          const otherUser = await OtherModel.findById(otherId)
            .select('_id').lean();
          if (!otherUser) {
            await Friendship.findByIdAndDelete(existing._id);
            logger.info(
              `[friends/request] cleaned orphan accepted ${existing._id} (other ${otherModel}:${otherId} deleted) — recreating`,
            );
            // Tomber dans le flux normal de création ci-dessous.
          } else {
            return res
              .status(409)
              .json({ error: `Already in state "${existing.status}".`, id: existing._id });
          }
        } catch (orphanCheckErr) {
          logger.warn('[friends/request] orphan check failed', orphanCheckErr);
          // Defensive : on tombe sur le 409 classique si le check plante.
          return res
            .status(409)
            .json({ error: `Already in state "${existing.status}".`, id: existing._id });
        }
      } else if (existing.status === 'pending' && !iAmRequester) {
        // v23.1.191 — Daniel : "je ne peux pas ajouter demande amis sa
        // me dis jai deja une demande en attente ds amis je nai
        // personne". Cas reel : l'autre partie m'a envoye une demande
        // que je n'ai jamais vue (notif perdue, etc.) → je tente de
        // l'ajouter et je suis bloque par 409.
        //
        // Nouvelle logique : si l'autre partie m'a envoye une demande
        // pending, mon tap "Inviter" la valide automatiquement (mutual
        // confirmation = on est tous les deux d'accord pour etre amis).
        existing.status = 'accepted';
        existing.acceptedAt = new Date();
        await existing.save();
        logger.info(
          `[friends/request] auto-accepted incoming pending ${existing._id} (other side wanted us as friends too)`,
        );
        // Notif a l'expediteur original pour le prevenir.
        try {
          const { sendNotification } = require('../services/notificationSender');
          await sendNotification({
            userId: String(existing.requesterId),
            role: String(existing.requesterModel || 'owner').toLowerCase(),
            type: 'friend_request_accepted',
            data: {
              friendshipId: String(existing._id),
              byUserId: String(user.id),
            },
          });
        } catch (_) {/* non-critical */}
        return res.status(200).json({
          friendship: await enrichFriendship(existing, user.id),
          autoAccepted: true,
        });
      } else {
        return res
          .status(409)
          .json({ error: `Already in state "${existing.status}".`, id: existing._id });
      }
    }

    const friendship = new Friendship({
      requesterId: user.id,
      requesterModel: user.model,
      addresseeId: targetId,
      addresseeModel: targetModel,
      status: 'pending',
    });
    await friendship.save();

    logger.info(
      `[friends] ${user.model} ${user.id} → ${targetModel} ${targetId} (pending)`,
    );

    // v23.1.177 — Daniel : "demande amis erreur une demande est deja en
    // attente alors que sa marche pas". Cause racine : la route N'ENVOIE
    // PAS de notif au destinataire → il ne savait jamais qu'une demande
    // arrivait. Maintenant on envoie un push notif + le destinataire peut
    // refresh sa friends_screen pour voir la demande dans l'onglet
    // "Demandes".
    try {
      const { sendNotification } = require('../services/notificationSender');
      const buildEmailLink = require('../utils/emailLinkBuilder').buildEmailLink;
      await sendNotification({
        userId: targetId,
        role: (targetRole || '').toLowerCase(),
        type: 'friend_request_received',
        title: 'friend_request_received_title',
        body: 'friend_request_received_body',
        data: {
          friendshipId: String(friendship._id),
          fromUserId: String(user.id),
          fromUserRole: req.user?.role || user.model.toLowerCase(),
          emailLink: buildEmailLink('notifications'),
        },
      });
    } catch (notifErr) {
      logger.warn('[friends/request] notif failed', notifErr);
    }

    // v23.1 part 205 — emit socket pour refresh temps réel des 2 cotés.
    // Avant : seule la notif push remontait, donc si l'app était ouverte
    // (pas en background) le destinataire ne voyait rien jusqu'à un kill.
    try {
      // v23.1.256 — BUG MAJEUR : require('../sockets/io') = module INEXISTANT
      // → throw avalé → la demande d'ami n'était JAMAIS poussée en temps réel.
      // De plus la room visée `user_<id>` ne matche pas la vraie room
      // `user:<role>:<id>` que le frontend rejoint. FIX : emitToUser (emitter)
      // qui cible la bonne user-room → demande reçue instantanément.
      const { emitToUser } = require('../sockets/emitter');
      const payload = {
        friendshipId: String(friendship._id),
        from: {
          userId: String(user.id),
          role: (user.model || '').toLowerCase(),
        },
      };
      emitToUser(
        (friendship.addresseeModel || '').toLowerCase(),
        String(friendship.addresseeId),
        'friend_request:received',
        payload,
      );
      emitToUser(
        (friendship.requesterModel || '').toLowerCase(),
        String(friendship.requesterId),
        'friend_request:received',
        payload,
      );
    } catch (socketErr) {
      logger.warn('[friends/request] socket emit failed', socketErr);
    }

    res.status(201).json({ friendship: await enrichFriendship(friendship, user.id) });
  } catch (e) {
    logger.error('[friends/request]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /friends/:id/accept ───────────────────────────────────────────────
router.post('/:id/accept', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const f = await Friendship.findById(req.params.id);
    if (!f) return res.status(404).json({ error: 'Request not found.' });
    if (String(f.addresseeId) !== String(user.id) || f.addresseeModel !== user.model) {
      return res.status(403).json({ error: 'Only the addressee can accept.' });
    }
    if (f.status !== 'pending') {
      return res.status(400).json({ error: `Already ${f.status}.` });
    }
    f.status = 'accepted';
    f.acceptedAt = new Date();
    await f.save();
    logger.info(`[friends] ${user.id} accepted ${f._id}`);

    // v23.1 part 205 — Daniel : "amis ajouter ma liste est vide". Root
    // cause partiel : quand l'addressee accepte, le requester n'était
    // JAMAIS notifié ni rafraîchi → il pensait sa demande encore pending
    // et ne voyait pas l'ami dans la liste tant qu'il ne tuait pas l'app.
    // Maintenant :
    //   - sendNotification push au requester (type=friend_request_accepted)
    //   - emit socket `friend_request:accepted` aux 2 user-rooms pour que
    //     les 2 frontends puissent appeler refresh() en temps réel.
    try {
      const { sendNotification } = require('../services/notificationSender');
      const buildEmailLink = require('../utils/emailLinkBuilder').buildEmailLink;
      await sendNotification({
        userId: f.requesterId,
        role: (f.requesterModel || '').toLowerCase(),
        type: 'friend_request_accepted',
        title: 'friend_request_accepted_title',
        body: 'friend_request_accepted_body',
        data: {
          friendshipId: String(f._id),
          byUserId: String(user.id),
          byUserRole: (user.model || '').toLowerCase(),
          emailLink: buildEmailLink('friends'),
        },
      });
    } catch (notifErr) {
      logger.warn('[friends/accept] notif failed', notifErr);
    }
    try {
      // v23.1.256 — même fix que /request : emitToUser (vraie room
      // user:<role>:<id>) au lieu du module inexistant sockets/io + room
      // `user_<id>`. L'acceptation est maintenant poussée en temps réel aux
      // 2 parties → la liste d'amis se rafraîchit sans kill de l'app.
      const { emitToUser } = require('../sockets/emitter');
      const payload = {
        friendshipId: String(f._id),
        by: { userId: String(user.id), role: (user.model || '').toLowerCase() },
      };
      emitToUser(
        (f.requesterModel || '').toLowerCase(),
        String(f.requesterId),
        'friend_request:accepted',
        payload,
      );
      emitToUser(
        (f.addresseeModel || '').toLowerCase(),
        String(f.addresseeId),
        'friend_request:accepted',
        payload,
      );
    } catch (socketErr) {
      logger.warn('[friends/accept] socket emit failed', socketErr);
    }

    res.json({ friendship: await enrichFriendship(f, user.id) });
  } catch (e) {
    logger.error('[friends/accept]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /friends/:id/decline ──────────────────────────────────────────────
router.post('/:id/decline', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const f = await Friendship.findById(req.params.id);
    if (!f) return res.status(404).json({ error: 'Request not found.' });
    if (String(f.addresseeId) !== String(user.id) || f.addresseeModel !== user.model) {
      return res.status(403).json({ error: 'Only the addressee can decline.' });
    }
    f.status = 'declined';
    f.declinedAt = new Date();
    await f.save();
    res.json({ ok: true });
  } catch (e) {
    logger.error('[friends/decline]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── DELETE /friends/:id — unfriend (either side) ───────────────────────────
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const f = await Friendship.findById(req.params.id);
    if (!f) return res.status(404).json({ error: 'Not found.' });
    const isParty =
      (String(f.requesterId) === String(user.id) && f.requesterModel === user.model) ||
      (String(f.addresseeId) === String(user.id) && f.addresseeModel === user.model);
    if (!isParty) return res.status(403).json({ error: 'Not your friendship.' });
    await f.deleteOne();
    res.json({ ok: true });
  } catch (e) {
    logger.error('[friends/delete]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /friends/:id/share — toggle "I broadcast my position to X" ────────
router.post('/:id/share', requireAuth, async (req, res) => {
  try {
    const { share } = req.body;
    const user = me(req);
    const f = await Friendship.findById(req.params.id);
    if (!f || f.status !== 'accepted') {
      return res.status(404).json({ error: 'Accepted friendship not found.' });
    }
    const isRequester =
      String(f.requesterId) === String(user.id) && f.requesterModel === user.model;
    const isAddressee =
      String(f.addresseeId) === String(user.id) && f.addresseeModel === user.model;
    if (!isRequester && !isAddressee) {
      return res.status(403).json({ error: 'Not your friendship.' });
    }
    if (isRequester) f.requesterSharesPosition = !!share;
    if (isAddressee) f.addresseeSharesPosition = !!share;
    await f.save();
    res.json({ friendship: await enrichFriendship(f, user.id) });
  } catch (e) {
    logger.error('[friends/share]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── v23.1.170 — Suivi famille (PawFollow Famille €9.99) ───────────────────
//
// Daniel : "fais le suivi famille en plus, si une famille veux se suivre
// que juste en cliquand sur le nom ds sa liste damis sa le geoloclaise".
//
// Trois routes :
//   GET    /:id/track-access      → l'autre user peut-il être tracké ?
//   POST   /family/invite-member  → ajouter un membre à ma famille (titulaire)
//   DELETE /family/member/:userId → retirer un membre

const UserSubscription = require('../models/UserSubscription');
const { isInSameFamily, familyActiveMatch } = require('../models/UserSubscription');

/**
 * GET /friends/:id/track-access
 * Réponse : { canTrack: bool, reason: 'family' | 'shared' | 'none' | 'no_friendship' }
 *
 * Logique :
 *   - Si pas amis (friendship.accepted) → canTrack=false, reason='no_friendship'
 *   - Si même famille PawFollow Famille → canTrack=true, reason='family'
 *   - Si l'autre a flag share-position=true vers moi → canTrack=true, reason='shared'
 *   - Sinon canTrack=false, reason='none'
 */
router.get('/:id/track-access', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const otherId = req.params.id;
    if (!otherId) return res.status(400).json({ error: 'Friend id required.' });

    // Friendship status check
    const friendship = await Friendship.findOne({
      status: 'accepted',
      $or: [
        { requesterId: user.id, addresseeId: otherId },
        { requesterId: otherId, addresseeId: user.id },
      ],
    }).lean();
    if (!friendship) {
      return res.json({ canTrack: false, reason: 'no_friendship' });
    }

    // Family check
    if (await isInSameFamily(user.id, otherId)) {
      return res.json({ canTrack: true, reason: 'family' });
    }

    // v23.1 part 226 — Daniel : "debloque le partage de position a mes
    // amis et famille si jai un abonnement paw follow". Si l'AMI a un
    // PawFollow actif, il broadcast a tous ses amis (v226 mapSocket) →
    // donc je peux le tracker. Symetriquement, on autorise aussi le tap
    // si MOI j'ai PawFollow (mon abo me debloque la fonctionnalite
    // "tracker mes amis").
    try {
      const { hasActivePawFollow } = require('../models/UserSubscription');
      const [iHavePawFollow, otherHasPawFollow] = await Promise.all([
        hasActivePawFollow(user.id),
        hasActivePawFollow(otherId),
      ]);
      if (iHavePawFollow || otherHasPawFollow) {
        return res.json({ canTrack: true, reason: 'pawfollow' });
      }
    } catch (_) {/* defensive */}

    // Per-friendship share flag (the OTHER must share with me).
    // v23.1.175 — Daniel : "reverifie que tte marche les suivis amis".
    // Bug audit : les noms de champs étaient WRONG (requesterShareWithAddressee
    // n'existe PAS dans le schéma Friendship). Les vrais champs sont
    // requesterSharesPosition / addresseeSharesPosition (cf. mapSocket.js:53-66
    // et Friendship.js:53-54).
    const otherSharesWithMe =
      (String(friendship.requesterId) === String(otherId) &&
        friendship.requesterSharesPosition === true) ||
      (String(friendship.addresseeId) === String(otherId) &&
        friendship.addresseeSharesPosition === true);
    if (otherSharesWithMe) {
      return res.json({ canTrack: true, reason: 'shared' });
    }

    return res.json({ canTrack: false, reason: 'none' });
  } catch (e) {
    logger.error('[friends/track-access]', e);
    res.status(500).json({ error: e.message });
  }
});

/**
 * GET /friends/:id/last-position
 *
 * v23.1 part 239 — Daniel : "voir position live je clic sur witoulek qui
 * est a murcia et sa me met ma geolocalisation a pego" + "voir la carte
 * sa mouvre la carte google dans la ville au lieu de mouvrir le paw map
 * sur la position excat du sitter".
 *
 * Endpoint qui retourne la DERNIERE position GPS connue d'un ami/famille
 * (lue depuis User.location.coordinates, mise a jour par mapSocket
 * map:position-update toutes les 10s). Permet a Daniel de retrouver
 * la position EXACTE et FRAICHE d'un ami au lieu du fallback metadata
 * stocke dans le message (qui peut etre stale ou la mauvaise position).
 *
 * Reponse :
 *   200 { lat, lng, at } si trackable + position connue
 *   200 { lat: null, lng: null } si trackable mais pas de position
 *   403 { error: ... } si pas autorise (pas amis, pas meme famille, etc.)
 */
router.get('/:id/last-position', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const otherId = req.params.id;
    if (!otherId) return res.status(400).json({ error: 'Friend id required.' });

    // Reuse the track-access logic for security.
    const friendship = await Friendship.findOne({
      status: 'accepted',
      $or: [
        { requesterId: user.id, addresseeId: otherId },
        { requesterId: otherId, addresseeId: user.id },
      ],
    }).lean();

    // v23.1 part 243 — Daniel : "le bouton afficher position on off
    // marche pas y reste bloquer sur auto". Si l'ami a EXPLICITEMENT
    // toggle off sa switch "partager position", on doit refuser meme
    // si PawFollow / famille — son choix manuel prime sur le bypass abo.
    // On lit son share-flag EN PREMIER : si false → 403 immediat.
    const otherShareFlag = friendship
      ? (String(friendship.requesterId) === String(otherId)
          ? friendship.requesterSharesPosition
          : friendship.addresseeSharesPosition)
      : null;
    if (otherShareFlag === false) {
      return res.status(403).json({
        error: 'Friend opted out of position sharing.',
        canTrack: false,
      });
    }

    let canTrack = false;
    if (friendship) {
      // Family bypass.
      try {
        if (await isInSameFamily(user.id, otherId)) canTrack = true;
      } catch (_) {/* */}
      // PawFollow bypass (mine OR other's).
      if (!canTrack) {
        try {
          const { hasActivePawFollow } = require('../models/UserSubscription');
          const [mine, other] = await Promise.all([
            hasActivePawFollow(user.id),
            hasActivePawFollow(otherId),
          ]);
          if (mine || other) canTrack = true;
        } catch (_) {/* */}
      }
      // Per-friendship share flag.
      if (!canTrack) {
        const shares =
          (String(friendship.requesterId) === String(otherId) &&
            friendship.requesterSharesPosition === true) ||
          (String(friendship.addresseeId) === String(otherId) &&
            friendship.addresseeSharesPosition === true);
        if (shares) canTrack = true;
      }
    }

    if (!canTrack) {
      return res.status(403).json({
        error: 'Not authorized to track this user.',
        canTrack: false,
      });
    }

    // Determine the other's model (Owner/Sitter/Walker) by querying each.
    let otherDoc = null;
    let otherModel = null;
    const Owner = require('../models/Owner');
    const Sitter = require('../models/Sitter');
    const Walker = require('../models/Walker');
    for (const [Model, name] of [[Owner, 'Owner'], [Sitter, 'Sitter'], [Walker, 'Walker']]) {
      try {
        const doc = await Model.findById(otherId).select('location').lean();
        if (doc) { otherDoc = doc; otherModel = name; break; }
      } catch (_) {/* */}
    }
    if (!otherDoc) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const coords = otherDoc.location?.coordinates;
    if (!Array.isArray(coords) || coords.length < 2) {
      return res.json({ lat: null, lng: null, otherModel });
    }
    // GeoJSON stores [lng, lat]
    return res.json({
      lat: Number(coords[1]),
      lng: Number(coords[0]),
      otherModel,
      city: otherDoc.location?.city || '',
    });
  } catch (e) {
    logger.error('[friends/last-position]', e);
    res.status(500).json({ error: e.message });
  }
});

/**
 * GET /friends/live-positions
 *
 * v23.1.351 — Daniel : "vérifie que quand on se connecte sur la PawMap la
 * 1re fois, tous les points, signalements ET amis/famille apparaissent".
 * AVANT : les positions amis n'arrivaient QUE par le live socket
 * (map:friend-position) → à la 1re ouverture la carte était vide d'amis
 * jusqu'au prochain tick GPS de LEUR téléphone, et un ami qui ne diffuse
 * pas n'apparaissait jamais (alors que sa dernière position est en base,
 * persistée toutes les 10s par mapSocket).
 *
 * Ce endpoint renvoie EN UNE FOIS la dernière position connue (< 24h) de
 * tous mes amis/famille TRAÇABLES, avec exactement les mêmes règles que
 * /:id/last-position : opt-out explicite prioritaire → famille → PawFollow
 * (le mien OU le sien) → flag de partage par amitié.
 */
router.get('/live-positions', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const friendships = await Friendship.find({
      status: 'accepted',
      $or: [{ requesterId: user.id }, { addresseeId: user.id }],
    }).lean();

    const Owner = require('../models/Owner');
    const Sitter = require('../models/Sitter');
    const Walker = require('../models/Walker');
    const { hasActivePawFollow } = require('../models/UserSubscription');
    let minePawFollow = false;
    try { minePawFollow = await hasActivePawFollow(user.id); } catch (_) {/* */}

    const MAX_AGE_MS = 24 * 60 * 60 * 1000; // fraîcheur : 24h max
    const now = Date.now();
    const positions = [];

    for (const f of friendships) {
      const iAmRequester = String(f.requesterId) === String(user.id);
      const otherId = iAmRequester ? String(f.addresseeId) : String(f.requesterId);
      const otherModel = iAmRequester ? f.addresseeModel : f.requesterModel;

      // Opt-out explicite de L'AUTRE → jamais visible (prime sur tout).
      const otherShareFlag = iAmRequester
        ? f.addresseeSharesPosition
        : f.requesterSharesPosition;
      if (otherShareFlag === false) continue;

      let canTrack = false;
      try { if (await isInSameFamily(user.id, otherId)) canTrack = true; } catch (_) {/* */}
      if (!canTrack && minePawFollow) canTrack = true;
      if (!canTrack) {
        try { if (await hasActivePawFollow(otherId)) canTrack = true; } catch (_) {/* */}
      }
      if (!canTrack && otherShareFlag === true) canTrack = true;
      if (!canTrack) continue;

      const Model =
        otherModel === 'Walker' ? Walker : otherModel === 'Sitter' ? Sitter : Owner;
      let doc = null;
      try { doc = await Model.findById(otherId).select('location').lean(); } catch (_) {/* */}
      const coords = doc?.location?.coordinates;
      if (!Array.isArray(coords) || coords.length < 2) continue;
      const at = doc.location?.updatedAt ? new Date(doc.location.updatedAt) : null;
      if (at && now - at.getTime() > MAX_AGE_MS) continue; // trop vieille

      positions.push({
        userId: otherId,
        role: String(otherModel || 'Owner').toLowerCase(),
        lat: Number(coords[1]),
        lng: Number(coords[0]),
        at: at ? at.toISOString() : null,
        city: doc.location?.city || '',
      });
    }

    res.json({ positions });
  } catch (e) {
    logger.error('[friends/live-positions]', e);
    res.status(500).json({ error: e.message });
  }
});

/**
 * GET /friends/family/members
 * Liste les membres de MA famille PawFollow + retourne mon statut titulaire.
 * Format de réponse :
 *   {
 *     hasActiveFamilyPlan: bool,
 *     members: [{ id, role, name, avatar, addedAt, email }],
 *     remainingSlots: number (4 - members.length quand active, 0 sinon)
 *   }
 */
router.get('/family/members', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const now = new Date();
    // v23.1 part 249 — Daniel : "ps famille nest tjr pas rajouter ds le
    // site web". Cause racine identifiee : la query etait CASE-SENSITIVE
    // sur userModel (cherchait 'Owner' / 'Sitter' / 'Walker') alors que
    // certains docs UserSubscription stockent en lowercase ('owner' etc.).
    // Resultat : si tu es titulaire de la sub Famille mais que ton sub
    // doc a userModel='owner' (lowercase), la query rate, hasActiveFamilyPlan
    // = false, et l'UI cote site web affiche zero famille.
    //
    // En plus, on couvre maintenant le cas "je suis membre d'une autre
    // famille" : un cluster de family-related users est retourne, regroupant :
    //   1. Mes membres (si je suis titulaire)
    //   2. Le titulaire + autres membres de la sub qui m'inclut (si je suis
    //      membre d'une famille d'un autre)
    // Cela donne au frontend une vue globale "ma famille étendue".
    // v23.1.281 — on UNIFIE la détection titulaire avec resolveOwnFamilySub
    // (même résolveur robuste que l'ajout/retrait : oldId + docs même email +
    // balayage email-titulaire + self-heal/re-point). Ainsi isHolder reflète
    // EXACTEMENT la capacité réelle d'ajouter/retirer (plus de désync entre la
    // carte "Inviter" et l'échec FAMILY_PLAN_REQUIRED).
    let ownSub = null;
    try {
      ownSub = await resolveOwnFamilySub(user);
    } catch (_) {
      ownSub = null;
    }

    // Subs qui m'incluent comme membre (someone else's family).
    // v23.1.283 — famille active tolérante (familyExpiry OU ancien plan).
    const subsHostingMe = await UserSubscription.find({
      'familyMembers.userId': user.id,
      ...familyActiveMatch(now),
    }).lean();

    // Aggregation : map id -> familyMemberEntry pour dedup.
    const byId = new Map();

    if (ownSub && Array.isArray(ownSub.familyMembers)) {
      for (const m of ownSub.familyMembers) {
        const id = String(m.userId);
        byId.set(id, {
          userId: id,
          userModel: m.userModel,
          email: m.email || null,
          addedAt: m.addedAt,
          status: m.status || 'active',
          // v23.1.336 — Daniel : "retirer famille bug 404 tjr". Ces membres
          // appartiennent à MA famille (je suis titulaire) → RETIRABLES. Les
          // autres (familles où je suis juste membre) ne le sont pas → le
          // frontend ne montrera le bouton retirer que si removable=true.
          removable: true,
        });
      }
    }
    for (const sub of subsHostingMe) {
      // Le titulaire de cette sub est un de mes "family circle".
      const holderId = String(sub.userId);
      if (holderId !== String(user.id) && !byId.has(holderId)) {
        byId.set(holderId, {
          userId: holderId,
          userModel: sub.userModel,
          email: null,
          addedAt: sub.createdAt,
          status: 'active', // le titulaire est always actif
        });
      }
      // Et les autres membres (sauf moi).
      for (const m of (sub.familyMembers || [])) {
        const id = String(m.userId);
        if (id === String(user.id)) continue;
        if (byId.has(id)) continue;
        byId.set(id, {
          userId: id,
          userModel: m.userModel,
          email: m.email || null,
          addedAt: m.addedAt,
          status: m.status || 'active',
        });
      }
    }

    // hasActiveFamilyPlan = je suis titulaire d'une sub active OU je suis
    // membre actif d'une sub. C'est plus permissif que l'ancienne version.
    const hasActiveFamilyPlan = !!ownSub || subsHostingMe.length > 0;

    // v23.1.281 — Daniel : "je n'arrive pas à ajouter de membre famille" alors
    // que la carte affiche la famille. CAUSE : il est MEMBRE d'une famille (pas
    // titulaire) → l'app lui montrait l'UI titulaire ("Inviter un membre") qui
    // échoue forcément (seul le titulaire peut ajouter/retirer). On expose donc
    // isHolder + holder pour que l'app affiche le bon état (titulaire vs membre).
    const isHolder = !!ownSub;
    let holder = null;
    if (!isHolder && subsHostingMe.length > 0) {
      const hostSub = subsHostingMe[0];
      try {
        const hMini = await fetchUserMini(hostSub.userId, hostSub.userModel);
        holder = {
          id: String(hostSub.userId),
          role: String(hostSub.userModel || '').toLowerCase(),
          name: hMini?.name || '',
          avatar: hMini?.avatar || '',
        };
      } catch (_) {/* defensive */}
    }

    if (byId.size === 0) {
      return res.json({
        hasActiveFamilyPlan,
        isHolder,
        holder,
        members: [],
        remainingSlots: ownSub
          ? Math.max(0, 5 - (Array.isArray(ownSub.familyMembers) ? ownSub.familyMembers.length : 0))
          : 0,
      });
    }

    const raw = Array.from(byId.values());
    // v23.1.398 — Daniel : « mon frère a Paw Premium mais reste violet
    // famille, pas de couronne ». La couche carte doit savoir QUELS membres
    // sont Premium. On résout premiumExpiry pour chaque membre en UNE requête.
    const memberIds = raw.map((m) => m.userId);
    const premiumSet = new Set();
    try {
      const premSubs = await UserSubscription.find({
        userId: { $in: memberIds },
        premiumExpiry: { $gt: now },
      }).select('userId').lean();
      for (const s of premSubs) premiumSet.add(String(s.userId));
    } catch (_) {/* best-effort : pas de couronne plutôt qu'un 500 */}
    // Enrichit avec nom + avatar + role normalise via fetchUserMini.
    const enriched = await Promise.all(
      raw.map(async (m) => {
        const mini = await fetchUserMini(m.userId, m.userModel);
        return {
          id: String(m.userId),
          role: (m.userModel || '').toLowerCase(),
          name: mini?.name || '',
          avatar: mini?.avatar || '',
          addedAt: m.addedAt,
          email: m.email,
          status: m.status,
          // v23.1.336 — true seulement pour les membres de MA famille (je suis
          // titulaire). Le frontend masque le bouton retirer si false.
          removable: m.removable === true,
          // v23.1.280 — tier PawSpot actif du membre → anneau doré/bleu sur
          // l'avatar dans l'onglet Famille de l'app (parité _FriendTile).
          pawSpotTier: mini?.pawSpotTier || null,
          // v23.1.398 — Paw Premium actif → couronne 👑 + anneau OR sur la carte.
          isPremium: premiumSet.has(String(m.userId)),
          // v451 — email pour la résolution premium CROSS-RÔLE (cf ci-dessous).
          _email: (mini?.email || '').toLowerCase(),
          // v451 — Daniel : « la famille garde le profil supprimé ». mini==null
          // = compte supprimé → on marque pour l'exclure de la liste (auto-clean).
          _deleted: !mini,
        };
      }),
    );

    // v451 — Daniel : « mon frère est Paw Premium, lui se voit Premium mais moi
    // je le vois en promeneur ». RACINE multi-profil (1 compte = 3 docs rôle aux
    // _id différents) : la famille stocke l'id d'UN rôle (ex. promeneur) mais le
    // premiumExpiry du frère peut être sur un AUTRE doc rôle (ex. owner) →
    // premiumSet (par userId) le rate. On résout donc le premium AUSSI par EMAIL
    // sur les 3 collections de rôle (couvre les comptes frères même si la sync
    // inter-rôles n'a pas tourné).
    try {
      const emails = [...new Set(enriched.map((e) => e._email).filter(Boolean))];
      if (emails.length) {
        const idToEmail = new Map();
        for (const RM of [Owner, Sitter, Walker]) {
          // eslint-disable-next-line no-await-in-loop
          const docs = await RM.find({ email: { $in: emails } }).select('_id email').lean();
          for (const d of docs) idToEmail.set(String(d._id), (d.email || '').toLowerCase());
        }
        const sibIds = [...idToEmail.keys()];
        const premiumEmails = new Set();
        if (sibIds.length) {
          const sibSubs = await UserSubscription.find({
            userId: { $in: sibIds },
            premiumExpiry: { $gt: now },
          }).select('userId').lean();
          for (const s of sibSubs) {
            const em = idToEmail.get(String(s.userId));
            if (em) premiumEmails.add(em);
          }
        }
        for (const e of enriched) {
          if (!e.isPremium && e._email && premiumEmails.has(e._email)) e.isPremium = true;
        }
      }
    } catch (_) {/* best-effort */}
    for (const e of enriched) delete e._email;

    // v451 — exclut les membres dont le compte a été supprimé + purge ces
    // entrées des familyMembers (best-effort) pour qu'elles ne réapparaissent
    // jamais (« quand on supprime, tout disparaît »).
    const aliveMembers = enriched.filter((m) => !m._deleted);
    const deletedMemberIds = enriched.filter((m) => m._deleted).map((m) => m.id);
    if (deletedMemberIds.length) {
      try {
        await UserSubscription.updateMany(
          { 'familyMembers.userId': { $in: deletedMemberIds } },
          { $pull: { familyMembers: { userId: { $in: deletedMemberIds } } } },
        );
      } catch (_) {/* best-effort */}
    }
    for (const e of aliveMembers) delete e._deleted;

    // remainingSlots compte les actives de la sub que JE detiens.
    const ownActiveCount = ownSub
      ? (Array.isArray(ownSub.familyMembers) ? ownSub.familyMembers : [])
          .filter((m) => !m.status || m.status === 'active').length
      : 0;
    res.json({
      hasActiveFamilyPlan,
      isHolder,
      holder,
      members: aliveMembers,
      remainingSlots: ownSub ? Math.max(0, 5 - ownActiveCount) : 0,
    });
  } catch (e) {
    logger.error('[friends/family/members]', e);
    res.status(500).json({ error: e.message });
  }
});

/**
 * POST /friends/family/invite-member  body: { userId, userRole, email? }
 * Le titulaire d'une sub PawFollow Famille active ajoute jusqu'à 4 membres.
 * 403 si pas de sub famille active. 409 si déjà membre. 422 si limite atteinte.
 */
router.post('/family/invite-member', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const { userId, userRole, email } = req.body || {};
    if (!userId || !userRole) {
      return res
        .status(400)
        .json({ error: 'userId and userRole are required.' });
    }
    const targetModel = ROLE_TO_MODEL_NAME[String(userRole).toLowerCase()];
    if (!targetModel) {
      return res.status(400).json({ error: 'Invalid userRole.' });
    }
    const now = new Date();
    // v23.1.266 — résolution robuste + SELF-HEAL de la sub Famille : gère les
    // abonnements orphelins (rattachés à un ancien doc après un switchRole
    // antérieur au fix de migration) et les répare. Voir resolveOwnFamilySub.
    const sub = await resolveOwnFamilySub(user);
    if (!sub) {
      return res.status(403).json({
        error: 'Active PawFollow Famille subscription required.',
        code: 'FAMILY_PLAN_REQUIRED',
      });
    }
    sub.familyMembers = sub.familyMembers || [];
    // v23.1.179 — Daniel : "c 5 membres" (pas 4). Le plan PawFollow Famille
    // permet jusqu'à 5 membres en plus du titulaire (5 emplacements
    // d'invités, total 6 personnes dans la famille avec le titulaire).
    if (sub.familyMembers.length >= 5) {
      return res.status(422).json({
        error: 'Family is full (5 members max in addition to you).',
        code: 'FAMILY_FULL',
      });
    }
    if (sub.familyMembers.some((m) => String(m.userId) === String(userId))) {
      return res.status(409).json({ error: 'Already a family member.' });
    }
    // v23.1.183 — Daniel : "developpe le sous menu amis famislle pour
    // accepter refuse rbloquer les demande damis et famille". Status
    // 'pending' au lieu d'auto-add : le destinataire reçoit une notif
    // family_invitation_received et doit accepter ou refuser depuis la
    // cloche pour rejoindre la famille.
    sub.familyMembers.push({
      userId,
      userModel: targetModel,
      email: email || undefined,
      addedAt: now,
      status: 'pending',
    });
    await sub.save();

    // ID du sous-document qu'on vient d'ajouter (pour l'accept/refuse).
    const invitation = sub.familyMembers[sub.familyMembers.length - 1];
    const invitationId = String(invitation._id);

    // v23.1.183 — Notif au destinataire avec INVITATION (pas family_member_added).
    try {
      const { sendNotification } = require('../services/notificationSender');
      await sendNotification({
        userId,
        role: String(userRole).toLowerCase(),
        type: 'family_invitation_received',
        data: {
          invitationId,
          familyOwnerId: String(user.id),
          familyOwnerRole: String(user.model).toLowerCase(),
        },
      });
    } catch (_) {/* non-critical */}

    res.status(201).json({
      success: true,
      invitationId,
      status: 'pending',
      familyMembersCount: sub.familyMembers.length,
      remainingSlots: 5 - sub.familyMembers.length,
    });
  } catch (e) {
    logger.error('[friends/family/invite-member]', e);
    res.status(500).json({ error: e.message });
  }
});

/**
 * POST /friends/family/invite-by-email  body: { email }
 * v23.1.174 — Daniel : "Par email : si l'email existe dans Firestore → envoyer
 * demande in-app ; sinon → envoyer email d'invitation HoPetSit".
 *
 * 1. On cherche l'email dans Owner / Sitter / Walker
 * 2. Si trouvé → ajoute à family (même logique que invite-member)
 * 3. Sinon → envoie un email SendGrid avec lien d'inscription parrainage
 *    https://hopetsit.com/invite/family/{token} qui auto-accepte la demande
 *    famille après inscription.
 */
router.post('/family/invite-by-email', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const email = (req.body?.email || '').toString().trim().toLowerCase();
    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'Valid email required.' });
    }
    const now = new Date();
    // v23.1.266 — résolution robuste + SELF-HEAL de la sub Famille : gère les
    // abonnements orphelins (rattachés à un ancien doc après un switchRole
    // antérieur au fix de migration) et les répare. Voir resolveOwnFamilySub.
    const sub = await resolveOwnFamilySub(user);
    if (!sub) {
      return res.status(403).json({
        error: 'Active PawFollow Famille subscription required.',
        code: 'FAMILY_PLAN_REQUIRED',
      });
    }
    sub.familyMembers = sub.familyMembers || [];
    // v23.1.179 — max 5 membres invités (cohérence avec invite-member).
    if (sub.familyMembers.length >= 5) {
      return res.status(422).json({
        error: 'Family is full.',
        code: 'FAMILY_FULL',
      });
    }

    // 1. Cherche l'email dans les 3 collections.
    const [owner, sitter, walker] = await Promise.all([
      Owner.findOne({ email }).select('_id name').lean(),
      Sitter.findOne({ email }).select('_id name').lean(),
      Walker.findOne({ email }).select('_id name').lean(),
    ]);
    const existing = owner || sitter || walker;
    if (existing) {
      const targetModel = owner ? 'Owner' : sitter ? 'Sitter' : 'Walker';
      const targetId = String(existing._id);
      if (sub.familyMembers.some((m) => String(m.userId) === targetId)) {
        return res.status(409).json({ error: 'Already a family member.' });
      }
      sub.familyMembers.push({
        userId: targetId,
        userModel: targetModel,
        email,
        addedAt: now,
      });
      await sub.save();
      try {
        const { sendNotification } = require('../services/notificationSender');
        await sendNotification({
          userId: targetId,
          role: targetModel.toLowerCase(),
          type: 'family_member_added',
          title: 'family_member_added_title',
          body: 'family_member_added_body',
          data: { addedBy: String(user.id) },
        });
      } catch (_) {/* non-critical */}
      return res.status(201).json({
        success: true,
        mode: 'existing_user',
        familyMembersCount: sub.familyMembers.length,
        remainingSlots: 5 - sub.familyMembers.length,
      });
    }

    // 2. User pas trouvé → on envoie un email d'invitation parrainage.
    // L'invité reçoit un lien https://hopetsit.com/invite/family/<token>
    // qui après inscription auto-accepte la demande famille.
    try {
      const emailService = require('../services/emailService');
      const inviteUrl =
        `${process.env.WEBSITE_URL || 'https://hopetsit.com'}` +
        `/invite/family/${encodeURIComponent(email)}?from=${user.id}`;
      // emailService.sendFamilyInvite est defensif : si pas dispo, on stocke
      // juste l'email dans family pending pour retry plus tard.
      if (typeof emailService.sendFamilyInvite === 'function') {
        await emailService.sendFamilyInvite({
          to: email,
          inviterName: (await me(req)).id, // sera enrichi côté service
          inviteUrl,
        });
      }
    } catch (e) {
      logger.warn('[friends/family/invite-by-email] email send failed', e);
    }

    // On track quand même l'invite envoyée (sans la réserver dans family
    // tant qu'elle n'est pas créée). Daniel peut suivre depuis un futur
    // écran "Invitations envoyées".
    return res.status(202).json({
      success: true,
      mode: 'email_invite_sent',
      email,
    });
  } catch (e) {
    logger.error('[friends/family/invite-by-email]', e);
    res.status(500).json({ error: e.message });
  }
});

/** DELETE /friends/family/member/:userId — titulaire retire un membre. */
router.delete('/family/member/:userId', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const targetId = req.params.userId;
    // v23.1.279 — Daniel : "je n'arrive pas à enlever un membre de famille".
    // CAUSE RACINE : ce DELETE était CASE-SENSITIVE sur userModel + exigeait
    // userId = user.id EXACT (aucun self-heal) → si la sub titulaire est
    // rattachée à un ancien doc de rôle, retrait raté en 404.
    // v23.1.281 — on UNIFIE avec resolveOwnFamilySub (même résolveur robuste
    // que l'ajout : oldId + docs même email + balayage email-titulaire). Ainsi
    // ajout ET retrait trouvent toujours la même sub titulaire.
    // v23.1.334 — Daniel : "retirer famille bug tjr" (404 Member not in family).
    // CAUSE RACINE : la LISTE affichée (GET /family/members) agrège les membres
    // de PLUSIEURS subs (celle que je détiens via resolveOwnFamilySub + d'autres
    // re-pointées / sur un autre de mes rôles). Mais le DELETE n'agissait que sur
    // resolveOwnFamilySub → si le membre était dans une AUTRE sub que je détiens,
    // 404 "Member not in family". FIX : on rassemble TOUTES mes identités de
    // titulaire (id + oldId + docs même email owner/sitter/walker) et on retire
    // le membre de TOUTE sub Famille que JE détiens qui le contient.
    const UserSubscription = require('../models/UserSubscription');
    const myHolderIds = new Set([String(user.id)]);
    let myEmail = null;
    try {
      const Model = MODEL_BY_NAME[user.model];
      const meDoc = Model
        ? await Model.findById(user.id).select('email oldId').lean()
        : null;
      if (meDoc && meDoc.oldId) myHolderIds.add(String(meDoc.oldId));
      if (meDoc && meDoc.email) {
        myEmail = String(meDoc.email).toLowerCase();
        const [owners, sitters, walkers] = await Promise.all([
          Owner.find({ email: meDoc.email }).select('_id oldId').lean(),
          Sitter.find({ email: meDoc.email }).select('_id oldId').lean(),
          Walker.find({ email: meDoc.email }).select('_id oldId').lean(),
        ]);
        for (const d of [...owners, ...sitters, ...walkers]) {
          myHolderIds.add(String(d._id));
          if (d.oldId) myHolderIds.add(String(d.oldId));
        }
      }
    } catch (e) {
      logger.warn('[family/member DELETE] holder-id resolution failed', e.message);
    }

    // v23.1.335 — Daniel : "tjr 404". CAUSE FINE : la sub Famille peut être
    // rattachée à un holder dont l'ID n'est PAS dans mes identités (doc de rôle
    // supprimé après switchRole / chaîne oldId cassée) → le filtre par ID seul
    // la ratait. On garde donc les subs contenant le membre dont le TITULAIRE a
    // mon email (même logique que resolveOwnFamilySub email-recovery).
    const subsWithMember = await UserSubscription.find({
      'familyMembers.userId': targetId,
    });
    const subs = [];
    for (const sub of subsWithMember) {
      if (myHolderIds.has(String(sub.userId))) { subs.push(sub); continue; }
      if (myEmail) {
        try {
          const HolderModel = MODEL_BY_NAME[sub.userModel]
            || MODEL_BY_NAME[ROLE_TO_MODEL_NAME[String(sub.userModel).toLowerCase()]];
          const holderDoc = HolderModel
            ? await HolderModel.findById(sub.userId).select('email').lean()
            : null;
          if (holderDoc && holderDoc.email
              && String(holderDoc.email).toLowerCase() === myEmail) {
            subs.push(sub);
          }
        } catch (_) {/* defensive */}
      }
    }
    if (!subs.length) {
      return res.status(404).json({ error: 'Member not in family.' });
    }
    let removed = 0;
    let lastSub = null;
    for (const sub of subs) {
      const before = (sub.familyMembers || []).length;
      sub.familyMembers = (sub.familyMembers || []).filter(
        (m) => String(m.userId) !== String(targetId),
      );
      if (sub.familyMembers.length !== before) {
        await sub.save();
        removed += before - sub.familyMembers.length;
        lastSub = sub;
      }
    }
    if (removed === 0 || !lastSub) {
      return res.status(404).json({ error: 'Member not in family.' });
    }
    logger.info(
      `[family/member DELETE] ${user.model}:${user.id} retiré ${targetId} `
      + `de ${subs.length} sub(s) détenue(s)`,
    );
    res.json({
      success: true,
      familyMembersCount: (lastSub.familyMembers || []).length,
      remainingSlots: 5 - (lastSub.familyMembers || []).length,
    });
  } catch (e) {
    logger.error('[friends/family/member DELETE]', e);
    res.status(500).json({ error: e.message });
  }
});

/**
 * POST /friends/family/leave — un MEMBRE quitte la/les famille(s) dont il fait
 * partie (se retire lui-même des familyMembers du/des titulaire(s)).
 *
 * v23.1.282 — Daniel : "j'ai l'abonnement famille et c'est bloqué, impossible
 * d'ajouter/enlever". CAUSE : dadaciao84 est MEMBRE de la famille d'un autre
 * compte → il ne peut pas gérer de famille tant qu'il est membre. On lui donne
 * une sortie : quitter la famille. Ensuite il est libre d'être son propre
 * titulaire (acheter PawFamily) ou d'être réinvité ailleurs.
 */
router.post('/family/leave', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const now = new Date();
    // Toutes les subs Famille actives où je figure comme membre.
    const subs = await UserSubscription.find({
      'familyMembers.userId': user.id,
      ...familyActiveMatch(now),
    });
    let removed = 0;
    for (const sub of subs) {
      const before = (sub.familyMembers || []).length;
      sub.familyMembers = (sub.familyMembers || []).filter(
        (m) => String(m.userId) !== String(user.id),
      );
      if (sub.familyMembers.length !== before) {
        removed += before - sub.familyMembers.length;
        await sub.save();
      }
    }
    if (removed === 0) {
      return res
        .status(404)
        .json({ error: 'Not a member of any family.', code: 'NOT_A_MEMBER' });
    }
    res.json({ success: true, leftFamilies: subs.length });
  } catch (e) {
    logger.error('[friends/family/leave]', e);
    res.status(500).json({ error: e.message });
  }
});

/**
 * v23.1.185 — Daniel mockup : nouvel onglet "Animaux" dans Famille &
 * Amis qui liste les pets de mes amis acceptes + membres famille
 * actifs. Permet de les contacter / suivre en un tap.
 *
 * GET /friends/pets
 * Renvoie { pets: [{ id, petName, breed, avatar, ownerId, ownerRole,
 * ownerName }] }.
 */
router.get('/pets', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    // 1) Collecte les userIds de mes amis acceptes + membres famille active.
    const friends = await Friendship.find({
      $or: [
        { requesterId: user.id, requesterModel: user.model, status: 'accepted' },
        { addresseeId: user.id, addresseeModel: user.model, status: 'accepted' },
      ],
    }).lean();
    const friendIds = new Set();
    for (const f of friends) {
      const otherId = String(f.requesterId) === String(user.id)
        ? f.addresseeId : f.requesterId;
      friendIds.add(String(otherId));
    }
    // Famille : titulaire ou membre actif.
    const now = new Date();
    const ownSub = await UserSubscription.findOne({
      userId: user.id,
      ...familyActiveMatch(now),
    }).lean();
    if (ownSub && Array.isArray(ownSub.familyMembers)) {
      for (const m of ownSub.familyMembers) {
        if (!m.status || m.status === 'active') friendIds.add(String(m.userId));
      }
    }
    const subsHostingMe = await UserSubscription.find({
      'familyMembers.userId': user.id,
      ...familyActiveMatch(now),
    }).lean();
    for (const sub of subsHostingMe) {
      friendIds.add(String(sub.userId));
      for (const m of (sub.familyMembers || [])) {
        if ((!m.status || m.status === 'active')
            && String(m.userId) !== String(user.id)) {
          friendIds.add(String(m.userId));
        }
      }
    }
    if (friendIds.size === 0) {
      return res.json({ pets: [] });
    }
    // 2) Resolve owner mini + fetch pets. Seuls les Owner ont des pets.
    const Owner = require('../models/Owner');
    const Pet = require('../models/Pet');
    const ownerIds = Array.from(friendIds);
    const owners = await Owner.find({ _id: { $in: ownerIds } })
      .select('name avatar')
      .lean();
    const ownerById = {};
    for (const o of owners) ownerById[String(o._id)] = o;
    const pets = await Pet.find({ ownerId: { $in: ownerIds } })
      .select('petName breed avatar ownerId photos')
      .lean();
    const enriched = pets.map((p) => {
      const owner = ownerById[String(p.ownerId)] || {};
      return {
        id: String(p._id),
        petName: p.petName || '',
        breed: p.breed || '',
        avatar: p.avatar?.url || (Array.isArray(p.photos) && p.photos[0]?.url) || '',
        ownerId: String(p.ownerId),
        ownerRole: 'owner',
        ownerName: owner.name || '',
      };
    });
    res.json({ pets: enriched });
  } catch (e) {
    logger.error('[friends/pets]', e);
    res.status(500).json({ error: e.message });
  }
});

/**
 * v23.1.183 — Daniel : "developpe le sous menu amis famislle pour
 * accepter refuse rbloquer les demande damis et famille".
 *
 * GET /friends/family/invitations
 * Liste les invitations famille EN ATTENTE adressées au user courant.
 * Cherche dans toutes les UserSubscription famille actives où
 * familyMembers contient { userId: moi, status: 'pending' }.
 */
router.get('/family/invitations', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const now = new Date();
    const subs = await UserSubscription.find({
      'familyMembers.userId': user.id,
      'familyMembers.status': 'pending',
      ...familyActiveMatch(now),
    }).lean();

    const invitations = [];
    for (const sub of subs) {
      const member = (sub.familyMembers || []).find(
        (m) => String(m.userId) === String(user.id) && m.status === 'pending',
      );
      if (!member) continue;
      // Récupère le nom du titulaire pour l'afficher dans la cloche.
      const ownerModel = require('../models/' + sub.userModel);
      const ownerDoc = await ownerModel
        .findById(sub.userId)
        .select('name avatar')
        .lean()
        .catch(() => null);
      invitations.push({
        id: String(member._id),
        invitationId: String(member._id),
        familyOwnerId: String(sub.userId),
        familyOwnerRole: String(sub.userModel).toLowerCase(),
        familyOwnerName: ownerDoc?.name || '',
        familyOwnerAvatar: ownerDoc?.avatar?.url || '',
        addedAt: member.addedAt,
      });
    }
    res.json({ invitations });
  } catch (e) {
    logger.error('[friends/family/invitations GET]', e);
    res.status(500).json({ error: e.message });
  }
});

/**
 * v23.1.183 — POST /friends/family/invitation/:id/accept
 * Le destinataire d'une invitation pending la transforme en active.
 */
router.post('/family/invitation/:id/accept', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const invitationId = req.params.id;
    const sub = await UserSubscription.findOne({
      // v23.1.283 — l'invitation est identifiée par son _id (n'existe que sur
      // une sub famille) ; plus de filtre plan:'famille' (famille découplée).
      'familyMembers._id': invitationId,
      'familyMembers.userId': user.id,
      status: 'active',
    });
    if (!sub) {
      return res.status(404).json({ error: 'Invitation not found.' });
    }
    const member = (sub.familyMembers || []).id(invitationId);
    if (!member) {
      return res.status(404).json({ error: 'Invitation not found.' });
    }
    if (String(member.userId) !== String(user.id)) {
      return res.status(403).json({ error: 'Not your invitation.' });
    }
    if (member.status !== 'pending') {
      return res.status(409).json({
        error: 'Invitation already responded to.',
        currentStatus: member.status,
      });
    }
    member.status = 'active';
    member.respondedAt = new Date();
    await sub.save();

    // Notif au titulaire pour l'informer.
    try {
      const { sendNotification } = require('../services/notificationSender');
      await sendNotification({
        userId: String(sub.userId),
        role: String(sub.userModel).toLowerCase(),
        type: 'family_invitation_accepted',
        data: {
          memberUserId: String(user.id),
          memberRole: String(user.model).toLowerCase(),
        },
      });
    } catch (_) {/* non-critical */}

    res.json({ success: true, status: 'active' });
  } catch (e) {
    logger.error('[friends/family/invitation accept]', e);
    res.status(500).json({ error: e.message });
  }
});

/**
 * v23.1.183 — POST /friends/family/invitation/:id/refuse
 * Le destinataire refuse l'invitation, on retire le sous-doc.
 */
router.post('/family/invitation/:id/refuse', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const invitationId = req.params.id;
    const sub = await UserSubscription.findOne({
      // v23.1.283 — famille découplée : plus de filtre plan:'famille'.
      'familyMembers._id': invitationId,
      'familyMembers.userId': user.id,
    });
    if (!sub) {
      return res.status(404).json({ error: 'Invitation not found.' });
    }
    const member = (sub.familyMembers || []).id(invitationId);
    if (!member) {
      return res.status(404).json({ error: 'Invitation not found.' });
    }
    if (String(member.userId) !== String(user.id)) {
      return res.status(403).json({ error: 'Not your invitation.' });
    }
    if (member.status !== 'pending') {
      return res.status(409).json({
        error: 'Invitation already responded to.',
        currentStatus: member.status,
      });
    }
    // Retire complètement le sous-document.
    sub.familyMembers = (sub.familyMembers || []).filter(
      (m) => String(m._id) !== String(invitationId),
    );
    await sub.save();

    // Notif au titulaire pour l'informer.
    try {
      const { sendNotification } = require('../services/notificationSender');
      await sendNotification({
        userId: String(sub.userId),
        role: String(sub.userModel).toLowerCase(),
        type: 'family_invitation_refused',
        data: {
          memberUserId: String(user.id),
          memberRole: String(user.model).toLowerCase(),
        },
      });
    } catch (_) {/* non-critical */}

    res.json({ success: true, status: 'refused' });
  } catch (e) {
    logger.error('[friends/family/invitation refuse]', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
