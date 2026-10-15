/**
 * 616 (FLO, 15/10/2026, demande Daniel du 10/10) — mandat de facturation.
 *
 * Les CGU contiennent le mandat par lequel CARDELLI HERMANOS LIMITED établit
 * les documents de prestation AU NOM du prestataire. Pour qu'il tienne
 * juridiquement, le prestataire l'accepte EXPLICITEMENT (case cochée) au
 * premier retrait : date + version enregistrées sur son compte
 * (`billingMandateAcceptedAt`, `billingMandateVersion`), rappelées dans l'admin
 * et sur chaque document de prestation.
 *
 * Version des CGU : LUE dans le code de l'app (`frontend/lib/data/static/
 * terms_of_service.dart`, constante `termsVersion` tenue par ZOE), jamais
 * recopiée à la main ici. Si le dépôt déployé ne contient pas le dossier
 * `frontend/` (serveur seul), on prend `TERMS_VERSION` de l'environnement,
 * puis le repli ci-dessous (dernière version connue au moment du build 616).
 *
 * Compatibilité (règle BOB, 15/10) : les apps ≤ 615 n'ont pas la case → leur
 * retrait N'EST PAS bloqué ; seul un client qui annonce un build ≥ 616 dans
 * `X-App-Version` (« 23.1.586+616 ») est refusé tant que le mandat n'est pas
 * accepté. Le site (« web ») et un client sans en-tête ne sont pas bloqués.
 */
const fs = require('fs');
const path = require('path');

/** Premier build de l'app qui affiche la case du mandat. */
const BILLING_MANDATE_MIN_BUILD = 616;

const FALLBACK_TERMS_VERSION = '2.4';
const TERMS_DART = path.resolve(__dirname, '../../../frontend/lib/data/static/terms_of_service.dart');

function readTermsVersionFromCode() {
  try {
    const src = fs.readFileSync(TERMS_DART, 'utf8');
    const m = src.match(/const\s+String\s+termsVersion\s*=\s*'(\d+\.\d+)'/);
    if (m) return m[1];
  } catch (_) { /* dossier frontend absent du déploiement serveur */ }
  const env = String(process.env.TERMS_VERSION || '').trim().replace(/^v/i, '');
  if (/^\d+\.\d+$/.test(env)) return env;
  return FALLBACK_TERMS_VERSION;
}

const BILLING_MANDATE_VERSION = readTermsVersionFromCode();

const isBillingMandateAccepted = (doc) => !!(doc && doc.billingMandateAcceptedAt);

/** « 23.1.586+616 » → 616 ; « web », vide ou absent → null. */
function appBuildOf(req) {
  const v = String((req && req.headers && req.headers['x-app-version']) || '').trim();
  const m = v.match(/\+(\d{1,6})$/);
  return m ? Number(m[1]) : null;
}

/**
 * Le retrait doit-il être refusé faute de mandat ? Oui seulement si le mandat
 * n'est pas accepté ET que le client est une app ≥ 616 (elle sait afficher la
 * case). Une app ≤ 615, le site ou un client inconnu passent : rien n'empêche
 * un vrai prestataire d'être payé aujourd'hui.
 */
function withdrawalBlockedByMandate(req, doc) {
  if (isBillingMandateAccepted(doc)) return false;
  const build = appBuildOf(req);
  return build != null && build >= BILLING_MANDATE_MIN_BUILD;
}

/** Champs renvoyés à l'app / à l'admin (jamais le document entier). */
const billingMandateView = (doc) => ({
  billingMandateAcceptedAt: doc?.billingMandateAcceptedAt || null,
  billingMandateVersion: doc?.billingMandateVersion || '',
  billingMandateCurrentVersion: BILLING_MANDATE_VERSION,
});

module.exports = {
  BILLING_MANDATE_VERSION,
  BILLING_MANDATE_MIN_BUILD,
  TERMS_DART,
  readTermsVersionFromCode,
  appBuildOf,
  isBillingMandateAccepted,
  withdrawalBlockedByMandate,
  billingMandateView,
};
