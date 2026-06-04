const mongoose = require('mongoose');
// Lazy-required inside getPlanPricing to avoid circular dependencies — this
// model is imported by pricingService's transitive dependencies at boot.
let pricingService = null;
function loadPricingService() {
  if (pricingService) return pricingService;
  try {
    pricingService = require('../services/pricingService');
  } catch (e) {
    pricingService = null;
  }
  return pricingService;
}

/**
 * UserSubscription — Tracks PawPass subscription for Owners / Sitters / Walkers,
 * and PawFollow subscriptions for tracking features.
 *
 * Pricing (Phase 1) — multi-currency:
 *   PawPass monthly : €6.99 / £5.89 / CHF 6.99 / $7.69  (30-day interval)
 *   PawPass yearly  : €49.99 / £42.19 / CHF 49.99 / $54.99  (365-day interval)
 *
 *   Chat add-on     : €2.99 / £2.59 / CHF 2.99 / $3.29 (monthly, free with booking)
 *
 *   PawFollow Solo  : €6.99 / £5.89 / CHF 6.99 / $7.69 (monthly)
 *   PawFollow Family: €9.99 / £8.49 / CHF 9.99 / $10.99 (monthly, POPULAIRE badge)
 *
 * Payment model:
 *   Phase 1 uses one-time PaymentIntents that extend `currentPeriodEnd` by the
 *   plan duration. This keeps the existing Stripe boost flow re-usable.
 *
 *   Later (Phase 2) we migrate to proper Stripe Subscriptions with webhooks
 *   (`customer.subscription.updated` / `.deleted`) for renewals and failed
 *   payments to auto-update `status`.
 *
 * The `features` object is a snapshot of what this subscription unlocks so the
 * frontend can gate UI without hitting the pricing config on every screen.
 */
const PREMIUM_PLAN_INTERVALS = {
  monthly: { intervalDays: 30, label: 'PawFollow Mensuel' },
  yearly: { intervalDays: 365, label: 'PawFollow Annuel' },
  // v22.1 — PawFollow Famille (anciennement PawPass Famille) :
  // partagé avec jusqu'à 5 membres de la famille. Mensuel uniquement.
  family: { intervalDays: 30, label: 'PawFollow Famille' },
};

const PREMIUM_PRICING = {
  EUR: { monthly: 6.99, yearly: 49.99, family: 9.99 },
  GBP: { monthly: 5.89, yearly: 42.19, family: 8.49 },
  CHF: { monthly: 6.99, yearly: 49.99, family: 9.99 },
  USD: { monthly: 7.69, yearly: 54.99, family: 10.99 },
};

const PAWFOLLOW_PLAN_INTERVALS = {
  solo: { intervalDays: 30, label: 'PawFollow Solo' },
  famille: { intervalDays: 30, label: 'PawFollow Famille' },
};

const PAWFOLLOW_PRICING = {
  EUR: { solo: 6.99, famille: 9.99 },
  GBP: { solo: 5.89, famille: 8.49 },
  CHF: { solo: 6.99, famille: 9.99 },
  USD: { solo: 7.69, famille: 10.99 },
};

const PAWFOLLOW_FEATURES = {
  solo: {
    slug: 'pawfollow_solo',
    name: 'PawFollow Solo',
    badge: null,
    features: [
      'live position 10s',
      'history journey',
      'safety zone alert',
      'direct chat walker/sitter',
    ],
  },
  famille: {
    slug: 'pawfollow_family',
    name: 'PawFollow Famille',
    badge: 'POPULAIRE',
    features: [
      'all PawFollow Solo',
      '5 family members tracking',
      'see who walks the pet',
      'shared real-time notifications',
      'family group chat with walker/sitter',
    ],
  },
};

/** Returns { amount, currency, intervalDays, label } for a (plan, currency) pair.
 *
 * Resolves the amount via pricingService first (DB-backed, editable from
 * admin), then falls back to the hardcoded PREMIUM_PRICING above if the
 * service is not initialized or doesn't have the row.
 */
