/**
 * v503 — Apple In-App Purchase (StoreKit 2) : vérification + crédit.
 *
 * Contrat (cf Downloads/HoPetSit_Backend_Apple_IAP_Etape_B_v503.pdf) :
 *  - L'app iOS (build 23.1.503) envoie après chaque achat/restauration :
 *      POST /apple-iap/validate { productId, transactionId,
 *        originalTransactionId: null, jws, source }
 *  - Le `jws` est le token SIGNÉ PAR APPLE (serverVerificationData StoreKit 2).
 *    On le vérifie LOCALEMENT (Option A du plan) avec la lib officielle
 *    @apple/app-store-server-library (chaîne x5c → racines Apple embarquées
 *    dans backend/certs/apple/*.cer). Zéro appel réseau, zéro clé .p8 requise.
 *  - environment Sandbox ET Production acceptés (indispensable pour la
 *    review Apple qui achète en sandbox sur le build de prod).
 *  - Crédit : on RÉUTILISE purchaseActivationController (même logique que le
 *    webhook Airwallex, provider 'apple_iap', idempotent sur transactionId).
 *
 * ⚠️ bundle iOS = com.cardellihermanos.hopetsit (renommé sur le Mac, PAS
 * com.hopetsit.app) — un mauvais bundleId ferait échouer TOUTES les
 * validations.
 */

const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

const APPLE_BUNDLE_ID =
  process.env.APPLE_BUNDLE_ID || 'com.cardellihermanos.hopetsit';
// App Store ID numérique de l'app (App Store Connect) — requis par la lib
// pour vérifier les NOTIFICATIONS en Production.
const APPLE_APP_APPLE_ID = Number(process.env.APPLE_APP_APPLE_ID || 6763645719);

// ── Mapping Product ID → crédit (source : PDF étape B, tableau §3) ──────────
// kind 'subscription' → activateSubscriptionFromWebhook (plan + intervalDays)
// kind 'pawspot'      → activatePawSpotFromWebhook (days)
// kind 'boost'        → activateBoostFromWebhook (tier + days)
const PRODUCT_MAP = {
  hopetsit_pawfollow_monthly: { kind: 'subscription', plan: 'monthly', intervalDays: 30 },
  hopetsit_pawfollow_yearly: { kind: 'subscription', plan: 'yearly', intervalDays: 365 },
  hopetsit_pawfamily_monthly: { kind: 'subscription', plan: 'family', intervalDays: 30 },
  hopetsit_pawfamily_yearly: { kind: 'subscription', plan: 'family_yearly', intervalDays: 365 },
  hopetsit_pawspot_monthly: { kind: 'pawspot', days: 30 },
  hopetsit_pawspot_yearly: { kind: 'pawspot', days: 365 },
  hopetsit_pawpremium_monthly: { kind: 'subscription', plan: 'premium_monthly', intervalDays: 30 },
  hopetsit_pawpremium_yearly: { kind: 'subscription', plan: 'premium_yearly', intervalDays: 365 },
  // Tiers réels de l'app : bronze 3 j / silver 7 j / platinum 30 j
  // (gold 15 j masqué sur iOS — pas de produit Apple).
  hopetsit_pawboost_t1: { kind: 'boost', tier: 'bronze', days: 3 },
  hopetsit_pawboost_t2: { kind: 'boost', tier: 'silver', days: 7 },
  hopetsit_pawboost_t3: { kind: 'boost', tier: 'platinum', days: 30 },
};

// ── Vérificateurs Apple (Production + Sandbox), construits paresseusement ───
let _verifiers = null;

function _loadAppleRootCerts() {
  const dir = path.join(__dirname, '..', '..', 'certs', 'apple');
  const certs = [];
  try {
    for (const f of fs.readdirSync(dir)) {
      if (f.toLowerCase().endsWith('.cer')) {
        certs.push(fs.readFileSync(path.join(dir, f)));
      }
    }
  } catch (e) {
    logger.error(`[appleIap] certs Apple introuvables dans ${dir} : ${e.message}`);
  }
  return certs;
}

