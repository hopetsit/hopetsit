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
const { ownerUnitRate } = require('../utils/applicationNewText617');

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

/**
 * 2810 (ZOE, ordre de BOB — Lili, Marine, Svitlana) — candidature « tarif à venir » : le
 * prestataire n'a PAS de tarif pour le service de la demande (ex. aucun tarif par visite sur
 * une demande de visites). Avant : 400 en anglais technique (« missing valid pricing »).
 * Désormais 409 `RATE_PENDING` avec une phrase claire dans la langue du propriétaire.
 * Le choix se débloque tout seul dès que le prestataire ajoute son tarif (620c).
 */
const RATE_PENDING_MSG = {
  fr: '{name} n’a pas encore de tarif {unit} : son prix sera calculé dès qu’il l’aura ajouté, puis tu pourras le choisir.',
  en: '{name} has not set a price {unit} yet: their total will be calculated as soon as they add it, then you can choose them.',
  es: '{name} aún no tiene tarifa {unit}: su precio se calculará en cuanto la añada y luego podrás elegirle.',
  de: '{name} hat noch keinen Preis {unit}: der Gesamtpreis wird berechnet, sobald er hinzugefügt ist, dann kannst du wählen.',
  it: '{name} non ha ancora una tariffa {unit}: il prezzo sarà calcolato appena la aggiunge, poi potrai sceglierlo.',
  pt: '{name} ainda não tem tarifa {unit}: o preço será calculado assim que a adicionar e depois podes escolher.',
  ko: '{name}님은 아직 {unit} 요금이 없습니다. 요금을 추가하면 가격이 계산되고 선택할 수 있습니다.',
  ja: '{name}さんはまだ{unit}の料金を設定していません。料金が追加されると価格が計算され、選べるようになります。',
  pl: '{name} nie ma jeszcze stawki {unit}: cena zostanie obliczona, gdy ją doda, wtedy będziesz mógł wybrać.',
};
const ratePendingMessage = (locale, name, unit) => {
  const l = String(locale || '').slice(0, 2);
  const tpl = RATE_PENDING_MSG[l] || RATE_PENDING_MSG.en;
  const label = (UNIT_LABEL[unit] || UNIT_LABEL.day)[RATE_PENDING_MSG[l] ? l : 'en'];
  const who = String(name || '').trim().split(/\s+/)[0] || (l === 'fr' ? 'Ce candidat' : 'This candidate');
  return tpl.replace('{name}', who).replace('{unit}', label);
};

/** Tier enregistré selon l'unité facturée. */
const tierForUnit = (unit) => (unit === 'visit' ? 'visit' : unit === 'walk' ? 'walk' : 'daily');

/**
 * Prix d'une candidature pour une demande DATÉE, par le moteur unique.
 * @returns {object|null} bloc `pricing` complet, ou null si le prestataire n'a pas de tarif pour ce service
 */
