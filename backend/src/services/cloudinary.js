const cloudinary = require('cloudinary').v2;

const {
  CLOUDINARY_CLOUD_NAME,
  CLOUDINARY_API_KEY,
  CLOUDINARY_API_SECRET,
} = process.env;

if (CLOUDINARY_CLOUD_NAME && CLOUDINARY_API_KEY && CLOUDINARY_API_SECRET) {
  cloudinary.config({
    cloud_name: CLOUDINARY_CLOUD_NAME,
    api_key: CLOUDINARY_API_KEY,
    api_secret: CLOUDINARY_API_SECRET,
  });
}

const ensureConfig = () => {
  if (!CLOUDINARY_CLOUD_NAME || !CLOUDINARY_API_KEY || !CLOUDINARY_API_SECRET) {
    throw new Error('Cloudinary environment variables are not configured.');
  }
};

const MAX_UPLOAD_PX = 2000;   // côté le plus long, à l'envoi
const MAX_DELIVERY_PX = 1600; // côté le plus long, à l'affichage

/**
 * Adresse de livraison d'une image : largeur plafonnée, qualité et format
 * automatiques (WebP/AVIF selon le navigateur ou le téléphone). Pour un
 * avatar de 56 px affiché sur une carte, ça divise le poids par 5 à 20.
 * Les vidéos et tout autre type sont rendus tels quels.
 */
const deliveryUrl = (result) => {
  if (!result || result.resource_type !== 'image' || !result.public_id) return (result && result.secure_url) || '';
  return cloudinary.url(result.public_id, {
    secure: true,
    resource_type: 'image',
    version: result.version,
    format: result.format || undefined,
    transformation: [{ width: MAX_DELIVERY_PX, height: MAX_DELIVERY_PX, crop: 'limit', quality: 'auto', fetch_format: 'auto' }],
  });
};

const buildThumbnailUrl = (result) => {
  if (result.resource_type === 'video') {
    return cloudinary.url(result.public_id, {
      resource_type: 'video',
      format: 'jpg',
      transformation: [{ width: 400, height: 400, crop: 'fill', gravity: 'auto' }],
    });
  }
  return result.secure_url;
};

const uploadMedia = async ({ file, folder = 'petsinsta', resourceType = 'auto', options = {} } = {}) => {
  ensureConfig();
  if (!file) {
    throw new Error('File payload is required for upload.');
  }
  // v23.1 part 127 — Phase 3 audit P3-5 : strip systématique de l'EXIF
  // sur tous les uploads. Sans ça, une photo de profil owner uploadée
  // depuis un téléphone perso embarque les coords GPS du domicile dans
  // ses métadonnées, et la photo est ensuite servie publiquement via le
  // CDN Cloudinary → leak RGPD + sécurité.
  //   - image_metadata: false   → l'API n'attache PAS les métadonnées
  //   - quality_analysis: false → idem
  //   - transformation `flags: 'strip_profile'` → strip ICC + EXIF + XMP
  //     sur le fichier servi (et stocké)
  // 619 (BOB, 19/10) — l'ancien compte Cloudinary a été coupé (quota du forfait
  // gratuit) : les photos étaient stockées ET servies en taille d'origine
  // (jusqu'à 4 032 px, plusieurs Mo). Désormais : image plafonnée à 2 000 px à
  // l'envoi (le stockage compte dans le quota), et adresse de livraison
  // allégée (voir deliveryUrl). Les vidéos ne changent pas.
  const result = await cloudinary.uploader.upload(file, {
    folder,
    resource_type: resourceType,
    image_metadata: false,
    quality_analysis: false,
    transformation: resourceType === 'video'
      ? [{ flags: 'strip_profile' }]
      : [{ width: MAX_UPLOAD_PX, height: MAX_UPLOAD_PX, crop: 'limit' }, { flags: 'strip_profile' }],
    ...options,
  });

  return {
    url: deliveryUrl(result),
    originalUrl: result.secure_url,
    publicId: result.public_id,
    resourceType: result.resource_type,
    format: result.format || '',
    bytes: result.bytes ?? null,
    width: result.width ?? null,
    height: result.height ?? null,
    duration: result.duration ?? null,
    createdAt: result.created_at,
    thumbnailUrl: buildThumbnailUrl(result),
    originalFilename: result.original_filename || '',
  };
};

module.exports = {
  uploadMedia,
  deliveryUrl,
  MAX_UPLOAD_PX,
  MAX_DELIVERY_PX,
};