function _getVerifiers() {
  if (_verifiers) return _verifiers;
  const { SignedDataVerifier, Environment } = require('@apple/app-store-server-library');
  const certs = _loadAppleRootCerts();
  if (!certs.length) {
    throw new Error('Aucun certificat racine Apple (backend/certs/apple/*.cer)');
  }
  const enableOnlineChecks = false; // pas d'OCSP réseau
  _verifiers = {
    production: new SignedDataVerifier(
      certs, enableOnlineChecks, Environment.PRODUCTION, APPLE_BUNDLE_ID, APPLE_APP_APPLE_ID,
    ),
    sandbox: new SignedDataVerifier(
      certs, enableOnlineChecks, Environment.SANDBOX, APPLE_BUNDLE_ID, APPLE_APP_APPLE_ID,
    ),
  };
  return _verifiers;
}

/**
 * Vérifie + décode un JWS de transaction StoreKit 2 (Production PUIS Sandbox).
 * @returns {Promise<{payload: object, environment: 'Production'|'Sandbox'}>}
 * @throws si la signature/le bundle/l'environnement ne collent pas.
 */
async function verifySignedTransaction(jws) {
  const v = _getVerifiers();
  try {
    const payload = await v.production.verifyAndDecodeTransaction(jws);
    return { payload, environment: 'Production' };
  } catch (prodErr) {
    try {
      const payload = await v.sandbox.verifyAndDecodeTransaction(jws);
      return { payload, environment: 'Sandbox' };
    } catch (sbErr) {
      logger.warn(
        `[appleIap] JWS invalide (prod: ${prodErr?.message} / sandbox: ${sbErr?.message})`,
      );
      throw new Error('Transaction Apple invalide (signature/bundle/environnement).');
    }
  }
}

/**
 * Vérifie + décode un signedPayload de notification V2 (Production PUIS Sandbox).
 */
async function verifySignedNotification(signedPayload) {
  const v = _getVerifiers();
  try {
    return await v.production.verifyAndDecodeNotification(signedPayload);
  } catch (_) {
    return v.sandbox.verifyAndDecodeNotification(signedPayload);
  }
}

/**
 * Crédite l'utilisateur pour une transaction Apple VÉRIFIÉE.
 * Réutilise purchaseActivationController (provider 'apple_iap', idempotent).
 * @param {{userId: string, role: string, productId: string,
 *          transactionId: string, originalTransactionId: string}} p
 */
async function creditForTransaction({ userId, role, productId, transactionId, originalTransactionId }) {
  const mapping = PRODUCT_MAP[productId];
  if (!mapping) throw new Error(`productId Apple inconnu : ${productId}`);

  const {
    activateSubscriptionFromWebhook,
    activateBoostFromWebhook,
    activatePawSpotFromWebhook,
  } = require('../controllers/purchaseActivationController');

  let result;
  if (mapping.kind === 'subscription') {
    result = await activateSubscriptionFromWebhook({
      piId: transactionId,
      metadata: {
        userId,
        role,
        plan: mapping.plan,
        intervalDays: mapping.intervalDays,
        currency: 'EUR',
        provider: 'apple_iap',
      },
    });
  } else if (mapping.kind === 'pawspot') {
    result = await activatePawSpotFromWebhook({
      piId: transactionId,
      metadata: { userId, role, days: mapping.days, provider: 'apple_iap' },
    });
  } else {
    result = await activateBoostFromWebhook({
      piId: transactionId,
      metadata: {
        userId,
        role,
        tier: mapping.tier,
        days: mapping.days,
        currency: 'EUR',
        provider: 'apple_iap',
      },
    });
  }

  // Lien webhook : mémorise l'originalTransactionId sur la sub du rôle
  // (abonnements/pawspot — les boosts consommables ne se renouvellent pas).
  if (originalTransactionId && mapping.kind !== 'boost') {
    try {
      const UserSubscription = require('../models/UserSubscription');
      const userModel = role === 'walker' ? 'Walker' : role === 'sitter' ? 'Sitter' : 'Owner';
      await UserSubscription.updateOne(
        { userId, userModel },
        { $set: { appleOriginalTransactionId: String(originalTransactionId) } },
      );
    } catch (e) {
      logger.warn(`[appleIap] set appleOriginalTransactionId failed : ${e.message}`);
    }
  }

  return result;
}