function getPlanPricing(plan, currency = 'EUR') {
  const interval = PREMIUM_PLAN_INTERVALS[plan];
  if (!interval) return null;
  const upper = String(currency || 'EUR').toUpperCase();
  const svc = loadPricingService();
  const servicePricing = svc && svc.get ? svc.get('premium') || {} : {};
  // v22.2 — Bug 16a : si la DB pricingService n'a pas de row pour ce
  // plan (ex: 'family' ajouté en code mais pas encore seed), on tombait
  // sur amount=undefined → crash frontend → TOUS les plans disparaissent.
  // Fix : on construit currencyRow en COMPOSANT DB + hardcoded fallback,
  // pour que chaque plan ait toujours un amount valide.
  const dbRow = servicePricing[upper] || servicePricing.EUR || {};
  const fallbackRow = PREMIUM_PRICING[upper] || PREMIUM_PRICING.EUR;
  const amount =
    dbRow[plan] != null && Number.isFinite(Number(dbRow[plan]))
      ? Number(dbRow[plan])
      : Number(fallbackRow[plan]);
  if (!Number.isFinite(amount) || amount <= 0) {
    // Pas de prix valide → on retourne null, le caller (route /plans)
    // fait .filter pour skip ce plan plutôt que de tout casser.
    return null;
  }
  return {
    amount,
    currency:
      servicePricing[upper] || PREMIUM_PRICING[upper] ? upper : 'EUR',
    intervalDays: interval.intervalDays,
    label: interval.label,
  };
}

function getPawFollowPricing(plan, currency = 'EUR') {
  const interval = PAWFOLLOW_PLAN_INTERVALS[plan];
  if (!interval) return null;
  const upper = String(currency || 'EUR').toUpperCase();
  const svc = loadPricingService();
  const servicePricing = svc && svc.get ? svc.get('pawfollow') || {} : {};
  const currencyRow =
    servicePricing[upper] ||
    servicePricing.EUR ||
    PAWFOLLOW_PRICING[upper] ||
    PAWFOLLOW_PRICING.EUR;
  return {
    amount: currencyRow[plan],
    currency:
      servicePricing[upper] || PAWFOLLOW_PRICING[upper] ? upper : 'EUR',
    intervalDays: interval.intervalDays,
    label: interval.label,
    ...PAWFOLLOW_FEATURES[plan],
  };
}

/** Legacy export kept for any caller that imports PREMIUM_PLANS — uses EUR. */
const PREMIUM_PLANS = {
  monthly: getPlanPricing('monthly', 'EUR'),
  yearly: getPlanPricing('yearly', 'EUR'),
};

const PREMIUM_FEATURES_DEFAULT = {
  // Couche 1 — always true for everyone (free tier shows it too)
  mapPoiVisible: true,

  // Couche 2 — reports (PawPass only)
  mapReportsVisible: true,
  mapReportsCreate: true,

  // Couche 3 — social (PawPass only)
  socialFriendsMap: true,
  socialChat: true,
  socialProximityAlerts: true,

  // Couche 4 — one free PawSpot per month
  mapBoostMonthlyCredit: 1,
};

