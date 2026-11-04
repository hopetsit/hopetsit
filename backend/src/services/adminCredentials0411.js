// 04/11 (BOB) — Daniel : « c possible de voir et modifier email et mot de passe, à ajouter
// dans admin ? ». VOIR le mot de passe est impossible : il est stocké chiffré (bcrypt), même
// l'admin ne peut pas le relire. On peut en revanche le REMPLACER. (L'e-mail se corrige déjà
// par PATCH /admin/users/:role/:id/email, v562.)
// Le nouveau mot de passe vaut pour la PERSONNE : ses profils propriétaire / gardien /
// promeneur (même e-mail ou même oldId), comme le badge staff. Il passe par save() pour être
// chiffré par le hook du modèle (un updateMany l'enregistrerait en clair).
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');

const MODELS = { owner: Owner, sitter: Sitter, walker: Walker };

function fail(status, message) {
  const e = new Error(message);
  e.status = status;
  return e;
}

async function setPassword(role, id, password) {
  const pwd = typeof password === 'string' ? password : '';
  if (pwd.length < 8) throw fail(400, 'Le mot de passe doit faire au moins 8 caractères.');
  if (pwd.length > 128) throw fail(400, 'Mot de passe trop long (128 caractères au plus).');
  const Model = MODELS[role];
  if (!Model) throw fail(400, 'Rôle invalide.');
  let target = null;
  try { target = await Model.findById(id).select('email oldId').lean(); } catch (_) { target = null; }
  if (!target) throw fail(404, 'Utilisateur introuvable.');
  const or = [{ _id: target._id }];
  if (target.email) or.push({ email: String(target.email).toLowerCase() });
  if (target.oldId) or.push({ oldId: target.oldId });
  const lists = await Promise.all([Owner, Sitter, Walker].map((M) => M.find({ $or: or })));
  for (const doc of lists.flat()) {
    doc.password = pwd;
    await doc.save({ validateModifiedOnly: true });
  }
  return { ok: true, profiles: { owner: lists[0].length, sitter: lists[1].length, walker: lists[2].length } };
}

module.exports = { setPassword };
