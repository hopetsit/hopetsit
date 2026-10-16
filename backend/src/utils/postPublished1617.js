/**
 * 1617 (LEO, 16/10/2026, complément BOB au §D.1) — NOTIFICATION AU PROPRIÉTAIRE
 * DÈS LA PUBLICATION : cloche + téléphone, jamais d'e-mail.
 *
 *   type `post_published_617`, data { postId, notified: N, alertRadiusKm, role }
 *   N > 0 : « N gardiens à moins de 100 km ont été prévenus · en général ils
 *           répondent dans la journée » (« promeneurs » pour une balade) ;
 *   N = 0 : « Aucun gardien près de chez toi pour l'instant : partage ton annonce ».
 *
 * Pourquoi pas `sendNotification` : il exige un gabarit dans
 * locales/<lang>/notifications.json, fichiers tenus par ADA (en parallèle ce
 * soir). Les 9 textes vivent donc ICI et l'envoi reprend les mêmes briques :
 * document Notification (cloche), socket `notification.new`, push FCM avec le
 * son et la catégorie « Réservations » des préférences de la personne.
 * Jamais pour une republication déjà prévenue (appelant : `why: 'already'`),
 * jamais à un compte +test hors des tests (NODE_ENV=test).
 */
const logger = require('./logger');
const { TEST_EMAIL_RE } = require('./testAccount2809');
const { decrypt } = require('./encryption');

const TYPE = 'post_published_617';
const LANGS = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

