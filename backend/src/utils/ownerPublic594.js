/**
 * v594 — Daniel (26/09) : « ma grande page de profil est vide ». La page
 * propriétaire ouverte depuis la PawMap ne recevait que nom + photo et ne
 * chargeait rien. Profil PUBLIC d'un propriétaire : nom, photo, bio, ville,
 * membre depuis, animaux (fiche publique, sans passeport ni vétérinaire).
 * Jamais d'e-mail, de téléphone ni d'adresse.
 */
const mongoose = require('mongoose');

const avatarUrl = (a) => (a && (typeof a === 'object' ? a.url : a)) || '';

function publicPet(pet) {
  return {
    id: String(pet._id),
    petName: pet.petName || '',
    avatar: avatarUrl(pet.avatar),
    photos: Array.isArray(pet.photos)
      ? pet.photos.map((p) => ({ url: p.url || '', publicId: p.publicId || '', uploadedAt: p.uploadedAt || null }))
      : [],
    category: pet.category || '',
    characterTraits: Array.isArray(pet.characterTraits) ? pet.characterTraits : [],
    breed: pet.breed || '',
    bio: pet.bio || '',
    weight: pet.weight || '',
    height: pet.height || '',
    age: typeof pet.age === 'number' ? pet.age : null,
    sex: pet.gender || '',
    compatibilities: {
      withDogs: pet.compatibilities?.withDogs || '',
      withCats: pet.compatibilities?.withCats || '',
      withChildren: pet.compatibilities?.withChildren || '',
      withNac: pet.compatibilities?.withNac || '',
    },
    vaccinationStatus: pet.vaccinationStatus || '',
    sterilized: pet.sterilized === true,
    microchipped: pet.microchipped === true,
  };
}

/** Profil public du propriétaire [id] ; un id d'un AUTRE rôle de la même
 *  personne est accepté (la carte peut porter l'id du gardien). null si absent
 *  ou bloqué. */
async function ownerPublicProfile(id) {
  const Owner = require('../models/Owner');
  const Pet = require('../models/Pet');
  const sid = String(id || '');
  if (!mongoose.Types.ObjectId.isValid(sid)) return null;
  const sel = 'name avatar profilePicture bio city location.city createdAt status';
  let o = await Owner.findById(sid).select(sel).lean();
  if (!o) {
    const { identityGroup } = require('./identityGroup');
    const g = await identityGroup(sid);
    const doc = (g.docs || []).find((d) => d.model === 'Owner');
    if (doc) o = await Owner.findById(doc.id).select(sel).lean();
  }
  if (!o || ['banned', 'suspended', 'deleted'].includes(o.status)) return null;
  const pets = await Pet.find({ ownerId: o._id }).sort({ createdAt: -1 }).limit(20).lean();
  return {
    id: String(o._id),
    name: o.name || '',
    avatar: avatarUrl(o.avatar) || avatarUrl(o.profilePicture),
    bio: (o.bio || '').trim(),
    city: (o.city || (o.location && o.location.city) || '').trim(),
    createdAt: o.createdAt || null,
    pets: pets.map(publicPet),
  };
}

module.exports = { ownerPublicProfile, publicPet };