const userSubscriptionSchema = new mongoose.Schema(
  {
    // Polymorphic owner ref (same pattern as Block.js)
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      refPath: 'userModel',
      index: true,
    },
    userModel: {
      type: String,
      enum: ['Owner', 'Sitter', 'Walker'],
      required: true,
    },

    // Plan type: pawpass (formerly premium), pawfollow, or none
    plan: {
      type: String,
      // v23.1.175 — Daniel : "qd je prend abonnement famille il ne se passe
      // rien". Cause racine : le frontend envoie 'family' (EN) mais l'enum
      // n'acceptait que 'famille' (FR) → ValidationError silencieuse →
      // sub jamais persistée. On accepte les 2 pour la compat.
      enum: ['none', 'monthly', 'yearly', 'solo', 'famille', 'family'],
      default: 'none',
      index: true,
    },
    planType: {
      type: String,
      enum: ['pawpass', 'pawfollow', 'chat'],
      default: 'pawpass',
    },
    status: {
      type: String,
      enum: ['active', 'past_due', 'canceled', 'expired', 'pending'],
      default: 'pending',
      index: true,
    },

    // Period window — renewals push currentPeriodEnd forward.
    // v23.1.283 — `plan`/`currentPeriodEnd` ne concernent QUE l'abo INDIVIDUEL
    // (monthly/yearly/solo). Le plan FAMILLE est devenu INDÉPENDANT : son propre
    // timer `familyExpiry` (ci-dessous) → prendre PawFollow ou PawFamily ne
    // désactive plus l'autre, et un mois individuel = 30 j sans empiler les
    // jours famille.
    currentPeriodStart: { type: Date, default: null },
    currentPeriodEnd: { type: Date, default: null, index: true },

    // v23.1.283 — Daniel : "prendre PawFollow ou PawFamily désactive l'autre".
    // Timer DÉDIÉ au plan Famille (titulaire), indépendant de l'abo individuel.
    // Rétro-compat : les anciennes subs famille (plan='famille' + currentPeriodEnd)
    // sont migrées vers familyExpiry à la 1re écriture (migrateLegacyFamily), et
    // les LECTURES acceptent les 2 formes (familyActiveMatch).
    familyExpiry: { type: Date, default: null, index: true },

    // Cancellation
    cancelAtPeriodEnd: { type: Boolean, default: false },
    canceledAt: { type: Date, default: null },

    // v21.1.1 — Stripe references removed.

    // Payment history (similar to boostPurchases on User models)
    payments: [
      {
        // v23.1.175 — Daniel : ajout de 'family' pour compat FR/EN.
        plan: {
          type: String,
          enum: ['monthly', 'yearly', 'solo', 'famille', 'family'],
        },
        amount: Number,
        currency: { type: String, default: 'EUR' },
        paidAt: { type: Date, default: Date.now },
        paymentProvider: { type: String, default: 'stripe' },
        paymentIntentId: String,
        periodStart: Date,
        periodEnd: Date,
      },
    ],

    // Feature snapshot
    features: {
      type: Object,
      default: () => ({ ...PREMIUM_FEATURES_DEFAULT }),
    },

    // PawSpot monthly credit ledger
    mapBoostCreditsRemaining: { type: Number, default: 0, min: 0 },
    mapBoostCreditsResetAt: { type: Date, default: null },

    // v23.1.170 — Daniel : "fais le suivi famille en plus". PawFollow
    // Famille (€9.99/mois) inclut jusqu'à 5 membres tracking. Cette liste
    // contient les userId des 4 autres membres (le titulaire de l'abo est
    // déjà identifié par userId du document). On stocke aussi le userModel
    // de chaque membre pour pouvoir requêter Owner / Sitter / Walker.
    //
    // Sécurité : un user ne peut être dans la famille qu'UNE seule fois
    // (cf. service helper isInSameFamily ci-dessous). Si le titulaire
    // annule son abo, la liste est conservée pour le réabonnement futur,
    // mais isInSameFamily renvoie false dès que la sub n'est plus active.
    familyMembers: [
      {
        userId: { type: mongoose.Schema.Types.ObjectId, required: true },
        userModel: {
          type: String,
          enum: ['Owner', 'Sitter', 'Walker'],
          required: true,
        },
        addedAt: { type: Date, default: Date.now },
        // Optionnel : l'email saisi par le titulaire (utile si l'invité
        // n'a pas encore créé son compte — feature future).
        email: String,
        // v23.1.183 — Daniel : "developpe le sous menu amis famislle
        // pour accepter refuse rbloquer". Avant on auto-ajoutait, le
        // destinataire n'avait aucun moyen de refuser. Maintenant le
        // status par défaut est 'pending' ; le destinataire doit
        // accepter (status='active') ou refuser (membre retiré).
        // Les anciens membres sans status sont considérés 'active'
        // (rétro-compat ; isInSameFamily les inclut).
        status: {
          type: String,
          enum: ['pending', 'active'],
          default: 'pending',
          index: true,
        },
        respondedAt: Date,
      },
    ],
  },
  { timestamps: true }
);

// One subscription doc per user
userSubscriptionSchema.index({ userId: 1, userModel: 1 }, { unique: true });
userSubscriptionSchema.index({ status: 1, currentPeriodEnd: 1 });

// v23.1.177 — Daniel : "je prend labonement famille et y se passe rien".
// Cause racine : le frontend / pricingService envoient 'family' (EN) mais
// toutes les routes qui cherchent les membres famille filtrent par
// `plan: 'famille'` (FR). Le pre-save hook normalise les valeurs en
// 'famille' (canonique FR) à l'écriture. Le côté lecture continue
// d'accepter 'family' via les enums.
userSubscriptionSchema.pre('save', function normalizeFamilyPlan(next) {
  if (this.plan === 'family') this.plan = 'famille';
  if (Array.isArray(this.payments)) {
    this.payments = this.payments.map((p) => {
      if (p.plan === 'family') p.plan = 'famille';
      return p;
    });
  }
  next();
});
// Pareil pour findOneAndUpdate (upsert / staff bypass).
userSubscriptionSchema.pre('findOneAndUpdate', function normalizeUpdate(next) {
  const update = this.getUpdate();
  if (update && update.plan === 'family') update.plan = 'famille';
  if (update && update.$set && update.$set.plan === 'family') {
    update.$set.plan = 'famille';
  }
  next();
});

