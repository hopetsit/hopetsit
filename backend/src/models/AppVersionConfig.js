const mongoose = require('mongoose');

/**
 * v561 — Daniel : « que l'app se mette à jour seule sur iOS et Android ».
 *
 * Singleton (`key: 'singleton'`) qui pilote la mise à jour dans l'app :
 *   - android.latest  : dernier versionCode publié sur Google Play
 *   - android.minimum : en dessous → mise à jour IMMÉDIATE (écran bloquant,
 *                        API Play In-App Updates) ; entre minimum et latest →
 *                        mise à jour SOUPLE (téléchargée en arrière-plan,
 *                        installée au prochain redémarrage)
 *   - ios.latest / ios.minimum : idem avec le build number ; iOS ne permet
 *     pas d'installer depuis l'app → bandeau « Nouvelle version » avec bouton
 *     App Store (bloquant sous le minimum)
 *   - url : fiche store (utilisée par le bouton)
 * Modifiable dans l'admin (page Tarifs → « Versions de l'app »).
 */
const PlatformSchema = new mongoose.Schema(
  {
    latest: { type: Number, default: 0 },
    minimum: { type: Number, default: 0 },
    url: { type: String, default: '' },
    message: { type: String, default: '' },
  },
  { _id: false },
);

const AppVersionConfigSchema = new mongoose.Schema(
  {
    key: { type: String, default: 'singleton', unique: true },
    android: { type: PlatformSchema, default: () => ({}) },
    ios: { type: PlatformSchema, default: () => ({}) },
  },
  { timestamps: true },
);

AppVersionConfigSchema.statics.getSingleton = async function getSingleton() {
  let doc = await this.findOne({ key: 'singleton' });
  if (!doc) {
    doc = await this.create({
      key: 'singleton',
      android: {
        latest: 0,
        minimum: 0,
        url: 'https://play.google.com/store/apps/details?id=com.cardellihermanos.hopetsit',
      },
      ios: { latest: 0, minimum: 0, url: 'https://apps.apple.com/app/id6763645719' },
    });
  }
  return doc;
};

module.exports = mongoose.model('AppVersionConfig', AppVersionConfigSchema);
