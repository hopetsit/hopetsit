const crypto = require('crypto');

const ALGO = 'aes-256-gcm';
const PREFIX = 'gcm:';

const getKey = () => {
  const hex = process.env.ENCRYPTION_KEY;
  if (!hex || hex.length !== 64) {
    throw new Error('ENCRYPTION_KEY must be set to a 64-char hex string (32 bytes).');
  }
  return Buffer.from(hex, 'hex');
};

const isEncrypted = (v) => typeof v === 'string' && v.startsWith(PREFIX);

const encrypt = (plaintext) => {
  if (plaintext == null || plaintext === '') return plaintext;
  if (typeof plaintext !== 'string') return plaintext;
  if (isEncrypted(plaintext)) return plaintext;
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv(ALGO, getKey(), iv);
  const ct = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${PREFIX}${iv.toString('base64')}:${tag.toString('base64')}:${ct.toString('base64')}`;
};

const decrypt = (stored) => {
  if (stored == null || stored === '') return stored;
  if (typeof stored !== 'string' || !isEncrypted(stored)) return stored; // legacy cleartext
  const [, payload] = stored.split(PREFIX);
  const [ivB64, tagB64, ctB64] = payload.split(':');
  if (!ivB64 || !tagB64 || !ctB64) return stored;
  const decipher = crypto.createDecipheriv(ALGO, getKey(), Buffer.from(ivB64, 'base64'));
  decipher.setAuthTag(Buffer.from(tagB64, 'base64'));
  const pt = Buffer.concat([decipher.update(Buffer.from(ctB64, 'base64')), decipher.final()]);
  return pt.toString('utf8');
};

const maskTail4 = (plaintext) => {
  if (!plaintext || typeof plaintext !== 'string') return '';
  if (plaintext.length <= 4) return '*'.repeat(plaintext.length);
  return '****' + plaintext.slice(-4);
};

const maskEmail = (email) => {
  if (!email || typeof email !== 'string' || !email.includes('@')) return '';
  const [local, domain] = email.split('@');
  const visible = local.length > 1 ? local[0] : '';
  return `${visible}***@${domain}`;
};

module.exports = { encrypt, decrypt, isEncrypted, maskTail4, maskEmail };
