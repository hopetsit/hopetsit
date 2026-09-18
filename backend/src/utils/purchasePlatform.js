'use strict';

/**
 * v566 — plateforme d'origine d'un achat boutique (ios | android | web).
 * L'app envoie `X-App-Platform` depuis le build 565 ; le site envoie
 * `X-App-Version: web`. Anciennes apps : '' (inconnu) — on n'invente rien.
 */
function platformFromRequest(req) {
  const h = (name) => String((req && req.headers && req.headers[name]) || '').trim().toLowerCase();
  const platform = h('x-app-platform');
  if (platform === 'ios' || platform === 'android' || platform === 'web') return platform;
  if (h('x-app-version') === 'web') return 'web';
  return '';
}

function normalizePlatform(raw) {
  const p = String(raw || '').trim().toLowerCase();
  return p === 'ios' || p === 'android' || p === 'web' ? p : '';
}

module.exports = { platformFromRequest, normalizePlatform };
