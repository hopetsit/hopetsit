// Matches common phone-number shapes:
// - optional leading +
// - digits, spaces, dots, dashes, parentheses
// - at least 8 digits total (after stripping non-digits)
const CANDIDATE = /\+?[\d][\d\s().-]{6,}\d/g;
const MASK = '[MASQUÉ]';

const countDigits = (s) => (s.match(/\d/g) || []).length;

const maskPhonesInText = (input) => {
  if (!input || typeof input !== 'string') return input;
  return input.replace(CANDIDATE, (match) =>
    countDigits(match) >= 8 ? MASK : match
  );
};

// v19.1.3 — block email addresses in chat to prevent users bypassing the
// platform. Catches standard emails + obfuscations like "user (at) domain",
// "user[dot]com", "user@domain dot com".
const EMAIL_STRICT = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g;
// Obfuscated pattern: word [at|(at)|AT ] word [dot|(.)|DOT] tld
const EMAIL_OBFUSCATED =
  /\b[A-Za-z0-9._%+-]+\s*[\[\(]?\s*(?:at|AT|arobase|@)\s*[\]\)]?\s*[A-Za-z0-9.-]+\s*[\[\(]?\s*(?:dot|DOT|point|\.)\s*[\]\)]?\s*[A-Za-z]{2,}\b/g;

const maskEmailsInText = (input) => {
  if (!input || typeof input !== 'string') return input;
  return input
    .replace(EMAIL_STRICT, MASK)
    .replace(EMAIL_OBFUSCATED, MASK);
};

// Convenience helper: masks both phone numbers and email addresses.
const maskContactInfoInText = (input) => {
  return maskEmailsInText(maskPhonesInText(input));
};

module.exports = {
  maskPhonesInText,
  maskEmailsInText,
  maskContactInfoInText,
  MASK,
};
