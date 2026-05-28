/**
 * KYC Controller
 * v23.1 part 36 — flow KYC payant pour sitter/walker.
 *
 * Endpoints :
 *   POST /kyc/initiate-payment  → crée Airwallex PI 3 EUR pour KYC
 *   POST /kyc/start             → après paiement, crée inquiry Persona + retourne URL hosted
 *   GET  /kyc/status            → retourne kycStatus de l'utilisateur courant
 *   POST /webhooks/persona      → reçoit inquiry.completed/approved/declined
 *   POST /webhooks/airwallex/kyc → reçoit kyc payment success (déclenche la suite du flow)
 *
 * Workflow :
 *   1. User (sitter/walker) tape "Vérifier mon identité" → POST /kyc/initiate-payment
 *      → backend crée Airwallex PI tagged metadata.type='kyc'
 *      → User paie via HPP webview Airwallex
 *   2. Webhook Airwallex (existant) détecte metadata.type='kyc' → marque
 *      User.kycStatus='pending_verification' + User.kycPaidAt + crée inquiry Persona
 *      + sauvegarde User.kycApplicantId (via /kyc/start endpoint async)
 *   3. Frontend appelle GET /kyc/status puis POST /kyc/start si pending_verification
 *      → backend retourne URL hosted Persona
 *      → frontend ouvre WebView Persona
 *   4. User scan ID + selfie sur Persona → Persona traite
 *   5. Webhook /webhooks/persona reçoit inquiry.completed → backend met
 *      User.kycStatus='verified' (si approved) ou 'rejected' (si declined)
 *      + envoie notification au user
 */
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const airwallex = require('../services/airwallexService');
const persona = require('../services/personaService');
const logger = require('../utils/logger');

const KYC_PRICE_EUR = 3; // 3 EUR fixed price

const _modelForRole = (role) => {
  if (role === 'sitter') return Sitter;
  if (role === 'walker') return Walker;
  return null;
};

/**
 * POST /kyc/initiate-payment
 * Body: {} (auth required, role sitter/walker)
 * Returns: { paymentIntent: { id, client_secret }, amount, currency }
 */
