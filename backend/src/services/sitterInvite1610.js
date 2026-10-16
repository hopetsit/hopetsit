/**
 * 1610 (SAM, 16/10/2026) — « LES PRESTATAIRES RECRUTENT » : ordre explicite de
 * Daniel (16/10, chat), exception unique à la règle « pas d'envoi en plus » du
 * 28/09. Constat : des dizaines de gardiens/promeneurs inscrits, 0 demande à
 * Paris. Chaque gardien connaît des propriétaires : on lui demande UNE fois de
 * partager sa fiche publique.
 *
 * RÈGLES (toutes testées dans tests/sitterInvite1610.test.js) :
 *   · qui : gardiens (Sitter) et promeneurs (Walker) ACTIFS, inscrits avec une
 *     VILLE (`city`, sinon `location.city`, sinon `coverageCity`) ;
 *   · jamais : comptes +test, sonde (@invalid.example), staff, suspendus, bannis ;
 *     en mode `testOnly`, SEULS les comptes +test (essai sans déranger personne) ;
 *   · UNE fois par PERSONNE (registre SitterInvite1610, personKey = empreinte de
 *     l'e-mail) : un gardien qui est aussi promeneur n'est prévenu qu'une fois
 *     (profil gardien choisi) ;
 *   · jamais entre 22 h et 8 h, heure LOCALE du destinataire (fuseau de sa
 *     position, sinon de son pays, sinon Paris) : il attend le matin ;
 *   · étalé : au plus BATCH_PER_TICK envois par passage, un passage toutes les
 *     TICK_MS (≈ 150/h au maximum) ;
 *   · canal : cloche + notification du téléphone, JAMAIS d'e-mail
 *     (`channels.email = false`) ; gabarit `sitter_invite_1610` (9 langues) ;
 *   · le lien de la fiche porte utm_source=app&utm_medium=share&
 *     utm_campaign=sitter_invite : les visites et les demandes publiées qui en
 *     découlent se lisent dans l'admin « Trafic du site » (campagne sitter_invite).
 *   · le texte de la notification contient le lien en clair (les apps publiées
 *     n'ont pas de bouton « partager ma fiche » : aucun build demandé).
 */
const crypto = require('crypto');
const logger = require('../utils/logger');
const { decrypt } = require('../utils/encryption');
const { TEST_EMAIL_RE } = require('../utils/testAccount2809');

const TYPE = 'sitter_invite_1610';
const SITE = 'https://www.hopetsit.com';
const UTM = 'utm_source=app&utm_medium=share&utm_campaign=sitter_invite';
const NIGHT_START = 22;
const NIGHT_END = 8;
const BATCH_PER_TICK = 25;
const TICK_MS = 10 * 60 * 1000;
const SCAN_LIMIT = 3000;
const DEFAULT_TZ = 'Europe/Paris';
const COUNTRY_TZ = { US: 'America/Chicago', GB: 'Europe/London', IE: 'Europe/London', PT: 'Europe/Lisbon', CA: 'America/Toronto', BR: 'America/Sao_Paulo', JP: 'Asia/Tokyo', KR: 'Asia/Seoul' };
const HARD_STAFF_EMAILS = ['dadaciao84@gmail.com', 'hopetsit@gmail.com'];
const NOT_A_PERSON_RE = /@invalid\.example$/i;
const SELECT = '_id email status isStaff city coverageCity location country appLocale fcmTokens';

