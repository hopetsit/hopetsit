/**
 * 611 (PAM, 04/10/2026) — Cam (capture de 19 h 16) : « Je suis OÙ ? ».
 * Mesuré : 136 PawPoints, profil marqué équipe (isStaff) → exclue du
 * classement public, donc absente de SA liste sans explication.
 * Règle : MA ligne est toujours rendue (`me`), sur chaque onglet :
 *   { position, pointsEarned, rank, excludedReason }
 *   · position = ma place exacte (1 + personnes devant moi), même hors des
 *     50 premiers ; null si je suis hors classement ;
 *   · excludedReason : 'staff' (compte équipe), 'test' (compte de test),
 *     'no_city' / 'no_country' (onglet « Ma ville » / « Mon pays » sans
 *     ville / pays connus) ; null sinon.
 * Les autres ne me voient toujours pas si je suis exclu.
 */
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const ranks611 = require('../services/ranks611');
const { isTestAccountEmail } = require('./testAccount2809');

async function leaderboardMe611({ userId, scope, myCity, myCountryDigits }) {
  let ids = [String(userId)];
  try {
    const got = await require('./personScope').personIds(userId);
    if (got && got.length) ids = got.map(String);
  } catch (_) { /* id seul */ }
  const mine = (await Promise.all([Owner, Sitter, Walker].map((M) => M.find({ _id: { $in: ids } })
    .select('email pawPoints isStaff').lean().catch(() => [])))).flat();
  const points = mine.reduce((m, d) => Math.max(m, Number(d.pawPoints) || 0), 0);
  const emails = new Set(mine.map((d) => String(d.email || '').toLowerCase().trim()).filter(Boolean));
  const out = { position: null, pointsEarned: points, rank: ranks611.rankFor(points), excludedReason: null };
  if (mine.some((d) => d.isStaff === true)) out.excludedReason = 'staff';
  else if (mine.some((d) => isTestAccountEmail(d.email))) out.excludedReason = 'test';
  else if (scope === 'city' && !myCity) out.excludedReason = 'no_city';
  else if (scope === 'country' && !myCountryDigits) out.excludedReason = 'no_country';
  if (out.excludedReason || points <= 0) return out;
  const ahead = new Set();
  for (const M of [Owner, Sitter, Walker]) {
    const filter = { pawPoints: { $gt: points }, isStaff: { $ne: true } };
    if (scope === 'city') filter['location.city'] = myCity;
    if (scope === 'country') filter.countryCode = new RegExp(`^\\s*\\+?\\s*${myCountryDigits}\\s*$`);
    // eslint-disable-next-line no-await-in-loop
    const docs = await M.find(filter).select('email').limit(5000).lean().catch(() => []);
    for (const d of docs) {
      const em = String(d.email || '').toLowerCase().trim();
      if (isTestAccountEmail(d.email) || emails.has(em)) continue;
      ahead.add(em || `id:${d._id}`);
    }
  }
  out.position = ahead.size + 1;
  return out;
}

module.exports = { leaderboardMe611 };
