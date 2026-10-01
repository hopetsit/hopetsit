'use strict';

/**
 * 606 (ZOE, 01/10/2026) — refus Apple 1.25/605, guideline 3.1.1 :
 * « the app uses promo codes to unlock access ».
 *
 * Sur iOS, aucun code MAISON ne doit débloquer quoi que ce soit : seuls les
 * « offer codes » d'Apple (StoreKit) sont permis. L'app ≥ 606 n'affiche plus
 * aucune entrée de code maison sur iOS ; le serveur refuse en plus, proprement,
 * les routes de code maison quand la requête vient d'une app iOS ≥ 606
 * (en-têtes `X-App-Platform: ios` + `X-App-Version: 23.1.x+606`).
 * Anciennes apps iOS (< 606 ou sans en-tête), Android et site : inchangés.
 */
const IOS_NO_HOUSE_CODES_MIN_BUILD = 606;

function buildFromVersionHeader(raw) {
  const v = String(raw || '').trim();
  const plus = v.match(/\+(\d{1,6})$/);
  if (plus) return Number(plus[1]);
  return null;
}

function isIosStoreClient606(req) {
  const h = (name) => String((req && req.headers && req.headers[name]) || '').trim().toLowerCase();
  if (h('x-app-platform') !== 'ios') return false;
  const build = buildFromVersionHeader(h('x-app-version'));
  return build !== null && build >= IOS_NO_HOUSE_CODES_MIN_BUILD;
}

const IOS_CODES_MESSAGE = {
  fr: "Sur iPhone et iPad, les codes s'utilisent uniquement via l'App Store.",
  en: 'On iPhone and iPad, codes can only be redeemed through the App Store.',
};

/** Middleware : 403 IOS_APP_STORE_CODES_ONLY pour une app iOS ≥ 606. */
function refuseHouseCodesOnIos606(req, res, next) {
  if (!isIosStoreClient606(req)) return next();
  const lang = String(req.headers['accept-language'] || '').slice(0, 2).toLowerCase();
  return res.status(403).json({
    error: IOS_CODES_MESSAGE[lang] || IOS_CODES_MESSAGE.en,
    code: 'IOS_APP_STORE_CODES_ONLY',
  });
}

module.exports = {
  IOS_NO_HOUSE_CODES_MIN_BUILD,
  buildFromVersionHeader,
  isIosStoreClient606,
  refuseHouseCodesOnIos606,
};
