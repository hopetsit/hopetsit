const IBAN_LENGTHS = {
  FR: 27, ES: 24, PT: 25, IT: 27, DE: 22,
  BE: 16, LU: 20, CH: 21, GB: 22,
  NL: 18, IE: 22, AT: 20, FI: 18, DK: 18, SE: 24, NO: 15, PL: 28,
};

const cleanIban = (iban) => String(iban || '').replace(/\s+/g, '').toUpperCase();

const mod97 = (numeric) => {
  let remainder = 0;
  for (let i = 0; i < numeric.length; i += 7) {
    const chunk = remainder.toString() + numeric.substring(i, i + 7);
    remainder = Number(chunk) % 97;
  }
  return remainder;
};

const validateIBAN = (iban) => {
  const s = cleanIban(iban);
  if (!/^[A-Z]{2}\d{2}[A-Z0-9]+$/.test(s)) {
    return { valid: false, reason: 'format' };
  }
  const country = s.slice(0, 2);
  const expectedLen = IBAN_LENGTHS[country];
  if (expectedLen && s.length !== expectedLen) {
    return { valid: false, country, reason: `length_${country}_${expectedLen}` };
  }
  if (s.length < 15 || s.length > 34) {
    return { valid: false, country, reason: 'length_bounds' };
  }
  const rearranged = s.slice(4) + s.slice(0, 4);
  const numeric = rearranged
    .split('')
    .map((c) => (/[A-Z]/.test(c) ? (c.charCodeAt(0) - 55).toString() : c))
    .join('');
  if (mod97(numeric) !== 1) return { valid: false, country, reason: 'checksum' };
  return { valid: true, country };
};

module.exports = { validateIBAN, cleanIban, IBAN_LENGTHS };
