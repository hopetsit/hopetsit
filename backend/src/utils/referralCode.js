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
 * Try up to N times to get a unique code across Owner + Sitter (+ Walker) collections.
 * Walker is optional to keep backwards compatibility with callers that pre-date the walker role.
 */
const generateUniqueReferralCode = async ({ Owner, Sitter, Walker = null, attempts = 5 }) => {
  for (let i = 0; i < attempts; i += 1) {
    const code = generateReferralCode(8);
    const checks = [
      Owner.exists({ referralCode: code }),
      Sitter.exists({ referralCode: code }),
    ];
    if (Walker) {
      checks.push(Walker.exists({ referralCode: code }));
    }
    const results = await Promise.all(checks);
    if (results.every((r) => !r)) return code;
  }
  throw new Error('Failed to generate a unique referral code after several attempts.');
};

module.exports = { generateReferralCode, generateUniqueReferralCode };
