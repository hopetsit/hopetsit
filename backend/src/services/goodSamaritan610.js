/**
 * 610 (ZOE, 04/10/2026) — « Geste du bon Samaritain » (REGLES_610.md, règle B.6).
 *
 * Quand un signalement de DANGER est confirmé par 3 AUTRES membres, son auteur
 * reçoit 24 h de Premium offert :
 *   · jamais l'auteur lui-même (aucun de ses 3 profils) ;
 *   · un vote par PERSONNE (ses profils propriétaire / gardien / promeneur ne
 *     comptent qu'une fois) ;
 *   · les comptes de test (« +test ») ne comptent pas ;
 *   · au plus 1 fois par 7 jours par personne ;
 *   · idempotent : un signalement est jugé UNE seule fois (« granted » ou
 *     « capped »), même avec des confirmations simultanées ;
 *   · mécanique existante des cadeaux admin : historique `admin_gift`, aucun
 *     paiement, aucun Stripe/Airwallex ;
 *   · notification in-app + push (type `good_samaritan_premium`), JAMAIS
 *     d'e-mail (règle de Daniel du 28/09 : aucun e-mail en plus).
 */
const MapReport = require('../models/MapReport');
const UserSubscription = require('../models/UserSubscription');
const { isDanger } = require('../utils/mapReportRules610');
const { identityGroup } = require('../utils/identityGroup');
const { isTestAccountEmail } = require('../utils/testAccount2809');
const logger = require('../utils/logger');

const SAMARITAN_THRESHOLD = 3;
const SAMARITAN_GIFT_MS = 24 * 60 * 60 * 1000;
const SAMARITAN_COOLDOWN_MS = 7 * 24 * 60 * 60 * 1000;
const NOTIF_TYPE = 'good_samaritan_premium';

const MODELS = () => ({
  Owner: require('../models/Owner'),
  Sitter: require('../models/Sitter'),
  Walker: require('../models/Walker'),
});

/** Nombre de PERSONNES (hors auteur, hors +test) qui ont confirmé. */
async function countValidVoters(report, authorSet) {
  const Models = MODELS();
  const persons = new Set();
  for (const c of report.confirmations || []) {
    const uid = String(c.userId);
    if (authorSet.has(uid)) continue;
    const Model = Models[c.userModel] || Models.Owner;
    let doc = null;
    try { doc = await Model.findById(uid).select('email').lean(); } catch (_) { doc = null; }
    if (!doc) continue; // compte supprimé : ne compte pas
    if (isTestAccountEmail(doc.email)) continue;
    let ids = [uid];
    try { ids = (await identityGroup(uid)).ids; } catch (_) { /* id seul */ }
    if (ids.some((id) => authorSet.has(String(id)))) continue;
    persons.add([...ids].map(String).sort()[0]);
  }
  return persons.size;
}

/** Prolonge de 24 h le Premium de chaque profil de l'auteur (cadeau admin). */
async function grantGift(authorGroup, report, now) {
  const { migrateLegacyFamily } = require('../models/UserSubscription');
  const docs = authorGroup.docs.length
    ? authorGroup.docs
    : [{ id: String(report.reporterId), model: report.reporterModel || 'Owner' }];
  const paymentId = `samaritan_${report._id}`;
  for (const d of docs) {
    let sub = await UserSubscription.findOne({ userId: d.id, userModel: d.model });
    if (!sub) sub = new UserSubscription({ userId: d.id, userModel: d.model });
    if ((sub.history || []).some((h) => h.paymentId === paymentId)) continue;
    migrateLegacyFamily(sub, now);
    const extendFrom = (x) =>
      new Date((x && new Date(x) > now ? new Date(x) : now).getTime() + SAMARITAN_GIFT_MS);
    const periodActive = sub.currentPeriodEnd && new Date(sub.currentPeriodEnd) > now;
    // Un abonnement payant en cours garde son forfait : on ne fait qu'ajouter 24 h.
    if (!periodActive) sub.plan = 'premium_monthly';
    sub.status = 'active';
    sub.currentPeriodStart = sub.currentPeriodStart || now;
    sub.currentPeriodEnd = extendFrom(sub.currentPeriodEnd);
    sub.pawspotExpiry = extendFrom(sub.pawspotExpiry);
    sub.premiumExpiry = extendFrom(sub.premiumExpiry);
    sub.history = sub.history || [];
    sub.history.push({
      plan: sub.plan || 'premium_monthly',
      paymentProvider: 'admin_gift',
      paymentId,
      activatedAt: now,
      expiresAt: sub.premiumExpiry,
      intervalDays: 1,
      currency: 'EUR',
    });
    await sub.save();
  }
}

