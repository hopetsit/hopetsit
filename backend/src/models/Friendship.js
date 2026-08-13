const mongoose = require('mongoose');

/**
 * Friendship — bidirectional relation between two users (Owner / Sitter / Walker).
 *
 * Stored as a single doc with `requester` + `addressee` (polymorphic refs).
 * A unique compound index enforces one pair per direction so duplicate
 * requests are rejected at the DB level.
 *
 * Status lifecycle:
 *   pending  → default when a request is sent
 *   accepted → both sides can see each other's live position (if enabled)
 *   declined → archived for 30 days (TTL would be nice but not critical)
 *
 * Per-side toggles:
 *   requesterSharesPosition / addresseeSharesPosition
 *     Controls whether THAT side broadcasts their live location to the other.
 *     Either side can toggle it without affecting the other's choice.
 */
const friendshipSchema = new mongoose.Schema(
  {
    requesterId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      refPath: 'requesterModel',
      index: true,
    },
    requesterModel: {
      type: String,
      enum: ['Owner', 'Sitter', 'Walker'],
      required: true,
    },

    addresseeId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      refPath: 'addresseeModel',
      index: true,
    },
    addresseeModel: {
      type: String,
      enum: ['Owner', 'Sitter', 'Walker'],
      required: true,
    },

    status: {
      type: String,
      enum: ['pending', 'accepted', 'declined'],
      default: 'pending',
      index: true,
    },

    // v532 — CONSENTEMENT. Ces deux drapeaux valaient `true` par défaut :
    // accepter une demande d'ami suffisait à diffuser sa position en direct à
    // cette personne, sans qu'on la lui ait jamais demandée. Le site promet
    // pourtant explicitement que « chaque ami accepte le partage ». On passe
    // donc à `false` : le partage doit être activé volontairement (bouton
    // POST /friends/:id/share, déjà présent dans l'app).
    // ATTENTION : un `default` Mongoose ne s'applique qu'à la CRÉATION — les
    // amitiés existantes gardent leur valeur actuelle et continuent de
    // fonctionner. Seules les nouvelles démarrent en partage désactivé.
    requesterSharesPosition: { type: Boolean, default: false },
    addresseeSharesPosition: { type: Boolean, default: false },

    acceptedAt: { type: Date, default: null },
    declinedAt: { type: Date, default: null },
  },
  { timestamps: true },
);

// Prevent duplicate requests in either direction.
friendshipSchema.index(
  { requesterId: 1, addresseeId: 1 },
  { unique: true },
);
// Fast lookup of my friends regardless of who initiated.
friendshipSchema.index({ addresseeId: 1, status: 1 });
friendshipSchema.index({ requesterId: 1, status: 1 });

module.exports = mongoose.model('Friendship', friendshipSchema);
