'use strict';

/**
 * 607 (FLO, 02/10/2026) — GET /admin/kyc-people : LECTURE SEULE.
 *
 *   ?status=all (défaut) | verified | paid_unverified
 *
 * Réponse : { generatedAt, summary, people[] } — 3010 : une ligne par PERSONNE (même e-mail, profils
 * gardien / promeneur / propriétaire regroupés : roles[], rolesVerified{}) vérifiée OU ayant payé (3 €) : nom, rôles, ville,
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
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const { isInternalEmail } = require('../utils/userCounts');
const { personRow, summarize, groupByPerson } = require('../utils/kycPeople607');

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
    // 3010 (ADA, Daniel 30/10 15 h) — UNE ligne par PERSONNE (même e-mail), sur les 3 profils : le propriétaire
    // est lu aussi (le serveur recopie l'identité vérifiée entre les profils, boostSync2910). Les e-mails ne
    // sont pas interrogeables (chiffrés, non déterministes) : on lit id + e-mail des 3 collections pour
    // connaître les profils existants de chaque personne, puis on regroupe (utils/kycPeople607.groupByPerson).
    const [sitters, walkers, owners, allO, allS, allW] = await Promise.all([
      Sitter.find(filter).select(FIELDS).lean(),
      Walker.find(filter).select(FIELDS).lean(),
      Owner.find(filter).select(FIELDS).lean(),
      Owner.find({}).select('email').lean(), Sitter.find({}).select('email').lean(), Walker.find({}).select('email').lean(),
    ]);
    const now = new Date();
    const keyOf = (d) => String(plainEmail(d.email) || '').trim().toLowerCase() || `id:${d._id}`;
    const isInternal = (d) => isInternalEmail(plainEmail(d.email));
    const rolesByKey = new Map();
    const addRole = (docs, role) => docs.forEach((d) => { const k = keyOf(d); if (!rolesByKey.has(k)) rolesByKey.set(k, []); rolesByKey.get(k).push(role); });
    addRole(allS, 'sitter'); addRole(allW, 'walker'); addRole(allO, 'owner');
    const rowOf = (d, role) => ({ ...personRow(d, role, { now, isInternal }), personKey: keyOf(d) });
    const all = groupByPerson([
      ...sitters.map((d) => rowOf(d, 'sitter')),
      ...walkers.map((d) => rowOf(d, 'walker')),
      ...owners.map((d) => rowOf(d, 'owner')),
    ], rolesByKey);
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
