/**
 * Invoice Routes — v23.1
 * Mounted at /invoices in app.js + /admin/invoices for the admin endpoint.
 */
const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const {
  listMyInvoices,
  getInvoice,
  renderInvoiceHtml,
  adminListInvoices,
} = require('../controllers/invoiceController');

const router = express.Router();

// User-facing routes — owner / sitter / walker.
router.get('/my', requireAuth, requireRole('owner', 'sitter', 'walker'), listMyInvoices);
router.get('/:id', requireAuth, requireRole('owner', 'sitter', 'walker', 'admin'), getInvoice);
// Printable HTML — auth required to prevent invoice ID enumeration.
router.get('/:id/html', requireAuth, requireRole('owner', 'sitter', 'walker', 'admin'), renderInvoiceHtml);

module.exports = router;

// ─── Separate admin sub-router (mounted at /admin/invoices) ────────────────
const adminRouter = express.Router();
adminRouter.get('/', requireAuth, requireRole('admin'), adminListInvoices);
module.exports.adminRouter = adminRouter;
