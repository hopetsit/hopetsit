/**
 * 620 (ZOE, 24/10/2026 — ordre de Daniel « dates à prévoir ») — CANDIDATURES SUR UNE
 * DEMANDE SANS DATES.
 *
 *   · Tant que la demande est « dates à prévoir » (`dateMode: 'tbd'`), chaque candidature
 *     est INDICATIVE : seul le tarif unitaire est connu (`pricing.indicative = true`,
 *     totaux null) et l'acceptation répond 409 `DATES_REQUIRED`.
 *   · Quand le propriétaire pose ses dates (PATCH /posts/:id → exact | approx), les
 *     candidatures en attente sont RECALCULÉES par le moteur unique
 *     (utils/pricingEngine620 : quantité × tarif unitaire, commission 20 % / 15 % Top,
 *     suppléments conservés) puis le propriétaire reçoit UNE notification
 *     `application_pricing_updated` (9 langues : « Vos dates sont posées, voici le prix de
 *     chaque candidat »). Devise : règle du 16/10 inchangée (la candidature garde la sienne).
 *
 * Testé dans tests/dates620.test.js.
 */
const logger = require('../utils/logger');
const engine = require('../utils/pricingEngine620');
const { calculateTotalWithAddOns, commissionRateForProvider } = require('../utils/pricing');

const TYPE_PRICING_UPDATED = 'application_pricing_updated';

const DATES_REQUIRED_MSG = {
  fr: 'Pose d’abord les dates de ta demande : le prix de chaque candidat sera calculé, puis tu pourras choisir.',
  en: 'Set the dates of your request first: each candidate’s price will be calculated, then you can choose.',
  es: 'Pon primero las fechas de tu solicitud: se calculará el precio de cada candidato y luego podrás elegir.',
  de: 'Lege zuerst die Daten deiner Anfrage fest: der Preis jedes Kandidaten wird berechnet, dann kannst du wählen.',
  it: 'Imposta prima le date della tua richiesta: il prezzo di ogni candidato verrà calcolato, poi potrai scegliere.',
  pt: 'Define primeiro as datas do teu pedido: o preço de cada candidato será calculado e depois podes escolher.',
  ko: '먼저 요청 날짜를 정해 주세요. 각 후보의 가격이 계산된 후 선택할 수 있습니다.',
  ja: 'まずリクエストの日程を設定してください。各候補者の料金が計算された後に選べます。',
  pl: 'Najpierw ustaw daty swojego zgłoszenia: cena każdego kandydata zostanie obliczona, potem wybierzesz.',
};
const datesRequiredMessage = (locale) => DATES_REQUIRED_MSG[String(locale || '').slice(0, 2)] || DATES_REQUIRED_MSG.en;

/** Tier enregistré selon l'unité facturée. */
const tierForUnit = (unit) => (unit === 'visit' ? 'visit' : unit === 'walk' ? 'walk' : 'daily');

/**
 * Prix d'une candidature pour une demande DATÉE, par le moteur unique.
 * @returns {object|null} bloc `pricing` complet, ou null si le prestataire n'a pas de tarif pour ce service
 */
function priceApplication({ application, post, provider, providerRole }) {
  const serviceType = engine.serviceKey(application.serviceType) || engine.mainService(post);
  const duration = Number(post.walkDurationMinutes || application.duration) || undefined;
  const r = engine.rateFor(provider, serviceType, { durationMinutes: duration });
  if (!r) return null;
  const isTop = providerRole === 'walker' ? provider.isTopWalker === true : provider.isTopSitter === true;
  const commissionRate = Number(application.pricing && application.pricing.commissionRate) || commissionRateForProvider(isTop);
  const currency = (application.pricing && application.pricing.currency) || provider.currency || 'EUR';
  const est = engine.estimate({ serviceType, rate: r.rate, post, commissionRate, currency });
  if (est.indicative) return null;
  const addOns = Array.isArray(application.pricing && application.pricing.addOns) ? application.pricing.addOns : [];
  const breakdown = calculateTotalWithAddOns(est.unitTotal, addOns, currency, commissionRate);
  const days = engine.dayCount(post) || 0;
  return {
    basePrice: breakdown.basePrice,
    pricingTier: tierForUnit(est.unit),
    appliedRate: r.rate,
    totalHours: 0,
    totalDays: days,
    quantity: est.quantity,
    unit: est.unit,
    indicative: false,
    addOns: breakdown.addOns || [],
    addOnsTotal: breakdown.addOnsTotal || 0,
    totalPrice: breakdown.totalPrice,
    commission: breakdown.commission,
    netPayout: breakdown.netPayout,
    commissionRate: breakdown.commissionRate,
    currency: breakdown.currency,
  };
}

