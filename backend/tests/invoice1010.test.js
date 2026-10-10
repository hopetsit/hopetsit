// 10/10/2026 (BOB, demande Daniel) — facture en DEUX parties : la prestation est vendue par le
// prestataire (document en son nom, mandat de facturation des CGU), les frais de plateforme sont
// facturés par CARDELLI HERMANOS LIMITED (adresse complète de Hong Kong). Un particulier reçoit une
// « note de prestation », un professionnel une « facture ». TVA formulée sans « exonération ».
// INVOICE1010_OUT=<dossier> écrit les 9 factures rendues pour relecture humaine.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
const fs = require('fs');
const path = require('path');

const mockStores = { Owner: [], Sitter: [], Walker: [], Invoice: [] };
const mockSeq = { n: 1 };
const mockOid = () => (mockSeq.n++).toString(16).padStart(24, '0');
const mockGet = (doc, p) => p.split('.').reduce((o, k) => (o == null ? undefined : o[k]), doc);
const mockSet = (doc, p, value) => { const keys = p.split('.'); let o = doc; for (const k of keys.slice(0, -1)) { if (o[k] == null || typeof o[k] !== 'object') o[k] = {}; o = o[k]; } o[keys[keys.length - 1]] = value; };
const mockMatches = (doc, filter) => Object.entries(filter || {}).every(([k, v]) => {
  if (k === '$or') return v.some((f) => mockMatches(doc, f));
  const cur = mockGet(doc, k);
  if (v === null) return cur == null;
  if (v && typeof v === 'object' && !(v instanceof Date)) { if ('$gte' in v || '$lt' in v) return true; }
  return String(cur) === String(v);
});
const mockClone = (v) => (v == null ? v : JSON.parse(JSON.stringify(v)));
const mockChain = (result) => { const c = { select: () => c, sort: () => c, limit: () => c, lean: async () => mockClone(result), catch: (fn) => Promise.resolve(mockClone(result)).catch(fn), then: (res, rej) => Promise.resolve(mockClone(result)).then(res, rej) }; return c; };
const mockFakeModel = (name) => { const store = mockStores[name]; return {
  modelName: name,
  create: jest.fn(async (data) => { const d = { _id: mockOid(), ...mockClone(data) }; store.push(d); return mockClone(d); }),
  findById: jest.fn((id) => mockChain(store.find((d) => String(d._id) === String(id)) || null)),
  findOne: jest.fn((f) => mockChain(store.find((d) => mockMatches(d, f)) || null)),
  find: jest.fn((f) => mockChain(store.filter((d) => mockMatches(d, f)))),
  countDocuments: jest.fn(async () => store.length),
  updateOne: jest.fn(async (f, u) => { const d = store.find((x) => mockMatches(x, f)); if (!d) return { modifiedCount: 0 }; for (const [k, v] of Object.entries((u && u.$set) || {})) mockSet(d, k, mockClone(v)); return { modifiedCount: 1 }; }),
}; };
jest.mock('../src/models/Owner', () => mockFakeModel('Owner'));
jest.mock('../src/models/Sitter', () => mockFakeModel('Sitter'));
jest.mock('../src/models/Walker', () => mockFakeModel('Walker'));
jest.mock('../src/models/Invoice', () => mockFakeModel('Invoice'));
jest.mock('../src/models/Booking', () => ({}));

