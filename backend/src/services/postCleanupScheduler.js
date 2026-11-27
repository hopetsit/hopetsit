/**
 * postCleanupScheduler.js — v23.1.288.
 *
 * Daniel : "après 48h que le service soit FINI, les annonces publiées
 * s'effacent automatiquement."
 *
 * A published request post (annonce) becomes stale once its service is over.
 * "Service over" is detected two ways:
 *   1. closedAt — set by completeBooking() when the related booking is marked
 *      'completed' (the precise "service finished" signal).
 *   2. endDate — the requested service window's end. Even if the booking was
 *      never explicitly completed (or the request was never booked), once the
 *      end date is 48h in the past the annonce is moot and should disappear.
 *
 * 48h after EITHER of those, the post is HARD-deleted (Daniel wants it erased,
 * not just hidden). Media posts (no endDate, never closed) are never matched.
 *
 * Runs hourly, mirrors the structure of mapReportTtlScheduler / payoutScheduler.
 */

const logger = require('../utils/logger');
const Post = require('../models/Post');

const ONE_HOUR_MS = 60 * 60 * 1000;
const GRACE_MS = 48 * 60 * 60 * 1000; // 48h after the service ends.

let timer = null;

/** 11/11 — historique avant effacement. Coupe-circuit : POST_ARCHIVE_1111=off → ancien comportement exact. */
const archiveEnabled = () => String(process.env.POST_ARCHIVE_1111 || '').trim().toLowerCase() !== 'off';
const firstName = (n) => String(n || '').trim().split(/\s+/)[0] || '';
const isTestOwner = (o, post) => /\+test|@example\.|@invalid\.example|\.test$/i.test(String((o && o.email) || ''))
  || (post.location && Number.isFinite(post.location.lat) && Number.isFinite(post.location.lng)
    && Math.abs(post.location.lat + 35) <= 1 && Math.abs(post.location.lng + 30) <= 1);

/**
 * Écrit une ligne d'historique par demande (jamais deux fois la même : clé postId).
 * @returns {Promise<Set<string>>} ids des demandes dont l'historique est bien écrit.
 */
async function archivePosts(posts, opts = {}) {
  const PostArchive = require('../models/PostArchive1111');
  const Application = require('../models/Application');
  const Owner = require('../models/Owner');
  const ok = new Set();
  const ownerIds = [...new Set(posts.map((p) => String(p.ownerId || '')).filter(Boolean))];
  const owners = ownerIds.length
    ? await Owner.find({ _id: { $in: ownerIds } }).select('name email').lean()
    : [];
  const ownerById = new Map(owners.map((o) => [String(o._id), o]));
  for (const p of posts) {
    try {
      const o = ownerById.get(String(p.ownerId || ''));
      const applicationsCount = await Application.countDocuments({ postId: p._id });
      await PostArchive.updateOne(
        { postId: p._id },
        {
          $setOnInsert: {
            postId: p._id,
            ownerId: p.ownerId || null,
            ownerFirstName: firstName(o && o.name),
            city: String((p.location && p.location.city) || p.city || ''),
            serviceTypes: Array.isArray(p.serviceTypes) ? p.serviceTypes : [],
            dateMode: p.dateMode || null,
            startDate: p.startDate || null,
            endDate: p.endDate || null,
            body: String(p.body || '').slice(0, 120), // court extrait : pas de long texte libre gardé
            status: String(p.status || ''),
            closedAt: p.closedAt || null,
            bookingId: (p.reservedBy && p.reservedBy.bookingId) || null,
            applicationsCount,
            postCreatedAt: p.createdAt || null,
            reason: opts.reason || (p.closedAt ? 'service_termine' : 'date_passee'),
            isTest: !!isTestOwner(o, p),
            archivedAt: new Date(),
          },
        },
        { upsert: true },
      );
      ok.add(String(p._id));
    } catch (e) {
      logger.warn(`[postCleanup] historique non écrit pour ${p._id} : ${e.message}`);
    }
  }
  return ok;
}

/**
 * Delete annonces whose service finished more than 48h ago.
 * 11/11/2026 (BOB, ordre de Daniel) : une ligne d'historique est écrite AVANT ; une demande dont
 * l'historique n'a pas pu être écrit n'est PAS effacée (elle repassera à l'heure suivante). Les demandes
 * à date de début seule (sans date de fin) sont aussi effacées 48 h après ce début (avant : jamais).
 * @returns {Promise<number>} number of posts deleted.
 */
