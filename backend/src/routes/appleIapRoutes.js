/**
 * v503 — Routes Apple In-App Purchase (StoreKit 2).
 *
 * POST /apple-iap/validate (requireAuth) — appelé par l'app iOS build 503
 * après chaque achat/restauration. Contrat exact :
 * Downloads/HoPetSit_Backend_Apple_IAP_Etape_B_v503.pdf.
 *
 * Réponse succès : { ok: true, ... } (l'app accepte aussi success/activated).
 * Toute autre réponse → l'app affiche une erreur et NE crédite PAS.
 *
 * Le webhook App Store Server Notifications V2 est monté directement dans
 * app.js (POST /webhooks/apple-iap, public, comme le webhook Airwallex).
 */

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();

router.post('/validate', requireAuth, async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = String(req.user?.role || 'owner').toLowerCase();
    const { productId, jws, source } = req.body || {};

    if (!userId) {
      return res.status(401).json({ ok: false, error: 'Authentification requise.' });
    }
    if (!productId || !jws) {
      return res.status(400).json({ ok: false, error: 'productId et jws sont requis.' });
    }

    const {
      PRODUCT_MAP,
      verifySignedTransaction,
      creditForTransaction,
    } = require('../services/appleIapService');

    if (!PRODUCT_MAP[productId]) {
      return res.status(400).json({ ok: false, error: `productId inconnu : ${productId}` });
    }

    // 1. Vérifie le token signé Apple (signature x5c + bundleId + environnement
    //    Production OU Sandbox — indispensable pour la review Apple).
    let payload;
    let environment;
    try {
      ({ payload, environment } = await verifySignedTransaction(String(jws)));
    } catch (e) {
      logger.warn(`[apple-iap/validate] JWS refusé user=${role}:${userId} : ${e.message}`);
      return res.status(400).json({ ok: false, error: 'Transaction Apple invalide.' });
    }

    // 2. Cohérence : le productId du body doit être celui du token signé.
    //    ⚠️ On ignore transactionId/originalTransactionId du BODY (l'app envoie
    //    originalTransactionId=null) : la seule source de vérité = le JWS.
    if (String(payload.productId) !== String(productId)) {
      logger.warn(
        `[apple-iap/validate] productId body (${productId}) ≠ JWS (${payload.productId})`,
      );
      return res.status(400).json({ ok: false, error: 'productId incohérent avec la transaction.' });
    }

    const transactionId = String(payload.transactionId);
    const originalTransactionId = String(
      payload.originalTransactionId || payload.transactionId,
    );

    // 3. Crédit (idempotent sur transactionId — une restauration ou un double
    //    POST répond ok:true sans re-créditer).
    const result = await creditForTransaction({
      userId,
      role,
      productId,
      transactionId,
      originalTransactionId,
    });

    logger.info(
      `[apple-iap/validate] OK ${role}:${userId} ${productId} tx=${transactionId} env=${environment} source=${source || 'purchase'} ${result?.alreadyActivated || result?.deduplicated ? '(déjà crédité)' : ''}`,
    );

    return res.json({
      ok: true,
      success: true,
      activated: true,
      alreadyActivated: !!(result?.alreadyActivated || result?.deduplicated),
      environment,
      productId,
      transactionId,
    });
  } catch (e) {
    logger.error('[apple-iap/validate] erreur', e);
    return res.status(500).json({ ok: false, error: 'Validation Apple impossible. Réessayez.' });
  }
});

module.exports = router;
