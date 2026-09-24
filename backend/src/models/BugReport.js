/**
 * BugReport model — v20.0.8
 *
 * User-submitted bug / feedback reports from the in-app "Signaler un bug"
 * screen. Used to surface issues without users having to leave the app.
 */
const mongoose = require('mongoose');

const bugReportSchema = new mongoose.Schema(
  {
    // Reporter identity (authenticated user).
    userId: { type: mongoose.Schema.Types.ObjectId, required: true },
    userRole: {
      type: String,
      enum: ['owner', 'sitter', 'walker'],
      required: true,
    },
    userName: { type: String, default: '' },
    userEmail: { type: String, default: '' },

    // Report content.
    title: { type: String, default: '', trim: true, maxLength: 120 },
    description: { type: String, required: true, trim: true, maxLength: 4000 },
    screen: { type: String, default: '' }, // which screen the user was on
    appVersion: { type: String, default: '' },
    platform: { type: String, default: '' }, // 'android' | 'ios'

    // v585 (lot D) — « Boîte à idées » : 'bug' (défaut, = un problème) ou
    // 'idea'. Les documents antérieurs n'ont pas le champ → bug.
    kind: { type: String, enum: ['bug', 'idea'], default: 'bug', index: true },

    // Admin workflow. Bug : open / in_progress / fixed / wontfix / duplicate.
    // Idée (v585) : open (nouvelle) / kept (retenue) / done (faite).
    status: {
      type: String,
      enum: ['open', 'in_progress', 'fixed', 'wontfix', 'duplicate', 'kept', 'done'],
      default: 'open',
      index: true,
    },
    adminNote: { type: String, default: '' },

    // Email delivery status (async, informational).
    emailDispatched: { type: Boolean, default: false },
  },
  { timestamps: true },
);

bugReportSchema.index({ createdAt: -1 });

module.exports = mongoose.model('BugReport', bugReportSchema);
