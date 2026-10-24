/**
 * 24/10/2026 (BOB, mail Firebase transmis par Daniel : 73 plantages / 3 utilisateurs en 618,
 * « NetworkImage — HTTP request failed ») — l'ancien cloud Cloudinary `ddllooujo` est coupé depuis le
 * 18/10 (toutes ses images répondent 401) ; 178 références y pointaient encore le 24/10 (144 avatars de
 * comptes, 17 avatars d'animaux, photos d'animaux). L'app charge ces images, reçoit 401 et plante.
 * Ici : on EFFACE ces références (les photos sont perdues, voir mémoire hopetsit_cloudinary_compte) :
 * l'app affiche la silhouette par défaut, plus d'erreur. Idempotent, non bloquant, UNE fois (marqueur).
 */
const DEAD = /\/ddllooujo\//;

async function purgeDeadCloudinary({ Owner, Sitter, Walker, Pet }) {
  const out = { accounts: 0, petAvatars: 0, petPhotos: 0 };
  for (const M of [Owner, Sitter, Walker].filter(Boolean)) {
    const r = await M.updateMany({ 'avatar.url': DEAD }, { $set: { 'avatar.url': '', 'avatar.publicId': '' } });
    out.accounts += r.modifiedCount || 0;
  }
  if (Pet) {
    const r1 = await Pet.updateMany({ 'avatar.url': DEAD }, { $set: { 'avatar.url': '', 'avatar.publicId': '' } });
    out.petAvatars = r1.modifiedCount || 0;
    const r2 = await Pet.updateMany({ 'photos.url': DEAD }, { $pull: { photos: { url: DEAD } } });
    out.petPhotos = r2.modifiedCount || 0;
  }
  return out;
}

module.exports = { purgeDeadCloudinary, DEAD };
