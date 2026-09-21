const mongoose = require('mongoose');

const Block = require('../models/Block');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const { sanitizeDoc, sanitizeUser } = require('../utils/sanitize');
const logger = require('../utils/logger');
// v576 — Daniel : « blocage valable pour la personne entière ». Un blocage
// était enregistré par COUPLE DE DOCUMENTS (moi-gardien → lui-propriétaire) :
// il ne s'appliquait plus dès que l'un des deux changeait de profil, et la
// liste « Bloqués » se vidait en changeant de rôle. On lit et on retire
// désormais sur le groupe d'identité des DEUX côtés ; l'écriture reste sur le
// document du rôle actif (aucune migration de données).
const { personIds, personIndex } = require('../utils/personScope');

const ROLE_TO_MODEL = {
  owner: 'Owner',
  sitter: 'Sitter',
  walker: 'Walker',
};

const MODEL_TO_ROLE = {
  Owner: 'owner',
  Sitter: 'sitter',
  Walker: 'walker',
};

const getModelByRole = (role) => {
  const modelName = ROLE_TO_MODEL[role];
  if (!modelName) {
    return null;
  }
  if (modelName === 'Owner') return Owner;
  if (modelName === 'Walker') return Walker;
  return Sitter;
};

const formatBlockResponse = (blockDoc) => {
  const doc = sanitizeDoc(blockDoc);
  if (blockDoc.blockedId) {
    doc.blocked = sanitizeUser(blockDoc.blockedId);
  }
  doc.blockedRole = MODEL_TO_ROLE[blockDoc.blockedModel] || 'sitter';
  delete doc.blockedId;
  delete doc.blockedModel;
  delete doc.blockerModel;
  return doc;
};

// Resolve the target of a block/unblock request from request body.
// Accepts either {targetUserId,targetRole} (preferred) or legacy
// {sitterId} / {ownerId} shapes so existing clients keep working.
const resolveTarget = (body, blockerRole) => {
  if (!body || typeof body !== 'object') {
    return { error: 'Request body is required.' };
  }

  let targetUserId = body.targetUserId || null;
  let targetRole = body.targetRole || null;

  if (!targetUserId && body.sitterId) {
    targetUserId = body.sitterId;
    targetRole = targetRole || 'sitter';
  }
  if (!targetUserId && body.ownerId) {
    targetUserId = body.ownerId;
    targetRole = targetRole || 'owner';
  }

  // If role wasn't supplied, assume the opposite of the blocker's role.
  if (!targetRole) {
    targetRole = blockerRole === 'owner' ? 'sitter' : 'owner';
  }

  if (!targetUserId || !mongoose.Types.ObjectId.isValid(targetUserId)) {
    return { error: 'A valid target user id is required.' };
  }
  if (!ROLE_TO_MODEL[targetRole]) {
    return { error: 'Target role must be "owner", "sitter" or "walker".' };
  }

  return { targetUserId, targetRole };
};

const blockUser = async (req, res) => {
  try {
    const blockerId = req.user?.id;
    const blockerRole = req.user?.role;

    if (!blockerId || !ROLE_TO_MODEL[blockerRole]) {
      return res.status(401).json({ error: 'Authentication required.' });
    }

    const resolved = resolveTarget(req.body, blockerRole);
    if (resolved.error) {
      return res.status(400).json({ error: resolved.error });
    }
    const { targetUserId, targetRole } = resolved;

    // v576 — on ne se bloque pas soi-même, y compris via un profil frère.
    const myIds = await personIds(blockerId);
    if (myIds.map(String).includes(String(targetUserId))) {
      return res.status(400).json({ error: 'You cannot block yourself.' });
    }

    const blockerModel = ROLE_TO_MODEL[blockerRole];
    const blockedModel = ROLE_TO_MODEL[targetRole];

    const BlockerModel = getModelByRole(blockerRole);
    const BlockedModel = getModelByRole(targetRole);

    const blockerExists = await BlockerModel.exists({ _id: blockerId });
    if (!blockerExists) {
      return res.status(404).json({ error: 'Blocker user not found.' });
    }
    const blockedExists = await BlockedModel.exists({ _id: targetUserId });
    if (!blockedExists) {
      return res.status(404).json({ error: 'Target user not found.' });
    }

    // v576 — idempotent à l'échelle de la PERSONNE : si j'ai déjà bloqué cet
    // humain depuis un autre de mes profils (ou l'un de ses autres profils),
    // on renvoie le blocage existant au lieu d'en créer un second.
    const targetIds = await personIds(targetUserId);
    const already = await Block.findOne({
      blockerId: { $in: myIds },
      blockedId: { $in: targetIds },
    }).populate('blockedId');
    if (already) {
      return res.status(201).json({ block: formatBlockResponse(already) });
    }

    const block = await Block.findOneAndUpdate(
      {
        blockerId,
        blockerModel,
        blockedId: targetUserId,
        blockedModel,
      },
      {
        blockerId,
        blockerModel,
        blockedId: targetUserId,
        blockedModel,
      },
      { new: true, upsert: true, setDefaultsOnInsert: true }
    ).populate('blockedId');

    res.status(201).json({ block: formatBlockResponse(block) });
  } catch (error) {
    logger.error('Block user error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid id provided.' });
    }
    res.status(500).json({ error: 'Unable to block user. Please try again later.' });
  }
};

