const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
// v532 — source unique de vérité des devises. AVANT : l'enum était figé à
// ['EUR','USD'] alors que l'app propose GBP et CHF (currency_helper.dart) et
// que le backend les accepte (utils/currency.js) → un sitter britannique ou
// suisse terminait ses 5 étapes d'inscription puis recevait un 500
// (ValidationError Mongoose). Aucune inscription possible depuis ces pays.
const { SUPPORTED_CURRENCIES } = require('../utils/currency');

const ownerSchema = new mongoose.Schema(
  {
    // Stable identifier used across role switches (owner <-> sitter)
    // Defaults to this document's _id for new accounts.
    oldId: {
      type: mongoose.Schema.Types.ObjectId,
      index: true,
      default: function () {
        return this._id;
      },
    },
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    mobile: { type: String, default: '' },
    countryCode: { type: String, default: '' }, // e.g. "+1", "+44"
    country: { type: String, default: '', uppercase: true, trim: true }, // ISO 3166-1 alpha-2, e.g. "FR"
    password: { type: String, required: true, minlength: 8 },
    language: { type: String, default: '' },
    // v23.1.348 — Daniel : 'la langue doit suivre le système dès l'installation'.
    // Code de langue UI de l'app ('fr'|'en'|'es'|'de'|'it'|'pt'), synchronisé
    // par l'app (PATCH /users/me/app-locale) au login + à chaque changement.
    // PRIORITAIRE sur 'language' pour la locale des notifications/emails —
    // 'language' reste le champ libre 'langues parlées' affiché sur les profils.
    appLocale: { type: String, default: '' },
    // v23.1.353 — PawSpot communautaire : PawPoints (+badges 🥉🥈🥇👑) et
    // récompenses premium (couleur badge, cadre doré, bannière).
    pawPoints: { type: Number, default: 0, index: true },
    // v416 — points DÉPENSABLES (échangés contre récompenses). pawPoints reste
    // le total À VIE (= niveau, ne baisse jamais). Backfill paresseux côté
    // pawPointsService.getPawState pour les comptes antérieurs.
    pawPointsSpendable: { type: Number, default: 0 },
    pawBadgeColor: { type: String, default: '' },
    pawGoldFrame: { type: Boolean, default: false },
    pawBannerUrl: { type: String, default: '' },
    currency: { type: String, enum: SUPPORTED_CURRENCIES, default: 'EUR' },
    address: { type: String, default: '' },
    bio: { type: String, default: '' },
    skills: { type: String, default: '' },
    acceptedTerms: { type: Boolean, default: false },
    // Sprint 5 step 4 — traceability of T&C acceptance.
    termsAcceptedAt: { type: Date, default: null },
    termsVersion: { type: String, default: '' },
    service: { type: [String], default: [] },
    verified: { type: Boolean, default: false },
    isStaff: { type: Boolean, default: false, index: true },
    // External authentication information
    firebaseUid: { type: String, default: null, index: true },
    authProvider: { type: String, enum: ['password', 'google', 'apple'], default: 'password' },
    // Firebase Cloud Messaging registration tokens (one per device). Deduplicated via $addToSet.
    fcmTokens: { type: [String], default: [] },
    // Coin Boost — profile boosting system
    boostExpiry: { type: Date, default: null },
    boostTier: { type: String, enum: [null, 'bronze', 'silver', 'gold', 'platinum'], default: null },
    boostPurchases: [{
      tier: { type: String },
      amount: { type: Number },
      currency: { type: String, default: 'EUR' },
      days: { type: Number },
      purchasedAt: { type: Date, default: Date.now },
      paymentProvider: { type: String },
      paymentId: { type: String },
      kind: { type: String, default: 'profile' }, // 'profile' | 'map'
    }],
    // Phase 5 — PawMap boost (pin highlighted on the map)
    mapBoostExpiry: { type: Date, default: null },
    mapBoostTier: { type: String, enum: [null, 'bronze', 'silver', 'gold', 'platinum'], default: null },
    // v23.1 part 108 — PawSpot location custom (cf Walker.js).
    mapBoostLocation: {
      type: { type: String, enum: ['Point'], default: 'Point' },
      coordinates: { type: [Number], default: undefined },
      label: { type: String, default: '' },
    },
    // Sprint 7 step 1 — loyalty: true when 10+ completed bookings.
    isPremium: { type: Boolean, default: false },
    // Sprint 7 step 3 — referral program.
    referralCode: { type: String, unique: true, sparse: true, index: true },
    referredBy: { type: String, default: '' },
    // Sprint 7 step 6 — admin moderation.
    status: { type: String, enum: ['active', 'suspended', 'banned'], default: 'active', index: true },
    banReason: { type: String, default: '' },
    bannedAt: { type: Date, default: null },
    // Sprint 5 step 2 — where the owner is willing to have the service happen.
    servicePreferences: {
      atOwner: { type: Boolean, default: true },  // service happens at the owner's home
      atSitter: { type: Boolean, default: false }, // service happens at the sitter's home
    },
    // v444 — Favoris prestataires : l'owner peut « liker » (cœur) un sitter ou
    // un walker depuis les cartes de recherche. 100 % ADDITIF (défaut []), aucune
    // casse. providerRole = 'sitter' | 'walker' ; providerId = _id du prestataire
    // (stocké en String pour rester agnostique du modèle référencé).
    favoriteProviders: {
      type: [
        {
          _id: false,
          providerId: { type: String, required: true },
          providerRole: { type: String, enum: ['sitter', 'walker'], required: true },
          addedAt: { type: Date, default: Date.now },
        },
      ],
      default: [],
    },
    // ─── v405 refonte — préférences owner (toggles maquette) + recherche.
    // 100% ADDITIF, tous avec défauts → aucune casse.
    preferences: {
      sendPhotosVideos: { type: Boolean, default: true },
      quickReplies: { type: Boolean, default: true },
      flexibleCancellation: { type: Boolean, default: true },
      pawMapInsurance: { type: Boolean, default: true },
      notifications: { type: Boolean, default: true },
      // v551 — Daniel : « une ligne dans le profil : masquer mon profil sur la
      // carte, pour quelqu'un qui ne veut pas être vu comme utilisateur sauf
      // par ses amis ». Retire le membre des DEUX couches de la PawMap
      // (/friends/members/world et /members/nearby) ; la couche live entre
      // amis (PawFollow) n'est pas concernée, elle dépend d'un partage que
      // l'utilisateur active lui-même. Défaut false = rien ne change pour les
      // comptes existants.
      hideFromMap: { type: Boolean, default: false },
    },
    searchPreferences: {
      // services recherchés (promenade, garderie, garde multi-jours, visite domicile)
      services: [{ type: String, trim: true }],
      radiusKm: { type: Number, default: 20 },
      preferredLanguage: { type: String, default: '' },
    },
    // v405 — date de naissance (affichée dans le profil, maquette).
    dateOfBirth: { type: String, default: '' },
    twoFactorEnabled: { type: Boolean, default: false },
    avatar: {
      url: { type: String, default: '' },
      publicId: { type: String, default: '' },
    },
    card: {
      holderName: { type: String, default: '' },
      number: { type: String, default: '' },
      maskedNumber: { type: String, default: '' },
      last4: { type: String, default: '' },
      brand: { type: String, default: '' },
      expMonth: { type: Number, default: null },
      expYear: { type: Number, default: null },
      expDate: { type: String, default: '' },
      cvc: { type: String, default: '' },
      updatedAt: { type: Date, default: null },
    },
    // Location for geospatial queries (GeoJSON Point format). Optional.
    // Only store when valid [lng, lat] coordinates exist; otherwise field is omitted (2dsphere index).
    location: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point',
      },
      coordinates: {
        type: [Number],
        default: undefined,
        validate: {
          validator: function(v) {
            return !v || (Array.isArray(v) && v.length === 2 &&
                   typeof v[0] === 'number' && typeof v[1] === 'number' &&
                   v[0] >= -180 && v[0] <= 180 && v[1] >= -90 && v[1] <= 90);
          },
          message: 'Coordinates must be [longitude, latitude] with valid ranges.',
        },
      },
      city: { type: String, default: '', trim: true },
      // v532 — horodatage de la DERNIERE position en direct. Le filtre de
      // fraicheur (24 h) de /friends/live-positions lisait deja ce champ, mais
      // il n'etait declare nulle part : Mongoose le jetait en silence, `at`
      // valait toujours null et aucune position perimee n'etait ecartee.
      updatedAt: { type: Date, default: null },
      // v532 — le partage en direct est-il actif ? Avant, « passer hors ligne »
      // faisait un $unset de location.coordinates. Mais la recherche de
      // prestataires exige ces coordonnees : le gardien disparaissait des
      // resultats jusqu'a ce qu'il ressaisisse son adresse. On garde donc les
      // coordonnees et on eteint le direct avec ce drapeau.
      liveShareActive: { type: Boolean, default: false },
    },

    // v21.1.1 — Stripe fields removed.
  },
  { timestamps: true }
);

