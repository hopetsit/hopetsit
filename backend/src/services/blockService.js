const Block = require('../models/Block');

const OWNER_BLOCK_FILTER = (ownerId, sitterId) => ({
  blockerId: ownerId,
  blockerModel: 'Owner',
  blockedId: sitterId,
  blockedModel: 'Sitter',
});

const SITTER_BLOCK_FILTER = (ownerId, sitterId) => ({
  blockerId: sitterId,
  blockerModel: 'Sitter',
  blockedId: ownerId,
  blockedModel: 'Owner',
});

const isOwnerSitterInteractionBlocked = async (ownerId, sitterId) => {
  if (!ownerId || !sitterId) {
    return false;
  }
  return Block.exists({
    $or: [OWNER_BLOCK_FILTER(ownerId, sitterId), SITTER_BLOCK_FILTER(ownerId, sitterId)],
  });
};

module.exports = {
  isOwnerSitterInteractionBlocked,
};