function priceApplication({ application, post, provider, providerRole }) {
  // 2610 — le service facturé est celui de la DEMANDE (le candidat répond à cette demande) ;
  // celui de la candidature ne sert qu'à défaut (index d'app ancienne parfois faux).
  const serviceType = engine.mainService(post) || engine.serviceKey(application.serviceType);
  const duration = Number(post.walkDurationMinutes || application.duration) || undefined;
  const r = engine.rateFor(provider, serviceType, { durationMinutes: duration });
  if (!r) return null;
  const isTop = providerRole === 'walker' ? provider.isTopWalker === true : provider.isTopSitter === true;
  const commissionRate = Number(application.pricing && application.pricing.commissionRate) || commissionRateForProvider(isTop);
  const currency = (application.pricing && application.pricing.currency) || provider.currency || 'EUR';
  const est = engine.estimate({ serviceType, rate: r.rate, post, commissionRate, currency, weeklyRate: provider.weeklyRate });
  if (est.indicative) return null;
  const addOns = Array.isArray(application.pricing && application.pricing.addOns) ? application.pricing.addOns : [];
  const breakdown = calculateTotalWithAddOns(est.unitTotal, addOns, currency, commissionRate);
  const days = engine.dayCount(post) || 0;
  return {
    basePrice: breakdown.basePrice,
    pricingTier: est.weeklyApplied ? 'weekly' : tierForUnit(est.unit),
    weeklyApplied: est.weeklyApplied === true,
    weeklyRate: est.weeklyApplied ? est.weeklyRate : null,
    weeks: est.weeklyApplied ? est.weeks : null,
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
      if (!pricing) {
        // 2610 (ZOE, relevé de LEO) — le candidat n'a AUCUN tarif pour le service de la demande
        // (ex. promeneur sur une garde) : avant, la candidature restait « indicative » sur une
        // demande datée → « pose tes dates » alors que les dates étaient posées, Choisir bloqué
        // sans explication. Elle passe en « tarif à venir » (stale), comme au changement de service.
        if (!(app.pricing && app.pricing.stale === true)) {
          const unit = engine.quantityFor(post, engine.mainService(post)).unit;
          app.pricing = {
            ...indicativePricing({ post, provider, providerRole, serviceType: engine.mainService(post), duration: post.walkDurationMinutes, addOns: Array.isArray(app.pricing && app.pricing.addOns) ? app.pricing.addOns : [] }),
            appliedRate: 0, unit, indicative: true, stale: true, totalPrice: null, commission: null, netPayout: null, basePrice: null, quantity: null,
          };
          // eslint-disable-next-line no-await-in-loop
          await app.save();
        }
        out.skipped.push(String(app._id));
        continue;
      }
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
    // 2610 (ZOE, relevé de LEO : « enregistrer mes dates » prenait 1,3 à 9,8 s) — la notification
    // (cloche + push + e-mail SMTP) partait AVANT la réponse au propriétaire. Elle part désormais
    // en arrière-plan ; `opts.await === true` garde l'ancien comportement (tests).
    const notifyNow = async () => {
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
    };
    out.notified = true;
    const run = notifyNow().catch((e) => logger.warn(`[reprice620] notification : ${e && e.message ? e.message : e}`));
    if (opts.await === true) await run;
  }
  return out;
}

/**
 * Bloc `pricing` INDICATIF d'une candidature sur une demande « dates à prévoir ».
 * @returns {object} (appliedRate = tarif unitaire, 0 si le prestataire n'en a pas pour ce service)
 */
