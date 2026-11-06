/**
 * 06/11/2026 (SAM, ordre de Daniel « oui fais tout ») — META CONVERSIONS API (événements serveur).
 *
 * Pourquoi : Meta optimisait la pub sur « formulaire rempli » et ne voyait ni la demande publiée ni le
 * paiement. Le pixel navigateur (website, après consentement) peut être refusé ou bloqué ; le serveur,
 * lui, sait à coup sûr quand un contact publie (Lead) et quand une réservation est payée (Purchase).
 * Même pixel, même eventID que le navigateur → Meta dédoublonne.
 *
 *   sendEvent({ name, email, value, currency, eventId, sourceUrl, testEventCode })
 *     → POST https://graph.facebook.com/v21.0/<pixelId>/events
 *       { data: [{ event_name, event_time, event_id, action_source: 'website', event_source_url,
 *                  user_data: { em: [sha256(e-mail minuscule)] }, custom_data: { value, currency } }] }
 *   leadPublished(lead, req)           → Lead     (eventId = id du contact AdLead)
 *   bookingPaid(booking, { amount, currency }) → Purchase (eventId = id de la réservation)
 *
 * Toujours « fire and forget » chez l'appelant : ne lève jamais, renvoie { sent, reason|status }.
 * Jamais d'envoi : coupe-circuit META_CAPI_0611=off · pixel ou jeton non configurés (config chiffrée en
 * base, PUT /admin/meta-leadgen/config { pixelId, capiToken }) · adresse de test (+test, example.com…).
 * Aucune donnée en clair : l'e-mail part HACHÉ, l'IP et le user-agent ne sont pas envoyés.
 */
const crypto = require('crypto');
const logger = require('../utils/logger');

const GRAPH = 'https://graph.facebook.com/v21.0';
const enabled = () => String(process.env.META_CAPI_0611 || '').toLowerCase() !== 'off';
const TEST_EMAIL = /\+test|@example\.(com|org|net)$|\.test$|@invalid\.example$|@test\.|^hopetsit@gmail\.com$|^dadaciao84@/i;

const normEmail = (e) => String(e || '').trim().toLowerCase();
const hashEmail = (e) => crypto.createHash('sha256').update(normEmail(e)).digest('hex');
const isTestEmail = (e) => TEST_EMAIL.test(normEmail(e));

async function defaultGetConfig() {
  // chargement tardif : la route metaLeadgen0511 porte la config (évite une boucle de require)
  const { getCapiConfig } = require('../routes/metaLeadgen0511');
  return getCapiConfig();
}

/**
 * Envoie UN événement. Renvoie { sent: true, status } ou { sent: false, reason }. Ne lève jamais.
 * deps : { fetch, getConfig, now } pour les tests.
 */
async function sendEvent(ev, deps = {}) {
  try {
    if (!enabled()) return { sent: false, reason: 'off' };
    const name = String((ev && ev.name) || '');
    if (!['Lead', 'Purchase', 'InitiateCheckout', 'ViewContent', 'PageView'].includes(name)) return { sent: false, reason: 'event_inconnu' };
    const email = normEmail(ev.email);
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { sent: false, reason: 'email_invalide' };
    if (isTestEmail(email)) return { sent: false, reason: 'email_test' };
    const cfg = await (deps.getConfig || defaultGetConfig)();
    const pixelId = String((cfg && cfg.pixelId) || '').trim();
    const token = String((cfg && cfg.token) || '').trim();
    if (!/^\d{6,}$/.test(pixelId) || !token) return { sent: false, reason: 'non_configure' };
    const now = typeof deps.now === 'function' ? deps.now() : Date.now();
    const data = {
      event_name: name,
      event_time: Math.floor(now / 1000),
      action_source: 'website',
      user_data: { em: [hashEmail(email)] },
    };
    if (ev.eventId) data.event_id = String(ev.eventId).slice(0, 80);
    if (ev.sourceUrl) data.event_source_url = String(ev.sourceUrl).slice(0, 500);
    const custom = {};
    if (typeof ev.value === 'number' && Number.isFinite(ev.value)) custom.value = Math.round(ev.value * 100) / 100;
    if (ev.currency) custom.currency = String(ev.currency).toUpperCase().slice(0, 3);
    if (ev.contentName) custom.content_name = String(ev.contentName).slice(0, 80);
    if (Object.keys(custom).length) data.custom_data = custom;
    const body = { data: [data] };
    if (ev.testEventCode) body.test_event_code = String(ev.testEventCode).slice(0, 40);
    const fetchImpl = deps.fetch || fetch;
    const ctl = new AbortController(); const timer = setTimeout(() => ctl.abort(), 8000);
    try {
      const r = await fetchImpl(`${GRAPH}/${pixelId}/events?access_token=${encodeURIComponent(token)}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body), signal: ctl.signal,
      });
      let out = null; try { out = await r.json(); } catch (_) { /* corps vide */ }
      if (!r.ok) {
        logger.warn(`[metaCapi0611] ${name} refusé : HTTP ${r.status} ${JSON.stringify(out || {}).slice(0, 200)}`);
        return { sent: false, reason: `graph_${r.status}`, status: r.status };
      }
      logger.info(`[metaCapi0611] ${name} envoyé (event_id ${data.event_id || '-'})`);
      return { sent: true, status: r.status, received: out && out.events_received };
    } finally { clearTimeout(timer); }
  } catch (e) {
    logger.warn(`[metaCapi0611] ${ev && ev.name} : ${e && e.message}`);
    return { sent: false, reason: 'exception' };
  }
}

/** Contact de la pub qui vient de PUBLIER sa demande (clic e-mail ou page merci). */
function leadPublished(lead, req, deps = {}) {
  const sourceUrl = req && req.get ? `${req.get('origin') || 'https://www.hopetsit.com'}${req.originalUrl || ''}`.split('?')[0] : 'https://www.hopetsit.com/posts/confirmer';
  return sendEvent({ name: 'Lead', email: lead && lead.email, eventId: lead && lead._id ? String(lead._id) : undefined, sourceUrl, contentName: 'demande_publiee' }, deps);
}

/** Réservation qui vient de passer en payée (webhook Airwallex). */
async function bookingPaid(booking, paid = {}, deps = {}) {
  try {
    if (!booking) return { sent: false, reason: 'no_booking' };
    let email = '';
    if (booking.ownerId) {
      const Owner = require('../models/Owner');
      const o = await (deps.findOwner || ((id) => Owner.findById(id).select('email').lean()))(booking.ownerId);
      email = (o && o.email) || '';
    }
    const amount = Number(paid.amount);
    const fallback = booking.pricing && Number(booking.pricing.totalPrice);
    const value = Number.isFinite(amount) && amount > 0 ? amount : (Number.isFinite(fallback) ? fallback : undefined);
    const currency = paid.currency || (booking.pricing && booking.pricing.currency) || 'EUR';
    return sendEvent({ name: 'Purchase', email, value, currency, eventId: String(booking._id), sourceUrl: 'https://www.hopetsit.com/application', contentName: 'reservation' }, deps);
  } catch (e) {
    logger.warn(`[metaCapi0611] Purchase : ${e && e.message}`);
    return { sent: false, reason: 'exception' };
  }
}

module.exports = { sendEvent, leadPublished, bookingPaid, hashEmail, isTestEmail, enabled };
