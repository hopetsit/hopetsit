'use strict';

/**
 * 607 (NEO, 02/10/2026, décision de Daniel) — PRÉVENTION de la fuite 607e :
 * à l'inscription et à la modification du profil, le serveur REFUSE une
 * « ville » qui ressemble à un e-mail, une adresse web, un numéro de téléphone
 * ou qui dépasse 60 caractères (même règle que utils/publicCity607).
 * Réponse : 400 { code: 'CITY_INVALID', error: <message dans la langue> }.
 * L'app ≥ 607 traduit le code ; les anciennes affichent leur erreur standard.
 */
const { isUnsafeCity } = require('../utils/publicCity607');

const CITY_INVALID_I18N = {
  fr: 'Cette ville n\'est pas valide : indique le nom de ta ville (pas d\'adresse e-mail, de lien ni de numéro).',
  en: 'This city isn\'t valid: enter the name of your city (no email address, link or phone number).',
  es: 'Esta ciudad no es válida: escribe el nombre de tu ciudad (sin correo electrónico, enlace ni número).',
  de: 'Diese Stadt ist ungültig: Gib den Namen deiner Stadt ein (keine E-Mail-Adresse, kein Link, keine Nummer).',
  it: 'Questa città non è valida: inserisci il nome della tua città (niente e-mail, link o numeri).',
  pt: 'Esta cidade não é válida: indica o nome da tua cidade (sem e-mail, link nem número).',
  pl: 'To miasto jest nieprawidłowe: wpisz nazwę swojego miasta (bez adresu e-mail, linku ani numeru).',
  ko: '올바른 도시가 아니에요. 도시 이름을 입력해 주세요 (이메일 주소, 링크, 전화번호 제외).',
  ja: 'この都市名は無効です。都市名を入力してください（メールアドレス、リンク、電話番号は不可）。',
};

// Routes qui écrivent la ville d'un compte (chemin sans /api/v1).
const GUARDED = [
  ['POST', /^\/auth\/(signup|google|apple|choose-service)\/?$/],
  ['PUT', /^\/users\/me\/profile\/?$/],
  ['PUT', /^\/users\/[^/]+\/profile\/?$/],
  ['PUT', /^\/sitters\/me\/profile\/?$/],
  ['PATCH', /^\/walkers\/me\/?$/],
];

function citiesIn(body) {
  if (!body || typeof body !== 'object') return [];
  const out = [];
  const take = (o) => {
    if (!o || typeof o !== 'object') return;
    for (const k of ['city', 'coverageCity']) if (typeof o[k] === 'string') out.push(o[k]);
    if (o.location && typeof o.location === 'object' && typeof o.location.city === 'string') out.push(o.location.city);
  };
  take(body);
  take(body.user);
  return out;
}

function langOf(req) {
  const b = req.body || {};
  const u = b.user || {};
  const cands = [b.appLocale, u.appLocale, b.language, u.language, String(req.headers['accept-language'] || '')];
  for (const c of cands) {
    const l = String(c || '').toLowerCase().trim().slice(0, 2);
    if (CITY_INVALID_I18N[l]) return l;
  }
  return 'en';
}

function cityGuard607(req, res, next) {
  const path = String(req.path || '').replace(/^\/api\/v1(?=\/)/, '');
  const hit = GUARDED.some(([m, rx]) => m === req.method && rx.test(path));
  if (!hit) return next();
  if (citiesIn(req.body).some(isUnsafeCity)) {
    return res.status(400).json({ code: 'CITY_INVALID', error: CITY_INVALID_I18N[langOf(req)] });
  }
  return next();
}

module.exports = { cityGuard607, CITY_INVALID_I18N, citiesIn };