const sha = (v) => crypto.createHash('sha256').update(String(v)).digest('hex').slice(0, 40);
const plainEmail = (stored) => {
  let e = stored;
  try { e = decrypt(stored); } catch (_) { /* illisible */ }
  return typeof e === 'string' ? e.trim().toLowerCase() : '';
};
const staffEmails = () => new Set([
  ...HARD_STAFF_EMAILS,
  ...String(process.env.STAFF_EMAILS || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean),
]);
const cityOf = (doc) => String(
  (doc && doc.city) || (doc && doc.location && doc.location.city) || (doc && doc.coverageCity) || '',
).trim();
const coordsOf = (doc) => {
  const c = doc && doc.location && doc.location.coordinates;
  if (!Array.isArray(c) || c.length < 2) return null;
  const lng = Number(c[0]); const lat = Number(c[1]);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || (lat === 0 && lng === 0)) return null;
  return { lat, lng };
};
const timeZoneOf = (doc) => {
  const c = coordsOf(doc);
  if (c) {
    try {
      const tz = require('./plushService607').timeZoneFor(c.lat, c.lng);
      if (tz) return tz;
    } catch (_) { /* repli */ }
  }
  const cc = String((doc && doc.country) || '').toUpperCase();
  return COUNTRY_TZ[cc] || DEFAULT_TZ;
};
const localHour = (tz, instantMs) => {
  try {
    const h = new Intl.DateTimeFormat('en-US', { timeZone: tz, hourCycle: 'h23', hour: '2-digit' })
      .formatToParts(new Date(instantMs)).find((p) => p.type === 'hour');
    return Number(h && h.value) % 24;
  } catch (_) {
    return new Date(instantMs).getUTCHours();
  }
};
const isNight = (tz, instantMs) => {
  const h = localHour(tz, instantMs);
  return h >= NIGHT_START || h < NIGHT_END;
};
const profileUrl = (role, id) => `${SITE}/p/${role}/${id}?${UTM}`;

/**
 * Choisit qui doit encore recevoir l'invitation. Ne modifie rien, n'envoie rien.
 * @returns {Promise<{candidates:Array, excluded:Object}>}
 */
const selectCandidates = async ({ testOnly = false, now = new Date() } = {}) => {
  const Sitter = require('../models/Sitter');
  const Walker = require('../models/Walker');
  const Registry = require('../models/SitterInvite1610');
  const staff = staffEmails();
  const excluded = { test: 0, notTest: 0, staff: 0, inactive: 0, noCity: 0, probe: 0, already: 0, samePerson: 0, night: 0 };
  const already = new Set((await Registry.find({}).select('personKey').lean()).map((r) => r.personKey));
  const seen = new Set();
  const candidates = [];
  // Gardiens d'abord : une personne qui a les deux profils reçoit l'invitation gardien.
  for (const [role, Model] of [['sitter', Sitter], ['walker', Walker]]) {
    let docs = [];
    try {
      docs = await Model.find({}).select(SELECT).limit(SCAN_LIMIT).lean();
    } catch (e) {
      logger.warn(`[invite1610] lecture ${role} : ${e && e.message ? e.message : e}`);
    }
    for (const d of docs) {
      const e = plainEmail(d.email);
      if (NOT_A_PERSON_RE.test(e)) { excluded.probe += 1; continue; }
      const isTest = TEST_EMAIL_RE.test(e);
      if (testOnly && !isTest) { excluded.notTest += 1; continue; }
      if (!testOnly && isTest) { excluded.test += 1; continue; }
      if (d.isStaff === true || staff.has(e)) { excluded.staff += 1; continue; }
      if (d.status && d.status !== 'active') { excluded.inactive += 1; continue; }
      const city = cityOf(d);
      if (!city) { excluded.noCity += 1; continue; }
      const personKey = e ? `e:${sha(e)}` : `i:${String(d._id)}`;
      if (already.has(personKey)) { excluded.already += 1; continue; }
      if (seen.has(personKey)) { excluded.samePerson += 1; continue; }
      seen.add(personKey);
      const tz = timeZoneOf(d);
      const night = isNight(tz, now.getTime());
      if (night) excluded.night += 1;
      candidates.push({ id: String(d._id), role, personKey, city, tz, night, isTest, hasToken: Array.isArray(d.fcmTokens) && d.fcmTokens.length > 0 });
    }
  }
  return { candidates, excluded };
};

/**
 * Un passage : envoie au plus `limit` invitations à ceux pour qui il fait jour.
 * `dryRun` : compte sans rien écrire ni envoyer. Ne lève jamais.
 */
