/**
 * v589 — Compteurs d'utilisateurs du tableau de bord admin.
 *
 * Daniel : « les compteurs Propriétaires / Gardiens / Promeneurs doivent être
 * JUSTES » + « Utilisateurs au total » en tête.
 *
 * RÈGLE (la même pour les 3 rôles, et reprise à l'identique par le filtre
 * « Vrais utilisateurs » de l'onglet Utilisateurs) :
 *   - un compte supprimé n'existe plus en base (suppression physique, voir
 *     /admin/deleted-accounts) → rien à exclure de ce côté ;
 *   - sont EXCLUS les comptes internes : e-mail contenant « +test », sonde
 *     technique « @invalid.example », et adresses de la maison
 *     (« dadaciao84@… », « hopetsit@… ») — même motif que supplyRoutes ;
 *   - sont GARDÉS : le staff (de vraies personnes avec Premium offert), les
 *     profils masqués de la vitrine, les comptes suspendus (toujours inscrits).
 *
 * Personnes uniques : une même personne peut avoir un profil propriétaire ET
 * gardien ET promeneur (même e-mail). On compte les e-mails distincts.
 *
 * Fonctions PURES (testées sans base) sauf `countUsers`, qui lit les 3 modèles.
 */

const INTERNAL_EMAIL_RE = /(\+test|^hopetsit@|^dadaciao84@|@invalid\.example)/i;

const normEmail = (e) => String(e || '').trim().toLowerCase();

function isInternalEmail(email) {
  return INTERNAL_EMAIL_RE.test(normEmail(email));
}

/**
 * @param {{owners: string[], sitters: string[], walkers: string[]}} emails
 *        e-mails EN CLAIR de chaque rôle (un élément par compte)
 */
function summarizeUsers({ owners = [], sitters = [], walkers = [] } = {}) {
  const roles = { owners, sitters, walkers };
  const out = { excluded: {}, raw: {} };
  const people = new Map(); // e-mail → nombre de rôles
  let noEmail = 0;
  for (const [role, list] of Object.entries(roles)) {
    const kept = list.filter((e) => !isInternalEmail(e));
    out[role] = kept.length;
    out.raw[role] = list.length;
    out.excluded[role] = list.length - kept.length;
    const seen = new Set();
    for (const e of kept) {
      const k = normEmail(e);
      if (!k) { noEmail += 1; continue; } // sans e-mail lisible : personne à part
      if (seen.has(k)) continue;
      seen.add(k);
      people.set(k, (people.get(k) || 0) + 1);
    }
  }
  out.total = out.owners + out.sitters + out.walkers;
  out.excluded.total = out.excluded.owners + out.excluded.sitters + out.excluded.walkers;
  out.raw.total = out.raw.owners + out.raw.sitters + out.raw.walkers;
  out.people = people.size + noEmail;
  out.multiRole = [...people.values()].filter((n) => n > 1).length;
  out.rule = 'hors comptes de test (+test), sonde @invalid.example et adresses internes (dadaciao84@, hopetsit@) ; staff et profils masqués comptés';
  return out;
}

/** Lit les e-mails des 3 rôles (déchiffrés) et renvoie le résumé. */
async function countUsers({ Owner, Sitter, Walker, decrypt }) {
  const plain = (v) => { try { return decrypt(v || '') || ''; } catch (_) { return ''; } };
  const read = async (Model) => (await Model.find({}).select('email').lean())
    .map((u) => plain(u.email));
  const [owners, sitters, walkers] = await Promise.all([read(Owner), read(Sitter), read(Walker)]);
  return summarizeUsers({ owners, sitters, walkers });
}

module.exports = { INTERNAL_EMAIL_RE, isInternalEmail, summarizeUsers, countUsers };