const initiatePayment = async (req, res) => {
  try {
    if (!req.user?.id) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    const role = (req.user.role || '').toLowerCase();
    const Model = _modelForRole(role);
    if (!Model) {
      return res.status(403).json({ error: 'Only sitter or walker can verify identity.' });
    }
    // v23.1 part 66 — Daniel : "verification identite ne marche pas".
    // Surface a clear error if the Persona env vars are missing so the
    // frontend doesn't fall through to a generic 500. Operators just need
    // to set PERSONA_API_KEY (live or sandbox) + PERSONA_TEMPLATE_ID on
    // Render for live mode.
    if (!process.env.PERSONA_API_KEY || !process.env.PERSONA_TEMPLATE_ID) {
      logger.error(
        '[kyc.initiatePayment] PERSONA env vars missing — KYC disabled until configured.',
      );
      return res.status(503).json({
        error: 'Identity verification is temporarily unavailable. Please try again later.',
        code: 'KYC_NOT_CONFIGURED',
      });
    }
    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found.' });

    // v23.1 part 127 — Phase 3 audit P3-10 : si le doc a un GeoJSON
    // pourri (`location.coordinates = []`, `[null,null]`, etc.), on
    // l'unset proprement AVANT toute autre opération. Sinon les save()
    // ultérieurs (boost, profile update) re-lèveront "Can't extract geo
    // keys" à chaque action.
    const _coords = user.location?.coordinates;
    const _isBroken =
      user.location &&
      (!Array.isArray(_coords) ||
        _coords.length !== 2 ||
        typeof _coords[0] !== 'number' ||
        typeof _coords[1] !== 'number' ||
        !Number.isFinite(_coords[0]) ||
        !Number.isFinite(_coords[1]));
    if (_isBroken) {
      logger.warn(
        `[kyc.initiatePayment] sanitizing broken location for ${role} ${user._id} : ${JSON.stringify(user.location)}`,
      );
      await Model.updateOne({ _id: user._id }, { $unset: { location: '' } });
      user.location = undefined;
    }

    // Idempotence : si déjà vérifié ou en cours, on ne paie pas une 2e fois.
    if (user.kycStatus === 'verified') {
      return res.status(400).json({ error: 'Already verified.', kycStatus: 'verified' });
    }
    if (user.kycStatus === 'pending_verification' && user.kycPaidAt) {
      return res.status(400).json({
        error: 'Payment already done. Use /kyc/start to launch verification.',
        kycStatus: 'pending_verification',
      });
    }

    // v23.1 part 84 — pay-with-wallet shortcut for KYC (3€). Walker/sitter
    // only (already gated above). Skip Airwallex PI entirely : debit
    // wallet + flip kycStatus to pending_verification.
    const payWithWallet = req.body?.payWithWallet === true;
    if (payWithWallet) {
      try {
        const { payFromWallet } = require('../services/walletService');
        await payFromWallet({
          userId: user._id.toString(),
          userRole: role,
          amount: KYC_PRICE_EUR,
          currency: 'EUR',
          type: 'debit_purchase',
          reference: 'kyc',
          meta: { kind: 'kyc' },
        });
        // Same activation as the webhook would do.
        // v23.1 part 127 — Phase 3 audit P3-10 : Daniel "Can't extract
        // geo keys" 500. Cause : user.save() revalide TOUT le doc, et si
        // `location.coordinates` est malformé (null, [], [null,null]),
        // l'index 2dsphere lève cette erreur. On update juste les champs
        // KYC en bypass de la revalidation Mongoose.
        const now = new Date();
        const piIdWallet = `wallet_${Date.now()}`;
        await Model.updateOne(
          { _id: user._id },
          {
            $set: {
              kycStatus: 'pending_verification',
              kycPaidAt: now,
              kycPaymentIntentId: piIdWallet,
            },
          },
        );
        user.kycStatus = 'pending_verification';
        user.kycPaidAt = now;
        user.kycPaymentIntentId = piIdWallet;
        return res.status(201).json({
          paidFromWallet: true,
          kycStatus: user.kycStatus,
          kycPaidAt: user.kycPaidAt,
          amount: KYC_PRICE_EUR,
          currency: 'EUR',
        });
      } catch (e) {
        if (e.code === 'INSUFFICIENT_BALANCE') {
          return res.status(402).json({ error: 'Solde wallet insuffisant.', code: 'INSUFFICIENT_BALANCE' });
        }
        logger.error('[kyc.initiatePayment] payWithWallet failed', e);
        return res.status(500).json({ error: e.message });
      }
    }

    // v23.1 part 67 — Daniel : "verification identite ne marche pas" /
    // "page Airwallex vide". Same fix as boutique : ALWAYS attach
    // customer_id so the HPP renders the payment-method picker.
    let airwallexCustomerId = null;
    try {
      const customer = await airwallex.findOrCreateCustomer({
        userId: user._id.toString(),
        email: user.email,
        firstName: (user.name || '').split(' ')[0] || user.name || '',
        lastName: (user.name || '').split(' ').slice(1).join(' ') || '',
      });
      airwallexCustomerId = customer?.id || null;
    } catch (custErr) {
      logger.warn(`[kyc.initiatePayment] customer ensure failed : ${custErr?.message || custErr}`);
    }

    // Crée Airwallex PI tagged metadata.type='kyc'
    const amountInCents = KYC_PRICE_EUR * 100;
    const paymentIntent = await airwallex.createPlatformPaymentIntent({
      amount: amountInCents,
      currency: 'EUR',
      ...(airwallexCustomerId ? { customer_id: airwallexCustomerId } : {}),
      metadata: {
        type: 'kyc',
        userId: user._id.toString(),
        role,
        userEmail: user.email || '',
      },
    });
    logger.info(`[kyc.initiatePayment] PI ${paymentIntent.id} created for ${role} ${user._id}`);

    // v23.1 part 127 — Phase 3 audit P3-10 : updateOne pour bypass la
    // revalidation 2dsphere (cf bloc wallet ci-dessus).
    await Model.updateOne(
      { _id: user._id },
      {
        $set: {
          kycStatus: 'pending_payment',
          kycPaymentIntentId: paymentIntent.id,
        },
      },
    );
    user.kycStatus = 'pending_payment';
    user.kycPaymentIntentId = paymentIntent.id;

    return res.status(201).json({
      paymentIntent: {
        id: paymentIntent.id,
        clientSecret: paymentIntent.client_secret,
      },
      amount: KYC_PRICE_EUR,
      currency: 'EUR',
    });
  } catch (err) {
    logger.error('[kyc.initiatePayment]', err);
    return res.status(500).json({ error: 'Unable to initiate KYC payment.', details: err.message });
  }
};

