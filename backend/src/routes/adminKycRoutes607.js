'use strict';

/**
 * 607 (FLO, 02/10/2026) — GET /admin/kyc-people : LECTURE SEULE.
 *
 *   ?status=all (défaut) | verified | paid_unverified
 *
 * Réponse : { generatedAt, summary, people[] } — une ligne par profil gardien /
 * promeneur vérifié OU ayant payé la vérification (3 €) : nom, rôle, ville,
 * date de vérification, méthode (didit / persona / admin_manual), payé oui/non,
 * date et canal du paiement, blocage éventuel (« session_jamais_creee » = payé
 * il y a plus d'une heure sans session chez le prestataire). Les comptes de
 * test / internes sont marqués `isTest` et exclus du résumé.
 * summary.revenue = revenus KYC par période (allTime, thisMonth, last30d,
 * last7d, today) pour les cartes du tableau de bord.
 *
 * Aucun e-mail, aucun identifiant de paiement ni de session dans la réponse.
 */

const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const { isInternalEmail } = require('../utils/userCounts');
const { personRow, summarize } = require('../utils/kycPeople607');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin')];

const plainEmail = (stored) => {
  try { return require('../utils/encryption').decrypt(stored); } catch (_) { return stored; }
};

const FIELDS = 'name email city location.city coverageCity kycStatus kycPaidAt kycVerifiedAt '
  + 'kycApplicantId kycPaymentIntentId identityVerification.status identityVerification.reviewedAt';

router.get('/', requireAdmin, async (req, res) => {
  try {
    const status = String(req.query.status || 'all');
    if (!['all', 'verified', 'paid_unverified'].includes(status)) {
      return res.status(400).json({ error: "status doit valoir 'all', 'verified' ou 'paid_unverified'." });
    }
    const filter = {
      $or: [
        { kycStatus: 'verified' },
        { 'identityVerification.status': 'verified' },
        { kycPaidAt: { $ne: null } },
      ],
    };
    const [sitters, walkers] = await Promise.all([
      Sitter.find(filter).select(FIELDS).lean(),
      Walker.find(filter).select(FIELDS).lean(),
    ]);
    const now = new Date();
    const isInternal = (d) => isInternalEmail(plainEmail(d.email));
    const all = [
      ...sitters.map((d) => personRow(d, 'sitter', { now, isInternal })),
      ...walkers.map((d) => personRow(d, 'walker', { now, isInternal })),
    ];
    let people = all;
    if (status === 'verified') people = all.filter((r) => r.verified);
    if (status === 'paid_unverified') people = all.filter((r) => r.paid && !r.verified);
    const ts = (r) => new Date(r.verifiedAt || r.paidAt || 0).getTime();
    people.sort((a, b) => ts(b) - ts(a));
    return res.json({ generatedAt: now, summary: summarize(all, { now }), people });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
