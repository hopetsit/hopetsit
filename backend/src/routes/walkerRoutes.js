const express = require('express');
const multer = require('multer');

const {
  listWalkers,
  getWalkerProfile,
  findNearbyWalkers,
  getMyWalkerProfile,
  updateMyWalkerProfile,
  getMyWalkerRates,
  updateMyWalkerRates,
  submitIdentityVerification,
  getMyIdentityVerification,
} = require('../controllers/walkerController');
const { requireAuth, requireRole } = require('../middleware/auth');

const router = express.Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
});

/**
 * Walker routes — public discovery + authenticated self-management.
 *
 * Public:
 *   GET  /walkers                 -> paginated list (filter ?city=)
 *   GET  /walkers/nearby          -> geospatial lookup (?lat=&lng=&radiusInMeters=)
 *   GET  /walkers/:id             -> single public profile
 *
 * Authenticated walker only:
 *   GET  /walkers/me              -> my full profile
 *   PATCH /walkers/me             -> update my editable fields
 *   GET  /walkers/me/rates        -> my walkRates
 *   PUT  /walkers/me/rates        -> replace my walkRates
 *
 * NOTE: /walkers/me routes MUST be declared before /walkers/:id so Express
 * does not treat "me" as an id.
 */

// Authenticated walker self-management (declared first to avoid :id collision).
router.get('/me', requireAuth, requireRole('walker'), getMyWalkerProfile);
router.patch('/me', requireAuth, requireRole('walker'), updateMyWalkerProfile);
router.get('/me/rates', requireAuth, requireRole('walker'), getMyWalkerRates);
router.put('/me/rates', requireAuth, requireRole('walker'), updateMyWalkerRates);
// Session v3.2 — identity verification (parity with /sitters/identity-verification).
router.post(
  '/identity-verification',
  requireAuth,
  requireRole('walker'),
  upload.single('document'),
  submitIdentityVerification,
);
router.get(
  '/me/identity-verification',
  requireAuth,
  requireRole('walker'),
  getMyIdentityVerification,
);

// Public discovery.
router.get('/nearby', findNearbyWalkers);
router.get('/', listWalkers);
router.get('/:id', getWalkerProfile);

module.exports = router;