const { createInvoiceForBooking, renderInvoiceHtml, INVOICE_LOCALES, invoiceTexts } = require('../src/controllers/invoiceController');
const call = async (handler, req) => { const res = { statusCode: 200, body: undefined, headers: {} }; res.status = (c) => { res.statusCode = c; return res; }; res.json = (b) => { res.body = b; return res; }; res.send = (b) => { res.body = b; return res; }; res.set = (k, v) => { res.headers[k] = v; return res; }; await handler({ query: {}, params: {}, headers: {}, body: {}, ...req }, res); return res; };
const esc = (v) => String(v).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
const seed = (business) => {
  const owner = { _id: mockOid(), email: 'owner+test@example.com', name: 'Camille Test' };
  const sitter = { _id: mockOid(), email: 'sitter+test@example.com', name: 'Paul Test',
    ...(business ? { billingInfo: { type: 'business', legalName: 'Paul Garde SARL', idType: 'siret', idNumber: '12345678900012', vatNumber: 'FR12345678900', address: '1 rue des Chats', postalCode: '75011', city: 'Paris', country: 'FR' } } : {}) };
  mockStores.Owner.push(owner); mockStores.Sitter.push(sitter); return { owner, sitter };
};
const booking = (owner, sitter) => ({ _id: mockOid(), ownerId: owner._id, sitterId: sitter._id, serviceType: 'pet_sitting', serviceDate: new Date('2026-10-17T10:00:00Z'), pricing: { totalPrice: 120, commission: 20, netPayout: 100, currency: 'eur' }, petIds: [{ petName: 'Rex' }] });
const render = async (owner, inv, lang) => String((await call(renderInvoiceHtml, { user: { id: String(owner._id), role: 'owner' }, params: { id: inv._id }, query: { lang } })).body);
const ADDRESS = 'Flat/Rm A, 12/F, ZJ 300, 300 Lockhart Road, Wan Chai, Hong Kong';
beforeEach(() => { for (const k of Object.keys(mockStores)) mockStores[k].length = 0; });

describe('10/10 — libellés des deux parties présents dans les 9 langues', () => {
  test.each(INVOICE_LOCALES)('%s', (l) => {
    const T = invoiceTexts(l);
    for (const k of ['sectionService', 'sectionFees', 'docNote', 'mandateNote', 'vatIndividual', 'vatBusiness', 'feesVat', 'platformNote', 'providerAmount']) expect({ lang: l, key: k, ok: !!T[k] }).toEqual({ lang: l, key: k, ok: true });
    expect(T.feesVat).toMatch(/CARDELLI HERMANOS LIMITED/);
    expect(T.feesVat.toLowerCase()).not.toMatch(/exon|exempt|befreit|esen|esent|isen|zwoln/);
  });
});

describe('10/10 — prestataire PARTICULIER : note de prestation + facture CARDELLI pour les frais', () => {
  test.each(INVOICE_LOCALES)('%s : 2 parties, adresse de Hong Kong, mandat, montants', async (l) => {
    const { owner, sitter } = seed(false);
    const inv = await createInvoiceForBooking(booking(owner, sitter));
    const html = await render(owner, inv, l);
    const T = invoiceTexts(l);
    expect(html).toContain(esc(T.sectionService));
    expect(html).toContain(esc(T.sectionFees));
    expect(html).toContain(esc(T.docNote));            // particulier → note de prestation
    expect(html).toContain(esc(T.vatIndividual));
    expect(html).not.toContain(esc(T.vatBusiness));
    expect(html).toContain(esc(T.mandateNote));
    expect(html).toContain(esc(T.feesVat));
    expect(html).toContain(esc(T.platformNote));
    expect(html).toContain(esc(ADDRESS));
    expect(html).toContain(`${inv.invoiceNumber}-A`);
    expect(html).toContain(`${inv.invoiceNumber}-B`);
    expect(html).toContain('100.00 EUR');            // tarif du prestataire (partie 1)
    expect(html).toContain('20.00 EUR');             // frais de plateforme (partie 2)
    expect(html).toContain('120.00 EUR');            // total payé
    expect(html).toContain(esc(T.escrowText));
    if (process.env.INVOICE1010_OUT) fs.writeFileSync(path.join(process.env.INVOICE1010_OUT, `facture_1010_${l}.html`), html);
  });
});

describe('10/10 — prestataire PROFESSIONNEL : facture en son nom, identifiants, TVA selon son régime', () => {
  test('fr', async () => {
    const { owner, sitter } = seed(true);
    const inv = await createInvoiceForBooking(booking(owner, sitter));
    const html = await render(owner, inv, 'fr');
    const T = invoiceTexts('fr');
    expect(html).toContain('Paul Garde SARL');
    expect(html).toContain('SIRET');
    expect(html).toContain('FR12345678900');
    expect(html).toContain(esc(T.vatBusiness));
    expect(html).not.toContain(esc(T.vatIndividual));
    expect(html).not.toContain(esc(T.docNote));
    expect((html.match(/Facture<\/b>/g) || []).length).toBe(2);   // partie A (pro) + partie B (CARDELLI)
    if (process.env.INVOICE1010_OUT) fs.writeFileSync(path.join(process.env.INVOICE1010_OUT, 'facture_1010_fr_professionnel.html'), html);
  });
});
