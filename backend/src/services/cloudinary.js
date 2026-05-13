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
  const result = await cloudinary.uploader.upload(file, {
    folder,
    resource_type: resourceType,
    image_metadata: false,
    quality_analysis: false,
    transformation: [{ flags: 'strip_profile' }],
    ...options,
  });

  return {
    url: result.secure_url,
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
};

