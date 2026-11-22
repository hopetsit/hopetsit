/**
 * 2211 — « Proposer mon prix » : page de réponse du gardien / promeneur, ouverte par le lien signé
 * de l'e-mail (services/priceOffer2211). Même schéma que « toujours libre ? » (routes/sitterFree1011).
 *
 *   GET  /price-offer/:token  → AFFICHE la demande, le prix proposé, ce que le prestataire toucherait
 *                               (net après commission) et son prix actuel, avec deux boutons
 *                               Accepter / Refuser. N'écrit RIEN : les robots des messageries ouvrent
 *                               les liens d'un e-mail, un simple passage ne doit rien accepter.
 *   POST /price-offer/:token  → applique la réponse portée par le jeton, puis affiche le résultat.
 *
 * Pas de mot de passe : le jeton signé désigne UNE candidature, UN prestataire, UNE proposition et
 * UNE réponse, 14 jours. Signature fausse ou jeton expiré : page d'erreur (400 / 410), rien ne change.
 * Aucune donnée personnelle n'est affichée (ni e-mail, ni téléphone, ni adresse, ni nom).
 */
const express = require('express');
const logger = require('../utils/logger');

const router = express.Router();
const LANGS = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

const noStore = (res) => {
  res.set('Cache-Control', 'no-store');
  res.set('X-Robots-Tag', 'noindex, nofollow');
  // « same-origin » et PAS « no-referrer » (piège du 10/11) : avec « no-referrer » le navigateur envoie
  // « Origin: null » sur le formulaire POST. Le filtre CORS de app.js accepte de toute façon cette
  // origine sur ce chemin ; le jeton ne sort pas du site.
  res.set('Referrer-Policy', 'same-origin');
};
const browserLang = (req) => {
  try { return req.acceptsLanguages(LANGS) || 'fr'; } catch (_) { return 'fr'; }
};
const text = () => require('../utils/priceOfferText2211');
const freeText = (lang) => require('../utils/sitterFreeText1011').L(lang).page;
const page = (res, status, opts) => {
  noStore(res);
  return res.status(status).type('html').send(text().pageHtml(opts));
};
const failPage = (res, reason, lang) => {
  const p = freeText(lang);
  const t = text().L(lang);
  if (reason === 'expired') return page(res, 410, { lang, title: t.expired, tone: 'warn' });
  if (reason === 'answered') return page(res, 410, { lang, title: t.already, tone: 'warn' });
  if (reason === 'gone') return page(res, 410, { lang, title: p.gone, tone: 'warn' });
  if (reason === 'error') return page(res, 500, { lang, title: p.error, tone: 'warn' });
  return page(res, 400, { lang, title: p.invalid, tone: 'warn' });
};
const langFor = async (req, app) => {
  let lang = browserLang(req);
  if (!app) return lang;
  try {
    const role = app.walkerId ? 'walker' : 'sitter';
    lang = (await require('../services/notificationSender').resolveRecipientLocale(role, String(app.walkerId || app.sitterId))) || lang;
  } catch (_) { /* langue du navigateur */ }
  return lang;
};

router.get('/:token', async (req, res) => {
  try {
    const svc = require('../services/priceOffer2211');
    const v = svc.verifyOfferLink(req.params.token);
    if (!v.ok) return failPage(res, v.reason, browserLang(req));
    const ctx = await svc.loadForAnswer(v);
    if (!ctx.ok) return failPage(res, ctx.reason, browserLang(req));
    const lang = await langFor(req, ctx.app);
    const t = text().L(lang);
    const m = (n) => text().money(n, ctx.view.currency, lang);
    if (ctx.status === 'accepted') return page(res, 200, { lang, title: t.thanksYes(m(ctx.view.amount), m(ctx.view.newNet)) });
    if (ctx.status === 'declined') return page(res, 200, { lang, title: t.thanksNo });
    if (ctx.status === 'expired') return failPage(res, 'expired', lang);
    if (ctx.status !== 'pending' || ctx.app.status !== 'pending' || ctx.app.archivedAt) return failPage(res, 'gone', lang);
    const base = `${req.baseUrl}/`;
    const sign = (answer) => encodeURIComponent(svc.signOfferLink({ applicationId: v.applicationId, providerId: v.providerId, index: v.index, answer }));
    return page(res, 200, {
      lang,
      title: t.pageTitle,
      lines: [t.intro],
      rows: text().rowsFor({ lang, post: ctx.post, serviceType: ctx.app.serviceType, view: ctx.view }),
      acceptAction: `${base}${sign('accept')}`,
      declineAction: `${base}${sign('decline')}`,
      acceptLabel: t.accept(m(ctx.view.newNet)),
      declineLabel: t.decline,
    });
  } catch (e) {
    logger.error('[priceOffer2211] GET', e);
    return failPage(res, 'error', browserLang(req));
  }
});

router.post('/:token', async (req, res) => {
  try {
    const svc = require('../services/priceOffer2211');
    const v = svc.verifyOfferLink(req.params.token);
    if (!v.ok) return failPage(res, v.reason, browserLang(req));
    const ctx = await svc.loadForAnswer(v);
    if (!ctx.ok) return failPage(res, ctx.reason, browserLang(req));
    const lang = await langFor(req, ctx.app);
    const r = await svc.respond({ applicationId: v.applicationId, providerId: v.providerId, index: v.index, answer: v.answer });
    if (!r.ok) return failPage(res, r.reason, lang);
    const t = text().L(lang);
    const m = (n) => text().money(n, r.view.currency, lang);
    if (r.answer === 'declined') return page(res, 200, { lang, title: t.thanksNo });
    return page(res, 200, { lang, title: t.thanksYes(m(r.view.amount), m(r.view.newNet)), lines: [t.ownerTold] });
  } catch (e) {
    logger.error('[priceOffer2211] POST', e);
    return failPage(res, 'error', browserLang(req));
  }
});

module.exports = router;