/**
 * À appeler après chaque confirmation enregistrée. Ne lève jamais.
 * @returns {Promise<{granted:boolean, status?:string, reason?:string}>}
 */
async function evaluateGoodSamaritan(reportId, now = new Date()) {
  try {
    const report = await MapReport.findById(reportId)
      .select('type reporterId reporterModel confirmations samaritan')
      .lean();
    if (!report) return { granted: false, reason: 'not_found' };
    if (!isDanger(report.type)) return { granted: false, reason: 'not_danger' };
    if (report.samaritan && report.samaritan.status) {
      return { granted: false, reason: 'already_judged', status: report.samaritan.status };
    }

    let authorGroup = { ids: [String(report.reporterId)], docs: [], set: new Set([String(report.reporterId)]) };
    try { authorGroup = await identityGroup(report.reporterId); } catch (_) { /* id seul */ }
    const authorSet = new Set([...authorGroup.set].map(String));

    const voters = await countValidVoters(report, authorSet);
    if (voters < SAMARITAN_THRESHOLD) return { granted: false, reason: 'below_threshold', voters };

    // Mongoose convertit les ids texte en ObjectId (reporterId est typé).
    const authorIds = [...authorSet].filter((id) => /^[a-f0-9]{24}$/i.test(id));
    const since = new Date(now.getTime() - SAMARITAN_COOLDOWN_MS);
    const recentGift = await MapReport.exists({
      _id: { $ne: report._id },
      reporterId: { $in: authorIds },
      'samaritan.status': 'granted',
      'samaritan.at': { $gt: since },
    });
    let status = recentGift ? 'capped' : 'granted';

    // Prise atomique : un seul appel juge ce signalement.
    const claimed = await MapReport.findOneAndUpdate(
      { _id: report._id, 'samaritan.status': { $in: [null, ''] } },
      { $set: { samaritan: { status, at: now, voters } } },
      { new: true },
    ).select('_id').lean();
    if (!claimed) return { granted: false, reason: 'already_judged' };

    if (status === 'granted') {
      // Deux dangers du même auteur jugés au même instant : seul le premier
      // (date puis id) donne ; l'autre repasse en « capped ».
      const winners = await MapReport.find({
        reporterId: { $in: authorIds },
        'samaritan.status': 'granted',
        'samaritan.at': { $gt: since },
      }).sort({ 'samaritan.at': 1, _id: 1 }).select('_id').limit(1).lean();
      if (winners.length && String(winners[0]._id) !== String(report._id)) {
        status = 'capped';
        await MapReport.updateOne({ _id: report._id }, { $set: { 'samaritan.status': 'capped' } });
      }
    }
    if (status !== 'granted') {
      logger.info(`[samaritan] report ${report._id} : 3 votes mais cadeau déjà reçu cette semaine`);
      return { granted: false, status };
    }

    await grantGift(authorGroup, report, now);
    try {
      const { sendNotification } = require('./notificationSender');
      await sendNotification({
        userId: report.reporterId,
        role: String(report.reporterModel || 'Owner').toLowerCase(),
        type: NOTIF_TYPE,
        data: { reportId: String(report._id), reportType: report.type },
      });
    } catch (e) {
      logger.warn(`[samaritan] notification non envoyée : ${e?.message || e}`);
    }
    logger.info(`[samaritan] report ${report._id} → 24 h de Premium offertes à ${report.reporterId}`);
    return { granted: true, status };
  } catch (e) {
    logger.error('[samaritan]', e);
    return { granted: false, reason: 'error' };
  }
}

module.exports = {
  evaluateGoodSamaritan,
  SAMARITAN_THRESHOLD,
  SAMARITAN_GIFT_MS,
  SAMARITAN_COOLDOWN_MS,
  NOTIF_TYPE,
};
