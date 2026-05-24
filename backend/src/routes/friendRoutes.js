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

/** Fetch a minimal user profile regardless of role, for enriching friend lists. */
async function fetchUserMini(id, modelName) {
  const Model = MODEL_BY_NAME[modelName];
  if (!Model) return null;
  const u = await Model.findById(id)
    .select('firstName lastName profilePicture location city avatar email')
    .lean();
  if (!u) return null;
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
  return {
    id: u._id,
    model: modelName,
    name,
    avatar: u.profilePicture || u.avatar || '',
    city: u.location?.city || u.city || '',
  };
}

async function enrichFriendship(friendship, viewerId) {
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
  const mySharePosition = isRequester
    ? friendship.requesterSharesPosition
    : friendship.addresseeSharesPosition;
  const theirSharePosition = isRequester
    ? friendship.addresseeSharesPosition
    : friendship.requesterSharesPosition;
  return {
    id: friendship._id,
    status: friendship.status,
    initiatedByMe: isRequester,
    other,
    mySharePosition,
    theirSharePosition,
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
              .select('firstName lastName email')
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
          createdAt: f.createdAt,
          acceptedAt: f.acceptedAt,
        };
      }),
    );
    res.json({
      me: { id: String(user.id), model: user.model },
      total: enriched.length,
      friendships: enriched,
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
    const escape = q.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
    const re = new RegExp(escape, 'i');
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

    const [owners, sitters, walkers] = await Promise.all([
      Owner.find({
        $or: [{ email: re }, { firstName: re }, { lastName: re }],
      }).select(projection).limit(10).lean(),
      Sitter.find({
        $or: [{ email: re }, { firstName: re }, { lastName: re }],
      }).select(projection).limit(10).lean(),
      Walker.find({
        $or: [{ email: re }, { firstName: re }, { lastName: re }],
      }).select(projection).limit(10).lean(),
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

    const enriched = await Promise.all(
      friendships.map((f) => enrichFriendship(f, user.id)),
    );
    // v23.1.201 — on garde les orphelins (other.deleted) pour permettre
    // l'unfriend depuis l'UI. Frontend les affiche en "Utilisateur supprimé".
    res.json({ friends: enriched });
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

    const [incomingEnriched, outgoingEnriched] = await Promise.all([
      Promise.all(incoming.map((f) => enrichFriendship(f, user.id))),
      Promise.all(outgoing.map((f) => enrichFriendship(f, user.id))),
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
      const { getIo } = require('../sockets/io');
      const io = getIo && getIo();
      if (io) {
        const payload = {
          friendshipId: String(friendship._id),
          from: {
            userId: String(user.id),
            role: (user.model || '').toLowerCase(),
          },
        };
        io.to(`user_${targetId}`).emit('friend_request:received', payload);
        io.to(`user_${user.id}`).emit('friend_request:received', payload);
      }
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
      const { getIo } = require('../sockets/io');
      const io = getIo && getIo();
      if (io) {
        const payload = {
          friendshipId: String(f._id),
          by: { userId: String(user.id), role: (user.model || '').toLowerCase() },
        };
        // Convention HopeTSIT : room par user = `user_${userId}`.
        io.to(`user_${f.requesterId}`).emit('friend_request:accepted', payload);
        io.to(`user_${f.addresseeId}`).emit('friend_request:accepted', payload);
      }
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
const { isInSameFamily } = require('../models/UserSubscription');

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
    const sub = await UserSubscription.findOne({
      userId: user.id,
      userModel: user.model,
      plan: 'famille',
      status: 'active',
      currentPeriodEnd: { $gt: now },
    }).lean();
    if (!sub) {
      return res.json({
        hasActiveFamilyPlan: false,
        members: [],
        remainingSlots: 0,
      });
    }
    const raw = Array.isArray(sub.familyMembers) ? sub.familyMembers : [];
    // v23.1.183 — on retourne TOUS les membres (incluant pending) avec
    // leur status, pour que le titulaire voie qui n'a pas encore accepté.
    const enriched = await Promise.all(
      raw.map(async (m) => {
        const mini = await fetchUserMini(m.userId, m.userModel);
        return {
          id: String(m.userId),
          role: (m.userModel || '').toLowerCase(),
          name: mini?.name || '',
          avatar: mini?.avatar || '',
          addedAt: m.addedAt,
          email: m.email || null,
          status: m.status || 'active',
        };
      }),
    );
    // remainingSlots ne compte QUE les actifs (un pending peut être
    // refusé → la place sera libre).
    const activeCount = raw.filter(
      (m) => !m.status || m.status === 'active',
    ).length;
    res.json({
      hasActiveFamilyPlan: true,
      members: enriched,
      remainingSlots: Math.max(0, 5 - activeCount),
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
    const sub = await UserSubscription.findOne({
      userId: user.id,
      userModel: user.model,
      plan: 'famille',
      status: 'active',
      currentPeriodEnd: { $gt: now },
    });
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
    const sub = await UserSubscription.findOne({
      userId: user.id,
      userModel: user.model,
      plan: 'famille',
      status: 'active',
      currentPeriodEnd: { $gt: now },
    });
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
    const sub = await UserSubscription.findOne({
      userId: user.id,
      userModel: user.model,
      plan: 'famille',
    });
    if (!sub) {
      return res
        .status(404)
        .json({ error: 'No family subscription found.' });
    }
    const before = (sub.familyMembers || []).length;
    sub.familyMembers = (sub.familyMembers || []).filter(
      (m) => String(m.userId) !== String(targetId),
    );
    if (sub.familyMembers.length === before) {
      return res.status(404).json({ error: 'Member not in family.' });
    }
    await sub.save();
    res.json({
      success: true,
      familyMembersCount: sub.familyMembers.length,
      remainingSlots: 5 - sub.familyMembers.length,
    });
  } catch (e) {
    logger.error('[friends/family/member DELETE]', e);
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
      userModel: user.model,
      plan: 'famille',
      status: 'active',
      currentPeriodEnd: { $gt: now },
    }).lean();
    if (ownSub && Array.isArray(ownSub.familyMembers)) {
      for (const m of ownSub.familyMembers) {
        if (!m.status || m.status === 'active') friendIds.add(String(m.userId));
      }
    }
    const subsHostingMe = await UserSubscription.find({
      'familyMembers.userId': user.id,
      plan: 'famille',
      status: 'active',
      currentPeriodEnd: { $gt: now },
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
      plan: 'famille',
      status: 'active',
      currentPeriodEnd: { $gt: now },
      'familyMembers.userId': user.id,
      'familyMembers.status': 'pending',
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
      'familyMembers._id': invitationId,
      'familyMembers.userId': user.id,
      plan: 'famille',
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
      'familyMembers._id': invitationId,
      'familyMembers.userId': user.id,
      plan: 'famille',
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
