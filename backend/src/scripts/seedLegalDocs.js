/**
 * seedLegalDocs.js — session v15-5.
 *
 * Imports the legal markdown files bundled under `backend/legal/` into the
 * MongoDB collections used by the admin dashboard (TermsDocument and
 * PrivacyPolicyDocument). Without this seed the admin UI shows "No document
 * yet" even though the mobile app ships with the same texts bundled in the
 * APK, which gave the confusing impression that the admin was broken.
 *
 * Behaviour:
 *   • Default — upsert only when no document exists yet for the language
 *     (safe: never overwrites text the admin has edited online).
 *   • --force — re-import all languages and overwrite whatever's in Mongo.
 *     Use after you've manually updated the .md files on disk and want them
 *     to become the new source of truth.
 *   • --dry-run — report what would change, touch nothing.
 *
 * Usage (local or on Render shell):
 *   node src/scripts/seedLegalDocs.js              # safe upsert
 *   node src/scripts/seedLegalDocs.js --force      # overwrite all
 *   node src/scripts/seedLegalDocs.js --dry-run    # preview only
 */

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const TermsDocument = require('../models/TermsDocument');
const PrivacyPolicyDocument = require('../models/PrivacyPolicyDocument');
const logger = require('../utils/logger');

const LANGUAGES = ['fr', 'en', 'de', 'es', 'it', 'pt'];
const LEGAL_DIR = path.resolve(__dirname, '../../legal');

/**
 * Reads a markdown file and returns its trimmed content, or null when the
 * file is missing. We return null (not throw) so a missing translation
 * doesn't abort the whole seed — we log a warning and move on.
 */
function readMd(fileName) {
  const fullPath = path.join(LEGAL_DIR, fileName);
  if (!fs.existsSync(fullPath)) {
    logger.warn(`[seedLegalDocs] missing file: ${fullPath}`);
    return null;
  }
  return fs.readFileSync(fullPath, 'utf8').trim();
}

/**
 * Upserts one document into the given Model for the given language.
 * Returns 'created' | 'updated' | 'skipped-exists' | 'skipped-empty'.
 */
async function upsertOne({ Model, language, content, version, force, dryRun }) {
  if (!content || content.length === 0) {
    return 'skipped-empty';
  }
  const existing = await Model.findOne({ language }).lean();
  if (existing && !force) {
    return 'skipped-exists';
  }
  if (dryRun) {
    return existing ? 'would-update' : 'would-create';
  }
  if (existing) {
    await Model.updateOne(
      { language },
      {
        $set: {
          content,
          version: version || existing.version || '1.0',
          updatedBy: 'seedLegalDocs',
        },
      },
    );
    return 'updated';
  }
  await Model.create({
    language,
    content,
    version: version || '1.0',
    updatedBy: 'seedLegalDocs',
  });
  return 'created';
}

/** Summary printer — groups per action for a readable report. */
function printSummary(title, results) {
  logger.info(`[seedLegalDocs] ${title}:`);
  const groups = {};
  for (const [lang, action] of Object.entries(results)) {
    groups[action] = groups[action] || [];
    groups[action].push(lang);
  }
  for (const [action, langs] of Object.entries(groups)) {
    logger.info(`  · ${action.padEnd(16)} → ${langs.join(', ').toUpperCase()}`);
  }
}

async function run({ force = false, dryRun = false } = {}) {
  const termsResults = {};
  const privacyResults = {};

  for (const lang of LANGUAGES) {
    const termsContent = readMd(`terms_${lang}.md`);
    termsResults[lang] = await upsertOne({
      Model: TermsDocument,
      language: lang,
      content: termsContent,
      force,
      dryRun,
    });

    const privacyContent = readMd(`privacy_${lang}.md`);
    privacyResults[lang] = await upsertOne({
      Model: PrivacyPolicyDocument,
      language: lang,
      content: privacyContent,
      force,
      dryRun,
    });
  }

  printSummary('Terms & Conditions', termsResults);
  printSummary('Privacy Policy', privacyResults);
  logger.info(
    dryRun
      ? '[seedLegalDocs] DRY RUN — nothing was written.'
      : force
        ? '[seedLegalDocs] FORCE mode — all languages overwritten with disk content.'
        : '[seedLegalDocs] Safe mode — only missing languages were seeded.',
  );

  return { termsResults, privacyResults };
}

// Exposed so runAllMigrations can chain the seed if we ever want to.
module.exports = { run, LANGUAGES, LEGAL_DIR };

// CLI entry point.
if (require.main === module) {
  const args = process.argv.slice(2);
  const force = args.includes('--force');
  const dryRun = args.includes('--dry-run');

  const MONGO_URI = process.env.MONGO_URI || process.env.MONGODB_URI;
  if (!MONGO_URI) {
    logger.error('[seedLegalDocs] MONGO_URI / MONGODB_URI env var is missing.');
    process.exit(1);
  }

  mongoose
    .connect(MONGO_URI)
    .then(() => run({ force, dryRun }))
    .then(() => mongoose.disconnect())
    .then(() => process.exit(0))
    .catch((err) => {
      logger.error('[seedLegalDocs] failed:', err);
      mongoose.disconnect().finally(() => process.exit(1));
    });
}
