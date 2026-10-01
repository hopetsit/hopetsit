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
// 607 (ZOE, 01/10/2026) — décision de Daniel : les codes de PARRAINAGE suivent
// la même règle (ils débloquent -10 % sur PawFollow/PawFamily pour le parrain).
// Refusés pour l'app iOS ≥ 607 seulement ; les 606 et plus anciennes gardent
// leur comportement (elles affichent encore le champ).
const IOS_NO_REFERRAL_CODES_MIN_BUILD = 607;

function buildFromVersionHeader(raw) {
  const v = String(raw || '').trim();
  const plus = v.match(/\+(\d{1,6})$/);
  if (plus) return Number(plus[1]);
  return null;
}

function isIosClientAtLeast(req, minBuild) {
  const h = (name) => String((req && req.headers && req.headers[name]) || '').trim().toLowerCase();
  if (h('x-app-platform') !== 'ios') return false;
  const build = buildFromVersionHeader(h('x-app-version'));
  return build !== null && build >= minBuild;
}

function isIosStoreClient606(req) {
  return isIosClientAtLeast(req, IOS_NO_HOUSE_CODES_MIN_BUILD);
}

/** 607 — app iOS qui ne doit plus utiliser de code de parrainage. */
function isIosNoReferralClient607(req) {
  return isIosClientAtLeast(req, IOS_NO_REFERRAL_CODES_MIN_BUILD);
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

/** 607 : même refus propre pour le parrainage (GET /users/me/referrals). */
function refuseReferralCodesOnIos607(req, res, next) {
  if (!isIosNoReferralClient607(req)) return next();
  const lang = String(req.headers['accept-language'] || '').slice(0, 2).toLowerCase();
  return res.status(403).json({
    error: IOS_CODES_MESSAGE[lang] || IOS_CODES_MESSAGE.en,
    code: 'IOS_APP_STORE_CODES_ONLY',
  });
}

module.exports = {
  IOS_NO_HOUSE_CODES_MIN_BUILD,
  IOS_NO_REFERRAL_CODES_MIN_BUILD,
  isIosNoReferralClient607,
  refuseReferralCodesOnIos607,
  buildFromVersionHeader,
  isIosStoreClient606,
  refuseHouseCodesOnIos606,
};
