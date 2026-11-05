/**
 * 0511 (BOB, plan validé par Daniel « tout », bloc B4) — « QU'EST-CE QUI VOUS RETIENT ? » EN 1 CLIC.
 *
 * Mesure du 05/11 (14 j) : 46 demandes avec candidats, 15 propriétaires ont ouvert leurs candidats,
 * 0 ont choisi. On ne sait pas pourquoi. Ceci pose UNE question, 4 réponses, zéro mot de passe :
 *   GET  /owner-why?p=<postId>&t=<tag>            → page avec 4 boutons (fr/en selon `lang`)
 *   GET  /owner-why/answer?p=&t=&a=<price|dates|talk|done> → enregistre (une réponse par demande, la
 *        dernière gagne) et dit merci ; « talk » renvoie vers la page des candidats.
 *   POST /admin/owner-why/link { postId }         → l'URL signée à mettre dans l'e-mail (admin)
 *   GET  /admin/owner-why                          → les réponses (admin)
 * Le tag = HMAC(JWT_SECRET, postId) tronqué : un lien ne vaut que pour sa demande. Aucune donnée
 * personnelle dans l'URL. Rien n'est envoyé d'ici : l'e-mail part par /admin/promo/send-campaign.
 */
const express = require('express');
const crypto = require('crypto');
const mongoose = require('mongoose');
const { requireAuth, requireRole } = require('../middleware/auth');
const { auditAdmin } = require('../middleware/auditAdmin');

const requireAdmin = [requireAuth, requireRole('admin'), auditAdmin];

const ANSWERS = ['price', 'dates', 'talk', 'done'];

const schema = new mongoose.Schema({
  postId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true, unique: true },
  answer: { type: String, enum: ANSWERS, required: true },
  lang: { type: String, default: 'fr' },
  answeredAt: { type: Date, default: Date.now },
  history: [{ answer: String, at: Date }],
}, { collection: 'ownerwhy0511' });
const OwnerWhy = mongoose.models.OwnerWhy0511 || mongoose.model('OwnerWhy0511', schema);

const tagFor = (postId) => crypto.createHmac('sha256', String(process.env.JWT_SECRET || 'hopetsit'))
  .update(`why0511:${postId}`).digest('hex').slice(0, 16);
const okTag = (postId, t) => {
  const a = Buffer.from(tagFor(postId)); const b = Buffer.from(String(t || ''));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
};
const esc = (x) => String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

const T = {
  fr: {
    title: 'Qu\'est-ce qui vous retient ?',
    sub: 'Des gardiens ont répondu à votre demande. Une seule question, un seul clic : ça nous aide à faire mieux.',
    price: 'C\'est trop cher', dates: 'Mes dates ne sont pas sûres', talk: 'Je veux parler au gardien d\'abord', done: 'Je n\'ai plus besoin de garde',
    thanks: 'Merci, c\'est noté.', talkNote: 'Vous pouvez poser votre question au gardien depuis la page de vos candidats.',
    back: 'Voir mes candidats',
  },
  en: {
    title: 'What is holding you back?',
    sub: 'Sitters replied to your request. One question, one click: it helps us do better.',
    price: 'It is too expensive', dates: 'My dates are not sure yet', talk: 'I want to talk to the sitter first', done: 'I no longer need a sitter',
    thanks: 'Thank you, noted.', talkNote: 'You can ask the sitter a question from your candidates page.',
    back: 'See my candidates',
  },
};
const langOf = (q) => (String(q.lang || '').toLowerCase().startsWith('en') ? 'en' : 'fr');

function page(lang, inner) {
  return `<!doctype html><html lang="${lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>HoPetSit</title>
<style>body{margin:0;background:#FFF6F2;font-family:-apple-system,Segoe UI,Roboto,sans-serif;color:#231715}main{max-width:520px;margin:0 auto;padding:32px 20px}h1{font-size:24px;margin:0 0 8px}p{font-size:16px;line-height:1.5;color:#6E4F48;margin:0 0 20px}a.b{display:block;margin:10px 0;padding:16px 18px;background:#fff;border:2px solid #F2D9D2;border-radius:14px;color:#231715;text-decoration:none;font-size:17px;font-weight:700}a.b:hover{border-color:#C92A12}a.p{display:inline-block;margin-top:12px;padding:14px 24px;background:#C92A12;color:#fff;border-radius:999px;text-decoration:none;font-weight:800}</style></head><body><main>${inner}</main></body></html>`;
}

const router = express.Router();

router.get('/', async (req, res) => {
  const { p, t } = req.query;
  if (!mongoose.isValidObjectId(String(p || '')) || !okTag(p, t)) return res.status(404).send('Not found');
  const lang = langOf(req.query); const L = T[lang];
  const u = (a) => `/owner-why/answer?p=${encodeURIComponent(String(p))}&t=${encodeURIComponent(String(t))}&a=${a}&lang=${lang}`;
  res.set('Cache-Control', 'no-store');
  return res.send(page(lang, `<h1>${esc(L.title)}</h1><p>${esc(L.sub)}</p>${ANSWERS.map((a) => `<a class="b" href="${u(a)}">${esc(L[a])}</a>`).join('')}`));
});

router.get('/answer', async (req, res) => {
  const { p, t, a } = req.query;
  if (!mongoose.isValidObjectId(String(p || '')) || !okTag(p, t) || !ANSWERS.includes(String(a))) return res.status(404).send('Not found');
  const lang = langOf(req.query); const L = T[lang];
  const now = new Date();
  await OwnerWhy.updateOne({ postId: p }, { $set: { answer: String(a), lang, answeredAt: now }, $push: { history: { answer: String(a), at: now } } }, { upsert: true });
  const { BASE_URL } = require('../utils/emailLinkBuilder');
  const extra = String(a) === 'talk' ? `<p>${esc(L.talkNote)}</p><a class="p" href="${BASE_URL}/posts?from=why">${esc(L.back)}</a>` : '';
  res.set('Cache-Control', 'no-store');
  return res.send(page(lang, `<h1>${esc(L.thanks)}</h1>${extra}`));
});

const adminRouter = express.Router();
adminRouter.post('/link', requireAdmin, async (req, res) => {
  const postId = String((req.body && req.body.postId) || '');
  if (!mongoose.isValidObjectId(postId)) return res.status(400).json({ error: 'postId' });
  const lang = langOf(req.body || {});
  // Le lien passe par le SERVEUR (pas le site) : pas de page Next à publier. Render expose RENDER_EXTERNAL_URL.
  const base = String(process.env.RENDER_EXTERNAL_URL || 'https://hopetsit-backend.onrender.com').replace(/\/$/, '');
  return res.json({ url: `${base}/owner-why?p=${postId}&t=${tagFor(postId)}&lang=${lang}`, tag: tagFor(postId) });
});
adminRouter.get('/', requireAdmin, async (req, res) => {
  const rows = await OwnerWhy.find({}).sort({ answeredAt: -1 }).limit(500).lean();
  const counts = {}; rows.forEach((r) => { counts[r.answer] = (counts[r.answer] || 0) + 1; });
  return res.json({ total: rows.length, counts, rows });
});

module.exports = router;
module.exports.adminRouter = adminRouter;
module.exports.tagFor = tagFor;
module.exports.OwnerWhy = OwnerWhy;
module.exports.ANSWERS = ANSWERS;
