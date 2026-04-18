const mongoose = require('mongoose');

const blockSchema = new mongoose.Schema(
  {
    blockerId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      refPath: 'blockerModel',
    },
    blockerModel: {
      type: String,
      required: true,
      enum: ['Owner', 'Sitter', 'Walker'],
    },
    blockedId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      refPath: 'blockedModel',
    },
    blockedModel: {
      type: String,
      required: true,
      enum: ['Owner', 'Sitter', 'Walker'],
    },
  },
  { timestamps: true }
);

blockSchema.index(
  { blockerId: 1, blockerModel: 1, blockedId: 1, blockedModel: 1 },
  { unique: true }
);

module.exports = mongoose.model('Block', blockSchema);

