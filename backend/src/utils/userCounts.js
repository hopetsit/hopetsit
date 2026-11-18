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

const DAY_MS = 86400000;

/**
 * 15/11/2026 (BOB, demande de Daniel) — « le VRAI nombre de gens à jour dans
 * l'app, en comptant les désinscrits ». Fonction PURE.
 *
 *   inscrits depuis le début = comptes présents + comptes désinscrits
 *   présents aujourd'hui     = comptes encore en base (une suppression efface
 *                              le compte : il n'est donc plus compté)
 *
 * Les désinscriptions viennent du journal DeletedAccount (tenu depuis la v530) :
 * un compte restauré n'est pas une désinscription ; les comptes de test /
 * internes sont exclus des deux côtés, avec la même règle que summarizeUsers.
 *
 * @param {{accounts: Array<{role:string,email:string,createdAt?:Date,verified?:boolean,status?:string,adLead?:boolean,lastSeenAt?:Date}>,
 *          deletions: Array<{role?:string,email?:string,deletedAt?:Date,source?:string,restoredAt?:Date}>, now?: Date}} p
 */
function summarizeMembers({ accounts = [], deletions = [], now = new Date() } = {}) {
  const t = now.getTime();
  const since = (d, days) => { const x = d ? new Date(d).getTime() : NaN; return Number.isFinite(x) && t - x <= days * DAY_MS; };
  const real = accounts.filter((a) => !isInternalEmail(a.email));
  const gone = deletions.filter((d) => !d.restoredAt && !isInternalEmail(d.email));
  const byRole = (list, role) => list.filter((x) => x.role === role).length;
  const blocked = real.filter((a) => a.status === 'suspended' || a.status === 'banned');
  const verified = real.filter((a) => a.verified === true);
  const unverified = real.filter((a) => a.verified !== true);
  const firstDeletion = gone.reduce((m, d) => {
    const x = d.deletedAt ? new Date(d.deletedAt).getTime() : NaN;
    return Number.isFinite(x) && (m === null || x < m) ? x : m;
  }, null);
  const win = (days) => {
    const joined = real.filter((a) => since(a.createdAt, days)).length;
    const left = gone.filter((d) => since(d.deletedAt, days)).length;
    // Un compte créé puis supprimé dans la période a aussi été « inscrit ».
    return { joined, left, net: joined - left };
  };
  // 18/11/2026 (BOB, demande de Daniel) — identités vérifiées (pièce d'identité), à côté des e-mails vérifiés.
  // « offerte » = vérification gratuite du 17/11 (kycPaymentIntentId « free_… ») ; « payée » = 3 € encaissés
  // (kycPaidAt) ; le reste a été validé à la main par l'admin. Un même compte n'est compté qu'une fois.
  const idOk = real.filter((a) => a.kycStatus === 'verified');
  const idFree = idOk.filter((a) => a.kycFree === true);
  const idPaid = idOk.filter((a) => a.kycFree !== true && a.kycPaid === true);
  const identity = {
    verified: idOk.length,
    free: idFree.length,
    paid: idPaid.length,
    other: idOk.length - idFree.length - idPaid.length,
    byRole: { owners: byRole(idOk, 'owner'), sitters: byRole(idOk, 'sitter'), walkers: byRole(idOk, 'walker') },
    inProgress: real.filter((a) => a.kycStatus === 'pending_verification').length,
    stoppedAtPayment: real.filter((a) => a.kycStatus === 'pending_payment').length,
    d1: idOk.filter((a) => since(a.kycVerifiedAt, 1)).length,
    d7: idOk.filter((a) => since(a.kycVerifiedAt, 7)).length,
  };
  return {
    identity,
    current: real.length,
    everRegistered: real.length + gone.length,
    deleted: gone.length,
    deletedByUser: gone.filter((d) => d.source !== 'admin').length,
    deletedByAdmin: gone.filter((d) => d.source === 'admin').length,
    deletedByRole: { owners: byRole(gone, 'owner'), sitters: byRole(gone, 'sitter'), walkers: byRole(gone, 'walker') },
    deletionsSince: firstDeletion === null ? null : new Date(firstDeletion).toISOString(),
    verified: verified.length,
    unverified: unverified.length,
    unverifiedAdLead: unverified.filter((a) => a.adLead === true).length,
    verifiedByRole: { owners: byRole(verified, 'owner'), sitters: byRole(verified, 'sitter'), walkers: byRole(verified, 'walker') },
    blocked: blocked.length,
    seen30d: real.filter((a) => since(a.lastSeenAt, 30)).length,
    seen7d: real.filter((a) => since(a.lastSeenAt, 7)).length,
    d1: win(1), d7: win(7), d30: win(30),
  };
}

/** Lit les 3 rôles (e-mails déchiffrés) + le journal des désinscriptions et renvoie le résumé. */
async function countUsers({ Owner, Sitter, Walker, decrypt, DeletedAccount = null, now = new Date() }) {
  const plain = (v) => { try { return decrypt(v || '') || ''; } catch (_) { return ''; } };
  const read = async (Model, role) => (await Model.find({}).select('email createdAt verified status adLeadAt lastSeenAt kycStatus kycPaidAt kycPaymentIntentId kycVerifiedAt').lean())
    .map((u) => ({ role, email: plain(u.email), createdAt: u.createdAt, verified: u.verified === true,
      status: u.status || 'active', adLead: Boolean(u.adLeadAt), lastSeenAt: u.lastSeenAt || null,
      kycStatus: u.kycStatus || 'none', kycFree: /^free_/.test(String(u.kycPaymentIntentId || '')),
      kycPaid: Boolean(u.kycPaidAt), kycVerifiedAt: u.kycVerifiedAt || null }));
  const [o, s, w] = await Promise.all([read(Owner, 'owner'), read(Sitter, 'sitter'), read(Walker, 'walker')]);
  const out = summarizeUsers({ owners: o.map((a) => a.email), sitters: s.map((a) => a.email), walkers: w.map((a) => a.email) });
  // Best-effort : sans journal lisible, les compteurs de base restent servis.
  try {
    let deletions = [];
    if (DeletedAccount) {
      deletions = await DeletedAccount.find({}).select('role email deletedAt source restoredAt').lean();
    }
    out.members = summarizeMembers({ accounts: [...o, ...s, ...w], deletions, now });
    out.members.journal = Boolean(DeletedAccount);
  } catch (_) { out.members = null; }
  return out;
}

module.exports = { INTERNAL_EMAIL_RE, isInternalEmail, summarizeUsers, summarizeMembers, countUsers };
