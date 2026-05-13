const crypto = require('crypto');

// v23.1 part 133 — Phase 7 audit P7-7 : code OTP toujours généré en clair
// (pour pouvoir l'envoyer par email à l'user), mais stocké en DB sous
// forme de hash SHA-256. Comparaison via timing-safe equal. Si la DB
// fuite, les OTP en cours ne sont plus utilisables directement par
// l'attaquant (il aurait à brute-forcer 1M de combinaisons * 1 hash).
const generateVerificationCode = () =>
  Math.floor(100000 + Math.random() * 900000).toString();

const hashCode = (code) =>
  crypto.createHash('sha256').update(String(code), 'utf8').digest('hex');

const compareCode = (submitted, storedHash) => {
  if (!submitted || !storedHash) return false;
  try {
    const sub = Buffer.from(hashCode(submitted), 'hex');
    const sto = Buffer.from(String(storedHash), 'hex');
    if (sub.length !== sto.length) return false;
    return crypto.timingSafeEqual(sub, sto);
  } catch (_) {
    return false;
  }
};

module.exports = {
  generateVerificationCode,
  hashCode,
  compareCode,
};
