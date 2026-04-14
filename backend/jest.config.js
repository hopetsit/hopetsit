/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',
  testMatch: ['<rootDir>/tests/**/*.test.js'],
  collectCoverageFrom: [
    'src/utils/**/*.js',
    'src/services/**/*.js',
    '!src/utils/logger.js',
    '!src/utils/sentry.js',
  ],
  coverageThreshold: {
    'src/utils/': {
      branches: 60,
      functions: 60,
      lines: 70,
      statements: 70,
    },
  },
  // Sprint 8 step 7 — silence pino during tests to keep output clean.
  setupFiles: ['<rootDir>/tests/setup-env.js'],
};
