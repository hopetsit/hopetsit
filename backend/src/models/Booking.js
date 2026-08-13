const mongoose = require('mongoose');

const bookingSchema = new mongoose.Schema(
  {
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Owner', required: true },
    // Session v16-owner-walker — the booking now targets either a Sitter
    // (traditional garde/garderie) OR a Walker (dog_walking). Exactly one
    // of the two must be set, enforced by the pre-save validator below.
    // Legacy bookings keep `sitterId` populated, so no migration needed.
    sitterId: { type: mongoose.Schema.Types.ObjectId, ref: 'Sitter', default: null },
    walkerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Walker', default: null },
    petIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Pet' }], // Array of pet IDs
    // v23.1 part 130 — Phase 6 audit P6-4 : cap les champs texte.
    description: { type: String, default: '', maxlength: 3000 },
    date: { type: String, required: true },
    startDate: { type: String, default: null },
    endDate: { type: String, default: null },
    timeSlot: { type: String, required: true },
    status: {
      type: String,
      enum: ['pending', 'accepted', 'rejected', 'agreed', 'paid', 'completed', 'payment_failed', 'cancelled', 'refunded'],
      default: 'pending',
    },
    // Payment status - tracks payment state separately from booking status
    paymentStatus: {
      type: String,
      enum: ['pending', 'paid', 'failed', 'refunded', 'cancelled', 'refund'],
      default: 'pending',
    },
    // Payout status - tracks payout to sitter/walker separately from payment capture.
    // Session v17 — 'scheduled' was already written by schedulePayoutForBooking
    // but silently rejected by the enum validator on save. Added so the
    // scheduler state is actually persisted and findable via
    // { payoutStatus: 'scheduled' } queries.
    payoutStatus: {
      type: String,
      // v18.5 — #3 : 'held' = le owner a payé la totalité MAIS le provider
      // n'avait pas encore configuré IBAN/PayPal au moment de la capture.
      // L'argent dort sur le compte plateforme. Le scheduler check
      // périodiquement si le provider a depuis configuré, et si oui
      // déclenche le transfert en marquant 'scheduled' → 'completed'.
      // v23.1 part 52 — added 'pending_manual_transfer' which is the
      // legitimate state when an Airwallex payout falls back to a manual
      // SEPA transfer queue (provider has no airwallexBeneficiaryId).
      // Without this enum entry, processProviderPayoutForBooking crashed
      // with "ValidationError: pending_manual_transfer is not a valid
      // enum value", which is the silent error Daniel saw : wallet was
      // credited (creditWallet runs BEFORE payout) but the booking_paid
      // notif step that followed crashed with the now-corrupt payoutStatus
      // pseudo-state.
      // v465 — Daniel : « Impossible d'annuler cette réservation ». RACINE :
      // selfCancelWithRefund fait `payoutStatus = 'cancelled'` quand le payout
      // était 'scheduled' (cas de TOUTE résa payée à venir), mais 'cancelled'
      // n'était PAS dans l'enum → ValidationError sur save() → 500 → erreur
      // générique côté app. On ajoute 'cancelled' (+ 'refunded' pour cohérence
      // avec les remboursements de payout).
      enum: ['pending', 'scheduled', 'processing', 'completed', 'failed', 'held', 'pending_manual_transfer', 'cancelled', 'refunded'],
      default: 'pending',
    },
    // v532 — horodatage de la prise de verrou du versement. Le seul garde-fou
    // anti-double-virement était `if (payoutStatus === 'completed') return`,
    // une lecture faite AVANT l'envoi de l'argent : deux exécutions
    // simultanées (tick du planificateur + confirmation manuelle, ou deux
    // instances Render) lisaient toutes les deux « pas encore versé » et
    // payaient le prestataire DEUX FOIS. On pose désormais un verrou atomique
    // (payoutStatus → 'processing') et ce champ permet de le reprendre si un
    // traitement est mort en cours de route.
    payoutProcessingAt: { type: Date, default: null },
    // v18.5 — #3 hold admin : montants dormants en attente que le provider
    // configure son IBAN ou PayPal. `heldAmount` = part provider (netPayout,
    // = 80% du total). `heldSince` = quand on a marqué held (pour tracking
    // + reporting). `heldReleasedAt` = quand on a débloqué (pour audit).
    heldAmount: { type: Number, default: null },
    heldSince: { type: Date, default: null, index: true },
    heldReleasedAt: { type: Date, default: null },
    // Status change timestamps
    acceptedAt: { type: Date, default: null },
    rejectedAt: { type: Date, default: null },
    agreedAt: { type: Date, default: null },
    paidAt: { type: Date, default: null },
    paymentFailedAt: { type: Date, default: null },
    // Payment provider and gateway-specific identifiers
    paymentProvider: {
      type: String,
      enum: ['airwallex', 'paypal'],
      default: null,
    },
    // v22.5 — Stripe field removed.
    // petsitterConnectedAccountId field deprecated — Stripe Connect no longer supported
    // v21.2 — Airwallex Payment Intent ID (replaces Stripe's stripePaymentIntentId).
    // Persisted by bookingController when creating a PI, used by webhook to
    // find the matching booking on payment success/failure.
    airwallexPaymentIntentId: {
      type: String,
      default: null,
    },
    // v21 — Airwallex Payout id created by payoutScheduler when releasing
    // the sitter's 80% cut after a successful booking. Used by admin to
    // track payout status and by the reconciliation cron.
    airwallexPayoutId: {
      type: String,
      default: null,
    },
    // PayPal payment information
    paypalOrderId: {
      type: String,
      default: null,
    },
    paypalCaptureId: {
      type: String,
      default: null,
    },
    // PayPal payout information (sitter earnings)
    sitterPaypalEmail: {
      type: String,
      default: '',
    },
    payoutId: {
      type: String,
      default: null,
    },
    payoutBatchId: {
      type: String,
      default: null,
    },
    payoutAt: {
      type: Date,
      default: null,
    },
    // Session v17 — actual datetime at which the scheduler should release
    // the funds. Set by schedulePayoutForBooking from the booking start
    // date (+ time slot in v17c, hour-exact). The scheduler query uses
    // { $lte: now } on this field so precise hour-exact releases work.
    // Indexed because the scheduler polls this column every few minutes.
    scheduledPayoutAt: {
      type: Date,
      default: null,
      index: true,
    },
    payoutError: {
      type: String,
      default: null,
    },
    // v23.1.259 — Système de confirmation de service (Daniel) :
    //   awaiting_start  : payé, le provider n'a pas encore démarré
    //   in_progress     : le provider a tapé "J'ai récupéré l'animal"
    //   awaiting_confirmation : le provider a tapé "J'ai rendu l'animal",
    //                     l'owner doit confirmer (libère le paiement)
    //   confirmed       : l'owner a confirmé → paiement libéré
    //   disputed        : l'owner a signalé un problème → paiement bloqué
    //   none            : bookings legacy (avant la feature) → ancien flux
    // Le payout n'est libéré que sur 'confirmed' OU par l'auto-release 48h
    // (scheduledPayoutAt = autoReleaseAt) ; jamais sur 'disputed'.
    confirmationStatus: {
      type: String,
      enum: [
        'none',
        'awaiting_start',
        'in_progress',
        'awaiting_confirmation',
        'confirmed',
        'disputed',
      ],
      default: 'none',
      index: true,
    },
    serviceStartedAt: { type: Date, default: null },
    serviceEndedAt: { type: Date, default: null },
    ownerConfirmedAt: { type: Date, default: null },
    // v23.1.340 — Daniel : "le sitter/walker doit avoir une notification pour
    // confirmer le début du service". Horodatage du rappel "C'est l'heure !
    // 🐾 appuie sur J'ai récupéré l'animal" envoyé au prestataire par le
    // scheduler quand l'heure de début arrive. Non-null = déjà envoyé (1 fois).
    serviceStartReminderSentAt: { type: Date, default: null },
    // v449 — Daniel : notif "Service dans 72h" au prestataire (1re confirmation
    // anticipée). Non-null = rappel T-72h déjà envoyé (1 fois).
    startServiceT72hReminderSentAt: { type: Date, default: null },
    // v23.1.354 — Daniel : la 2e confirmation (fin de service) ne sort sur le
    // bandeau que 30 min avant la fin + rappel push/mail au prestataire.
    serviceEndReminderSentAt: { type: Date, default: null },
    // Date à laquelle le paiement est auto-libéré si l'owner ne confirme pas
    // (= fin de service + 48h ; recalculée quand le provider marque "rendu").
    autoReleaseAt: { type: Date, default: null },
    disputeReason: { type: String, default: null },
    disputedAt: { type: Date, default: null },
    // v532 — PREUVE DE REMISE / RÉCUPÉRATION.
    //
    // Jusqu'ici le cycle ne reposait que sur deux boutons : aucune photo,
    // aucun code, aucune position — en cas de litige (« il n'est jamais
    // venu » contre « si, j'y étais »), la plateforme n'avait strictement
    // aucun élément, et rien n'empêchait un prestataire d'enchaîner
    // « récupéré » puis « rendu » sans jamais voir l'animal.
    //
    // handoverCode : 4 chiffres générés au paiement. Le PROPRIÉTAIRE le voit
    // dans son app et le montre au prestataire, qui le saisit au moment de la
    // remise — il ne peut donc pas valider à distance.
    handoverCode: { type: String, default: null },
    // Photos horodatées, prises par le prestataire (Cloudinary).
    pickupProof: {
      url: { type: String, default: '' },
      publicId: { type: String, default: '' },
      at: { type: Date, default: null },
    },
    returnProof: {
      url: { type: String, default: '' },
      publicId: { type: String, default: '' },
      at: { type: Date, default: null },
    },
    // Arbitrage d'un litige par l'administrateur (cf. resolveDispute).
    disputeResolvedAt: { type: Date, default: null },
    disputeResolution: {
      type: String,
      enum: ['released', 'refunded', null],
      default: null,
    },
    disputeResolutionNote: { type: String, default: null },
    // Self-cancellation (72h window)
    cancelledAt: { type: Date, default: null },
    // v465 — ajout de 'walker' : selfCancelWithRefund pose cancelledBy='walker'
    // quand un promeneur annule (sinon ValidationError sur save() → 500).
    cancelledBy: { type: String, enum: ['owner', 'sitter', 'walker', null], default: null },
    cancellationReason: { type: String, default: null },
    // Cancellation tracking (for mutual agreement requirement)
    cancellation: {
      ownerRequested: { type: Boolean, default: false },
      sitterRequested: { type: Boolean, default: false },
      ownerConfirmed: { type: Boolean, default: false },
      sitterConfirmed: { type: Boolean, default: false },
      requestedAt: { type: Date, default: null },
      confirmedAt: { type: Date, default: null },
      refundId: { type: String, default: null },
    },
    // Service details
    serviceType: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
    houseSittingVenue: {
      type: String,
      enum: ['owners_home', 'sitters_home'],
      default: null,
    },
    requestFingerprint: {
      type: String,
      default: null,
      index: true,
    },
    duration: {
      type: Number, // Duration in minutes (30, 45, 60, etc.) or nights for overnight stay
      default: null,
    },
    locationType: {
      type: String,
      enum: ['standard', 'large_city'],
      default: 'standard',
    },
    // Pricing information
    pricing: {
      basePrice: { type: Number, required: true },
      pricingTier: { type: String, enum: ['hourly', 'daily', 'weekly', 'monthly'], default: 'hourly' },
      appliedRate: { type: Number, default: 0 },
      totalHours: { type: Number, default: 0 },
      totalDays: { type: Number, default: 0 },
      addOns: [
        {
          type: { type: String, default: '' }, // extraAnimals, medicationSpecialCare, additionalDog, lateEveningWalk
          description: { type: String, default: '' },
          amount: { type: Number, default: 0 },
          currency: { type: String, default: 'EUR' },
        },
      ],
      addOnsTotal: { type: Number, default: 0 },
      totalPrice: { type: Number, required: true }, // Total price owner pays
      commission: { type: Number, required: true }, // 20% platform commission
      netPayout: { type: Number, required: true }, // Amount sitter receives (80%)
      commissionRate: { type: Number, default: 0.2 }, // 20%
      currency: { type: String, default: 'EUR' },
    },
    // Recommended price range at time of booking (for reference)
    recommendedPriceRange: {
      min: { type: Number, default: null },
      max: { type: Number, default: null },
      currency: { type: String, default: 'EUR' },
    },
  },
  { timestamps: true }
);

