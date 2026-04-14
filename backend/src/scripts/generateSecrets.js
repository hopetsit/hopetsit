/**
 * Sprint 6.5 step 6 — generate high-entropy secrets.
 *
 * For each target variable (ENCRYPTION_KEY, JWT_SECRET):
 *   - If already set to a strong value in backend/.env, skip.
 *   - Otherwise, generate 32 random bytes (64 hex chars) and print it
 *     together with instructions to copy it into .env and the secret manager.
 *
 * Safe: never mutates .env automatically.
 *
 * Usage:  node src/scripts/generateSecrets.js
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ENV_PATH = path.join(__dirname, '..', '..', '.env');
const TARGETS = ['ENCRYPTION_KEY', 'JWT_SECRET'];
const MIN_LENGTH = 32; // accept anything at least 32 chars as "set"

const readEnvFile = () => {
  if (!fs.existsSync(ENV_PATH)) return {};
  const text = fs.readFileSync(ENV_PATH, 'utf8');
  const out = {};
  for (const line of text.split(/\r?\n/)) {
    const m = /^\s*([A-Z0-9_]+)\s*=\s*(.*)$/.exec(line);
    if (!m) continue;
    let value = m[2].trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    out[m[1]] = value;
  }
  return out;
};

const isPlaceholder = (v) => {
  if (!v) return true;
  if (v.length < MIN_LENGTH) return true;
  // Treat <TEMPLATE> values and hopetsit_* demo values as placeholders.
  if (/^<.*>$/.test(v)) return true;
  if (/^(hopetsit|change|placeholder|example)_?/i.test(v)) return true;
  return false;
};

const gen = () => crypto.randomBytes(32).toString('hex');

const main = () => {
  const env = readEnvFile();
  const generated = {};
  const kept = {};

  for (const key of TARGETS) {
    const current = env[key] || process.env[key];
    if (!isPlaceholder(current)) {
      kept[key] = '***present (skipped)***';
    } else {
      generated[key] = gen();
    }
  }

  console.log('============================================================');
  console.log('HopeTSIT — generateSecrets');
  console.log('============================================================');
  for (const [k, v] of Object.entries(kept)) console.log(`• ${k}: ${v}`);

  if (Object.keys(generated).length === 0) {
    console.log('\nAll secrets present — nothing to generate. ✅');
    return;
  }

  console.log('\nNewly generated secrets (copy these into backend/.env and your secret manager):');
  console.log('------------------------------------------------------------');
  for (const [k, v] of Object.entries(generated)) {
    console.log(`${k}=${v}`);
  }
  console.log('------------------------------------------------------------');
  console.log('\nNext steps:');
  console.log('  1. Append the lines above to backend/.env (or replace the existing placeholder).');
  console.log('  2. Add the same values to your deployment env (Render/Vercel/AWS Secrets Manager).');
  console.log('  3. Rotating ENCRYPTION_KEY requires re-encrypting existing data — do NOT rotate in prod without a migration.');
  console.log('  4. Rotating JWT_SECRET will invalidate all current sessions (expected).');
};

main();
