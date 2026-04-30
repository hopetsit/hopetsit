/**
 * Invoice — v23.1
 *
 * Auto-generated when a booking payment succeeds. One row is created per
 * booking, holding the snapshot needed for both the owner-facing invoice
 * and the provider-facing payout note. Visible in-app under "Mes
 * Réservations → onglet Factures" for the owner, sitter and walker, and
 * in the admin dashboard under Invoices.
 */

const mongoose = require('mongoose');

const invoiceSchema = new mongoose.Schema(
  {
    // HOP-YYYY-NNNN — unique, human-readable.
    invoiceNumber: { type: String, required: true, unique: true, index: true },

    // Linked booking.
    bookingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      required: true,
      index: true,
    },
    airwallexPaymentIntentId: { type: String, default: '', index: true },

    // Parties (snapshot — names/emails captured at issue time so a later
    // profile change doesn't rewrite history).
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Owner',
      required: true,
      index: true,
    },
    ownerName: { type: String, default: '' },
    ownerEmail: { type: String, default: '' },

    providerId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      index: true,
    },
    providerRole: {
      type: String,
      enum: ['sitter', 'walker'],
      required: true,
      index: true,
    },
    providerName: { type: String, default: '' },
    providerEmail: { type: String, default: '' },

    // Service summary (snapshot).
    serviceType: { type: String, default: '' },
    serviceDate: { type: Date, default: null },
    startDate: { type: Date, default: null },
    endDate: { type: Date, default: null },
    petNames: { type: [String], default: [] },

    // Amounts (in major units, EUR by default).
    grossAmount: { type: Number, required: true },
    commission: { type: Number, default: 0 }, // 20% platform fee
    netPayout: { type: Number, default: 0 }, // 80% to provider
    currency: { type: String, default: 'EUR' },

    // Status: 'paid' (owner has paid) | 'refunded' (cancellation refund issued).
    status: {
      type: String,
      enum: ['paid', 'refunded'],
      default: 'paid',
    },

    // Issued / paid timestamps.
    issuedAt: { type: Date, default: Date.now },
    paidAt: { type: Date, default: null },
    refundedAt: { type: Date, default: null },

    // Optional cached PDF URL (Cloudinary / S3). Generated lazily on first
    // download request to keep the booking flow fast.
    pdfUrl: { type: String, default: '' },
  },
  { timestamps: true },
);

// Compound indexes for the "my invoices" queries.
invoiceSchema.index({ ownerId: 1, issuedAt: -1 });
invoiceSchema.index({ providerId: 1, issuedAt: -1 });

module.exports = mongoose.model('Invoice', invoiceSchema);
