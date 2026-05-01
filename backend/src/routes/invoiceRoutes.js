/**
 * Invoice Routes — v23.1
 * Mounted at /invoices in app.js + /admin/invoices for the admin endpoint.
 */
const express = require('express');
const jwt = require('jsonwebtoken');
const { requireAuth, requireRole } = require('../middleware/auth');
const {
  listMyInvoices,
  getInvoice,
  renderInvoiceHtml,
  adminListInvoices,
} = require('../controllers/invoiceController');

const router = express.Router();

// v23.1 part 34 — middleware spécial pour /:id/html : accepte le JWT soit
// dans le header Authorization, soit dans le query param ?token=JWT. Permet
// au mobile d'ouvrir la facture dans un browser/webview qui n'a pas accès
// au header (cas Daniel screenshot "Authorization token is required").
const requireAuthQueryOrHeader = (req, res, next) => {
  try {
    const headerToken = (req.headers.authorization || '').toString().trim();
    const queryToken = (req.query.token || '').toString().trim();
    let token = null;
    if (headerToken.toLowerCase().startsWith('bearer ')) {
      token = headerToken.slice(7).trim();
    } else if (queryToken.length > 0) {
      token = queryToken;
    }
    if (!token) {
      return res.status(401).send('Authorization token is required.');
    }
    const secret = process.env.JWT_SECRET;
    if (!secret) {
      return res.status(500).send('JWT_SECRET not configured.');
    }
    const payload = jwt.verify(token, secret);
    req.user = { id: payload.id, role: payload.role };
    return next();
  } catch (e) {
    return res.status(401).send('Invalid or expired token.');
  }
};

// User-facing routes — owner / sitter / walker.
router.get('/my', requireAuth, requireRole('owner', 'sitter', 'walker'), listMyInvoices);
router.get('/:id', requireAuth, requireRole('owner', 'sitter', 'walker', 'admin'), getInvoice);
// Printable HTML — auth via header OR query param (mobile WebView).
router.get('/:id/html', requireAuthQueryOrHeader, renderInvoiceHtml);

module.exports = router;

// ─── Separate admin sub-router (mounted at /admin/invoices) ────────────────
const adminRouter = express.Router();
adminRouter.get('/', requireAuth, requireRole('admin'), adminListInvoices);
module.exports.adminRouter = adminRouter;