/**
 * Webhook App Store Server Notifications V2 : renouvellements, remboursements…
 * Retrouve l'abonné via appleOriginalTransactionId (posé au 1er achat).
 */
async function handleNotification(signedPayload) {
  const notif = await verifySignedNotification(signedPayload);
  const type = notif?.notificationType || '';
  const subtype = notif?.subtype || '';

  // Décode la transaction jointe (si présente) pour productId + ids.
  let tx = null;
  const signedTx = notif?.data?.signedTransactionInfo;
  if (signedTx) {
    try {
      tx = (await verifySignedTransaction(signedTx)).payload;
    } catch (e) {
      logger.warn(`[appleIap][webhook] signedTransactionInfo invalide : ${e.message}`);
    }
  }
  const originalTransactionId = String(
    tx?.originalTransactionId || notif?.data?.originalTransactionId || '',
  );
  const productId = tx?.productId || '';

  logger.info(
    `[appleIap][webhook] ${type}${subtype ? `/${subtype}` : ''} product=${productId} otid=${originalTransactionId}`,
  );
  if (!originalTransactionId) return { handled: false, reason: 'no originalTransactionId' };

  const UserSubscription = require('../models/UserSubscription');
  const sub = await UserSubscription.findOne({
    appleOriginalTransactionId: originalTransactionId,
  });
  if (!sub) {
    logger.warn(`[appleIap][webhook] aucun abonné pour otid=${originalTransactionId}`);
    return { handled: false, reason: 'subscriber not found' };
  }
  const role = String(sub.userModel || 'Owner').toLowerCase();

  const RENEW_TYPES = ['DID_RENEW', 'SUBSCRIBED', 'DID_CHANGE_RENEWAL_STATUS', 'OFFER_REDEEMED'];
  const REVOKE_TYPES = ['EXPIRED', 'REFUND', 'REVOKE', 'GRACE_PERIOD_EXPIRED'];

  if (RENEW_TYPES.includes(type) && tx && PRODUCT_MAP[productId]) {
    // DID_CHANGE_RENEWAL_STATUS sans nouvelle transaction facturée = no-op
    // (le crédit est idempotent sur transactionId de toute façon).
    if (type === 'DID_CHANGE_RENEWAL_STATUS') return { handled: true, noop: true };
    await creditForTransaction({
      userId: String(sub.userId),
      role,
      productId,
      transactionId: String(tx.transactionId),
      originalTransactionId,
    });
    return { handled: true, credited: true };
  }

  if (REVOKE_TYPES.includes(type)) {
    // Coupe le timer correspondant au produit (ou tous si produit inconnu).
    const now = new Date();
    const mapping = PRODUCT_MAP[productId];
    const kind = mapping?.kind;
    const plan = mapping?.plan || '';
    if (kind === 'pawspot') {
      sub.pawspotExpiry = now;
    } else if (plan === 'family' || plan === 'family_yearly') {
      sub.familyExpiry = now;
    } else if (plan.startsWith('premium')) {
      sub.premiumExpiry = now;
      sub.currentPeriodEnd = now;
      sub.pawspotExpiry = now;
    } else if (kind === 'subscription') {
      sub.currentPeriodEnd = now;
    } else {
      // Produit inconnu dans la notification → prudence : individuel only.
      sub.currentPeriodEnd = now;
    }
    await sub.save();
    logger.info(`[appleIap][webhook] ${type} → timers coupés (${sub.userModel} ${sub.userId})`);
    return { handled: true, revoked: true };
  }

  return { handled: true, ignoredType: type };
}

module.exports = {
  PRODUCT_MAP,
  verifySignedTransaction,
  verifySignedNotification,
  creditForTransaction,
  handleNotification,
};
