process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.ENCRYPTION_KEY =
  'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
// 17/11/2026 (BOB) — en PRODUCTION, « compte du contact pub créé seulement au clic » est allumé par défaut
// (AD_LEAD_ACCOUNT_AT_CLICK_1711). Les suites écrites avant le 17/11 décrivent l'ancien comportement (compte créé
// dès le brouillon) : elles tournent éteintes. Le mode allumé et la valeur par défaut sont testés dans emailFirst1711.
if (process.env.AD_LEAD_ACCOUNT_AT_CLICK_1711 === undefined) process.env.AD_LEAD_ACCOUNT_AT_CLICK_1711 = 'off';
