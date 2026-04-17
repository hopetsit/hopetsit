/**
 * Friend Routes — Phase 4 (Social).
 *
 * Endpoints:
 *   GET    /              → list my accepted friends
 *   GET    /requests      → list pending requests (incoming + outgoing)
 *   POST   /request       → send a friend request to { targetId, targetRole }
 *   POST   /:id/accept    → accept a pending request addressed to me
 *   POST   /:id/decline   → decline a pending request addressed to me
 *   DELETE /:id           → unfriend (works in either direction)
 *   POST   /:id/share     → toggle my position-sharing flag for this friend
 *
 * All endpoints require auth. Per-side sharing flag lets each user control
 * whether the other can see their live location (Phase 4.3 sockets).
 */
const express = require('express');
const { requireAuth } = require('../middleware/auth');
const Friendship = require('../models/Friendship');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const logger = require('../utils/logger');

const router = express.Router();

const ROLE_TO_MODEL_NAME = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };
const MODEL_BY_NAME = { Owner, Sitter, Walker };

function me(req) {
  return {
    id: req.user.id,
    role: req.user.role,
    model: ROLE_TO_MODEL_NAME[req.user.role] || 'Owner',
  };
}

/** Fetch a minimal user profile regardless of role, for enriching friend lists. */
async function fetchUserMini(id, modelName) {
  const Model = MODEL_BY_NAME[modelName];
  if (!Model) return null;
  const u = await Model.findById(id)
    .select('firstName lastName profilePicture location city avatar')
    .lean();
  return u
    ? {
        id: u._id,
        model: modelName,
        name: [u.firstName, u.lastName].filter(Boolean).join(' ').trim(),
        avatar: u.profilePicture || u.avatar || '',
        city: u.location?.city || u.city || '',
      }
    : null;
}

async function enrichFriendship(friendship, viewerId) {
  const isRequester = String(friendship.requesterId) === String(viewerId);
  const other = isRequester
    ? await fetchUserMini(friendship.addresseeId, friendship.addresseeModel)
    : await fetchUserMini(friendship.requesterId, friendship.requesterModel);
  const mySharePosition = isRequester
    ? friendship.requesterSharesPosition
    : friendship.addresseeSharesPosition;
  const theirSharePosition = isRequester
    ? friendship.addresseeSharesPosition
    : friendship.requesterSharesPosition;
  return {
    id: friendship._id,
    status: friendship.status,
    initiatedByMe: isRequester,
    other,
    mySharePosition,
    theirSharePosition,
    createdAt: friendship.createdAt,
    acceptedAt: friendship.acceptedAt,
  };
}