async function purgeFinishedPosts() {
  const now = Date.now();
  const cutoff = new Date(now - GRACE_MS);
  const withArchive = archiveEnabled();
  // Either the booking was completed (closedAt) OR the requested period ended
  // (endDate), and that happened more than 48h ago.
  const or = [
    { closedAt: { $ne: null, $lt: cutoff } },
    { endDate: { $ne: null, $lt: cutoff } },
  ];
  // (ZOE) jamais une demande réservée par cette clause : une réservation en cours ne perd pas son annonce ;
  // réservée puis terminée → couverte par closedAt.
  if (withArchive) {
    or.push({
      postType: 'request', 'reservedBy.bookingId': { $in: [null] },
      endDate: { $in: [null] }, startDate: { $ne: null, $lt: cutoff },
    });
  }
  const filter = { $or: or };

  // Capture the ids first so we can clean up dangling Applications too.
  let ids;
  if (withArchive) {
    const stale = await Post.find(filter)
      .select('_id ownerId postType body serviceTypes dateMode startDate endDate status closedAt reservedBy location city createdAt')
      .lean();
    if (!stale.length) return 0;
    const archived = await archivePosts(stale);
    ids = stale.filter((p) => archived.has(String(p._id))).map((p) => p._id);
    if (!ids.length) return 0;
  } else {
    const stale = await Post.find(filter).select('_id').lean();
    if (!stale.length) return 0;
    ids = stale.map((p) => p._id);
  }

  const result = await Post.deleteMany({ _id: { $in: ids } });

  // Best-effort: drop orphaned Applications pointing at the deleted posts so
  // they don't linger in candidate feeds. Never let this fail the purge.
  try {
    const Application = require('../models/Application');
    await Application.deleteMany({ postId: { $in: ids } });
  } catch (e) {
    logger.warn(`[postCleanup] application cleanup skipped: ${e.message}`);
  }

  if (result.deletedCount > 0) {
    logger.info(
      `🧹 [postCleanup] Deleted ${result.deletedCount} annonce(s) finished >48h ago`,
    );
  }
  return result.deletedCount || 0;
}

/**
 * 27/11/2026 (BOB, ordre de Daniel : « efface celles sans date de début, ça sert à rien ») — demandes SANS AUCUNE
 * date (« dates à prévoir »), jamais réservées, publiées depuis plus de `olderThanDays` jours : une ligne d'historique
 * (reason 'sans_date') puis effacement de la demande et de ses candidatures. Jamais automatique : appelée seulement par
 * POST /admin/posts-history-1111/purge-nodate. `dryRun` (défaut) ne touche à rien et rend la liste.
 */
async function purgeNoDatePosts({ olderThanDays = 14, dryRun = true } = {}) {
  const days = Math.min(365, Math.max(1, Number(olderThanDays) || 14));
  const cutoff = new Date(Date.now() - days * 24 * ONE_HOUR_MS);
  const Application = require('../models/Application');
  const found = await Post.find({
    postType: 'request', 'reservedBy.bookingId': { $in: [null] },
    startDate: { $in: [null] }, endDate: { $in: [null] }, closedAt: { $in: [null] },
    createdAt: { $lt: cutoff },
  }).select('_id ownerId postType body serviceTypes dateMode startDate endDate status closedAt reservedBy location city createdAt').lean();
  // 27/11 (ZOE, contrôle du lot) — `reservedBy` est posé « au mieux » au choix du gardien (applicationController) : une
  // demande dont une candidature est acceptée ou liée à une réservation n'est JAMAIS effacée, même sans ce drapeau.
  const linked = found.length
    ? new Set((await Application.distinct('postId', { postId: { $in: found.map((p) => p._id) }, $or: [{ status: 'accepted' }, { bookingId: { $ne: null } }] })).map(String))
    : new Set();
  const stale = found.filter((p) => !linked.has(String(p._id)));
  const applications = stale.length ? await Application.countDocuments({ postId: { $in: stale.map((p) => p._id) } }) : 0;
  const items = stale.map((p) => ({ postId: String(p._id), city: String((p.location && p.location.city) || p.city || ''), createdAt: p.createdAt }));
  if (dryRun || !stale.length) return { dryRun: true, olderThanDays: days, found: stale.length, applications, deleted: 0, items };
  const archived = await archivePosts(stale, { reason: 'sans_date' });
  const ids = stale.filter((p) => archived.has(String(p._id))).map((p) => p._id);
  if (!ids.length) return { dryRun: false, olderThanDays: days, found: stale.length, applications, deleted: 0, items };
  const result = await Post.deleteMany({ _id: { $in: ids }, startDate: { $in: [null] }, endDate: { $in: [null] }, 'reservedBy.bookingId': { $in: [null] } });
  let applicationsDeleted = 0;
  try { applicationsDeleted = (await Application.deleteMany({ postId: { $in: ids } })).deletedCount || 0; } catch (e) { logger.warn(`[postCleanup] candidatures sans date non effacées : ${e.message}`); }
  logger.info(`🧹 [postCleanup] ${result.deletedCount} demande(s) sans date effacée(s) (ordre admin), ${applicationsDeleted} candidature(s)`);
  return { dryRun: false, olderThanDays: days, found: stale.length, applications, deleted: result.deletedCount || 0, applicationsDeleted, items };
}

async function tick() {
  try {
    await purgeFinishedPosts();
  } catch (error) {
    logger.error('[postCleanup] sweep failed', error);
  }
}

/**
 * Start the post-cleanup scheduler.
 * @param {{intervalMs?: number, runImmediately?: boolean}} opts
 */
function startPostCleanupScheduler(opts = {}) {
  const intervalMs = opts.intervalMs || ONE_HOUR_MS;
  const runImmediately = opts.runImmediately !== false;

  if (timer) return;

  if (runImmediately) tick(); // fire-and-forget

  timer = setInterval(tick, intervalMs);
  if (typeof timer.unref === 'function') {
    timer.unref();
  }

  logger.info(
    `🗓️ Post cleanup scheduler started (every ${Math.round(intervalMs / 60000)}m, 48h grace)`,
  );
}

function stopPostCleanupScheduler() {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}

module.exports = {
  startPostCleanupScheduler,
  stopPostCleanupScheduler,
  // exported for tests / manual runs
  purgeFinishedPosts,
  purgeNoDatePosts,
  archivePosts,
};
