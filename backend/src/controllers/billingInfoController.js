/**
 * v566 — Informations de facturation de l'utilisateur courant.
 *
 *   GET   /users/me/billing-info  → l'objet complet (champs vides si absent)
 *   PATCH /users/me/billing-info  → corps partiel → objet complet, écrit sur
 *                                   les 3 docs de la même personne.
 *   GET   /admin/users/:role/:id/billing-info → lecture seule (admin).
 *
 * Contrat et règles de nettoyage : utils/billingInfo.js.
 */
const logger = require('../utils/logger');
const {
  mergeBillingInfo,
  resolveBillingInfoAcrossRoles,
  writeBillingInfoAcrossRoles,
} = require('../utils/billingInfo');

const MODEL_NAME_BY_ROLE = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' };

const getMyBillingInfo = async (req, res) => {
  try {
    const modelName = MODEL_NAME_BY_ROLE[String(req.user?.role || '').toLowerCase()];
    if (!modelName) return res.status(403).json({ error: 'Unsupported role.' });
    const info = await resolveBillingInfoAcrossRoles(req.user.id, modelName);
    return res.json(info);
  } catch (e) {
    logger.error('getMyBillingInfo error', e);
    return res.status(500).json({ error: 'Unable to load billing information.' });
  }
};

const updateMyBillingInfo = async (req, res) => {
  try {
    const modelName = MODEL_NAME_BY_ROLE[String(req.user?.role || '').toLowerCase()];
    if (!modelName) return res.status(403).json({ error: 'Unsupported role.' });
    const current = await resolveBillingInfoAcrossRoles(req.user.id, modelName);
    const merged = mergeBillingInfo(current, req.body);
    if (merged.error) {
      const { error, ...rest } = merged;
      return res.status(400).json({ error, ...rest });
    }
    const touched = await writeBillingInfoAcrossRoles(req.user.id, merged.value);
    if (!touched) return res.status(404).json({ error: 'User not found.' });
    // Jamais le numéro lui-même dans les journaux (donnée fiscale personnelle).
    logger.info(
      `[billing.info] ${req.user.role}:${req.user.id} → type=${merged.value.type} ` +
      `idType=${merged.value.idType || '-'} country=${merged.value.country || '-'} (${touched} doc(s))`,
    );
    return res.json(merged.value);
  } catch (e) {
    logger.error('updateMyBillingInfo error', e);
    return res.status(500).json({ error: 'Unable to update billing information.' });
  }
};

// Admin — lecture seule.
const adminGetBillingInfo = async (req, res) => {
  try {
    const modelName = MODEL_NAME_BY_ROLE[String(req.params.role || '').toLowerCase()];
    if (!modelName) return res.status(400).json({ error: 'role must be owner, sitter or walker.' });
    if (!/^[0-9a-fA-F]{24}$/.test(String(req.params.id || ''))) {
      return res.status(404).json({ error: 'User not found.' });
    }
    const billingInfo = await resolveBillingInfoAcrossRoles(req.params.id, modelName);
    return res.json({ billingInfo });
  } catch (e) {
    logger.error('adminGetBillingInfo error', e);
    return res.status(500).json({ error: 'Unable to load billing information.' });
  }
};

module.exports = { getMyBillingInfo, updateMyBillingInfo, adminGetBillingInfo };
