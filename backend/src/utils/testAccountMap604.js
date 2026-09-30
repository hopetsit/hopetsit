/**
 * v604 (ZOE, 30/09/2026) — LES COMPTES DE TEST NE SORTENT JAMAIS EN PUBLIC.
 *
 * Constat (BOB, 30/09) : +testsitter et +testwalker se sont retrouvés au
 * centre de Paris et apparaissaient comme gardien et promeneur aux vrais
 * utilisateurs parisiens. Certaines routes filtraient déjà les `+test`, mais
 * chacune à sa façon (regex Mongo sur l'e-mail en clair, oubli sur d'autres).
 *
 * Règle unique, appliquée APRÈS lecture (jamais par regex Mongo : un e-mail
 * stocké chiffré ne matcherait pas) :
 *   · un compte dont l'e-mail (déchiffré si besoin) contient « +test » est un
 *     compte de test (utils/testAccount2809.js) ;
 *   · il n'apparaît pour PERSONNE dans les listes publiques (gardiens et
 *     promeneurs autour de moi, listes, couche PawMap, recherche) et n'est
 *     jamais compté dans l'offre (« N gardiens à Paris ») ;
 *   · exceptions : lui-même, et ses AMIS (entre amis on voit toujours l'autre).
 * Seuls les comptes `+test` sont concernés (pas le compte de Daniel, ni
 * hopetsit@ — ceux-là restent gérés par leurs règles existantes).
 */
const { isTestAccountEmail } = require('./testAccount2809');

const idOf = (d) => (d ? String(d._id || d.id || '') : '');

/** Le document (Owner/Sitter/Walker, lean ou non) est-il un compte de test ? */
function isTestAccountDoc(doc) {
  return !!doc && isTestAccountEmail(doc.email);
}

/**
 * Le lecteur peut-il voir ce compte ? Vrai pour tout compte normal ; pour un
 * compte de test, seulement s'il s'agit du lecteur lui-même ou d'un ami.
 * @param {object} doc
 * @param {{viewerIds?:Set<string>, friendIds?:Set<string>}} [ctx]
 */
function testAccountVisibleTo(doc, { viewerIds, friendIds } = {}) {
  if (!isTestAccountDoc(doc)) return true;
  const id = idOf(doc);
  if (!id) return false;
  if (viewerIds && viewerIds.has(id)) return true;
  if (friendIds && friendIds.has(id)) return true;
  return false;
}

/**
 * Post-filtre d'une liste. [pick] extrait le document de chaque élément
 * (par défaut l'élément lui-même).
 */
function hideTestAccounts(items, ctx = {}, pick = (x) => x) {
  return (items || []).filter((x) => testAccountVisibleTo(pick(x), ctx));
}

module.exports = { isTestAccountDoc, testAccountVisibleTo, hideTestAccounts };