/**
 * POST /kyc/start
 * Body: {} (auth required, status must be pending_verification)
 * Returns: { inquiryId, oneTimeLink, kycStatus }
 */
const startVerification = async (req, res) => {
  try {
    if (!req.user?.id) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    const role = (req.user.role || '').toLowerCase();
    const Model = _modelForRole(role);
    if (!Model) return res.status(403).json({ error: 'Only sitter or walker.' });
    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found.' });

    if (user.kycStatus === 'verified') {
      return res.status(400).json({ error: 'Already verified.' });
    }
    if (user.kycStatus !== 'pending_verification' || !user.kycPaidAt) {
      return res.status(400).json({
        error: 'Payment required first. Call /kyc/initiate-payment.',
        kycStatus: user.kycStatus,
      });
    }

    // v23.1 part 240 — Daniel screenshot : "toujour impossible de verifier
    // mon identiter" → 500 Persona 409 Conflict.
    // ROOT CAUSE FOUND : `user.kycApplicantId` est stocke en DB et pointe
    // vers une inquiry Persona dont le status est DEJA TERMINAL
    // (completed / approved / declined / expired / failed) OU dont une
    // session est deja ouverte ailleurs (auto link). Dans tous ces cas,
    // POST /inquiries/:id/generate-one-time-link renvoie 409 et le 228
    // fix v228 ne le couvrait pas (il couvrait le 409 de CREATE, pas du
    // generate-one-time-link).
    //
    // FIX DEEP v240 : helper interne `_resolveInquiryId` qui :
    //   1. Si kycApplicantId existe → GET /inquiries/:id pour verifier
    //      le status. Terminal ou inutilisable ? on l'oublie.
    //   2. Sinon → findByReferenceId (idem v228).
    //   3. Sinon → createInquiry (idem v228). 409 fallback findByRef.
    //   4. Wrapper generateOneTimeLink avec recovery : si 409, on null
    //      out l'inquiryId et on recommence UNE FOIS la creation.
    const referenceId = `${role}_${user._id.toString()}`;
    const fullName = (user.name || '').trim();
    const firstName = fullName.split(' ')[0] || '';
    const lastName = fullName.split(' ').slice(1).join(' ') || '';

    const TERMINAL_STATUSES = new Set([
      'completed', 'approved', 'declined', 'failed', 'expired',
    ]);

    const _isStale = (inquiry) => {
      try {
        const st = (inquiry?.data?.attributes?.status
                  || inquiry?.attributes?.status
                  || '').toLowerCase();
        return TERMINAL_STATUSES.has(st);
      } catch (_) { return false; }
    };

    const _createFreshInquiry = async () => {
      try {
        const inquiry = await persona.createInquiry({
          userId: user._id.toString(),
          firstName, lastName, email: user.email, role,
        });
        return inquiry?.data?.id || null;
      } catch (createErr) {
        if (createErr?.status === 409) {
          // Existing inquiry under this reference-id → reuse.
          logger.warn(`[kyc.start] Persona 409 on createInquiry for ${referenceId}, falling back to findByRef.`);
          try {
            const retry = await persona.findInquiryByReferenceId(referenceId);
            if (retry?.id) return retry.id;
          } catch (_) {/* defensive */}
        }
        logger.error(`[kyc.start] Persona createInquiry failed: ${createErr?.message} status=${createErr?.status}`);
        throw createErr;
      }
    };

    // Step A — try to use the stored inquiry, but verify it's not stale.
    let inquiryId = user.kycApplicantId;
    if (inquiryId) {
      try {
        const detail = await persona.getInquiry(inquiryId);
        if (_isStale(detail)) {
          logger.warn(`[kyc.start] Stored inquiry ${inquiryId} is in terminal status, refreshing.`);
          inquiryId = null;
          await Model.updateOne(
            { _id: user._id },
            { $unset: { kycApplicantId: '' } },
          );
          user.kycApplicantId = undefined;
        }
      } catch (e) {
        // Could be 404 (deleted) or other → drop and recreate.
        logger.warn(`[kyc.start] Stored inquiry ${inquiryId} lookup failed (${e?.status || ''} ${e?.message}). Refreshing.`);
        inquiryId = null;
        await Model.updateOne(
          { _id: user._id },
          { $unset: { kycApplicantId: '' } },
        );
        user.kycApplicantId = undefined;
      }
    }

    // Step B — no usable id yet : findByRef then create.
    if (!inquiryId) {
      try {
        const existing = await persona.findInquiryByReferenceId(referenceId);
        if (existing?.id && !_isStale(existing)) {
          inquiryId = existing.id;
          logger.info(`[kyc.start] Reused existing non-stale Persona inquiry ${inquiryId}.`);
        }
      } catch (_) {/* defensive */}
    }
    if (!inquiryId) {
      try {
        inquiryId = await _createFreshInquiry();
      } catch (createErr) {
        return res.status(502).json({
          error: 'Persona inquiry creation failed. Please contact support.',
          code: 'PERSONA_INQUIRY_FAILED',
          details: createErr?.data || createErr?.message,
        });
      }
    }
    if (!inquiryId) {
      return res.status(502).json({ error: 'Persona inquiry creation failed.' });
    }
    // Persist the (possibly new) inquiry id.
    await Model.updateOne(
      { _id: user._id },
      { $set: { kycApplicantId: inquiryId } },
    );
    user.kycApplicantId = inquiryId;
    logger.info(`[kyc.start] Persona inquiry ${inquiryId} stored for ${role} ${user._id}`);

    // Step C — generate one-time link with 409 recovery (create a new
    // inquiry and retry once if Persona refuses the link on the stored id).
    let linkResp;
    try {
      linkResp = await persona.generateOneTimeLink(inquiryId);
    } catch (linkErr) {
      if (linkErr?.status === 409) {
        logger.warn(`[kyc.start] Persona 409 on generate-one-time-link for ${inquiryId}, recreating inquiry once.`);
        try {
          await Model.updateOne(
            { _id: user._id },
            { $unset: { kycApplicantId: '' } },
          );
          inquiryId = await _createFreshInquiry();
          if (!inquiryId) throw new Error('Unable to recreate inquiry after 409.');
          await Model.updateOne(
            { _id: user._id },
            { $set: { kycApplicantId: inquiryId } },
          );
          user.kycApplicantId = inquiryId;
          linkResp = await persona.generateOneTimeLink(inquiryId);
        } catch (recreateErr) {
          logger.error(`[kyc.start] 409 recovery failed: ${recreateErr?.message}`);
          return res.status(502).json({
            error: 'Unable to refresh the Persona verification link. Please try again in a few minutes or contact support.',
            code: 'PERSONA_LINK_409_RECOVERY_FAILED',
            details: recreateErr?.data || recreateErr?.message,
          });
        }
      } else {
        logger.error(`[kyc.start] generateOneTimeLink failed (${linkErr?.status}): ${linkErr?.message}`);
        return res.status(502).json({
          error: 'Persona link generation failed. Please contact support.',
          code: 'PERSONA_LINK_FAILED',
          details: linkErr?.data || linkErr?.message,
        });
      }
    }
    // v23.1 part 243 — Daniel screenshot logs Render : Persona return
    // `data.attributes` SANS url ni meta.one-time-link → 502
    // PERSONA_LINK_EMPTY → user bloque sur "Erreur verifier identite".
    // Le call POST /generate-one-time-link retournait l'inquiry au lieu
    // du wrapper meta.one-time-link (probable changement API Persona
    // non documente). On lit maintenant DESORMAIS plus de chemins :
    //   - meta['one-time-link']   (format historique)
    //   - data.attributes.url     (deja en place)
    //   - data.attributes['one-time-link']  (variante)
    //   - links.session           (autre variante observee chez Persona)
    let oneTimeLink =
      linkResp?.meta?.['one-time-link'] ||
      linkResp?.data?.attributes?.url ||
      linkResp?.data?.attributes?.['one-time-link'] ||
      linkResp?.links?.session ||
      null;

    // v243 FALLBACK : si Persona ne retourne aucun lien malgre une
    // creation d'inquiry reussie, on construit l'URL hosted officielle
    // a partir de l'inquiryId. Format documente sur le portail Persona :
    //   https://withpersona.com/verify?inquiry-id={inquiry_id}
    // Pour les environnements sandbox, on ajoute environment-id si on
    // l'a en env var (sinon Persona infere depuis l'API key). C'est le
    // meme flow que le one-time-link mais avec un parametre direct, donc
    // pas de regression de securite (l'inquiry est deja liee au user
    // via reference_id sitter/walker_userId).
    if (!oneTimeLink && inquiryId) {
      const fallbackUrl = `https://withpersona.com/verify?inquiry-id=${encodeURIComponent(inquiryId)}`;
      logger.warn(
        `[kyc.start] Persona did not return a one-time link, falling back to hosted URL. ` +
        `inquiryId=${inquiryId} fallback=${fallbackUrl} ` +
        `rawResponse=${JSON.stringify(linkResp).slice(0, 1500)}`,
      );
      oneTimeLink = fallbackUrl;
    }

    if (!oneTimeLink) {
      logger.error(
        `[kyc.start] Persona did NOT return a one-time link and no fallback possible. ` +
        `inquiryId=${inquiryId} rawResponse=${JSON.stringify(linkResp).slice(0, 1500)}`,
      );
      return res.status(502).json({
        error: 'Persona did not return a verification link. The Persona inquiry was created but the link generation failed. Check Render logs for the raw Persona response.',
        code: 'PERSONA_LINK_EMPTY',
        inquiryId,
      });
    }

    return res.json({
      inquiryId,
      oneTimeLink,
      kycStatus: user.kycStatus,
    });
  } catch (err) {
    logger.error('[kyc.start]', err);
    // v23.1 part 66 — surface "missing env" as a clean 503 with a code so
    // the frontend can show a friendly "indisponible" message instead of
    // the raw stack-trace.
    if (err.message && err.message.includes('env var is not configured')) {
      return res.status(503).json({
        error: 'Identity verification is temporarily unavailable. Please try again later.',
        code: 'KYC_NOT_CONFIGURED',
      });
    }
    return res.status(500).json({ error: 'Unable to start KYC verification.', details: err.message });
  }
};

