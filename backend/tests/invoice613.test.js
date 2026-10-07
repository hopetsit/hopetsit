// v613 — facture : escrowText = règle réelle (100 % au prestataire, libération à la
// confirmation du propriétaire ou 48 h après la fin), et libellé de commission au
// vrai taux (15 % pour un prestataire Top, 20 % sinon). Harnais repris de invoice576.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const fs = require('fs');
const path = require('path');

const mockStores = { Owner: [], Sitter: [], Walker: [], Invoice: [] };
const mockSeq = { n: 1 };
const mockOid = () => (mockSeq.n++).toString(16).padStart(24, '0');

const mockGet = (doc, p) => p.split('.').reduce((o, k) => (o == null ? undefined : o[k]), doc);
const mockSet = (doc, p, value) => {
  const keys = p.split('.');
  let o = doc;
  for (const k of keys.slice(0, -1)) { if (o[k] == null || typeof o[k] !== 'object') o[k] = {}; o = o[k]; }
  o[keys[keys.length - 1]] = value;
};
const mockMatches = (doc, filter) => Object.entries(filter || {}).every(([k, v]) => {
  if (k === '$or') return v.some((f) => mockMatches(doc, f));
  const cur = mockGet(doc, k);
  if (v === null) return cur == null;
  if (v && typeof v === 'object' && !(v instanceof Date)) {
    if ('$gte' in v || '$lt' in v) return true;
  }
  return String(cur) === String(v);
});
const mockClone = (v) => (v == null ? v : JSON.parse(JSON.stringify(v)));
const mockChain = (result) => {
  const c = {
    select: () => c, sort: () => c, limit: () => c,
    lean: async () => mockClone(result),
    catch: (fn) => Promise.resolve(mockClone(result)).catch(fn),
    then: (res, rej) => Promise.resolve(mockClone(result)).then(res, rej),
  };
  return c;
};
const mockFakeModel = (name) => {
  const store = mockStores[name];
  return {
    modelName: name,
    create: jest.fn(async (data) => { const d = { _id: mockOid(), ...mockClone(data) }; store.push(d); return mockClone(d); }),
    findById: jest.fn((id) => mockChain(store.find((d) => String(d._id) === String(id)) || null)),
    findOne: jest.fn((f) => mockChain(store.find((d) => mockMatches(d, f)) || null)),
    find: jest.fn((f) => mockChain(store.filter((d) => mockMatches(d, f)))),
    countDocuments: jest.fn(async () => store.length),
    updateOne: jest.fn(async (f, u) => {
      const d = store.find((x) => mockMatches(x, f));
      if (!d) return { modifiedCount: 0 };
      for (const [k, v] of Object.entries((u && u.$set) || {})) mockSet(d, k, mockClone(v));
      return { modifiedCount: 1 };
    }),
  };
};

jest.mock('../src/models/Owner', () => mockFakeModel('Owner'));
jest.mock('../src/models/Sitter', () => mockFakeModel('Sitter'));
jest.mock('../src/models/Walker', () => mockFakeModel('Walker'));
jest.mock('../src/models/Invoice', () => mockFakeModel('Invoice'));
jest.mock('../src/models/Booking', () => ({}));

const {
  createInvoiceForBooking,
  renderInvoiceHtml,
  INVOICE_LOCALES,
  invoiceTexts,
  commissionLabel,
} = require('../src/controllers/invoiceController');

const call = async (handler, req) => {
  const res = { statusCode: 200, body: undefined, headers: {} };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  res.send = (b) => { res.body = b; return res; };
  res.set = (k, v) => { res.headers[k] = v; return res; };
  await handler({ query: {}, params: {}, headers: {}, body: {}, ...req }, res);
  return res;
};