/**
 * Convenience: returns true when the subscription is active AND within its
 * paid window. Handles edge-cases where the cron hasn't flipped status yet.
 */
userSubscriptionSchema.methods.isCurrentlyPremium = function isCurrentlyPremium() {
  if (this.status !== 'active') return false;
  if (!this.currentPeriodEnd) return false;
  return new Date(this.currentPeriodEnd) > new Date();
};

// v23.1.283 — DÉCOUPLAGE famille / individuel.
// Source de vérité de l'expiration FAMILLE d'une sub (titulaire) :
//   - nouveau champ familyExpiry, OU
//   - rétro-compat : ancienne forme plan='famille'/'family' + currentPeriodEnd.
function familyExpiryOf(sub) {
  if (!sub) return null;
  if (sub.familyExpiry) return sub.familyExpiry;
  if (
    (sub.plan === 'famille' || sub.plan === 'family') &&
    sub.currentPeriodEnd
  ) {
    return sub.currentPeriodEnd;
  }
  return null;
}

// Condition de requête Mongoose « plan Famille actif » (titulaire), tolérante
// aux 2 formes (nouveau familyExpiry OU ancienne plan='famille'). À combiner
// avec d'autres champs via spread : { userId: x, ...familyActiveMatch(now) }.
// v23.1.284 — Daniel : "j'ai un plan famille actif mais je dois RE-acheter
// pour débloquer l'invitation". CAUSE probable : la branche legacy exigeait
// status:'active', or le champ status peut être périmé (past_due/canceled alors
// que la période payée court encore). On se fie désormais à la DATE seule
// (currentPeriodEnd/familyExpiry futur = accès), plus robuste.
function familyActiveMatch(now = new Date()) {
  return {
    $or: [
      { familyExpiry: { $gt: now } },
      {
        plan: { $in: ['famille', 'family'] },
        currentPeriodEnd: { $gt: now },
      },
    ],
  };
}

// Migration-à-l'écriture : déplace une ancienne sub famille (plan='famille' +
// currentPeriodEnd) vers familyExpiry, et libère le slot individuel
// (plan='none', currentPeriodEnd=null). Idempotent. À appeler en début
// d'activation pour que prendre un abo individuel ne perde pas la famille.
function migrateLegacyFamily(sub, now = new Date()) {
  if (!sub) return;
  if (
    !sub.familyExpiry &&
    (sub.plan === 'famille' || sub.plan === 'family') &&
    sub.currentPeriodEnd &&
    new Date(sub.currentPeriodEnd) > now
  ) {
    sub.familyExpiry = sub.currentPeriodEnd;
    sub.currentPeriodEnd = null;
    sub.currentPeriodStart = null;
    sub.plan = 'none';
  }
}

/**
 * v23.1.170 — Helper : retourne true si userA et userB sont membres de la
 * même famille PawFollow Famille (peu importe qui est le titulaire). Pour
 * que ça soit "actif", il faut que la sub du titulaire soit active +
 * currentPeriodEnd dans le futur.
 *
 * Logique :
 *   - On charge toutes les subs `famille` actives qui contiennent userA
 *     en titulaire OU dans familyMembers
 *   - Pour chacune, on vérifie si userB y figure aussi
 *   - Si oui → même famille.
 *
 * @param {string} userAId - ObjectId string
 * @param {string} userBId - ObjectId string
 * @returns {Promise<boolean>}
 */