const runSitterInvites = async (opts = {}) => {
  const now = opts.now instanceof Date ? opts.now : new Date();
  const testOnly = opts.testOnly === true;
  const dryRun = opts.dryRun === true;
  // Essai de nuit sur les comptes +test SEULEMENT : jamais pour une vraie personne.
  const ignoreNight = testOnly && opts.ignoreNight === true;
  const limit = Number.isFinite(Number(opts.limit)) ? Math.max(0, Number(opts.limit)) : BATCH_PER_TICK;
  const send = typeof opts.send === 'function' ? opts.send : require('./notificationSender').sendNotification;
  const Registry = require('../models/SitterInvite1610');
  const report = { testOnly, dryRun, eligible: 0, waitingNight: 0, sent: [], failed: 0, skipped: {} };
  let selection;
  try {
    selection = await selectCandidates({ testOnly, now });
  } catch (e) {
    logger.warn(`[invite1610] sélection : ${e && e.message ? e.message : e}`);
    return report;
  }
  report.skipped = selection.excluded;
  const daytime = selection.candidates.filter((c) => ignoreNight || !c.night);
  report.eligible = selection.candidates.length;
  report.waitingNight = selection.candidates.length - daytime.length;
  report.byCity = {};
  for (const c of selection.candidates) report.byCity[c.city] = (report.byCity[c.city] || 0) + 1;
  if (dryRun) return report;

  for (const c of daytime.slice(0, limit)) {
    let claim;
    try {
      // Place prise AVANT l'envoi : jamais deux fois, même si deux serveurs balaient.
      // eslint-disable-next-line no-await-in-loop
      claim = await Registry.create({ personKey: c.personKey, recipientId: c.id, recipientRole: c.role, city: c.city, timeZone: c.tz, testOnly });
    } catch (e) {
      if (e && e.code === 11000) { report.skipped.already = (report.skipped.already || 0) + 1; continue; }
      logger.warn(`[invite1610] registre ${c.id} : ${e && e.message ? e.message : e}`);
      continue;
    }
    try {
      // eslint-disable-next-line no-await-in-loop
      await send({
        userId: c.id,
        role: c.role,
        type: TYPE,
        data: {
          profileUrl: profileUrl(c.role, c.id),
          providerRole: c.role,
          providerId: c.id,
          sitterInvite1610: '1',
        },
        channels: { email: false },
      });
      report.sent.push({ id: c.id, role: c.role, city: c.city, tz: c.tz });
      logger.info(`[invite1610] envoyé : ${c.role} ${c.id} (${c.city}, ${c.tz}${testOnly ? ', test' : ''})`);
    } catch (e) {
      report.failed += 1;
      // eslint-disable-next-line no-await-in-loop
      await Registry.updateOne({ _id: claim._id }, { $set: { status: 'failed', error: String(e && e.message ? e.message : e).slice(0, 300) } });
      logger.warn(`[invite1610] envoi échoué ${c.role} ${c.id} : ${e && e.message ? e.message : e}`);
    }
  }
  return report;
};

let timer = null;
let running = false;
const tick = async () => {
  if (running) return;
  running = true;
  try {
    const r = await runSitterInvites();
    if (r.sent.length || r.failed) logger.info(`[invite1610] passage : ${r.sent.length} envoyé(s), ${r.failed} échec(s), ${r.waitingNight} en attente du matin`);
  } catch (e) {
    logger.warn(`[invite1610] passage : ${e && e.message ? e.message : e}`);
  } finally {
    running = false;
  }
};
const startSitterInviteScheduler = () => {
  if (timer) return timer;
  if (String(process.env.SITTER_INVITE_1610_OFF || '') === '1') {
    logger.info('[invite1610] planificateur désactivé (SITTER_INVITE_1610_OFF=1)');
    return null;
  }
  timer = setInterval(tick, TICK_MS);
  if (typeof timer.unref === 'function') timer.unref();
  setTimeout(tick, 90 * 1000).unref();
  logger.info(`[invite1610] planificateur démarré : ${BATCH_PER_TICK} envois au plus toutes les ${TICK_MS / 60000} min, jamais 22 h-8 h locale`);
  return timer;
};
const stopSitterInviteScheduler = () => { if (timer) clearInterval(timer); timer = null; };

module.exports = {
  TYPE, BATCH_PER_TICK, TICK_MS, profileUrl, isNight, timeZoneOf,
  selectCandidates, runSitterInvites, startSitterInviteScheduler, stopSitterInviteScheduler,
};