const seed = () => {
  const owner = { _id: mockOid(), email: 'owner+test@example.com', name: 'Owner Test' };
  const sitter = { _id: mockOid(), email: 'sitter+test@example.com', name: 'Sitter Test' };
  mockStores.Owner.push(owner); mockStores.Sitter.push(sitter);
  return { owner, sitter };
};
// Tarif 100 € : normal → 20 € de commission, 120 € payés ; Top → 15 €, 115 €.
const booking = (owner, sitter, commission) => ({
  _id: mockOid(), ownerId: owner._id, sitterId: sitter._id, serviceType: 'pet_sitting',
  serviceDate: new Date('2026-10-10T10:00:00Z'),
  pricing: { totalPrice: 100 + commission, commission, netPayout: 100, currency: 'eur' },
  petIds: [{ petName: 'Rex' }],
});

beforeEach(() => { for (const k of Object.keys(mockStores)) mockStores[k].length = 0; });

describe('v613 — escrowText dit la règle réelle, dans les 9 langues', () => {
  const HOURS48 = { en: '48 hours', fr: '48 heures', es: '48 horas', de: '48 Stunden', it: '48 ore', pt: '48 horas', ko: '48시간', ja: '48時間', pl: '48 godzin' };
  test.each(['de', 'en', 'es', 'fr', 'it', 'ja', 'ko', 'pl', 'pt'])('%s : 48 h, 100 %, plus jamais 24 h ni 80 %', (l) => {
    expect(INVOICE_LOCALES).toContain(l);
    const t = invoiceTexts(l).escrowText;
    expect(t).toContain(HOURS48[l]);
    expect(t).toMatch(/100\s?%/);
    expect(t).not.toMatch(/24/);
    expect(t).not.toMatch(/80\s?%/);
  });
  test('le français garde « wallet » (décision du 30/09)', () => {
    expect(invoiceTexts('fr').escrowText).toContain('wallet');
    expect(invoiceTexts('fr').escrowText).not.toContain('portefeuille');
  });
});

describe('v613 — libellé de commission au vrai taux', () => {
  test('15 % pour un Top, 20 % sinon, pas de pourcentage pour un taux hors barème', () => {
    const fr = invoiceTexts('fr').commission;
    expect(commissionLabel(fr, 15, 100)).toBe('Commission HoPetSit (15%)');
    expect(commissionLabel(fr, 20, 100)).toBe('Commission HoPetSit (20%)');
    expect(commissionLabel(fr, 24, 96)).toBe('Commission HoPetSit');
    expect(commissionLabel(fr, 0, 100)).toBe('Commission HoPetSit');
    expect(commissionLabel(invoiceTexts('ja').commission, 24, 96)).toBe('HoPetSit プラットフォーム手数料');
  });

  test.each(INVOICE_LOCALES)('%s : facture générée (Top) → 15 % affiché, escrowText présent', async (l) => {
    const { owner, sitter } = seed();
    const inv = await createInvoiceForBooking(booking(owner, sitter, 15));
    const res = await call(renderInvoiceHtml, { user: { id: String(owner._id), role: 'owner' }, params: { id: inv._id }, query: { lang: l } });
    expect(res.statusCode).toBe(200);
    const html = String(res.body);
    expect(html).toMatch(/\(15\s?%\)/);
    expect(html).not.toMatch(/\(20\s?%\)/);
    expect(html).toContain('115.00 EUR');
    expect(html).toContain('100.00 EUR');
    const esc = (v) => String(v).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    expect(html).toContain(esc(invoiceTexts(l).escrowText));
  });

  test('facture générée (prestataire normal, fr) → 20 %', async () => {
    const { owner, sitter } = seed();
    const inv = await createInvoiceForBooking(booking(owner, sitter, 20));
    const res = await call(renderInvoiceHtml, { user: { id: String(owner._id), role: 'owner' }, params: { id: inv._id }, query: { lang: 'fr' } });
    const html = String(res.body);
    expect(html).toContain('Commission HoPetSit (20%)');
    expect(html).toContain('120.00 EUR');
    // Relecture humaine : INVOICE613_OUT=<dossier> écrit la facture rendue.
    if (process.env.INVOICE613_OUT) require('fs').writeFileSync(require('path').join(process.env.INVOICE613_OUT, 'facture613_fr.html'), html);
  });
});