function indicativePricing({ post, provider, providerRole, serviceType, duration, addOns = [] }) {
  const key = engine.mainService(post) || engine.serviceKey(serviceType);
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

/* ─────────────────────────────────────────────────────────────────────────────
 * 620b (ZOE, 24/10/2026 — ordre de Daniel « requalifie la demande de Svitlana en visites à
 * domicile, 1 par jour, et préviens les gardiens ») — LA DEMANDE CHANGE DE SERVICE.
 *
 * Quand `updatePost` change le service (`serviceTypes`), les visites par jour ou le lieu de
 * garde d'une demande qui a des candidatures EN ATTENTE, chacune est recalculée par le
 * moteur unique pour le NOUVEAU service :
 *   · le prestataire a un tarif pour ce service (ex. visitRate > 0) → nouveaux totaux
 *     (ou tarif unitaire indicatif si la demande est « dates à prévoir ») ; notification
 *     `application_pricing_updated` au prestataire (gabarit application_service_repriced)
 *     et UNE au propriétaire (gabarit application_service_repriced_owner) ;
 *   · sinon → `pricing.indicative = true`, `pricing.stale = true`, totaux null (« tarif à
 *     venir » côté propriétaire) ; notification `application_service_changed` au prestataire
 *     (« ajoute ton tarif par visite pour rester candidat »).
 * Idempotent : une candidature déjà alignée sur le nouveau service (même service, même
 * unité, ou déjà marquée stale) n'est ni réécrite ni re-notifiée → aucun double envoi.
 * ───────────────────────────────────────────────────────────────────────────── */
const TYPE_SERVICE_CHANGED = 'application_service_changed';
const TEMPLATE_SERVICE_REPRICED = 'application_service_repriced';
const TEMPLATE_SERVICE_REPRICED_OWNER = 'application_service_repriced_owner';

const UNIT_LABEL = {
  visit: { fr: 'par visite', en: 'per visit', es: 'por visita', de: 'pro Besuch', it: 'a visita', pt: 'por visita', ko: '방문당', ja: '訪問ごと', pl: 'za wizytę' },
  day: { fr: 'par jour', en: 'per day', es: 'por día', de: 'pro Tag', it: 'al giorno', pt: 'por dia', ko: '일당', ja: '1日ごと', pl: 'za dzień' },
  night: { fr: 'par nuit', en: 'per night', es: 'por noche', de: 'pro Nacht', it: 'a notte', pt: 'por noite', ko: '1박당', ja: '1泊ごと', pl: 'za noc' },
  walk: { fr: 'par balade', en: 'per walk', es: 'por paseo', de: 'pro Spaziergang', it: 'a passeggiata', pt: 'por passeio', ko: '산책당', ja: '散歩ごと', pl: 'za spacer' },
};

/** Libellé du service dans la langue du lecteur (catalogue 620), repli sur la clé. */
function serviceLabel(serviceType, lang) {
  const key = engine.serviceKey(serviceType);
  const l = String(lang || 'fr').slice(0, 2);
  try {
    const cat = require('./serviceCatalogService').getServices620();
    const list = Array.isArray(cat) ? cat : (cat && Array.isArray(cat.all) ? cat.all : []);
    const entry = list.find((x) => x && x.key === key);
    if (entry && entry.label) return entry.label[l] || entry.label.en || entry.label.fr || key;
  } catch (_) { /* catalogue indisponible : clé brute */ }
  return key;
}
const unitLabel = (unit, lang) => (UNIT_LABEL[unit] || UNIT_LABEL.day)[String(lang || 'fr').slice(0, 2)] || UNIT_LABEL[unit].fr;

/** Empreinte « service » d'une demande : service principal, visites/jour, lieu de garde. */
function serviceFingerprint(post) {
  const key = engine.mainService(post || {});
  return [key, engine.visitsPerDayOf(post || {}), (post && post.houseSittingVenue) || '', (post && post.serviceLocation) || ''].join('|');
}

/**
 * Une candidature déjà alignée sur le service actuel de la demande n'est pas retouchée.
 * `hasRate` : le prestataire a maintenant un tarif pour ce service → une candidature
 * « tarif à venir » (stale) n'est plus alignée, on la recalcule.
 */
function isAligned(app, post, hasRate = false) {
  const key = engine.mainService(post);
  const q = engine.quantityFor(post, key);
  const sameService = engine.serviceKey(app.serviceType) === key;
  const p = app.pricing || {};
  if (!sameService) return false;
  if (p.stale === true) return !hasRate;
  if (engine.effectiveDateMode(post) === 'tbd') return p.indicative === true && p.unit === q.unit;
  return p.indicative !== true && p.unit === q.unit && Number(p.quantity) === Number(q.quantity);
}

const near = (a, b) => Math.abs((Number(a) || 0) - (Number(b) || 0)) <= 0.011;

/**
 * 2610 (ZOE) — le bloc `pricing` stocké correspond-il au prix que calcule le moteur unique
 * aujourd'hui ? (tarif unitaire, quantité, unité, total). Une candidature « tarif à venir »
 * sans tarif connu est conforme ; avec un tarif désormais connu, elle ne l'est plus.
 */
function matchesExpected(app, post, provider, providerRole, r) {
  const p = app.pricing || {};
  if (!r) return p.stale === true;
  if (p.stale === true) return false;
  const isTbd = engine.effectiveDateMode(post) === 'tbd';
  if (isTbd) {
    return p.indicative === true && p.totalPrice == null && near(p.appliedRate, r.rate);
  }
  const expected = priceApplication({ application: app, post, provider, providerRole });
  if (!expected) return false;
  return p.indicative !== true
    && p.unit === expected.unit
    && Number(p.quantity) === Number(expected.quantity)
    && near(p.appliedRate, expected.appliedRate)
    && near(p.totalPrice, expected.totalPrice);
}

/** Total incohérent : inférieur au tarif unitaire, ou absent sur une demande datée. */
function isIncoherentTotal(pricing) {
  const p = pricing || {};
  if (p.indicative === true || p.stale === true) return false;
  const total = Number(p.totalPrice);
  const rate = Number(p.appliedRate);
  if (!(total > 0)) return true;
  return rate > 0 && total + 0.001 < rate;
}

const fmtMoney = (n, currency, lang) => {
  try { return new Intl.NumberFormat(String(lang || 'fr').slice(0, 2), { style: 'currency', currency: currency || 'EUR' }).format(Number(n) || 0); }
  catch (_) { return `${Number(n) || 0} ${currency || 'EUR'}`; }
};

/**
 * Recalcule / marque les candidatures en attente après un changement de service de la demande.
 * @param {object} post   document Post (après enregistrement)
 * @param {{notify?:boolean, send?:Function, force?:boolean, dryRun?:boolean}} [opts]
 * @returns {Promise<{repriced:string[], stale:string[], skipped:string[], aligned:string[], notified:{owner:boolean, providers:number}}>}
 */
async function repriceAfterServiceChange(post, opts = {}) {
  const Application = require('../models/Application');
  const out = { repriced: [], stale: [], skipped: [], aligned: [], notified: { owner: false, providers: 0 }, details: [] };
  if (!post) return out;
  const pending = await Application.find({ postId: post._id, status: 'pending' });
  if (!pending.length) return out;
  const Sitter = require('../models/Sitter');
  const Walker = require('../models/Walker');
  const Owner = require('../models/Owner');
  const key = engine.mainService(post);
  const isTbd = engine.effectiveDateMode(post) === 'tbd';
  const send = opts.notify === false ? null : (typeof opts.send === 'function' ? opts.send : require('./notificationSender').sendNotification);
  const ownerId = String(post.ownerId && post.ownerId._id ? post.ownerId._id : post.ownerId);
  let ownerLang = 'fr';
  try { const o = await Owner.findById(ownerId).select('appLocale language').lean(); ownerLang = (o && (o.appLocale || o.language)) || 'fr'; } catch (_) { /* fr */ }
  const changed = [];
  for (const app of pending) {
    try {
      const providerRole = app.walkerId ? 'walker' : 'sitter';
      const Model = providerRole === 'walker' ? Walker : Sitter;
      // eslint-disable-next-line no-await-in-loop
      const provider = await Model.findById(providerRole === 'walker' ? app.walkerId : app.sitterId)
        .select('hourlyRate dailyRate weeklyRate monthlyRate visitRate visitDurationMinutes walkRates currency isTopSitter isTopWalker appLocale language').lean();
      if (!provider) { out.skipped.push(String(app._id)); continue; }
      const r = engine.rateFor(provider, key, { durationMinutes: Number(post.walkDurationMinutes || app.duration) || undefined });
      // 2610 — « aligné » = le prix STOCKÉ est celui que donne le moteur aujourd'hui (tarif,
      // quantité, total). Avant, seuls le service et l'unité étaient comparés : 2,70 € pour un
      // tarif de 18 €/jour passait pour « aligné » et n'était jamais corrigé.
      if (!opts.force && isAligned(app, post, !!r) && matchesExpected(app, post, provider, providerRole, r)) { out.aligned.push(String(app._id)); continue; }
      const providerId = String(providerRole === 'walker' ? app.walkerId : app.sitterId);
      const lang = provider.appLocale || provider.language || 'fr';
      const before = app.serviceType;
      const totalBefore = app.pricing && typeof app.pricing.totalPrice === 'number' ? app.pricing.totalPrice : null;
      const rateBefore = app.pricing && typeof app.pricing.appliedRate === 'number' ? app.pricing.appliedRate : null;
      app.serviceType = key;
      app.houseSittingVenue = key === 'house_sitting' ? (post.houseSittingVenue || app.houseSittingVenue || null) : null;
      let pricing = null;
      if (r) {
        pricing = isTbd
          ? indicativePricing({ post, provider, providerRole, serviceType: key, duration: post.walkDurationMinutes, addOns: Array.isArray(app.pricing && app.pricing.addOns) ? app.pricing.addOns : [] })
          : priceApplication({ application: app, post, provider, providerRole });
      }
      if (pricing) {
        pricing.stale = false;
        app.pricing = pricing;
        if (!isTbd) {
          if (!app.timeSlot) app.timeSlot = 'flexible';
          app.serviceDate = post.startDate || app.serviceDate;
          app.startDate = post.startDate || app.startDate;
          app.endDate = post.endDate || app.endDate;
        }
        out.repriced.push(String(app._id));
        changed.push({ app, providerId, providerRole, lang, kind: 'repriced', pricing });
      } else {
        const unit = engine.quantityFor(post, key).unit;
        app.pricing = {
          ...indicativePricing({ post, provider, providerRole, serviceType: key, duration: post.walkDurationMinutes, addOns: Array.isArray(app.pricing && app.pricing.addOns) ? app.pricing.addOns : [] }),
          appliedRate: 0, unit, indicative: true, stale: true, totalPrice: null, commission: null, netPayout: null, basePrice: null, quantity: null,
        };
        out.stale.push(String(app._id));
        changed.push({ app, providerId, providerRole, lang, kind: 'stale', unit });
      }
      out.details.push({ id: String(app._id), providerId, role: providerRole, from: before, to: key, kind: pricing ? 'repriced' : 'stale', total: pricing ? pricing.totalPrice : null, rate: pricing ? pricing.appliedRate : 0, totalBefore, rateBefore, quantity: pricing ? pricing.quantity : null, unit: pricing ? pricing.unit : null, indicative: pricing ? !!pricing.indicative : true, currency: pricing ? pricing.currency : null });
      // eslint-disable-next-line no-await-in-loop
      if (!opts.dryRun) await app.save();
    } catch (e) {
      out.skipped.push(String(app._id));
      logger.warn(`[reprice620b] candidature ${app._id} : ${e && e.message ? e.message : e}`);
    }
  }
  if (opts.dryRun || !send || !changed.length) return out;
  for (const c of changed) {
    try {
      const data = { postId: String(post._id), applicationId: String(c.app._id), service: serviceLabel(key, c.lang), serviceKey: key, serviceChanged: '1' };
      if (c.kind === 'repriced') {
        const p = c.pricing;
        const total = p.indicative ? `${fmtMoney(p.appliedRate, p.currency, c.lang)} ${unitLabel(p.unit, c.lang)}` : fmtMoney(p.totalPrice, p.currency, c.lang);
        // eslint-disable-next-line no-await-in-loop
        await send({ userId: c.providerId, role: c.providerRole, type: TYPE_PRICING_UPDATED, templateType: TEMPLATE_SERVICE_REPRICED, data: { ...data, total, candidates: '1', pricing620: '1' } });
      } else {
        // eslint-disable-next-line no-await-in-loop
        await send({ userId: c.providerId, role: c.providerRole, type: TYPE_SERVICE_CHANGED, data: { ...data, unitLabel: unitLabel(c.unit, c.lang) } });
      }
      out.notified.providers += 1;
    } catch (e) {
      logger.warn(`[reprice620b] notification prestataire ${c.providerId} : ${e && e.message ? e.message : e}`);
    }
  }
  if (out.repriced.length) {
    try {
      await send({
        userId: ownerId, role: 'owner', type: TYPE_PRICING_UPDATED, templateType: TEMPLATE_SERVICE_REPRICED_OWNER,
        data: { postId: String(post._id), applicationId: out.repriced[0], candidates: String(out.repriced.length), service: serviceLabel(key, ownerLang), serviceKey: key, serviceChanged: '1', pricing620: '1' },
      });
      out.notified.owner = true;
    } catch (e) {
      logger.warn(`[reprice620b] notification propriétaire : ${e && e.message ? e.message : e}`);
    }
  }
  return out;
}

/* ─────────────────────────────────────────────────────────────────────────────
 * 620c (ZOE, 24/10/2026 — décision de Daniel, 21 h, via BOB) — LE PRESTATAIRE AJOUTE OU
 * CHANGE SON TARIF.
 *
 * À chaque PUT qui pose ou change un tarif (PUT /users/me/profile, /sitters/me/pricing|rates,
 * /sitters/me/profile, /walkers/me/rates), ses candidatures EN ATTENTE marquées « tarif à
 * venir » (`pricing.stale = true`) sur une demande dont il tarife désormais le service sont
 * recalculées par le moteur unique (totaux réels, ou tarif unitaire indicatif si la demande
 * est « dates à prévoir »), `stale = false`, puis :
 *   · le propriétaire reçoit `application_pricing_updated` (gabarit application_rate_added_owner :
 *     « <Prénom> a ajouté son tarif : <total> ») ;
 *   · le prestataire reçoit `application_pricing_updated` (gabarit application_rate_added).
 * Une candidature qui n'était PAS stale n'est jamais retouchée : une offre faite reste une
 * offre, et rien n'est envoyé. Idempotent : `stale` passe à false, un second PUT identique ne
 * trouve plus rien (0 envoi). Comptes de test : aucun e-mail (règle +test du notificationSender).
 * ───────────────────────────────────────────────────────────────────────────── */
const TEMPLATE_RATE_ADDED = 'application_rate_added';
const TEMPLATE_RATE_ADDED_OWNER = 'application_rate_added_owner';
const RATE_FIELDS = ['hourlyRate', 'dailyRate', 'weeklyRate', 'monthlyRate', 'visitRate', 'visitDurationMinutes', 'walkRates'];

/** Le corps d'une requête pose ou change un tarif (champs de la grille 620). */
function touchesRates(body) {
  const b = body && typeof body === 'object' ? body : {};
  return RATE_FIELDS.some((k) => Object.prototype.hasOwnProperty.call(b, k) && b[k] !== undefined);
}

const firstNameOf = (p) => {
  const f = String((p && p.firstName) || '').trim();
  if (f) return f;
  return String((p && p.name) || '').trim().split(/\s+/)[0] || 'HoPetSit';
};

/**
 * Recalcule les candidatures « tarif à venir » d'un prestataire qui vient de poser un tarif.
 * @param {{providerId:string, providerRole:'sitter'|'walker'}} who
 * @param {{notify?:boolean, send?:Function, dryRun?:boolean}} [opts]
 * @returns {Promise<{repriced:string[], kept:string[], skipped:string[], notified:{owners:number, provider:number}, details:object[]}>}
 */
async function repriceAfterRateChange({ providerId, providerRole } = {}, opts = {}) {
  const out = { repriced: [], kept: [], skipped: [], notified: { owners: 0, provider: 0 }, details: [] };
  if (!providerId) return out;
  const role = providerRole === 'walker' ? 'walker' : 'sitter';
  const Application = require('../models/Application');
  const Post = require('../models/Post');
  const Model = role === 'walker' ? require('../models/Walker') : require('../models/Sitter');
  const provider = await Model.findById(providerId)
    .select('name firstName hourlyRate dailyRate weeklyRate monthlyRate visitRate visitDurationMinutes walkRates currency isTopSitter isTopWalker appLocale language').lean();
  if (!provider) return out;
  const filter = { status: 'pending', 'pricing.stale': true };
  filter[role === 'walker' ? 'walkerId' : 'sitterId'] = provider._id;
  const stale = await Application.find(filter);
  if (!stale.length) return out;
  const send = opts.notify === false ? null : (typeof opts.send === 'function' ? opts.send : require('./notificationSender').sendNotification);
  const lang = provider.appLocale || provider.language || 'fr';
  const changed = [];
  for (const app of stale) {
    try {
      // eslint-disable-next-line no-await-in-loop
      const post = await Post.findById(app.postId).lean();
      if (!post || post.status === 'closed') { out.skipped.push(String(app._id)); continue; }
      const key = engine.mainService(post);
      const r = engine.rateFor(provider, key, { durationMinutes: Number(post.walkDurationMinutes || app.duration) || undefined });
      if (!r) { out.kept.push(String(app._id)); continue; } // toujours pas de tarif pour ce service
      const isTbd = engine.effectiveDateMode(post) === 'tbd';
      const addOns = Array.isArray(app.pricing && app.pricing.addOns) ? app.pricing.addOns : [];
      const pricing = isTbd
        ? indicativePricing({ post, provider, providerRole: role, serviceType: key, duration: post.walkDurationMinutes, addOns })
        : priceApplication({ application: app, post, provider, providerRole: role });
      if (!pricing) { out.skipped.push(String(app._id)); continue; }
      pricing.stale = false;
      app.serviceType = key;
      app.pricing = pricing;
      if (!isTbd) {
        if (!app.timeSlot) app.timeSlot = 'flexible';
        app.serviceDate = post.startDate || app.serviceDate;
        app.startDate = post.startDate || app.startDate;
        app.endDate = post.endDate || app.endDate;
      }
      // eslint-disable-next-line no-await-in-loop
      if (!opts.dryRun) await app.save();
      out.repriced.push(String(app._id));
      out.details.push({ id: String(app._id), postId: String(post._id), service: key, total: pricing.totalPrice, rate: pricing.appliedRate, unit: pricing.unit, indicative: !!pricing.indicative });
      changed.push({ app, post, pricing, key });
    } catch (e) {
      out.skipped.push(String(app._id));
      logger.warn(`[reprice620c] candidature ${app._id} : ${e && e.message ? e.message : e}`);
    }
  }
  if (opts.dryRun || !send || !changed.length) return out;
  const Owner = require('../models/Owner');
  const providerName = firstNameOf(provider);
  for (const c of changed) {
    const ownerId = String(c.post.ownerId && c.post.ownerId._id ? c.post.ownerId._id : c.post.ownerId);
    let ownerLang = 'fr';
    try {
      // eslint-disable-next-line no-await-in-loop
      const o = await Owner.findById(ownerId).select('appLocale language').lean();
      ownerLang = (o && (o.appLocale || o.language)) || 'fr';
    } catch (_) { /* fr */ }
    // 2610 — tarif indicatif FRAIS COMPRIS pour le propriétaire, net pour le prestataire.
    const totalIn = (l, forOwner = false) => (c.pricing.indicative
      ? `${fmtMoney(forOwner ? ownerUnitRate(c.pricing) : c.pricing.appliedRate, c.pricing.currency, l)} ${unitLabel(c.pricing.unit, l)}`
      : fmtMoney(c.pricing.totalPrice, c.pricing.currency, l));
    const base = { postId: String(c.post._id), applicationId: String(c.app._id), serviceKey: c.key, rateAdded: '1', pricing620: '1', candidates: '1' };
    try {
      // eslint-disable-next-line no-await-in-loop
      await send({
        userId: ownerId, role: 'owner', type: TYPE_PRICING_UPDATED, templateType: TEMPLATE_RATE_ADDED_OWNER,
        data: { ...base, providerName, total: totalIn(ownerLang, true), service: serviceLabel(c.key, ownerLang) },
      });
      out.notified.owners += 1;
    } catch (e) {
      logger.warn(`[reprice620c] notification propriétaire ${ownerId} : ${e && e.message ? e.message : e}`);
    }
    try {
      // eslint-disable-next-line no-await-in-loop
      await send({
        userId: String(provider._id), role, type: TYPE_PRICING_UPDATED, templateType: TEMPLATE_RATE_ADDED,
        data: { ...base, total: totalIn(lang), service: serviceLabel(c.key, lang) },
      });
      out.notified.provider += 1;
    } catch (e) {
      logger.warn(`[reprice620c] notification prestataire ${provider._id} : ${e && e.message ? e.message : e}`);
    }
  }
  return out;
}

/**
 * Appel « jamais bloquant » depuis les contrôleurs de profil / tarifs : ne lève pas, renvoie
 * `{ repriced: n }` quand au moins une candidature a été recalculée, sinon null.
 */
async function repriceAfterRateChangeSafe(body, who) {
  try {
    if (!touchesRates(body)) return null;
    const r = await repriceAfterRateChange(who);
    return r.repriced.length ? { repriced: r.repriced.length, notified: r.notified } : null;
  } catch (e) {
    logger.warn(`[reprice620c] ${e && e.message ? e.message : e}`);
    return null;
  }
}

module.exports = {
  TYPE_PRICING_UPDATED,
  TYPE_SERVICE_CHANGED,
  TEMPLATE_SERVICE_REPRICED,
  TEMPLATE_SERVICE_REPRICED_OWNER,
  TEMPLATE_RATE_ADDED,
  TEMPLATE_RATE_ADDED_OWNER,
  RATE_FIELDS,
  touchesRates,
  repriceAfterRateChange,
  repriceAfterRateChangeSafe,
  serviceFingerprint,
  serviceLabel,
  unitLabel,
  isAligned,
  matchesExpected,
  isIncoherentTotal,
  repriceAfterServiceChange,
  datesRequiredMessage,
  ratePendingMessage,
  priceApplication,
  indicativePricing,
  repriceApplicationsForPost,
  tierForUnit,
};
