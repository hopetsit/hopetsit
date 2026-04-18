/**
 * Content moderation service — session v3.3.
 *
 * Runs uploaded images through Google Cloud Vision Safe Search to filter
 * pornography, violence and other unsafe content. Called by the upload
 * pipeline right after Cloudinary returns a URL; if the verdict is unsafe
 * the asset is destroyed on Cloudinary and the caller is informed so the
 * route can reject the upload.
 *
 * Env:
 *   GOOGLE_VISION_API_KEY      — Google Cloud API key with Vision API enabled.
 *   CONTENT_MODERATION_ENABLED — 'true' to turn the feature on; anything
 *                                else leaves it dormant (useful for dev and
 *                                until the key is provisioned on Render).
 *
 * Pricing: 1 500 free calls/month on Google Cloud, then $1.50 / 1000.
 */

const logger = require('../utils/logger');

const ENABLED = String(process.env.CONTENT_MODERATION_ENABLED || '').toLowerCase() === 'true';
const API_KEY = process.env.GOOGLE_VISION_API_KEY || '';

const LIKELIHOOD_UNSAFE = new Set(['LIKELY', 'VERY_LIKELY']);

/**
 * Calls Vision Safe Search on a remote image URL.
 *
 * Returns:
 *   { ok: true }                 → safe (or moderation disabled)
 *   { ok: false, reasons: [] }   → flagged; `reasons` is a list like
 *                                  ['adult', 'violence'] so the caller can
 *                                  show a specific error to the user.
 */
async function moderateImage(imageUrl) {
  if (!ENABLED || !API_KEY) {
    return { ok: true, skipped: true };
  }
  if (!imageUrl || typeof imageUrl !== 'string') {
    return { ok: true, skipped: true };
  }
  try {
    const body = {
      requests: [
        {
          image: { source: { imageUri: imageUrl } },
          features: [{ type: 'SAFE_SEARCH_DETECTION', maxResults: 1 }],
        },
      ],
    };
    const res = await fetch(
      `https://vision.googleapis.com/v1/images:annotate?key=${API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      },
    );
    if (!res.ok) {
      logger.warn('[contentModeration] Vision API non-200', {
        status: res.status,
      });
      // Fail open — better to let a rare upload through than to block all
      // uploads if Vision is down. Still log the event so we can audit.
      return { ok: true, skipped: true, reason: `vision_${res.status}` };
    }
    const data = await res.json();
    const ann = data?.responses?.[0]?.safeSearchAnnotation || {};
    const reasons = [];
    if (LIKELIHOOD_UNSAFE.has(ann.adult)) reasons.push('adult');
    if (LIKELIHOOD_UNSAFE.has(ann.violence)) reasons.push('violence');
    if (LIKELIHOOD_UNSAFE.has(ann.racy)) reasons.push('racy');
    if (reasons.length === 0) return { ok: true };
    return { ok: false, reasons, raw: ann };
  } catch (e) {
    logger.error('[contentModeration] failed', e);
    return { ok: true, skipped: true, reason: 'exception' };
  }
}

/**
 * Convenience helper that pairs well with Cloudinary uploads: upload,
 * moderate, if flagged destroy the asset on Cloudinary and throw an
 * HttpError so the route returns 422 to the client.
 *
 * Usage:
 *   const upload = await uploadMedia(...);
 *   await rejectIfUnsafe(upload);  // throws if unsafe
 *   // safe to persist upload.url on the user doc
 */
async function rejectIfUnsafe(uploadResult) {
  if (!uploadResult?.url) return;
  const verdict = await moderateImage(uploadResult.url);
  if (!verdict.ok) {
    // Best-effort cleanup on Cloudinary.
    try {
      const cloudinary = require('cloudinary').v2;
      if (uploadResult.publicId) {
        await cloudinary.uploader.destroy(uploadResult.publicId);
      }
    } catch (_) {}
    const err = new Error(
      `This image was rejected by automatic moderation (${verdict.reasons.join(', ')}).`,
    );
    err.status = 422;
    err.code = 'CONTENT_REJECTED';
    err.details = { reasons: verdict.reasons };
    throw err;
  }
}

module.exports = {
  moderateImage,
  rejectIfUnsafe,
  isEnabled: () => ENABLED && !!API_KEY,
};
