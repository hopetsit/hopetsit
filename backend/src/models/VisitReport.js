const mongoose = require('mongoose');

const visitReportSchema = new mongoose.Schema(
  {
    bookingId: { type: mongoose.Schema.Types.ObjectId, ref: 'Booking', required: true, index: true },
    sitterId: { type: mongoose.Schema.Types.ObjectId, ref: 'Sitter', required: true, index: true },
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', required: true, index: true },
    submittedAt: { type: Date, default: Date.now },
    notes: { type: String, default: '', trim: true, maxlength: 2000 },
    photos: { type: [String], default: [] },
    mood: { type: String, enum: ['happy', 'calm', 'anxious'], default: 'calm' },
    activities: { type: [String], default: [] },
  },
  { timestamps: true }
);

module.exports = mongoose.model('VisitReport', visitReportSchema);
