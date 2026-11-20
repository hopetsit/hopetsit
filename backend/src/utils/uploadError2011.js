// 20/11/2026 (BOB) — une photo trop lourde n'est pas une panne du serveur.
// Avant : multer levait « File too large », le gestionnaire global répondait
// 500 « Internal server error » et Sentry envoyait une alerte (cas réel du
// 20/11 : photo de profil > 10 Mo à l'inscription d'une propriétaire).
// Maintenant : réponse claire 413 (ou 400), dans la langue de la personne,
// et pas d'alerte Sentry. Fonction pure, sans dépendance, pour être testée seule.

const MESSAGES = {
  LIMIT_FILE_SIZE: {
    status: 413,
    code: 'FILE_TOO_LARGE',
    fr: 'Cette photo est trop lourde. Choisissez une image plus légère et réessayez.',
    en: 'This photo is too large. Please choose a smaller image and try again.',
  },
  LIMIT_FILE_COUNT: {
    status: 400,
    code: 'TOO_MANY_FILES',
    fr: 'Trop de fichiers envoyés en une fois.',
    en: 'Too many files sent at once.',
  },
  LIMIT_UNEXPECTED_FILE: {
    status: 400,
    code: 'UNEXPECTED_FILE',
    fr: 'Ce fichier ne peut pas être envoyé ici.',
    en: 'This file cannot be uploaded here.',
  },
};

function isUploadError(err) {
  return !!err && err.name === 'MulterError' && typeof err.code === 'string';
}

function pickLang(acceptLanguage) {
  return /^\s*fr\b/i.test(String(acceptLanguage || '')) ? 'fr' : 'en';
}

/**
 * @returns {null | { status: number, body: { error: string, code: string } }}
 * null = ce n'est pas une erreur d'envoi de fichier, le gestionnaire global continue comme avant.
 */
function uploadErrorResponse(err, acceptLanguage) {
  if (!isUploadError(err)) return null;
  const lang = pickLang(acceptLanguage);
  const m = MESSAGES[err.code];
  if (!m) {
    return {
      status: 400,
      body: {
        error: lang === 'fr' ? 'Ce fichier n\'a pas pu être envoyé.' : 'This file could not be uploaded.',
        code: 'UPLOAD_REJECTED',
      },
    };
  }
  return { status: m.status, body: { error: m[lang], code: m.code } };
}

module.exports = { uploadErrorResponse, isUploadError, pickLang };