const unblockUser = async (req, res) => {
  try {
    const blockerId = req.user?.id;
    const blockerRole = req.user?.role;

    if (!blockerId || !ROLE_TO_MODEL[blockerRole]) {
      return res.status(401).json({ error: 'Authentication required.' });
    }

    // Allow target via body OR via route param (:id) for DELETE convenience.
    const body = { ...(req.body || {}) };
    if (!body.targetUserId && req.params && req.params.id) {
      body.targetUserId = req.params.id;
    }

    const resolved = resolveTarget(body, blockerRole);
    if (resolved.error) {
      return res.status(400).json({ error: resolved.error });
    }
    const { targetUserId, targetRole } = resolved;

    const blockerModel = ROLE_TO_MODEL[blockerRole];
    const blockedModel = ROLE_TO_MODEL[targetRole];

    let result = await Block.findOneAndDelete({
      blockerId,
      blockerModel,
      blockedId: targetUserId,
      blockedModel,
    });

    // v566 — le rôle de la cible était DEVINÉ (opposé au mien) quand l'appelant
    // ne le donnait pas (`DELETE /blocks/:id`, `unblockSitter` de l'app) → 404
    // en débloquant un promeneur ou quelqu'un du même rôle que soi. Un blocage
    // est identifié par (moi, l'autre) : on retire l'entrée quel que soit le
    // modèle enregistré pour la cible.
    if (!result) {
      result = await Block.findOneAndDelete({ blockerId, blockerModel, blockedId: targetUserId });
    }

    // v576 — le blocage appartient à la PERSONNE : je dois pouvoir débloquer
    // depuis n'importe lequel de mes profils, même si le blocage avait été
    // posé depuis un autre, et même si la cible a changé de profil entretemps.
    const [myIds, targetIds] = await Promise.all([
      personIds(blockerId),
      personIds(targetUserId),
    ]);
    const extra = await Block.deleteMany({
      blockerId: { $in: myIds },
      blockedId: { $in: targetIds },
    });

    if (!result && !(extra?.deletedCount > 0)) {
      return res.status(404).json({ error: 'Block entry not found.' });
    }

    res.json({ success: true });
  } catch (error) {
    logger.error('Unblock user error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid id provided.' });
    }
    res.status(500).json({ error: 'Unable to unblock user. Please try again later.' });
  }
};

const listBlocked = async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;

    if (!userId || !ROLE_TO_MODEL[role]) {
      return res.status(401).json({ error: 'Authentication required.' });
    }

    // v576 — la liste est celle de la PERSONNE : on lit sur mes 3 profils, et
    // on n'affiche qu'UNE ligne par humain bloqué (sinon quelqu'un bloqué
    // depuis deux de mes profils apparaissait deux fois).
    const myIds = await personIds(userId);
    const blocks = await Block.find({
      blockerId: { $in: myIds },
    }).populate('blockedId');

    const idx = await personIndex(
      blocks.map((b) => String(b.blockedId?._id || b.blockedId)).filter(Boolean),
    );
    const seen = new Set();
    const unique = [];
    for (const b of blocks) {
      const id = String(b.blockedId?._id || b.blockedId || '');
      const key = idx.get(id)?.key || `i:${id}`;
      if (seen.has(key)) continue;
      seen.add(key);
      unique.push(b);
    }

    res.json({
      blocks: unique.map(formatBlockResponse),
    });
  } catch (error) {
    logger.error('List blocked users error', error);
    res.status(500).json({ error: 'Unable to fetch blocked users. Please try again later.' });
  }
};

module.exports = {
  blockUser,
  unblockUser,
  listBlocked,
};
