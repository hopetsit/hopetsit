/**
 * personName.js — v575
 *
 * « Dans mon profil j'ai que "nom" et pas "nom et prénom" » (Daniel, 21/09/2026).
 *
 * Le projet n'a JAMAIS eu que `name` (un seul champ) sur Owner / Sitter /
 * Walker, et ce champ est la source d'affichage PARTOUT : cartes, chat,
 * réservations, factures, e-mails, notifications, site, admin. On ne peut donc
 * pas le remplacer — on l'ENCADRE :
 *
 *   • `firstName` et `lastName` sont ajoutés aux trois schémas, optionnels ;
 *   • quand l'app les envoie, `name` est recalculé (« Prénom Nom », espaces
 *     simples) : rien d'autre dans le code n'a besoin de changer ;
 *   • quand une ANCIENNE app n'envoie que `name`, on met `name` à jour et on
 *     re-dérive `firstName` / `lastName` ;
 *   • pour un compte historique qui n'a que `name`, le découpage par défaut
 *     (1er mot = prénom, le reste = nom) est calculé À LA LECTURE et n'est PAS
 *     écrit en base tant que l'utilisateur n'a rien enregistré — aucune
 *     migration de données de production.
 *
 * Le nom LÉGAL des factures est un champ séparé (`billingInfo.legalName`,
 * cf. `utils/billingInfo.js`) : il n'est jamais touché ici.
 */

const squash = (v) => String(v == null ? '' : v).replace(/\s+/g, ' ').trim();

/**
 * Découpe un nom complet : 1er mot = prénom, le reste = nom.
 * Un seul mot ⇒ prénom seul (lastName vide).
 */
const splitFullName = (fullName) => {
  const clean = squash(fullName);
  if (!clean) return { firstName: '', lastName: '' };
  const parts = clean.split(' ');
  if (parts.length === 1) return { firstName: parts[0], lastName: '' };
  return { firstName: parts[0], lastName: parts.slice(1).join(' ') };
};

/** « Prénom Nom », sans espace parasite si l'un des deux manque. */
const joinFullName = (firstName, lastName) =>
  squash(`${squash(firstName)} ${squash(lastName)}`);

/**
 * Calcule le trio { name, firstName, lastName } à écrire, à partir du corps de
 * requête et du document courant. Renvoie `null` si la requête ne parle pas du
 * nom (aucun des trois champs fourni).
 *
 * Règles :
 *  - `firstName` et/ou `lastName` fournis (app ≥ 575) ⇒ ils font foi et
 *    `name` est recalculé. Le champ non fourni garde sa valeur actuelle (ou,
 *    pour un compte historique, sa valeur dérivée de `name`).
 *  - seul `name` fourni (ancienne app, site) ⇒ `name` est pris tel quel et
 *    `firstName`/`lastName` sont re-dérivés.
 *  - un nom complet vide est refusé (`name` est `required` dans les schémas) :
 *    la fonction lève, l'appelant renvoie 400.
 */
const buildNameUpdate = (body = {}, currentDoc = {}) => {
  const hasFirst = Object.prototype.hasOwnProperty.call(body, 'firstName');
  const hasLast = Object.prototype.hasOwnProperty.call(body, 'lastName');
  const hasName = Object.prototype.hasOwnProperty.call(body, 'name');
  if (!hasFirst && !hasLast && !hasName) return null;

  const derived = deriveNameParts(currentDoc);

  if (hasFirst || hasLast) {
    const firstName = squash(hasFirst ? body.firstName : derived.firstName);
    const lastName = squash(hasLast ? body.lastName : derived.lastName);
    const name = joinFullName(firstName, lastName);
    if (!name) throw new Error('Name must be a non-empty string.');
    return { name, firstName, lastName };
  }

  // Ancienne app / site : seul `name` est envoyé.
  if (typeof body.name !== 'string') throw new Error('Name must be a non-empty string.');
  const name = squash(body.name);
  if (!name) throw new Error('Name must be a non-empty string.');
  const parts = splitFullName(name);
  return { name, firstName: parts.firstName, lastName: parts.lastName };
};

/**
 * Prénom / nom d'un document, dérivés de `name` quand les champs sont vides.
 * Lecture seule : n'écrit rien.
 */
const deriveNameParts = (doc = {}) => {
  const firstName = squash(doc && doc.firstName);
  const lastName = squash(doc && doc.lastName);
  if (firstName || lastName) return { firstName, lastName };
  return splitFullName(doc && doc.name);
};

/**
 * Complète `firstName` / `lastName` dans un objet de réponse déjà sérialisé,
 * sans rien persister. Utilisé par `sanitizeUser`.
 */
const withDerivedNameParts = (out) => {
  if (!out || typeof out !== 'object') return out;
  const { firstName, lastName } = deriveNameParts(out);
  out.firstName = firstName;
  out.lastName = lastName;
  return out;
};

/** L'élément « nom » de la complétion de profil est-il rempli ? */
const hasFullName = (doc = {}) => {
  const { firstName, lastName } = deriveNameParts(doc);
  return !!firstName && !!lastName;
};

module.exports = {
  splitFullName,
  joinFullName,
  buildNameUpdate,
  deriveNameParts,
  withDerivedNameParts,
  hasFullName,
};
