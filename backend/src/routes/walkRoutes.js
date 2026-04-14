const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const {
  startWalk,
  pushPosition,
  endWalk,
  getActiveWalk,
} = require('../controllers/walkController');

const router = express.Router();

router.post('/start', requireAuth, requireRole('sitter'), startWalk);
router.post('/:id/position', requireAuth, requireRole('sitter'), pushPosition);
router.post('/:id/end', requireAuth, requireRole('sitter'), endWalk);
router.get('/active', requireAuth, getActiveWalk);

module.exports = router;
