const crypto = require('crypto');

const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1 for readability

const generateReferralCode = (length = 8) => {
  const bytes = crypto.randomBytes(length);
  let out = '';
  for (let i = 0; i < length; i += 1) {
    out += ALPHABET[bytes[i] % ALPHABET.length];
  }
  return out;
};

/**
 * Try up to N times to get a unique code across Owner + Sitter collections.
 */
const generateUniqueReferralCode = async ({ Owner, Sitter, attempts = 5 }) => {
  for (let i = 0; i < attempts; i += 1) {
    const code = generateReferralCode(8);
    const [o, s] = await Promise.all([
      Owner.exists({ referralCode: code }),
      Sitter.exists({ referralCode: code }),
    ]);
    if (!o && !s) return code;
  }
  throw new Error('Failed to generate a unique referral code after several attempts.');
};

module.exports = { generateReferralCode, generateUniqueReferralCode };
