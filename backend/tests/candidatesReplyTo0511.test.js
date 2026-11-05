// 05/11 (BOB, Daniel « fais les 3 ») — e-mails « candidats » : réponse possible vers
// contact@hopetsit.com et expéditeur « Daniel de HoPetSit » ; les autres e-mails inchangés.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.SMTP_HOST = 'smtp.test';
process.env.SMTP_FROM = 'HoPetSit <contact@hopetsit.com>';
const mockSendMail = jest.fn(async () => ({ messageId: 'm1' }));
jest.mock('nodemailer', () => ({ createTransport: () => ({ sendMail: mockSendMail, verify: (cb) => cb && cb(null) }) }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn() }) }));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
let mongo;
beforeAll(async () => { mongo = await MongoMemoryServer.create(); await mongoose.connect(mongo.getUri()); }, 60000);
afterAll(async () => { await mongoose.disconnect(); await mongo.stop(); });
beforeEach(() => mockSendMail.mockClear());

test('un e-mail ordinaire garde HoPetSit + no-reply', async () => {
  const { sendEmail } = require('../src/services/emailService');
  await sendEmail('a@example.org', 'S', 'T', '<p>T</p>');
  const m = mockSendMail.mock.calls[0][0];
  expect(m.from).toBe('HoPetSit <contact@hopetsit.com>');
  expect(m.replyTo).toMatch(/no-reply/);
  expect(m.headers['Auto-Submitted']).toBe('auto-generated');
});

test('e-mail candidats : Daniel de HoPetSit, réponse vers contact@, bouton Répondre visible', async () => {
  const Owner = require('../src/models/Owner');
  const o = await Owner.create({ name: 'Ingrid B', email: 'ingrid0511r@example.org', password: 'MotDePasse0511!', verified: true, appLocale: 'fr' });
  const { sendEmailOnly } = require('../src/services/notificationSender');
  const r = await sendEmailOnly({ userId: String(o._id), role: 'owner', type: 'application_new', data: { applicationId: String(new mongoose.Types.ObjectId()), providerName: 'Sarah' } });
  expect(r.sent).toBe(true);
  const m = mockSendMail.mock.calls[0][0];
  expect(m.to).toBe('ingrid0511r@example.org');
  expect(m.from).toBe('"Daniel de HoPetSit" <contact@hopetsit.com>');
  expect(m.replyTo).toBe('contact@hopetsit.com');
  expect(m.headers['Auto-Submitted']).toBeUndefined();
});

test('CANDIDATES_REPLY_TO=off et CANDIDATES_FROM_NAME=off : ancien comportement', async () => {
  process.env.CANDIDATES_REPLY_TO = 'off'; process.env.CANDIDATES_FROM_NAME = 'off';
  const Owner = require('../src/models/Owner');
  const o = await Owner.create({ name: 'Odile', email: 'odile0511r@example.org', password: 'MotDePasse0511!', verified: true });
  const { sendEmailOnly } = require('../src/services/notificationSender');
  await sendEmailOnly({ userId: String(o._id), role: 'owner', type: 'application_new', data: {} });
  const m = mockSendMail.mock.calls[0][0];
  expect(m.from).toBe('HoPetSit <contact@hopetsit.com>');
  expect(m.replyTo).toMatch(/no-reply/);
  delete process.env.CANDIDATES_REPLY_TO; delete process.env.CANDIDATES_FROM_NAME;
});