const TEXTS = {
  fr: {
    title: 'Ta demande est publiée',
    some_sitter: '{n} gardiens à moins de {km} km ont été prévenus · en général ils répondent dans la journée',
    one_sitter: '1 gardien à moins de {km} km a été prévenu · en général il répond dans la journée',
    some_walker: '{n} promeneurs à moins de {km} km ont été prévenus · en général ils répondent dans la journée',
    one_walker: '1 promeneur à moins de {km} km a été prévenu · en général il répond dans la journée',
    none_sitter: 'Aucun gardien près de chez toi pour l’instant : partage ton annonce',
    none_walker: 'Aucun promeneur près de chez toi pour l’instant : partage ton annonce',
  },
  en: {
    title: 'Your request is live',
    some_sitter: '{n} sitters within {km} km have been notified · they usually reply within the day',
    one_sitter: '1 sitter within {km} km has been notified · they usually reply within the day',
    some_walker: '{n} walkers within {km} km have been notified · they usually reply within the day',
    one_walker: '1 walker within {km} km has been notified · they usually reply within the day',
    none_sitter: 'No sitter near you yet: share your request',
    none_walker: 'No walker near you yet: share your request',
  },
  es: {
    title: 'Tu solicitud está publicada',
    some_sitter: '{n} cuidadores a menos de {km} km han sido avisados · suelen responder el mismo día',
    one_sitter: '1 cuidador a menos de {km} km ha sido avisado · suele responder el mismo día',
    some_walker: '{n} paseadores a menos de {km} km han sido avisados · suelen responder el mismo día',
    one_walker: '1 paseador a menos de {km} km ha sido avisado · suele responder el mismo día',
    none_sitter: 'Aún no hay cuidadores cerca de ti: comparte tu anuncio',
    none_walker: 'Aún no hay paseadores cerca de ti: comparte tu anuncio',
  },
  de: {
    title: 'Deine Anfrage ist online',
    some_sitter: '{n} Betreuer im Umkreis von {km} km wurden benachrichtigt · sie antworten meist noch am selben Tag',
    one_sitter: '1 Betreuer im Umkreis von {km} km wurde benachrichtigt · antwortet meist noch am selben Tag',
    some_walker: '{n} Gassigeher im Umkreis von {km} km wurden benachrichtigt · sie antworten meist noch am selben Tag',
    one_walker: '1 Gassigeher im Umkreis von {km} km wurde benachrichtigt · antwortet meist noch am selben Tag',
    none_sitter: 'Noch kein Betreuer in deiner Nähe: teile deine Anfrage',
    none_walker: 'Noch kein Gassigeher in deiner Nähe: teile deine Anfrage',
  },
  it: {
    title: 'La tua richiesta è online',
    some_sitter: '{n} pet sitter entro {km} km sono stati avvisati · di solito rispondono in giornata',
    one_sitter: '1 pet sitter entro {km} km è stato avvisato · di solito risponde in giornata',
    some_walker: '{n} dog walker entro {km} km sono stati avvisati · di solito rispondono in giornata',
    one_walker: '1 dog walker entro {km} km è stato avvisato · di solito risponde in giornata',
    none_sitter: 'Nessun pet sitter vicino a te per ora: condividi il tuo annuncio',
    none_walker: 'Nessun dog walker vicino a te per ora: condividi il tuo annuncio',
  },
  pt: {
    title: 'O teu pedido está publicado',
    some_sitter: '{n} cuidadores a menos de {km} km foram avisados · normalmente respondem no próprio dia',
    one_sitter: '1 cuidador a menos de {km} km foi avisado · normalmente responde no próprio dia',
    some_walker: '{n} passeadores a menos de {km} km foram avisados · normalmente respondem no próprio dia',
    one_walker: '1 passeador a menos de {km} km foi avisado · normalmente responde no próprio dia',
    none_sitter: 'Ainda nenhum cuidador perto de ti: partilha o teu anúncio',
    none_walker: 'Ainda nenhum passeador perto de ti: partilha o teu anúncio',
  },
  ko: {
    title: '요청이 게시되었어요',
    some_sitter: '{km} km 이내 펫시터 {n}명에게 알림을 보냈어요 · 보통 당일에 답해요',
    one_sitter: '{km} km 이내 펫시터 1명에게 알림을 보냈어요 · 보통 당일에 답해요',
    some_walker: '{km} km 이내 산책 도우미 {n}명에게 알림을 보냈어요 · 보통 당일에 답해요',
    one_walker: '{km} km 이내 산책 도우미 1명에게 알림을 보냈어요 · 보통 당일에 답해요',
    none_sitter: '아직 근처에 펫시터가 없어요: 요청을 공유해 보세요',
    none_walker: '아직 근처에 산책 도우미가 없어요: 요청을 공유해 보세요',
  },
  ja: {
    title: '依頼を掲載しました',
    some_sitter: '{km} km以内のシッター{n}人に通知しました · 通常その日のうちに返事があります',
    one_sitter: '{km} km以内のシッター1人に通知しました · 通常その日のうちに返事があります',
    some_walker: '{km} km以内の散歩代行{n}人に通知しました · 通常その日のうちに返事があります',
    one_walker: '{km} km以内の散歩代行1人に通知しました · 通常その日のうちに返事があります',
    none_sitter: '近くにシッターがまだいません：依頼をシェアしましょう',
    none_walker: '近くに散歩代行がまだいません：依頼をシェアしましょう',
  },
  pl: {
    title: 'Twoje ogłoszenie jest online',
    some_sitter: '{n} opiekunów w promieniu {km} km zostało powiadomionych · zwykle odpowiadają tego samego dnia',
    one_sitter: '1 opiekun w promieniu {km} km został powiadomiony · zwykle odpowiada tego samego dnia',
    some_walker: '{n} wyprowadzaczy w promieniu {km} km zostało powiadomionych · zwykle odpowiadają tego samego dnia',
    one_walker: '1 wyprowadzacz w promieniu {km} km został powiadomiony · zwykle odpowiada tego samego dnia',
    none_sitter: 'Na razie brak opiekunów w pobliżu: udostępnij swoje ogłoszenie',
    none_walker: 'Na razie brak wyprowadzaczy w pobliżu: udostępnij swoje ogłoszenie',
  },
};

const langOf = (raw) => {
  const l = String(raw || '').trim().toLowerCase().slice(0, 2);
  return LANGS.includes(l) ? l : 'en';
};

/** Texte (titre + corps) dans une langue : pur, testé seul. */
function publishedText({ lang, notified, radiusKm, role }) {
  const t = TEXTS[langOf(lang)];
  const n = Number.isFinite(Number(notified)) ? Math.max(0, Math.round(Number(notified))) : 0;
  const r = role === 'walker' ? 'walker' : 'sitter';
  let body;
  if (n === 0) body = t[`none_${r}`];
  else if (n === 1) body = t[`one_${r}`];
  else body = t[`some_${r}`];
  body = body.replace('{n}', String(n)).replace('{km}', String(Math.round(Number(radiusKm) || 0)));
  return { title: t.title, body };
}

const plainEmail = (stored) => {
  let e = stored;
  try { e = decrypt(stored); } catch (_) { /* illisible */ }
  return typeof e === 'string' ? e.trim().toLowerCase() : '';
};

/**
 * Envoie la notification au propriétaire. Best-effort, jamais bloquant.
 * @returns {Promise<{sent:boolean, why?:string, bell?:boolean, push?:string}>}
 */
