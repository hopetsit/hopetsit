/**
 * 10/11/2026 (BOB, accord de Daniel 23 h : « Oui, ajoute-la ») — ACCORD SMS FACULTATIF sur la page de demande
 * (site /request · /demande, écran « c'est en ligne », sous « Voir mes candidats »).
 *
 * Pourquoi : le dossier du numéro gratuit américain (Twilio) a été refusé, entre autres parce que le site ne
 * montrait aucun endroit où la personne ACCEPTE de recevoir des SMS. Ici elle saisit son numéro et coche une
 * case NON cochée par défaut ; rien n'est obligatoire pour publier, voir ses candidats ou payer.
 *
 *   POST /ad-leads/sms-consent { id, phone, consent: true }   (jeton de session obligatoire)
 *     → le contact doit appartenir au compte connecté (sinon 403), la case doit être cochée (consent === true,
 *       sinon 400 CONSENT_REQUIRED), le numéro est mis au format international (sinon 400 PHONE_INVALID).
 *     → on garde : numéro, date, texte EXACT accepté (version serveur), adresse IP. 5 essais / h par contact.
 *
 * Coupe-circuit sans rebuild : DEMANDE_SMS_1011=off sur Render → route 404 et le site ne montre plus le bloc
 * (drapeau `smsConsent` de /ad-leads/code/check). Pays ouverts : DEMANDE_SMS_1011_COUNTRIES (défaut « US »).
 * Aucun SMS n'est envoyé par cette route. Jamais de numéro dans les journaux.
 */
const express = require('express');
const logger = require('../utils/logger');
const AdLead = require('../models/AdLead2210');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
const ID_RE = /^[a-f0-9]{32}$/;
const HOUR_MS = 3600 * 1000;
const MAX_TRIES_1H = 5;
const VERSION = '1011-v1';

// Texte EXACT de la case (le même que sur le site, website/src/lib/i18n/demande0811.ts, clés sms_box*).
const CONSENT_TEXT = {
  en: 'I agree to receive text messages from HoPetSit about my pet-care request (new sitter replies and booking updates). Message frequency varies. Message and data rates may apply. Reply STOP to unsubscribe, HELP for help. Consent is not a condition of purchase. See our Privacy Policy and Terms.',
  fr: "J'accepte de recevoir des SMS de HoPetSit au sujet de ma demande de garde (réponses des gardiens, suivi de réservation). Fréquence variable. Des frais de message peuvent s'appliquer. Réponds STOP pour arrêter, AIDE pour de l'aide. Ce n'est pas une condition d'achat. Voir notre Politique de confidentialité et nos Conditions.",
};

const tries = new Map(); // id → [horodatages]
function countIn(key, now) {
  const list = (tries.get(key) || []).filter((t) => now - t < HOUR_MS);
  tries.set(key, list);
  if (tries.size > 5000) for (const k of tries.keys()) { if (tries.size <= 4000) break; tries.delete(k); }
  return list;
}
function resetForTest() { tries.clear(); }

function enabled() { return String(process.env.DEMANDE_SMS_1011 || '').toLowerCase() !== 'off'; }
function countries() {
  return String(process.env.DEMANDE_SMS_1011_COUNTRIES || 'US').split(',').map((x) => x.trim().toUpperCase()).filter(Boolean);
}
/** Le bloc est-il proposé pour ce contact ? (drapeau renvoyé au site par /ad-leads/code/check) */
function offeredFor(lead) {
  return enabled() && !!lead && countries().includes(String(lead.country || '').toUpperCase());
}

/** Numéro → format international « +… » (E.164), sinon ''. Repli par pays : US/CA 10 chiffres, FR 0X XX XX XX XX. */
function normalizePhone(raw, country) {
  const s = String(raw || '').trim();
  if (!s || s.length > 32 || /[^\d+\s().-]/.test(s)) return '';
  const plus = s.startsWith('+');
  let d = s.replace(/\D/g, '');
  if (!plus && d.startsWith('00')) return normalizePhone(`+${d.slice(2)}`, country);
  const c = String(country || '').toUpperCase();
  if (!plus) {
    if (c === 'US' || c === 'CA') {
      if (d.length === 11 && d.startsWith('1')) d = d.slice(1);
      if (d.length !== 10) return '';
      d = `1${d}`;
    } else if (c === 'FR') {
      if (d.length !== 10 || !d.startsWith('0')) return '';
      d = `33${d.slice(1)}`;
    } else return '';
  }
  if (d.length < 8 || d.length > 15 || d.startsWith('0')) return '';
  // Amérique du Nord : indicatif régional et central ne commencent jamais par 0 ou 1.
  if (d.startsWith('1') && !/^1[2-9]\d{2}[2-9]\d{6}$/.test(d)) return '';
  return `+${d}`;
}

router.post('/', (req, res, next) => (enabled() ? next() : res.status(404).json({ error: 'not_found', code: 'NOT_FOUND' })), requireAuth, async (req, res) => {
  try {
    const b = req.body || {};
    const id = String(b.id || '');
    if (!ID_RE.test(id)) return res.status(404).json({ error: 'not_found', code: 'NOT_FOUND' });
    const lead = await AdLead.findById(id);
    if (!lead) return res.status(404).json({ error: 'not_found', code: 'NOT_FOUND' });
    if (!lead.ownerId || String(lead.ownerId) !== String(req.user && req.user.id)) {
      return res.status(403).json({ error: 'FORBIDDEN', code: 'FORBIDDEN' });
    }
    if (!offeredFor(lead)) return res.status(404).json({ error: 'not_found', code: 'NOT_FOUND' });
    const now = Date.now();
    const list = countIn(id, now);
    if (list.length >= MAX_TRIES_1H) return res.status(429).json({ error: 'TOO_MANY', code: 'TOO_MANY' });
    list.push(now);
    if (b.consent !== true) return res.status(400).json({ error: 'CONSENT_REQUIRED', code: 'CONSENT_REQUIRED' });
    const phone = normalizePhone(b.phone, lead.country);
    if (!phone) return res.status(400).json({ error: 'PHONE_INVALID', code: 'PHONE_INVALID' });
    lead.smsPhone = phone;
    lead.smsConsentAt = new Date();
    lead.smsConsentText = `${VERSION} | ${lead.lang === 'en' ? CONSENT_TEXT.en : CONSENT_TEXT.fr}`;
    lead.smsConsentIp = String(req.ip || '').slice(0, 64);
    lead.smsOptOutAt = undefined;
    await lead.save();
    logger.info({ leadId: String(lead._id) }, '[demandeSms1011] accord SMS enregistré');
    return res.json({ ok: true });
  } catch (e) {
    logger.error('[demandeSms1011] failed', e && e.message);
    return res.status(500).json({ error: 'Unable to save.' });
  }
});

module.exports = router;
module.exports.offeredFor = offeredFor;
module.exports.normalizePhone = normalizePhone;
module.exports.CONSENT_TEXT = CONSENT_TEXT;
module.exports.VERSION = VERSION;
module.exports._resetForTest = resetForTest;
