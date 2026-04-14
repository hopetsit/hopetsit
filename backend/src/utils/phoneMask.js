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

module.exports = { maskPhonesInText, MASK };
