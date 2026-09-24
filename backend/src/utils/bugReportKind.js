/**
 * v585 (lot D du chantier du 24/09) — « Boîte à idées » de Daniel (25/09).
 *
 * Une seule entrée « Une idée ? Un problème ? » dans l'app et sur le site :
 * elle passe par le circuit de signalement DÉJÀ existant (`POST /bug-reports`,
 * modèle BugReport) avec une étiquette `kind` :
 *   · 'bug'  = un problème (défaut, comme avant : les anciennes apps n'envoient
 *              pas de `kind`) ;
 *   · 'idea' = une idée.
 * Aucune nouvelle route. Les règles pures sont ici pour être testées par jest
 * sans base ni réseau.
 */

const KINDS = ['bug', 'idea'];

/** Statuts historiques d'un bug (inchangés). */
const BUG_STATUSES = ['open', 'in_progress', 'fixed', 'wontfix', 'duplicate'];

/** Statuts d'une idée : nouvelle (open) / retenue (kept) / faite (done). */
const IDEA_STATUSES = ['open', 'kept', 'done', 'wontfix', 'duplicate'];

/** Tout statut accepté par le schéma. */
const ALL_STATUSES = Array.from(new Set([...BUG_STATUSES, ...IDEA_STATUSES]));

/**
 * Étiquette normalisée depuis ce que le client envoie. « problem » (le choix
 * du formulaire) et tout inconnu = 'bug', pour ne rien casser.
 */
function normalizeKind(raw) {
  const k = String(raw || '')
    .trim()
    .toLowerCase();
  if (k === 'idea' || k === 'idée' || k === 'idee') return 'idea';
  return 'bug';
}

/** Longueur minimale de la description : 10 pour un bug, 3 pour une idée. */
function minDescriptionLength(kind) {
  return kind === 'idea' ? 3 : 10;
}

/** Un statut est-il permis pour cette étiquette ? */
function isValidStatus(kind, status) {
  const list = kind === 'idea' ? IDEA_STATUSES : BUG_STATUSES;
  return list.includes(String(status || ''));
}

/** Sujet de l'e-mail envoyé à la boîte HoPetSit. */
function mailSubject(doc) {
  const tag = doc.kind === 'idea' ? 'idée' : 'bug';
  return `[HoPetSit ${tag}] ${doc.title || doc._id}`;
}

/** Filtre Mongo pour l'admin : `?kind=idea|bug`, sinon tout. */
function kindFilter(raw) {
  const k = String(raw || '')
    .trim()
    .toLowerCase();
  if (k === 'idea') return { kind: 'idea' };
  // Les documents d'avant le lot D n'ont pas de `kind` : ils sont des bugs.
  if (k === 'bug') return { $or: [{ kind: 'bug' }, { kind: { $exists: false } }] };
  return {};
}

/**
 * Filtre de la liste admin depuis `req.query` (`kind`, `status`).
 * Le compteur « ouverts » de l'admin ne compte que les BUGS ouverts ; les
 * idées nouvelles ont leur propre compteur (`ideaOpenFilter`).
 */
function adminListFilter(query) {
  const q = query || {};
  const filter = { ...kindFilter(q.kind) };
  if (q.status) filter.status = String(q.status);
  return {
    filter,
    bugOpenFilter: { status: 'open', ...kindFilter('bug') },
    ideaOpenFilter: { status: 'open', kind: 'idea' },
  };
}

/**
 * Mise à jour admin depuis `req.body` (`status`, `adminNote`).
 * Renvoie `{ error }` (statut inconnu) ou `{ update }`.
 */
function adminUpdateFromBody(body) {
  const b = body || {};
  const update = {};
  if (b.status) {
    if (!ALL_STATUSES.includes(String(b.status))) {
      return { error: 'Unknown status.' };
    }
    update.status = String(b.status);
  }
  if (typeof b.adminNote === 'string') update.adminNote = b.adminNote;
  return { update };
}

module.exports = {
  adminListFilter,
  adminUpdateFromBody,
  KINDS,
  BUG_STATUSES,
  IDEA_STATUSES,
  ALL_STATUSES,
  normalizeKind,
  minDescriptionLength,
  isValidStatus,
  mailSubject,
  kindFilter,
};