// ── GET /friends — my accepted friends ─────────────────────────────────────
router.get('/', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const friendships = await Friendship.find({
      status: 'accepted',
      $or: [
        { requesterId: user.id, requesterModel: user.model },
        { addresseeId: user.id, addresseeModel: user.model },
      ],
    })
      .sort({ acceptedAt: -1 })
      .lean();

    const enriched = await Promise.all(
      friendships.map((f) => enrichFriendship(f, user.id)),
    );
    res.json({ friends: enriched.filter((f) => f.other !== null) });
  } catch (e) {
    logger.error('[friends/list]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── GET /friends/requests — pending (incoming + outgoing) ──────────────────
router.get('/requests', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const [incoming, outgoing] = await Promise.all([
      Friendship.find({
        status: 'pending',
        addresseeId: user.id,
        addresseeModel: user.model,
      }).lean(),
      Friendship.find({
        status: 'pending',
        requesterId: user.id,
        requesterModel: user.model,
      }).lean(),
    ]);

    const [incomingEnriched, outgoingEnriched] = await Promise.all([
      Promise.all(incoming.map((f) => enrichFriendship(f, user.id))),
      Promise.all(outgoing.map((f) => enrichFriendship(f, user.id))),
    ]);

    res.json({
      incoming: incomingEnriched.filter((f) => f.other !== null),
      outgoing: outgoingEnriched.filter((f) => f.other !== null),
    });
  } catch (e) {
    logger.error('[friends/requests]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /friends/request — send a new request ─────────────────────────────
router.post('/request', requireAuth, async (req, res) => {
  try {
    const { targetId, targetRole } = req.body;
    const targetModel = ROLE_TO_MODEL_NAME[targetRole];
    if (!targetId || !targetModel) {
      return res
        .status(400)
        .json({ error: 'targetId and targetRole are required.' });
    }

    const user = me(req);
    if (String(targetId) === String(user.id) && targetModel === user.model) {
      return res.status(400).json({ error: 'Cannot befriend yourself.' });
    }

    // Avoid duplicates in either direction.
    const existing = await Friendship.findOne({
      $or: [
        {
          requesterId: user.id,
          requesterModel: user.model,
          addresseeId: targetId,
          addresseeModel: targetModel,
        },
        {
          requesterId: targetId,
          requesterModel: targetModel,
          addresseeId: user.id,
          addresseeModel: user.model,
        },
      ],
    });
    if (existing) {
      return res
        .status(409)
        .json({ error: `Already in state "${existing.status}".`, id: existing._id });
    }

    const friendship = new Friendship({
      requesterId: user.id,
      requesterModel: user.model,
      addresseeId: targetId,
      addresseeModel: targetModel,
      status: 'pending',
    });
    await friendship.save();

    logger.info(
      `[friends] ${user.model} ${user.id} → ${targetModel} ${targetId} (pending)`,
    );
    res.status(201).json({ friendship: await enrichFriendship(friendship, user.id) });
  } catch (e) {
    logger.error('[friends/request]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /friends/:id/accept ───────────────────────────────────────────────
router.post('/:id/accept', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const f = await Friendship.findById(req.params.id);
    if (!f) return res.status(404).json({ error: 'Request not found.' });
    if (String(f.addresseeId) !== String(user.id) || f.addresseeModel !== user.model) {
      return res.status(403).json({ error: 'Only the addressee can accept.' });
    }
    if (f.status !== 'pending') {
      return res.status(400).json({ error: `Already ${f.status}.` });
    }
    f.status = 'accepted';
    f.acceptedAt = new Date();
    await f.save();
    logger.info(`[friends] ${user.id} accepted ${f._id}`);
    res.json({ friendship: await enrichFriendship(f, user.id) });
  } catch (e) {
    logger.error('[friends/accept]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /friends/:id/decline ──────────────────────────────────────────────
router.post('/:id/decline', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const f = await Friendship.findById(req.params.id);
    if (!f) return res.status(404).json({ error: 'Request not found.' });
    if (String(f.addresseeId) !== String(user.id) || f.addresseeModel !== user.model) {
      return res.status(403).json({ error: 'Only the addressee can decline.' });
    }
    f.status = 'declined';
    f.declinedAt = new Date();
    await f.save();
    res.json({ ok: true });
  } catch (e) {
    logger.error('[friends/decline]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── DELETE /friends/:id — unfriend (either side) ───────────────────────────
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const user = me(req);
    const f = await Friendship.findById(req.params.id);
    if (!f) return res.status(404).json({ error: 'Not found.' });
    const isParty =
      (String(f.requesterId) === String(user.id) && f.requesterModel === user.model) ||
      (String(f.addresseeId) === String(user.id) && f.addresseeModel === user.model);
    if (!isParty) return res.status(403).json({ error: 'Not your friendship.' });
    await f.deleteOne();
    res.json({ ok: true });
  } catch (e) {
    logger.error('[friends/delete]', e);
    res.status(500).json({ error: e.message });
  }
});

// ── POST /friends/:id/share — toggle "I broadcast my position to X" ────────
router.post('/:id/share', requireAuth, async (req, res) => {
  try {
    const { share } = req.body;
    const user = me(req);
    const f = await Friendship.findById(req.params.id);
    if (!f || f.status !== 'accepted') {
      return res.status(404).json({ error: 'Accepted friendship not found.' });
    }
    const isRequester =
      String(f.requesterId) === String(user.id) && f.requesterModel === user.model;
    const isAddressee =
      String(f.addresseeId) === String(user.id) && f.addresseeModel === user.model;
    if (!isRequester && !isAddressee) {
      return res.status(403).json({ error: 'Not your friendship.' });
    }
    if (isRequester) f.requesterSharesPosition = !!share;
    if (isAddressee) f.addresseeSharesPosition = !!share;
    await f.save();
    res.json({ friendship: await enrichFriendship(f, user.id) });
  } catch (e) {
    logger.error('[friends/share]', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
