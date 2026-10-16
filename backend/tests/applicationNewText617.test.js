// 617 (ADA, 16/10/2026) — §D.3 : texte de la notification « candidature reçue »
// (« <Prénom> a répondu » / « N candidat(s) sur ta demande · choisis et paie en 2 minutes »).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
jest.mock('../src/sockets/emitter', () => ({
  emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0),
  isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false),
}));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ sendEachForMulticast: jest.fn(async () => ({ successCount: 0, failureCount: 0, responses: [] })) }) }));

const fs = require('fs');
const path = require('path');
const { render } = require('../src/utils/i18nTemplate');
const { TEMPLATE, applicationNewData617 } = require('../src/utils/applicationNewText617');
const { renderNotificationContent } = require('../src/services/notificationSender');

const LANGS = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const tmpl = (l) => require(`../src/locales/${l}/notifications.json`)[TEMPLATE];

describe('données de la notification', () => {
  test('prénom du candidat (firstName, sinon 1er mot du nom), total ≥ 1, marqueur', () => {
    expect(applicationNewData617({ provider: { firstName: 'Paul', lastName: 'Martin', name: 'Paul Martin' }, pendingCount: 3 }))
      .toEqual({ candidateName: 'Paul', candidates: '3', appNew617: '1' });
    expect(applicationNewData617({ provider: { name: 'Sasha Lee' }, pendingCount: 1 }).candidateName).toBe('Sasha');
    expect(applicationNewData617({ provider: null, pendingCount: 0 })).toEqual({ candidateName: 'HoPetSit', candidates: '1', appNew617: '1' });
    expect(applicationNewData617({ provider: { name: 'X' }, pendingCount: NaN }).candidates).toBe('1');
  });
});

describe('texte dans les 9 langues', () => {
  test.each(LANGS)('%s : titre avec le prénom, corps avec le total, aucune variable restante', (l) => {
    const t = tmpl(l);
    const data = applicationNewData617({ provider: { name: 'Paul Martin' }, pendingCount: 2 });
    const title = render(t.title, data);
    const body = render(t.body, { ...data, emailLink: 'https://www.hopetsit.com/x' });
    expect(title).toContain('Paul');
    expect(body).toContain('2');
    expect(title).not.toMatch(/\{\{/);
    expect(body).not.toMatch(/\{\{/);
    expect(render(t.emailBody, { ...data, emailLink: 'https://www.hopetsit.com/x' })).toContain('https://www.hopetsit.com/x');
  });
  test('français : texte exact demandé', () => {
    const data = applicationNewData617({ provider: { name: 'Paul Martin' }, pendingCount: 3 });
    expect(render(tmpl('fr').title, data)).toBe('Paul a répondu');
    expect(render(tmpl('fr').body, data)).toBe('3 candidat(s) sur ta demande · choisis et paie en 2 minutes');
  });
});

describe('la cloche re-rend le bon gabarit', () => {
  test('avec le marqueur appNew617 → nouveau texte ; sans marqueur (anciennes notifications) → ancien texte intact', () => {
    const data = { applicationId: '507f1f77bcf86cd799439011', ...applicationNewData617({ provider: { name: 'Paul Martin' }, pendingCount: 2 }) };
    expect(renderNotificationContent('application_new', data, 'fr')).toEqual({ title: 'Paul a répondu', body: '2 candidat(s) sur ta demande · choisis et paie en 2 minutes' });
    expect(renderNotificationContent('application_new', data, 'en').title).toBe('Paul replied');
    expect(renderNotificationContent('application_new', { applicationId: '507f1f77bcf86cd799439011' }, 'fr')).toEqual({ title: 'Nouvelle candidature', body: "Un prestataire t'a envoyé une demande." });
    // Le rappel 615 garde son gabarit.
    const r615 = renderNotificationContent('application_new', { reminder615: 'r1', candidates: '2', serviceKind: 'walk' }, 'fr');
    expect(r615.title).toBe('2 candidats t’attendent');
  });
});

describe('branchement dans createApplication', () => {
  test('templateType application_new_617, type application_new conservé, applicationId/postId conservés', () => {
    const src = fs.readFileSync(path.join(__dirname, '..', 'src', 'controllers', 'applicationController.js'), 'utf8');
    const i = src.indexOf('templateType: text617.TEMPLATE');
    expect(i).toBeGreaterThan(0);
    const block = src.slice(i - 400, i + 900);
    expect(block).toContain("type: 'application_new'");
    expect(block).toContain('applicationId: application._id.toString()');
    expect(block).toContain('postId: String(application.postId._id || application.postId)');
    expect(block).toContain('applicationNewData617({ provider: providerDoc617, pendingCount: pendingCount617 })');
    expect(src).toContain("Application.countDocuments({\n          postId: application.postId._id || application.postId, status: 'pending',");
  });
});
