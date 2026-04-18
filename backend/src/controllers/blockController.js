const mongoose = require('mongoose');

const Block = require('../models/Block');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const { sanitizeDoc, sanitizeUser } = require('../utils/sanitize');
const logger = require('../utils/logger');

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

    if (blockerRole === targetRole && blockerId === targetUserId) {
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

    const result = await Block.findOneAndDelete({
      blockerId,
      blockerModel,
      blockedId: targetUserId,
      blockedModel,
    });

    if (!result) {
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

    const blockerModel = ROLE_TO_MODEL[role];

    const blocks = await Block.find({
      blockerId: userId,
      blockerModel,
    }).populate('blockedId');

    res.json({
      blocks: blocks.map(formatBlockResponse),
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
