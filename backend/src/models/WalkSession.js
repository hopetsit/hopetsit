const mongoose = require('mongoose');

const positionSchema = new mongoose.Schema(
  {
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
    timestamp: { type: Date, default: Date.now },
  },
  { _id: false }
);

const walkSessionSchema = new mongoose.Schema(
  {
    bookingId: { type: mongoose.Schema.Types.ObjectId, ref: 'Booking', required: true, index: true },
    sitterId: { type: mongoose.Schema.Types.ObjectId, ref: 'Sitter', required: true, index: true },
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', required: true, index: true },
    startedAt: { type: Date, default: Date.now },
    endedAt: { type: Date, default: null },
    positions: { type: [positionSchema], default: [] },
    status: { type: String, enum: ['active', 'ended'], default: 'active', index: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('WalkSession', walkSessionSchema);