/**
 * GET /kyc/status
 * Returns: { kycStatus, kycPaidAt, kycVerifiedAt, kycRejectionReason }
 */
const getStatus = async (req, res) => {
  try {
    if (!req.user?.id) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    const role = (req.user.role || '').toLowerCase();
    const Model = _modelForRole(role);
    if (!Model) return res.status(403).json({ error: 'Only sitter or walker.' });
    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found.' });

    // v23.1 part 247 — Daniel : "jai bien verifier mon identiter sa la
    // valider mais sa ne mas pas mis dans lapp ni identiter verifier".
    //
    // Root cause : le user a complete Persona avec succes mais le webhook
    // /webhooks/persona n'a soit pas fire (sandbox lent), soit signature
    // mismatch, soit notre serveur l'a manque. Resultat : kycStatus reste
    // 'pending_verification' meme apres validation cote Persona.
    //
    // Fix : si on est en pending_verification et qu'on a un kycApplicantId,
    // on POLL Persona en synchrone via getInquiry(). Si Persona retourne
    // completed/approved -> on flip kycStatus = 'verified' direct ici,
    // exactement comme le webhook l'aurait fait. Si decline/failed/expired
    // -> 'rejected'. Le user revoit son badge des le prochain refresh.
    //
    // Throttle : on poll au max toutes les 30s pour eviter de hammer
    // l'API Persona si le user spam /kyc/status. Le timestamp de derniere
    // verif est stocke en RAM (cache process) — pas crucial qu'il soit
    // persistant, c'est juste un soft limit.
    if (
      user.kycStatus === 'pending_verification' &&
      user.kycApplicantId &&
      _shouldPollPersona(user._id.toString())
    ) {
      try {
        const inquiry = await persona.getInquiry(user.kycApplicantId);
        const inqStatus = (inquiry?.data?.attributes?.status || '').toLowerCase();
        const decisionStatus = (inquiry?.data?.attributes?.['decision-status'] || '').toLowerCase();
        logger.info(
          `[kyc.getStatus] poll persona for user=${user._id} ` +
          `inquiryStatus=${inqStatus} decisionStatus=${decisionStatus}`,
        );
        let newStatus = null;
        let rejectionReason = null;
        if (inqStatus === 'approved' || inqStatus === 'completed') {
          if (decisionStatus === 'declined') {
            newStatus = 'rejected';
            rejectionReason = 'Document or selfie verification failed.';
          } else {
            newStatus = 'verified';
          }
        } else if (inqStatus === 'declined' || inqStatus === 'failed') {
          newStatus = 'rejected';
          rejectionReason = 'Verification declined by Persona.';
        } else if (inqStatus === 'expired') {
          newStatus = 'rejected';
          rejectionReason = 'Verification link expired.';
        }
        if (newStatus && newStatus !== user.kycStatus) {
          const _persUpdate = {
            kycStatus: newStatus,
            kycRejectionReason: rejectionReason,
          };
          if (newStatus === 'verified') {
            _persUpdate.kycVerifiedAt = new Date();
            _persUpdate.verified = true;
            user.kycVerifiedAt = _persUpdate.kycVerifiedAt;
            user.verified = true;
          }
          await Model.updateOne({ _id: user._id }, { $set: _persUpdate });
          user.kycStatus = newStatus;
          user.kycRejectionReason = rejectionReason;
          logger.info(
            `✅ [kyc.getStatus.poll] ${role} ${user._id} → kycStatus=${newStatus} ` +
            `(webhook fallback)`,
          );
          // Notif push.
          try {
            const { sendNotification } = require('../services/notificationSender');
            const notifType = newStatus === 'verified' ? 'kyc_verified' : 'kyc_rejected';
            sendNotification({
              userId: user._id.toString(),
              role,
              type: notifType,
              data: { kycStatus: newStatus, reason: rejectionReason },
              actor: { role: 'system', id: null },
            }).catch(() => {});
          } catch (_) { /* noop */ }
        }
      } catch (pollErr) {
        // Best-effort poll — on logue mais on continue, on retourne le
        // status DB tel quel.
        logger.warn(`[kyc.getStatus.poll] persona poll failed: ${pollErr.message}`);
      }
    }

    return res.json({
      kycStatus: user.kycStatus || 'none',
      kycPaidAt: user.kycPaidAt || null,
      kycVerifiedAt: user.kycVerifiedAt || null,
      kycRejectionReason: user.kycRejectionReason || null,
      isVerified: user.kycStatus === 'verified',
      price: KYC_PRICE_EUR,
      currency: 'EUR',
    });
  } catch (err) {
    logger.error('[kyc.getStatus]', err);
    return res.status(500).json({ error: 'Unable to fetch KYC status.' });
  }
};