// Create geospatial index for location queries (e.g., finding nearby sitters)
ownerSchema.index({ 'location': '2dsphere' });
// v23.1 part 108 — 2dsphere sur mapBoostLocation (PawSpot custom).
ownerSchema.index({ 'mapBoostLocation': '2dsphere' }, { sparse: true });

// Strip invalid location before save so MongoDB 2dsphere index never sees coordinates: null
ownerSchema.pre('save', function stripInvalidLocation(next) {
  if (!this.location) return next();
  const coords = this.location.coordinates;
  const valid =
    Array.isArray(coords) &&
    coords.length === 2 &&
    typeof coords[0] === 'number' &&
    typeof coords[1] === 'number' &&
    coords[0] >= -180 &&
    coords[0] <= 180 &&
    coords[1] >= -90 &&
    coords[1] <= 90;
  if (!valid) {
    this.location = undefined;
  }
  next();
});

// v23.1 part 136 — fix Daniel "Google Login Error: Can't extract geo keys".
// Mongoose initialise auto `location: { type: 'Point' }` à cause du default
// 'Point' sur location.type. Si coordinates sont absentes/cassées, le doc
// devient un GeoJSON partiel que l'index 2dsphere refuse au save (et qui
// fait échouer le Google Sign In, le KYC, le boost, l'update profil...).
// Pre-validate hook : si location.coordinates n'est pas un [lng, lat] valide,
// on supprime tout l'objet location pour que l'index 2dsphere skippe le doc.
ownerSchema.pre('validate', function sanitizeLocation(next) {
  const loc = this.location;
  if (loc) {
    const c = loc.coordinates;
    const valid =
      Array.isArray(c) &&
      c.length === 2 &&
      typeof c[0] === 'number' && Number.isFinite(c[0]) &&
      typeof c[1] === 'number' && Number.isFinite(c[1]);
    if (!valid) {
      this.location = undefined;
    }
  }
  // Idem pour mapBoostLocation (PawSpot custom).
  const mloc = this.mapBoostLocation;
  if (mloc) {
    const c = mloc.coordinates;
    const valid =
      Array.isArray(c) &&
      c.length === 2 &&
      typeof c[0] === 'number' && Number.isFinite(c[0]) &&
      typeof c[1] === 'number' && Number.isFinite(c[1]);
    if (!valid) {
      this.mapBoostLocation = undefined;
    }
  }
  next();
});

ownerSchema.pre('save', async function hashPassword(next) {
  if (!this.isModified('password')) {
    return next();
  }

  try {
    const salt = await bcrypt.genSalt(12);
    this.password = await bcrypt.hash(this.password, salt);
    return next();
  } catch (error) {
    return next(error);
  }
});

ownerSchema.methods.comparePassword = function comparePassword(candidate) {
  return bcrypt.compare(candidate, this.password);
};

module.exports = mongoose.model('Owner', ownerSchema);

