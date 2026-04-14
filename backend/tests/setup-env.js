process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.ENCRYPTION_KEY =
  'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