// v23.1 part 247 — throttle pour le poll Persona dans getStatus. Cache
// process-level (pas persistant — redemarre serveur reset). 30s entre 2
// polls par user. Suffit pour le polling /kyc/status frontend qui tape
// au max 1x par seconde.
const _personaPollCache = new Map();
function _shouldPollPersona(userId) {
  const now = Date.now();
  const last = _personaPollCache.get(userId) || 0;
  if (now - last < 30000) return false;
  _personaPollCache.set(userId, now);
  return true;
}

/**
 * v23.1 part 75 — POST /kyc/confirm-payment
 * Body: {} (auth, sitter/walker)
 * Returns: { kycStatus, kycPaidAt }
 *
 * Daniel : "sa as debiter et sa menvoi pas a la verification id". The
 * Airwallex webhook is unreliable in some setups (signature mismatch,
 * URL not yet configured, transient 5xx). This endpoint lets the
 * frontend force-confirm the KYC payment after the payment WebView
 * closes with success — we re-fetch the PI from Airwallex to verify
 * status, and if SUCCEEDED we run the same activation logic the
 * webhook would have. Fully idempotent : safe to call from both the
 * webhook AND the frontend without double-effects.
 */
const confirmPayment = async (req, res) => {
  try {
    if (!req.user?.id) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    const role = (req.user.role || '').toLowerCase();
    const Model = _modelForRole(role);
    if (!Model) return res.status(403).json({ error: 'Only sitter or walker.' });
    const user = await Model.findById(req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found.' });

    // Already verified or in flight → just return current status (idempotent).
    if (user.kycStatus === 'verified' || user.kycStatus === 'pending_verification') {
      return res.json({
        kycStatus: user.kycStatus,
        kycPaidAt: user.kycPaidAt || null,
        alreadyConfirmed: true,
      });
    }

    const piId = user.kycPaymentIntentId;
    if (!piId) {
      return res.status(400).json({
        error: 'No KYC payment intent recorded. Call /kyc/initiate-payment first.',
        kycStatus: user.kycStatus || 'none',
      });
    }

    let pi;
    try {
      pi = await airwallex.retrievePaymentIntent(piId);
    } catch (e) {
      logger.error(`[kyc.confirmPayment] Airwallex retrieve failed for ${piId} : ${e.message}`);
      return res.status(502).json({ error: 'Unable to verify payment with Airwallex.' });
    }

    const status = (pi?.status || '').toUpperCase();
    if (status !== 'SUCCEEDED') {
      return res.status(409).json({
        error: `Payment not yet succeeded (status=${status}).`,
        kycStatus: user.kycStatus || 'none',
        airwallexStatus: status,
      });
    }

    // Run the same logic as the webhook handler.
    await onKycPaymentSucceeded(pi);

    // Reload to return fresh status.
    const fresh = await Model.findById(req.user.id).lean();
    return res.json({
      kycStatus: fresh?.kycStatus || 'pending_verification',
      kycPaidAt: fresh?.kycPaidAt || null,
      forced: true,
    });
  } catch (err) {
    logger.error('[kyc.confirmPayment]', err);
    return res.status(500).json({ error: 'Unable to confirm KYC payment.', details: err.message });
  }
};

/**
 * Internal helper: called by airwallexWebhookController when a KYC payment
 * succeeds (metadata.type === 'kyc'). Marks user kycStatus='pending_verification'
 * + kycPaidAt = now. Frontend must then POST /kyc/start to launch the inquiry.
 */
const onKycPaymentSucceeded = async (paymentIntent) => {
  try {
    const userId = paymentIntent?.metadata?.userId;
    const role = (paymentIntent?.metadata?.role || '').toLowerCase();
    const Model = _modelForRole(role);
    if (!Model || !userId) {
      logger.warn(`[kyc.onPaymentSucceeded] missing userId or role in PI metadata`);
      return;
    }
    const user = await Model.findById(userId);
    if (!user) return;
    if (user.kycStatus === 'verified') return; // idempotent
    // v23.1 part 127 — Phase 3 audit P3-10 : updateOne pour bypass la
    // revalidation 2dsphere (cf initiatePayment).
    const _pidNow = new Date();
    await Model.updateOne(
      { _id: user._id },
      {
        $set: {
          kycStatus: 'pending_verification',
          kycPaidAt: _pidNow,
          kycPaymentIntentId: paymentIntent.id,
        },
      },
    );
    user.kycStatus = 'pending_verification';
    user.kycPaidAt = _pidNow;
    user.kycPaymentIntentId = paymentIntent.id;
    logger.info(`✅ [kyc.onPaymentSucceeded] ${role} ${userId} → pending_verification`);

    // Notif user : "Paiement confirmé, complète maintenant ta vérification"
    try {
      const { sendNotification } = require('../services/notificationSender');
      sendNotification({
        userId: userId.toString(),
        role,
        type: 'kyc_payment_succeeded',
        data: { kycStatus: 'pending_verification' },
        actor: { role: 'system', id: null },
      }).catch(() => {});
    } catch (_) { /* noop */ }
  } catch (e) {
    logger.error(`[kyc.onPaymentSucceeded] ${e.message}`);
  }
};

/**
 * POST /webhooks/persona
 * Reçoit inquiry.completed / approved / declined / failed events de Persona.
 * Met à jour User.kycStatus et envoie notif.
 *
 * IMPORTANT : ce route doit utiliser express.raw() pour preserver le rawBody
 * et permettre la signature HMAC verify.
 */
const personaWebhook = async (req, res) => {
  try {
    const rawBody = req.rawBody || (req.body instanceof Buffer ? req.body.toString('utf8') : JSON.stringify(req.body));
    const signature = req.headers['persona-signature'];
    if (!persona.verifyWebhookSignature(rawBody, signature)) {
      logger.warn(`[persona.webhook] signature mismatch`);
      return res.status(401).json({ error: 'Invalid signature' });
    }
    const payload = typeof rawBody === 'string' ? JSON.parse(rawBody) : req.body;
    const eventName = payload?.data?.attributes?.name;
    const inquiry = payload?.data?.attributes?.payload?.data;
    const inquiryId = inquiry?.id;
    const inquiryStatus = (inquiry?.attributes?.status || '').toLowerCase();
    const referenceId = inquiry?.attributes?.['reference-id'] || '';
    logger.info(`[persona.webhook] event=${eventName} inquiry=${inquiryId} status=${inquiryStatus} ref=${referenceId}`);

    // Parse reference-id "role_userId"
    const [role, userId] = referenceId.split('_');
    const Model = _modelForRole(role);
    if (!Model || !userId) {
      logger.warn(`[persona.webhook] invalid reference-id ${referenceId}`);
      return res.status(200).json({ ok: true });
    }
    const user = await Model.findById(userId);
    if (!user) return res.status(200).json({ ok: true });
    if (user.kycApplicantId !== inquiryId) {
      logger.warn(`[persona.webhook] inquiry mismatch user=${userId} stored=${user.kycApplicantId} got=${inquiryId}`);
    }

    // Map Persona status → kycStatus
    let newStatus = user.kycStatus;
    let rejectionReason = null;
    if (inquiryStatus === 'approved' || inquiryStatus === 'completed') {
      // Approved or completed (auto-approval): verified
      // Note: Persona returns 'completed' if the inquiry finished and 'approved'
      //       if a Decision rule auto-marked it OK.
      const decisions = inquiry?.relationships?.decisions?.data;
      const declined = Array.isArray(decisions) && decisions.length > 0 &&
        (inquiry?.attributes?.['decision-status'] || '').toLowerCase() === 'declined';
      if (declined) {
        newStatus = 'rejected';
        rejectionReason = 'Document or selfie verification failed.';
      } else {
        newStatus = 'verified';
      }
    } else if (inquiryStatus === 'declined' || inquiryStatus === 'failed') {
      newStatus = 'rejected';
      rejectionReason = 'Verification declined by Persona.';
    } else if (inquiryStatus === 'expired') {
      newStatus = 'rejected';
      rejectionReason = 'Verification link expired.';
    }
    // v23.1 part 127 — Phase 3 audit P3-10 : updateOne pour bypass la
    // revalidation 2dsphere. On regroupe les champs à set selon newStatus.
    const _persUpdate = {
      kycStatus: newStatus,
      kycRejectionReason: rejectionReason,
    };
    if (newStatus === 'verified') {
      _persUpdate.kycVerifiedAt = new Date();
      _persUpdate.verified = true; // sync legacy `verified` field
      user.kycVerifiedAt = _persUpdate.kycVerifiedAt;
      user.verified = true;
    }
    await Model.updateOne({ _id: user._id }, { $set: _persUpdate });
    user.kycStatus = newStatus;
    user.kycRejectionReason = rejectionReason;
    logger.info(`✅ [persona.webhook] ${role} ${userId} → kycStatus=${newStatus}`);

    // Notif user
    try {
      const { sendNotification } = require('../services/notificationSender');
      const notifType = newStatus === 'verified' ? 'kyc_verified' : 'kyc_rejected';
      sendNotification({
        userId: userId.toString(),
        role,
        type: notifType,
        data: { kycStatus: newStatus, reason: rejectionReason },
        actor: { role: 'system', id: null },
      }).catch(() => {});
    } catch (_) { /* noop */ }

    return res.status(200).json({ ok: true });
  } catch (e) {
    logger.error(`[persona.webhook] ${e.message}`);
    return res.status(500).json({ error: 'Webhook processing failed.' });
  }
};

module.exports = {
  initiatePayment,
  startVerification,
  getStatus,
  confirmPayment, // v23.1 part 75 — client-side KYC payment confirmation fallback
  onKycPaymentSucceeded,
  personaWebhook,
};
