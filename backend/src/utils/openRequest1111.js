/**
 * 11/11/2026 (BOB, ordre de Daniel : « côté gardien et promeneur, sur la PawMap et le profil, les annonces
 * dont la date de commencement est dépassée ne doivent plus s'afficher »).
 *
 * UNE règle pour dire si une demande est encore proposée aux prestataires, d'après ses dates :
 *   • AVANT : visible tant que la date de FIN n'était pas passée (une garde commencée restait proposée) ;
 *   • MAINTENANT : visible jusqu'à la fin du JOUR de début. Les dates sont enregistrées à minuit (jour seul,
 *     sans fuseau) : on laisse donc une marge de 30 h après ce minuit pour que la demande « pour aujourd'hui »
 *     reste visible toute la journée, y compris aux États-Unis (avant, elle disparaissait dès minuit UTC).
 *   • sans date de début : on regarde la date de fin ; sans aucune date (« dates à prévoir ») : toujours visible.
 *
 * Coupe-circuit sans redéploiement de code : REQUEST_HIDE_STARTED_1111=off → ancienne règle (date de fin).
 * Marge réglable : REQUEST_START_GRACE_H_1111 (heures, 0 à 72, défaut 30).
 * Ne touche PAS à ce que voit le propriétaire (« mes annonces ») ni à l'admin.
 */
const enabled = () => String(process.env.REQUEST_HIDE_STARTED_1111 || '').trim().toLowerCase() !== 'off';

const graceMs = () => {
  const raw = process.env.REQUEST_START_GRACE_H_1111;
  const h = raw === undefined || raw === '' ? NaN : Number(raw);
  return (Number.isFinite(h) && h >= 0 && h <= 72 ? h : 30) * 3600000;
};

/** Clauses `$or` Mongo : la demande est encore ouverte d'après ses dates. */
function dateOpenOr(now = new Date()) {
  if (!enabled()) {
    return [
      { endDate: { $gte: now } },
      { endDate: { $in: [null] }, startDate: { $gte: now } },
      { endDate: { $in: [null] }, startDate: { $in: [null] } },
    ];
  }
  const cut = new Date(now.getTime() - graceMs());
  return [
    { startDate: { $gte: cut } },
    { startDate: { $in: [null] }, endDate: { $gte: cut } },
    { startDate: { $in: [null] }, endDate: { $in: [null] } },
  ];
}

/** Même règle sur un document déjà chargé. */
function isDateOpen(post, now = new Date()) {
  const d = (v) => { if (!v) return null; const x = new Date(v); return Number.isNaN(x.getTime()) ? null : x; };
  const s = d(post && post.startDate); const e = d(post && post.endDate);
  if (!enabled()) {
    if (e) return e >= now;
    if (s) return s >= now;
    return true;
  }
  const cut = now.getTime() - graceMs();
  if (s) return s.getTime() >= cut;
  if (e) return e.getTime() >= cut;
  return true;
}

module.exports = { enabled, graceMs, dateOpenOr, isDateOpen };