async function notifyOwnerPublished({ ownerId, owner, postId, notified, radiusKm, role }) {
  const out = { sent: false };
  try {
    if (!ownerId || !owner || !postId) return { ...out, why: 'missing' };
    const email = plainEmail(owner.email);
    if (TEST_EMAIL_RE.test(email) && process.env.NODE_ENV !== 'test') return { ...out, why: 'test_account' };

    const sender = require('../services/notificationSender');
    const appLocale = await sender.resolveAppLocaleAcrossRoles(owner, ownerId);
    const lang = langOf(appLocale || owner.language);
    const n = Number.isFinite(Number(notified)) ? Number(notified) : 0;
    const { title, body } = publishedText({ lang, notified: n, radiusKm, role });
    const data = {
      postId: String(postId), notified: n, alertRadiusKm: Math.round(Number(radiusKm) || 0),
      role: role === 'walker' ? 'walker' : 'sitter',
    };

    // 1) Cloche (document) puis socket avec l'id : l'app insère la ligne en direct.
    let created = null;
    try {
      const Notification = require('../models/Notification');
      created = await Notification.create({
        recipientRole: 'owner', recipientId: ownerId, actorRole: 'system', actorId: null, type: TYPE, title, body, data,
      });
      out.bell = true;
    } catch (e) {
      logger.warn(`[post1617] cloche non créée : ${e && e.message ? e.message : e}`);
    }
    try {
      const { emitToUser } = require('../sockets/emitter');
      const payload = {
        type: TYPE, title, body, data, recipientRole: 'owner', recipientId: String(ownerId), actorRole: 'system', actorId: null,
      };
      if (created) {
        payload.id = String(created._id); payload._id = payload.id; payload.notificationId = payload.id;
        payload.createdAt = created.createdAt ? new Date(created.createdAt).toISOString() : new Date().toISOString();
        payload.readAt = null;
      }
      emitToUser('owner', ownerId, 'notification.new', payload);
    } catch (_) { /* best-effort */ }

    // 2) Téléphone : catégorie « Réservations » et son de la personne ; jamais d'e-mail.
    const prefs = await sender.resolveNotificationPrefsAcrossRoles(owner, ownerId);
    if (prefs && prefs.categories && prefs.categories.bookings === false) {
      out.push = 'category_off';
    } else {
      const tokens = await gatherTokens(owner, ownerId);
      if (!tokens.length) out.push = 'no_token';
      else {
        const snd = sender.pushSoundConfig(prefs && prefs.sound);
        const firebaseAdmin = require('../config/firebaseAdmin');
        const message = {
          tokens,
          notification: { title, body },
          data: Object.fromEntries(Object.entries({ ...data, type: TYPE, route: `/post/${data.postId}`, sound: snd.dataSound })
            .map(([k, v]) => [k, String(v ?? '')])),
          android: { priority: 'high', notification: { ...snd.android } },
          apns: { headers: { 'apns-priority': '10', 'apns-push-type': 'alert' }, payload: { aps: { ...(snd.apnsSound ? { sound: snd.apnsSound } : {}) } } },
        };
        try {
          const r = await firebaseAdmin.messaging().sendEachForMulticast(message);
          out.push = r && r.successCount > 0 ? 'sent' : 'failed';
        } catch (e) {
          out.push = 'failed';
          logger.warn(`[post1617] push : ${e && e.message ? e.message : e}`);
        }
      }
    }
    out.sent = !!out.bell || out.push === 'sent';
    logger.info(`[post1617] propriétaire ${ownerId} prévenu (${lang}, N=${n}, cloche ${out.bell ? 'oui' : 'non'}, téléphone ${out.push})`);
    return out;
  } catch (e) {
    logger.warn(`[post1617] notification propriétaire : ${e && e.message ? e.message : e}`);
    return { ...out, why: 'error' };
  }
}

/** Jetons FCM de la personne (ses 3 profils), comme gatherFcmTokens. */
async function gatherTokens(primary, userId) {
  const set = new Set((primary && primary.fcmTokens) || []);
  try {
    const or = [{ _id: userId }];
    if (primary && primary.email) or.push({ email: primary.email });
    if (primary && primary.oldId != null) or.push({ oldId: primary.oldId });
    const docs = await Promise.all(['Owner', 'Sitter', 'Walker'].map((m) => require(`../models/${m}`)
      .find({ $or: or }).select('fcmTokens').lean()));
    for (const d of docs.flat()) for (const t of d.fcmTokens || []) if (t) set.add(t);
  } catch (_) { /* jetons du doc principal seulement */ }
  return [...set].filter(Boolean);
}

module.exports = { TYPE, TEXTS, LANGS, publishedText, notifyOwnerPublished };
