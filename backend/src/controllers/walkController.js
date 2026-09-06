const WalkSession = require('../models/WalkSession');
const Booking = require('../models/Booking');
const { emitToWalk } = require('../sockets/emitter');
const logger = require('../utils/logger');

const startWalk = async (req, res) => {
  try {
    const { bookingId } = req.body || {};
    if (!bookingId) return res.status(400).json({ error: 'bookingId is required.' });
    const booking = await Booking.findById(bookingId).select('ownerId sitterId paymentStatus status');
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    if (String(booking.sitterId) !== req.user.id) {
      return res.status(403).json({ error: 'Only the assigned sitter can start a walk.' });
    }
    if (booking.paymentStatus !== 'paid') {
      return res.status(400).json({ error: 'Booking payment must be completed to start a walk.' });
    }

    // Close any previously active session for the same booking.
    await WalkSession.updateMany(
      { bookingId, status: 'active' },
      { $set: { status: 'ended', endedAt: new Date() } }
    );

    const walk = await WalkSession.create({
      bookingId,
      sitterId: booking.sitterId,
      ownerId: booking.ownerId,
      startedAt: new Date(),
      status: 'active',
      positions: [],
    });
    // v552 — Daniel : « faut-il un bouton on/off dans les messages pour être
    // prévenu quand il promène ? ». Réponse produit : non — le propriétaire ne
    // veut pas s'abonner à quelque chose, il veut être prévenu pendant SA
    // réservation, et le promeneur ne doit rien avoir à faire de plus que
    // « Démarrer la balade ». On notifie donc automatiquement, ici.
    try {
      const { sendNotification } = require('../services/notificationSender');
      await sendNotification({
        userId: booking.ownerId,
        role: 'owner',
        type: 'walk_started',
        data: { bookingId: String(bookingId), walkId: String(walk._id) },
        actor: { role: 'sitter', id: req.user.id },
      });
    } catch (nerr) {
      logger.warn(`[startWalk] notify owner failed : ${nerr?.message || nerr}`);
    }

    res.status(201).json({ walk });
  } catch (e) {
    logger.error('startWalk error', e);
    res.status(500).json({ error: 'Unable to start walk.' });
  }
};

const pushPosition = async (req, res) => {
  try {
    const { id } = req.params;
    const { lat, lng } = req.body || {};
    if (typeof lat !== 'number' || typeof lng !== 'number') {
      return res.status(400).json({ error: 'lat and lng (numbers) are required.' });
    }
    const walk = await WalkSession.findById(id);
    if (!walk) return res.status(404).json({ error: 'Walk not found.' });
    if (String(walk.sitterId) !== req.user.id) {
      return res.status(403).json({ error: 'Only the sitter can push positions.' });
    }
    if (walk.status !== 'active') {
      return res.status(400).json({ error: 'Walk is not active.' });
    }
    const position = { lat, lng, timestamp: new Date() };
    walk.positions.push(position);
    await walk.save();
    emitToWalk(id, 'walk.position', { walkId: id, ...position });
    res.json({ ok: true, positionsCount: walk.positions.length });
  } catch (e) {
    logger.error('pushPosition error', e);
    res.status(500).json({ error: 'Unable to push position.' });
  }
};

const endWalk = async (req, res) => {
  try {
    const { id } = req.params;
    const walk = await WalkSession.findById(id);
    if (!walk) return res.status(404).json({ error: 'Walk not found.' });
    if (String(walk.sitterId) !== req.user.id) {
      return res.status(403).json({ error: 'Only the sitter can end the walk.' });
    }
    walk.status = 'ended';
    walk.endedAt = new Date();
    await walk.save();
    emitToWalk(id, 'walk.ended', { walkId: id, endedAt: walk.endedAt });

    // v552 — résumé de fin de balade au propriétaire (durée + points GPS).
    try {
      const { sendNotification } = require('../services/notificationSender');
      const minutes = walk.startedAt
        ? Math.max(1, Math.round((walk.endedAt - walk.startedAt) / 60000))
        : 0;
      await sendNotification({
        userId: walk.ownerId,
        role: 'owner',
        type: 'walk_finished',
        data: {
          bookingId: String(walk.bookingId),
          walkId: String(walk._id),
          minutes,
        },
        actor: { role: 'sitter', id: req.user.id },
      });
    } catch (nerr) {
      logger.warn(`[endWalk] notify owner failed : ${nerr?.message || nerr}`);
    }

    res.json({ walk });
  } catch (e) {
    logger.error('endWalk error', e);
    res.status(500).json({ error: 'Unable to end walk.' });
  }
};

const getActiveWalk = async (req, res) => {
  try {
    const { bookingId } = req.query || {};
    if (!bookingId) return res.status(400).json({ error: 'bookingId is required.' });
    const walk = await WalkSession.findOne({ bookingId, status: 'active' })
      .sort({ startedAt: -1 })
      .lean();
    if (!walk) return res.json({ walk: null });
    const uid = req.user.id;
    const isParticipant =
      String(walk.sitterId) === uid || String(walk.ownerId) === uid;
    if (!isParticipant) return res.status(403).json({ error: 'Not a participant.' });
    res.json({ walk });
  } catch (e) {
    logger.error('getActiveWalk error', e);
    res.status(500).json({ error: 'Unable to fetch active walk.' });
  }
};

module.exports = { startWalk, pushPosition, endWalk, getActiveWalk };