async function isInSameFamily(userAId, userBId) {
  if (!userAId || !userBId) return false;
  const a = String(userAId);
  const b = String(userBId);
  if (a === b) return true;
  const Model = mongoose.model('UserSubscription');
  const now = new Date();
  // Sub où A est titulaire ET active ET famille → vérifier si B est dedans
  const subA = await Model.findOne({
    userId: a,
    ...familyActiveMatch(now),
  }).lean();
  // v23.1.183 — n'inclut que les membres status='active' (les 'pending'
  // sont des invitations en attente, l'invité n'a pas encore accepté).
  // Les anciens membres sans status sont considérés actifs (rétro-compat).
  const isActiveMember = (m) =>
    !m.status || m.status === 'active';
  if (subA && Array.isArray(subA.familyMembers)) {
    if (subA.familyMembers.some(
      (m) => isActiveMember(m) && String(m.userId) === b,
    )) return true;
  }
  // Sub où B est titulaire ET active ET famille → vérifier si A est dedans
  const subB = await Model.findOne({
    userId: b,
    ...familyActiveMatch(now),
  }).lean();
  if (subB && Array.isArray(subB.familyMembers)) {
    if (subB.familyMembers.some(
      (m) => isActiveMember(m) && String(m.userId) === a,
    )) return true;
  }
  // Subs où A figure en family member → vérifier si B figure dans la même
  const subsContainingA = await Model.find({
    'familyMembers.userId': a,
    ...familyActiveMatch(now),
  }).lean();
  for (const sub of subsContainingA) {
    // v23.1.183 — ignore les membres pending.
    const memberIds = (sub.familyMembers || [])
      .filter((m) => !m.status || m.status === 'active')
      .map((m) => String(m.userId));
    if (memberIds.includes(b) || String(sub.userId) === b) return true;
  }
  return false;
}

// v23.1 part 226 — Daniel : "debloque le partage de position a mes amis
// et famille si jai un abonnement paw follow". Helper qui dit si un user
// a un PawFollow ACTIF (n'importe quel tier : monthly / yearly / family).
// Utilise par mapSocket (broadcast position auto a tous les amis sans
// avoir besoin de toggler la switch ami par ami) et par friendRoutes
// /track-access (autorisation de tracker un ami).
async function hasActivePawFollow(userId) {
  if (!userId) return false;
  const Model = mongoose.model('UserSubscription');
  const now = new Date();
  // 1) Abo PROPRE actif : individuel (status active + currentPeriodEnd futur)
  //    OU titulaire d'un plan Famille actif (familyExpiry futur OU ancien
  //    plan='famille'). v23.1.283 — famille découplée de l'individuel.
  // v23.1.284 — détection par DATE (pas par status, qui peut être périmé) :
  // période individuelle OU familyExpiry dans le futur = actif.
  const own = await Model.findOne({
    userId: String(userId),
    $or: [
      { currentPeriodEnd: { $gt: now } },
      { familyExpiry: { $gt: now } },
    ],
  })
    .select('_id')
    .lean();
  if (own) return true;
  // 2) v23.1.280 — Daniel (décision : modèle "un seul PawFamily, membres
  // GRATUITS"). Un MEMBRE accepté d'un plan Famille actif bénéficie du
  // PawFollow gratuitement via le titulaire. On vérifie donc l'appartenance
  // à une sub 'famille' active en tant que membre status='active' (les
  // 'pending' n'ont pas encore accepté ; les anciens membres sans status
  // sont considérés actifs pour rétro-compat, cf isInSameFamily).
  const asMember = await Model.findOne({
    ...familyActiveMatch(now),
    familyMembers: {
      $elemMatch: {
        userId: String(userId),
        $or: [{ status: 'active' }, { status: { $exists: false } }],
      },
    },
  })
    .select('_id')
    .lean();
  return !!asMember;
}

module.exports = mongoose.model('UserSubscription', userSubscriptionSchema);
module.exports.PREMIUM_PLANS = PREMIUM_PLANS;
module.exports.PREMIUM_PLAN_INTERVALS = PREMIUM_PLAN_INTERVALS;
module.exports.PREMIUM_PRICING = PREMIUM_PRICING;
module.exports.PREMIUM_FEATURES_DEFAULT = PREMIUM_FEATURES_DEFAULT;
module.exports.isInSameFamily = isInSameFamily;
module.exports.hasActivePawFollow = hasActivePawFollow;
// v23.1.283 — découplage famille / individuel.
module.exports.familyExpiryOf = familyExpiryOf;
module.exports.familyActiveMatch = familyActiveMatch;
module.exports.migrateLegacyFamily = migrateLegacyFamily;
module.exports.getPlanPricing = getPlanPricing;
module.exports.PAWFOLLOW_PLAN_INTERVALS = PAWFOLLOW_PLAN_INTERVALS;
module.exports.PAWFOLLOW_PRICING = PAWFOLLOW_PRICING;
module.exports.PAWFOLLOW_FEATURES = PAWFOLLOW_FEATURES;
module.exports.getPawFollowPricing = getPawFollowPricing;