/**
 * Recalcule les candidatures en attente d'une demande qui vient de recevoir ses dates.
 * @param {object} post  document Post (après enregistrement des dates)
 * @param {{notify?:boolean, send?:Function, onlyIndicative?:boolean}} [opts]
 * @returns {Promise<{repriced:string[], skipped:string[], notified:boolean}>}
 */
async function repriceApplicationsForPost(post, opts = {}) {
  const Application = require('../models/Application');
  const out = { repriced: [], skipped: [], notified: false };
  if (!post || engine.effectiveDateMode(post) === 'tbd') return out;
  const filter = { postId: post._id, status: 'pending' };
  if (opts.onlyIndicative) filter['pricing.indicative'] = true;
  const pending = await Application.find(filter);
  if (!pending.length) return out;
  const Sitter = require('../models/Sitter');
  const Walker = require('../models/Walker');
  for (const app of pending) {
    try {
      const providerRole = app.walkerId ? 'walker' : 'sitter';
      const Model = providerRole === 'walker' ? Walker : Sitter;
      // eslint-disable-next-line no-await-in-loop
      const provider = await Model.findById(providerRole === 'walker' ? app.walkerId : app.sitterId)
        .select('hourlyRate dailyRate weeklyRate monthlyRate visitRate visitDurationMinutes walkRates currency isTopSitter isTopWalker').lean();
      if (!provider) { out.skipped.push(String(app._id)); continue; }
      const pricing = priceApplication({ application: app, post, provider, providerRole });
      if (!pricing) { out.skipped.push(String(app._id)); continue; }
      app.pricing = pricing;
      // Une candidature posée sans dates n'a ni date ni créneau : la réservation les exige.
      if (!app.timeSlot) app.timeSlot = 'flexible';
      app.serviceDate = post.startDate || app.serviceDate;
      app.startDate = post.startDate || app.startDate;
      app.endDate = post.endDate || app.endDate;
      // eslint-disable-next-line no-await-in-loop
      await app.save();
      out.repriced.push(String(app._id));
    } catch (e) {
      out.skipped.push(String(app._id));
      logger.warn(`[reprice620] candidature ${app._id} : ${e && e.message ? e.message : e}`);
    }
  }
  if (out.repriced.length && opts.notify !== false) {
    try {
      const send = typeof opts.send === 'function' ? opts.send : require('./notificationSender').sendNotification;
      await send({
        userId: String(post.ownerId && post.ownerId._id ? post.ownerId._id : post.ownerId),
        role: 'owner',
        type: TYPE_PRICING_UPDATED,
        data: {
          postId: String(post._id),
          applicationId: out.repriced[0],
          candidates: String(out.repriced.length),
          pricing620: '1',
        },
      });
      out.notified = true;
    } catch (e) {
      logger.warn(`[reprice620] notification : ${e && e.message ? e.message : e}`);
    }
  }
  return out;
}

/**
 * Bloc `pricing` INDICATIF d'une candidature sur une demande « dates à prévoir ».
 * @returns {object} (appliedRate = tarif unitaire, 0 si le prestataire n'en a pas pour ce service)
 */
function indicativePricing({ post, provider, providerRole, serviceType, duration, addOns = [] }) {
  const key = engine.serviceKey(serviceType) || engine.mainService(post);
  const r = engine.rateFor(provider, key, { durationMinutes: Number(duration) || undefined });
  const isTop = providerRole === 'walker' ? provider.isTopWalker === true : provider.isTopSitter === true;
  const q = engine.quantityFor(post, key);
  return {
    basePrice: null,
    pricingTier: 'indicative',
    appliedRate: r ? r.rate : 0,
    totalHours: 0,
    totalDays: 0,
    quantity: null,
    unit: r ? r.unit : q.unit,
    indicative: true,
    addOns: addOns.map((a) => ({ type: a.type || '', description: a.description || '', amount: Number(a.amount) || 0 })),
    addOnsTotal: addOns.reduce((s, a) => s + (Number(a.amount) || 0), 0),
    totalPrice: null,
    commission: null,
    netPayout: null,
    commissionRate: commissionRateForProvider(isTop),
  };
}

module.exports = {
  TYPE_PRICING_UPDATED,
  datesRequiredMessage,
  priceApplication,
  indicativePricing,
  repriceApplicationsForPost,
  tierForUnit,
};
