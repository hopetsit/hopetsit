/**
 * 1011 (FLO) — liens signés « Oui, je suis libre » / « Non, plus disponible » reçus par e-mail.
 *
 *   GET  /sitter-free/:token  → AFFICHE une page de confirmation avec un bouton. N'écrit RIEN :
 *                               les robots des messageries ouvrent les liens d'un e-mail, et un
 *                               simple passage ne doit ni dire « oui » ni retirer une candidature.
 *   POST /sitter-free/:token  → applique la réponse (le bouton de la page), puis affiche le résultat.
 *
 * Pas de mot de passe : le jeton signé (services/sitterFree1011) désigne UNE candidature et UN
 * prestataire, pour UNE réponse, 14 jours. Signature fausse ou jeton expiré : page d'erreur, rien
 * ne change. Aucune donnée personnelle n'est affichée (ni e-mail, ni téléphone, ni adresse).
 */
const express = require('express');
const logger = require('../utils/logger');

const router = express.Router();
const LANGS = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

const noStore = (res) => {
  res.set('Cache-Control', 'no-store');
  res.set('X-Robots-Tag', 'noindex, nofollow');
  // 10/11 (BOB) — « same-origin » et PAS « no-referrer » : avec « no-referrer » le navigateur envoie
  // « Origin: null » quand on appuie sur le bouton (formulaire POST), le filtre CORS refusait et la
  // personne voyait une erreur — aucun « oui » ne pouvait revenir. Le jeton ne sort toujours pas du site :
  // « same-origin » n'envoie l'adresse de la page qu'à ce même serveur.
  res.set('Referrer-Policy', 'same-origin');
};
const browserLang = (req) => {
  try { return req.acceptsLanguages(LANGS) || 'fr'; } catch (_) { return 'fr'; }
};
const page = (res, status, opts) => {
  const text = require('../utils/sitterFreeText1011');
  noStore(res);
  return res.status(status).type('html').send(text.pageHtml(opts));
};
const pageText = (lang) => {
  const text = require('../utils/sitterFreeText1011');
  return text.L(lang).page;
};

/** Lecture seule : la candidature, sa demande et la langue de son auteur. */
const context = async (v, req) => {
  const Application = require('../models/Application');
  const Post = require('../models/Post');
  const app = await Application.findById(v.applicationId).select('sitterId walkerId postId status serviceType archivedAt').lean();
  let lang = browserLang(req);
  if (!app) return { app: null, post: null, lang };
  const role = app.walkerId ? 'walker' : 'sitter';
  const owner = String(app.walkerId || app.sitterId || '');
  if (owner !== v.providerId) return { app: null, post: null, lang, mismatch: true };
  try { lang = (await require('../services/notificationSender').resolveRecipientLocale(role, owner)) || lang; } catch (_) { /* langue du navigateur */ }
  const post = app.postId ? await Post.findById(app.postId).select('startDate endDate dateMode location city petIds animalTypes animalCount serviceTypes').lean() : null;
  return { app, post, lang };
};

const failPage = (res, reason, lang) => {
  const p = pageText(lang);
  if (reason === 'expired') return page(res, 410, { lang, title: p.expired, tone: 'warn' });
  if (reason === 'gone') return page(res, 410, { lang, title: p.gone, tone: 'warn' });
  if (reason === 'error') return page(res, 500, { lang, title: p.error, tone: 'warn' });
  return page(res, 400, { lang, title: p.invalid, tone: 'warn' });
};

router.get('/:token', async (req, res) => {
  try {
    const svc = require('../services/sitterFree1011');
    const text = require('../utils/sitterFreeText1011');
    const v = svc.verifyAnswerLink(req.params.token);
    if (!v.ok) return failPage(res, v.reason, browserLang(req));
    const ctx = await context(v, req);
    if (ctx.mismatch) return failPage(res, 'invalid', ctx.lang);
    if (!ctx.app || ctx.app.status !== 'pending' || ctx.app.archivedAt) return failPage(res, 'gone', ctx.lang);
    const p = pageText(ctx.lang);
    const t = text.L(ctx.lang);
    let about = '';
    try { about = ctx.post ? text.questionLine({ lang: ctx.lang, post: ctx.post, serviceType: ctx.app.serviceType, petNames: [] }) : ''; } catch (_) { about = ''; }
    const action = `${req.baseUrl}/${encodeURIComponent(req.params.token)}`;
    if (v.answer === 'no') return page(res, 200, { lang: ctx.lang, title: p.noTitle, lines: [about, p.noText], button: p.noBtn, action, tone: 'warn' });
    return page(res, 200, { lang: ctx.lang, title: p.yesTitle, lines: [about, p.yesText], button: t.yes, action });
  } catch (e) {
    logger.error('[sitterFree1011] GET', e);
    return failPage(res, 'error', browserLang(req));
  }
});

router.post('/:token', async (req, res) => {
  try {
    const svc = require('../services/sitterFree1011');
    const v = svc.verifyAnswerLink(req.params.token);
    if (!v.ok) return failPage(res, v.reason, browserLang(req));
    const ctx = await context(v, req);
    if (ctx.mismatch) return failPage(res, 'invalid', ctx.lang);
    const p = pageText(ctx.lang);
    const r = v.answer === 'no'
      ? await svc.answerNo({ applicationId: v.applicationId, providerId: v.providerId })
      : await svc.answerYes({ applicationId: v.applicationId, providerId: v.providerId });
    if (!r.ok) return failPage(res, r.reason, ctx.lang);
    if (r.answer === 'no') return page(res, 200, { lang: ctx.lang, title: p.thanksNo });
    return page(res, 200, { lang: ctx.lang, title: p.thanksYes, lines: [r.ownerTold ? p.ownerTold : ''] });
  } catch (e) {
    logger.error('[sitterFree1011] POST', e);
    return failPage(res, 'error', browserLang(req));
  }
});

module.exports = router;
