const crypto = require('crypto');

const stableSortObject = (value) => {
  if (Array.isArray(value)) {
    return value.map(stableSortObject);
  }
  if (value && typeof value === 'object') {
    return Object.keys(value)
      .sort()
      .reduce((acc, key) => {
        acc[key] = stableSortObject(value[key]);
        return acc;
      }, {});
  }
  return value;
};

const normalizeText = (value) => {
  if (value == null) return '';
  return String(value).trim();
};

const normalizeDate = (value) => {
  if (value == null) return '';
  if (value instanceof Date) return value.toISOString();
  const raw = String(value).trim();
  if (!raw) return '';
  const parsed = new Date(raw);
  return Number.isNaN(parsed.getTime()) ? raw : parsed.toISOString();
};

const normalizeNumber = (value) => {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
};

const normalizePetIds = (petIds = []) =>
  [...new Set((Array.isArray(petIds) ? petIds : []).map((id) => String(id).trim()).filter(Boolean))].sort();

const normalizeAddOns = (addOns = []) =>
  (Array.isArray(addOns) ? addOns : [])
    .map((a) => ({
      type: normalizeText(a?.type),
      description: normalizeText(a?.description),
      amount: normalizeNumber(a?.amount),
    }))
    .sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));

const buildRequestFingerprint = (payload) => {
  const normalized = stableSortObject(payload);
  return crypto.createHash('sha256').update(JSON.stringify(normalized)).digest('hex');
};

module.exports = {
  buildRequestFingerprint,
  normalizeText,
  normalizeDate,
  normalizeNumber,
  normalizePetIds,
  normalizeAddOns,
};

