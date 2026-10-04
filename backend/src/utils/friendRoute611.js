/**
 * 611 (PAM, décision BOB du 04/10) — ITINÉRAIRE VERS UN AMI : GRATUIT.
 * Le calcul passe par Valhalla / OSRM publics (sans coût). Seul l'itinéraire
 * vers les spots et les lieux reste un avantage d'abonnement.
 * `friendRouteCheck({ userId, friendId, toLat, toLng })` :
 *   · ami ACCEPTÉ (3 profils = une personne, même source que la règle A) ;
 *   · la destination doit être la position de l'ami VISIBLE pour moi (son
 *     direct, sinon sa vraie position de profil), à ~100 m près ;
 * → { ok:true } ; { ok:false, status:403, code } sinon.
 */
const mapVisibility = require('./mapVisibility');

const TOLERANCE_M = 100;

function metersBetween(aLat, aLng, bLat, bLng) {
  const R = 6371000;
  const r = (d) => (d * Math.PI) / 180;
  const dLat = r(bLat - aLat);
  const dLng = r(bLng - aLng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(r(aLat)) * Math.cos(r(bLat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

async function friendRouteCheck({ userId, friendId, toLat, toLng }) {
  const fid = String(friendId || '');
  if (!/^[a-f0-9]{24}$/i.test(fid)) return { ok: false, status: 403, code: 'NOT_A_FRIEND' };
  const friends = await mapVisibility.friendIdsOf(userId);
  if (!friends.has(fid)) return { ok: false, status: 403, code: 'NOT_A_FRIEND' };
  const { personIds } = require('./personScope');
  const ids = (await personIds(fid)).map(String);
  const points = [];
  // son direct en cours
  try {
    const s = require('../sockets/mapSocket').getLiveSessionForIds(ids);
    if (s && Number.isFinite(s.lat) && Number.isFinite(s.lng)) points.push([s.lat, s.lng]);
  } catch (_) { /* pas de direct */ }
  // sa vraie position de profil (règle A), sauf « Masqué »
  const entries = [];
  for (const [name, role] of [['Owner', 'owner'], ['Sitter', 'sitter'], ['Walker', 'walker']]) {
    // eslint-disable-next-line no-await-in-loop
    const docs = await require(`../models/${name}`).find({ _id: { $in: ids } })
      .select('location preferences.mapVisibility preferences.hideFromMap +homeLocation city updatedAt createdAt email')
      .lean().catch(() => []);
    for (const d of docs) entries.push({ d, role });
  }
  try {
    const fp = require('./friendPosition587').friendPositionOf(entries);
    if (fp.location && Array.isArray(fp.location.coordinates)) {
      points.push([fp.location.coordinates[1], fp.location.coordinates[0]]);
    }
  } catch (_) { /* aucune position */ }
  const ok = points.some(([la, ln]) => metersBetween(la, ln, toLat, toLng) <= TOLERANCE_M);
  return ok ? { ok: true } : { ok: false, status: 403, code: 'FRIEND_POSITION_MISMATCH' };
}

module.exports = { friendRouteCheck, TOLERANCE_M };