bookingSchema.index({ ownerId: 1, sitterId: 1, status: 1, requestFingerprint: 1 });
// Session v16-owner-walker — mirror index for walker lookups.
bookingSchema.index({ ownerId: 1, walkerId: 1, status: 1, requestFingerprint: 1 });

// v23.1.321 — Daniel : "rends-le efficace pour des milliers d'utilisateurs".
// CRITIQUE : le webhook Airwallex et le reconcile font findOne({ airwallexPaymentIntentId })
// / findOne({ airwallexPayoutId }) — SANS index = scan COMPLET de la collection
// à chaque paiement/payout. Sparse car la plupart des bookings n'ont pas encore
// d'intent. Idem payout.
bookingSchema.index({ airwallexPaymentIntentId: 1 }, { sparse: true });
bookingSchema.index({ airwallexPayoutId: 1 }, { sparse: true });
// Stats/revenus admin : sum des paiements payés par date.
bookingSchema.index({ paymentStatus: 1, paidAt: -1 });
// Fidélité / Top : countDocuments par prestataire + statut (self-heal à chaque
// lecture de profil → requête chaude).
bookingSchema.index({ sitterId: 1, status: 1 });
bookingSchema.index({ walkerId: 1, status: 1 });
bookingSchema.index({ ownerId: 1, status: 1 });

// Session v16-owner-walker — enforce exactly one provider target. Without
// this, a buggy caller could persist a booking with neither field set (the
// booking would end up linked to nobody) or with both set (ambiguous which
// provider gets paid). Validator is pre('validate') so error surfaces on
// save() before any downstream $set does weird stuff.
bookingSchema.pre('validate', function (next) {
  const hasSitter = !!this.sitterId;
  const hasWalker = !!this.walkerId;
  if (hasSitter && hasWalker) {
    return next(
      new Error('Booking cannot target both a sitter and a walker.'),
    );
  }
  if (!hasSitter && !hasWalker) {
    return next(
      new Error('Booking must target either a sitter or a walker.'),
    );
  }
  next();
});

module.exports = mongoose.model('Booking', bookingSchema);