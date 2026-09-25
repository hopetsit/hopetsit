// v586 (point 9 de Daniel, 25/09/2026) — « Demandes en cours » sur la fiche
// d'un PROPRIÉTAIRE vue par un gardien / promeneur connecté.
//
// GET /posts/requests/by-owner/:ownerId — LECTURE SEULE.
//   · demandes ACTIVES seulement : annonce de type `request`, non masquée,
//     non fermée, non déjà réservée, période non passée ;
//   · du propriétaire ET de ses autres profils (1 personne = jusqu'à 3
//     documents reliés par l'e-mail, `identityGroup`) ;
//   · jamais d'adresse exacte, ni coordonnées, ni e-mail / téléphone : la ville
//     seule, et une distance ARRONDIE au km quand le spectateur envoie sa
//     position (lat / lng) ;
//   · compte de test / staff / masqué par la modération → liste vide ;
//   · ses propres annonces → liste vide (le serveur refuse de toute façon une
//     candidature sur sa propre annonce : 403 OWN_POST) ;
//   · `myApplication` : statut de MA candidature sur l'annonce (pending /
//     accepted / rejected) pour afficher « déjà envoyée » / « refusée ».
const mongoose = require('mongoose');
const logger = require('../utils/logger');
const { identityGroup, selfIdSet } = require('../utils/identityGroup');
const { isTestOrStaff } = require('../utils/mapVisibility');
const searchRadius = require('../utils/searchRadius');

const MAX_POSTS = 10;

/** Période encore à venir (ou en cours) : fin, sinon début, sinon création < 60 j. */
function isStillActive(post, now = new Date()) {
  const end = post.endDate ? new Date(post.endDate) : null;
  const start = post.startDate ? new Date(post.startDate) : null;
  const ref = end && !Number.isNaN(end.getTime()) ? end : start;
  if (ref && !Number.isNaN(ref.getTime())) {
    // Tolérance d'un jour : une demande « aujourd'hui » reste visible.
    return ref.getTime() >= now.getTime() - 24 * 3600 * 1000;
  }
  return true;
}

const getOwnerActiveRequests = async (req, res) => {
  try {
    const { ownerId } = req.params;
    const role = String(req.user?.role || '').toLowerCase();
    if (role !== 'sitter' && role !== 'walker') {
      return res.status(403).json({ error: 'Only sitters and walkers can read these requests.' });
    }
    if (!mongoose.Types.ObjectId.isValid(String(ownerId || ''))) {
      return res.status(400).json({ error: 'Invalid owner id.' });
    }

    const Owner = require('../models/Owner');
    const Post = require('../models/Post');
    const Pet = require('../models/Pet');
    const Application = require('../models/Application');

    // Moi-même (un de mes 3 profils) → rien.
    const mine = await selfIdSet(req);
    if (mine.has(String(ownerId))) {
      return res.json({ posts: [], count: 0 });
    }

    const group = await identityGroup(ownerId);
    const ownerIds = group.docs.filter((d) => d.model === 'Owner').map((d) => d.id);
    if (!ownerIds.length) return res.json({ posts: [], count: 0 });

    const owners = await Owner.find({ _id: { $in: ownerIds } })
      .select('_id name email isStaff hiddenFromPublic currency')
      .lean();
    const publicOwners = owners.filter((o) => !isTestOrStaff(o));
    if (!publicOwners.length) return res.json({ posts: [], count: 0 });
    const ownerById = new Map(publicOwners.map((o) => [String(o._id), o]));

    const raw = await Post.find({
      ownerId: { $in: [...ownerById.keys()] },
      postType: 'request',
      hidden: { $ne: true },
      status: { $ne: 'closed' },
    })
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();

    const now = new Date();
    const active = raw
      .filter((p) => !(p.reservedBy && p.reservedBy.bookingId))
      .filter((p) => isStillActive(p, now))
      .slice(0, MAX_POSTS);

    // Filtre de service du spectateur (même règle que la carte) : un
    // promeneur ne voit que les promenades, un gardien jamais les promenades.
    const services = (p) => (Array.isArray(p.serviceTypes) ? p.serviceTypes : []);
    const visible = active.filter((p) => (role === 'walker'
      ? services(p).includes('dog_walking')
      : !services(p).includes('dog_walking') || services(p).length > 1));

    const petIdsOf = (p) => (Array.isArray(p.petIds) && p.petIds.length
      ? p.petIds.map((x) => String(x && x._id ? x._id : x))
      : (p.petId ? [String(p.petId)] : []));
    const allPetIds = [...new Set(visible.flatMap(petIdsOf))]
      .filter((id) => mongoose.Types.ObjectId.isValid(id));
    const pets = allPetIds.length
      ? await Pet.find({ _id: { $in: allPetIds } }).select('_id petName category').lean()
      : [];
    const petById = new Map(pets.map((p) => [String(p._id), p]));

    const providerField = role === 'walker' ? 'walkerId' : 'sitterId';
    const apps = visible.length
      ? await Application.find({
        [providerField]: req.user.id,
        postId: { $in: visible.map((p) => p._id) },
      })
        .select('postId status createdAt')
        .sort({ createdAt: -1 })
        .lean()
      : [];
    const appByPost = new Map();
    for (const a of apps) {
      const k = String(a.postId);
      if (!appByPost.has(k)) appByPost.set(k, a.status);
    }

    const vLat = parseFloat(req.query.lat);
    const vLng = parseFloat(req.query.lng);
    const hasViewer = Number.isFinite(vLat) && Number.isFinite(vLng) && !(vLat === 0 && vLng === 0);

    const posts = visible.map((p) => {
      const lat = Number(p.location?.lat);
      const lng = Number(p.location?.lng);
      let distanceKm = null;
      if (hasViewer && Number.isFinite(lat) && Number.isFinite(lng) && !(lat === 0 && lng === 0)) {
        // Arrondi au km : jamais une distance qui trahirait l'adresse.
        distanceKm = Math.max(1, Math.round(searchRadius.haversineKm(vLat, vLng, lat, lng)));
      }
      const ids = petIdsOf(p);
      const owner = ownerById.get(String(p.ownerId));
      return {
        id: String(p._id),
        ownerId: String(p.ownerId),
        serviceTypes: services(p),
        serviceLocation: p.serviceLocation || '',
        startDate: p.startDate || null,
        endDate: p.endDate || null,
        walkDurationMinutes: typeof p.walkDurationMinutes === 'number' ? p.walkDurationMinutes : null,
        city: String(p.location?.city || '').trim(),
        distanceKm,
        budget: Number(p.budget) > 0 ? Number(p.budget) : 0,
        currency: String(owner?.currency || 'EUR'),
        petIds: ids,
        pets: ids.map((id) => petById.get(id)).filter(Boolean)
          .map((pet) => ({ id: String(pet._id), name: pet.petName || '', category: pet.category || '' })),
        myApplication: appByPost.get(String(p._id)) || null,
        createdAt: p.createdAt || null,
      };
    });

    return res.json({ posts, count: posts.length });
  } catch (error) {
    logger.error('[posts/requests/by-owner] Error', error);
    return res.status(500).json({ error: 'Unable to fetch requests.' });
  }
};

module.exports = { getOwnerActiveRequests, isStillActive };
