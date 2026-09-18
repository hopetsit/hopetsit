// v566 — informations de facturation : PATCH → GET, synchro sur les 3 docs de
// la personne, instantané à la création de facture, remplissage UNIQUE d'une
// ancienne facture. SANS base réelle (modèles remplacés par un magasin en
// mémoire), aucun compte ni e-mail réel.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mockStores = { Owner: [], Sitter: [], Walker: [], Invoice: [] };
const mockSeq = { n: 1 };
const mockOid = () => (mockSeq.n++).toString(16).padStart(24, '0');

const mockGet = (doc, path) => path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), doc);
const mockSet = (doc, path, value) => {
  const keys = path.split('.');
  let o = doc;
  for (const k of keys.slice(0, -1)) { if (o[k] == null || typeof o[k] !== 'object') o[k] = {}; o = o[k]; }
  o[keys[keys.length - 1]] = value;
};
const mockMatches = (doc, filter) => Object.entries(filter || {}).every(([k, v]) => {
  if (k === '$or') return v.some((f) => mockMatches(doc, f));
  const cur = mockGet(doc, k);
  if (v === null) return cur == null; // Mongo : null matche aussi « absent »
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

const { getMyBillingInfo, updateMyBillingInfo, adminGetBillingInfo } = require('../src/controllers/billingInfoController');
const { createInvoiceForBooking, getInvoice, listMyInvoices, renderInvoiceHtml } = require('../src/controllers/invoiceController');
const { normalizeBillingInfo, mergeBillingInfo } = require('../src/utils/billingInfo');

const call = async (handler, req) => {
  const res = { statusCode: 200, body: undefined, headers: {} };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = JSON.parse(JSON.stringify(b)); return res; };
  res.send = (b) => { res.body = b; return res; };
  res.set = (k, v) => { res.headers[k] = v; return res; };
  await handler({ query: {}, params: {}, headers: {}, body: {}, ...req }, res);
  return res;
};

const seedPerson = (email) => {
  const owner = { _id: mockOid(), email, name: 'Camille Test' };
  const sitter = { _id: mockOid(), email, name: 'Camille Test' };
  const walker = { _id: mockOid(), email, name: 'Camille Test' };
  mockStores.Owner.push(owner); mockStores.Sitter.push(sitter); mockStores.Walker.push(walker);
  return { owner, sitter, walker };
};

beforeEach(() => { for (const k of Object.keys(mockStores)) mockStores[k].length = 0; });

describe('billingInfo — nettoyage et validation', () => {
  test('objet complet avec champs vides si absent', () => {
    expect(normalizeBillingInfo(undefined)).toEqual({
      type: 'individual', legalName: '', idType: '', idNumber: '', vatNumber: '',
      address: '', postalCode: '', city: '', country: '', updatedAt: null,
    });
  });

  test('idNumber / vatNumber en majuscules sans espaces superflus, chaînes bornées à 120', () => {
    const { value } = mergeBillingInfo(null, {
      idNumber: '  x1234567 l ', vatNumber: ' fr  12 345678901', legalName: 'A'.repeat(300), country: 'es',
    });
    expect(value.idNumber).toBe('X1234567 L');
    expect(value.vatNumber).toBe('FR 12 345678901');
    expect(value.legalName).toHaveLength(120);
    expect(value.country).toBe('ES');
    expect(value.updatedAt).toBeInstanceOf(Date);
  });

  test('valeurs refusées : type, idType, pays ; clé inconnue ignorée', () => {
    expect(mergeBillingInfo(null, { type: 'robot' }).error).toBeTruthy();
    expect(mergeBillingInfo(null, { idType: 'dni' }).error).toBeTruthy();
    expect(mergeBillingInfo(null, { country: 'France' }).error).toBeTruthy();
    // Clé inconnue : ignorée (jamais de 400 sur un PATCH partiel) ; idType '' = remise à zéro.
    expect(mergeBillingInfo(null, { iban: 'X', city: 'Paris' }).value).toMatchObject({ city: 'Paris' });
    expect(mergeBillingInfo(null, { iban: 'X' }).value.iban).toBeUndefined();
    expect(mergeBillingInfo({ idType: 'nif', idNumber: 'A1' }, { idType: '' }).value).toMatchObject({ idType: '', idNumber: 'A1' });
    expect(mergeBillingInfo(null, {}).value.type).toBe('individual');
    expect(mergeBillingInfo(null, { legalName: { $ne: 1 } }).error).toBeTruthy();
  });
});

describe('GET / PATCH /users/me/billing-info', () => {
  test('GET sans donnée → champs vides', async () => {
    const { owner } = seedPerson('billing+a@example.test');
    const res = await call(getMyBillingInfo, { user: { id: owner._id, role: 'owner' } });
    expect(res.statusCode).toBe(200);
    expect(res.body.idNumber).toBe('');
    expect(res.body.type).toBe('individual');
  });

  test('PATCH partiel → GET renvoie la fusion ; écrit sur les 3 docs de la personne', async () => {
    const { owner, sitter, walker } = seedPerson('billing+b@example.test');
    const other = seedPerson('billing+other@example.test');

    let res = await call(updateMyBillingInfo, {
      user: { id: sitter._id, role: 'sitter' },
      body: { type: 'business', legalName: 'Camille Pets SL', idType: 'cif', idNumber: 'b-1234 5678', country: 'ES' },
    });
    expect(res.statusCode).toBe(200);
    expect(res.body).toMatchObject({ type: 'business', idType: 'cif', idNumber: 'B-1234 5678', country: 'ES', vatNumber: '' });

    // 2e PATCH partiel : ne touche que la TVA et la ville.
    res = await call(updateMyBillingInfo, {
      user: { id: owner._id, role: 'owner' }, body: { vatNumber: 'esb12345678', city: 'Alicante' },
    });
    expect(res.body).toMatchObject({ legalName: 'Camille Pets SL', idNumber: 'B-1234 5678', vatNumber: 'ESB12345678', city: 'Alicante' });

    // Synchro : les 3 docs portent la même chose, l'autre personne rien.
    for (const [store, d] of [['Owner', owner], ['Sitter', sitter], ['Walker', walker]]) {
      const doc = mockStores[store].find((x) => x._id === d._id);
      expect(doc.billingInfo).toMatchObject({ legalName: 'Camille Pets SL', vatNumber: 'ESB12345678', city: 'Alicante' });
    }
    expect(mockStores.Owner.find((x) => x._id === other.owner._id).billingInfo).toBeUndefined();

    // GET depuis le 3e profil.
    res = await call(getMyBillingInfo, { user: { id: walker._id, role: 'walker' } });
    expect(res.body).toMatchObject({ type: 'business', idType: 'cif', idNumber: 'B-1234 5678', city: 'Alicante' });
    expect(res.body.updatedAt).toBeTruthy();
  });

  test('profil créé APRÈS la saisie (sans billingInfo) → lu depuis le profil frère', async () => {
    const { owner } = seedPerson('billing+c@example.test');
    await call(updateMyBillingInfo, { user: { id: owner._id, role: 'owner' }, body: { idType: 'nie', idNumber: 'x1234567l' } });
    const late = { _id: mockOid(), email: 'billing+c@example.test' };
    mockStores.Walker.push(late);
    const res = await call(getMyBillingInfo, { user: { id: late._id, role: 'walker' } });
    expect(res.body).toMatchObject({ idType: 'nie', idNumber: 'X1234567L' });
  });

  test('400 sur valeur invalide, 403 sur rôle non géré, rien écrit', async () => {
    const { owner } = seedPerson('billing+d@example.test');
    let res = await call(updateMyBillingInfo, { user: { id: owner._id, role: 'owner' }, body: { idType: 'xxx' } });
    expect(res.statusCode).toBe(400);
    expect(mockStores.Owner[0].billingInfo).toBeUndefined();
    res = await call(updateMyBillingInfo, { user: { id: owner._id, role: 'admin' }, body: {} });
    expect(res.statusCode).toBe(403);
  });

  test('admin : lecture seule par rôle + id', async () => {
    const { owner, sitter } = seedPerson('billing+e@example.test');
    await call(updateMyBillingInfo, { user: { id: owner._id, role: 'owner' }, body: { idType: 'siret', idNumber: '123 456 789 00012' } });
    const res = await call(adminGetBillingInfo, { user: { id: 'adm', role: 'admin' }, params: { role: 'sitter', id: sitter._id } });
    expect(res.body.billingInfo).toMatchObject({ idType: 'siret', idNumber: '123 456 789 00012' });
    const bad = await call(adminGetBillingInfo, { user: { id: 'adm', role: 'admin' }, params: { role: 'staff', id: sitter._id } });
    expect(bad.statusCode).toBe(400);
  });
});

describe('factures — instantanés issuerBilling / customerBilling', () => {
  const booking = (owner, sitter) => ({
    _id: mockOid(), ownerId: owner._id, sitterId: sitter._id, serviceType: 'pet_sitting',
    pricing: { totalPrice: 120, commission: 20, netPayout: 100, currency: 'eur' }, petIds: [],
  });

  test('instantané copié à la CRÉATION, et figé ensuite', async () => {
    const a = seedPerson('billing+owner@example.test');
    const b = seedPerson('billing+sitter@example.test');
    await call(updateMyBillingInfo, { user: { id: a.owner._id, role: 'owner' }, body: { legalName: 'Camille Durand', idType: 'nif', idNumber: '12345678z', country: 'ES' } });
    await call(updateMyBillingInfo, { user: { id: b.sitter._id, role: 'sitter' }, body: { type: 'business', legalName: 'Sitter SARL', idType: 'siret', idNumber: '12345678900012', vatNumber: 'fr12345678901', country: 'FR' } });

    const inv = await createInvoiceForBooking(booking(a.owner, b.sitter));
    expect(inv.customerBilling).toMatchObject({ legalName: 'Camille Durand', idType: 'nif', idNumber: '12345678Z' });
    expect(inv.issuerBilling).toMatchObject({ legalName: 'Sitter SARL', idType: 'siret', vatNumber: 'FR12345678901' });
    expect(inv.issuerBilling.snapshotAt).toBeTruthy();

    // Le propriétaire change son NIF APRÈS : la facture ne bouge pas.
    await call(updateMyBillingInfo, { user: { id: a.owner._id, role: 'owner' }, body: { idNumber: '99999999R', legalName: 'Autre Nom' } });
    const detail = await call(getInvoice, { user: { id: a.owner._id, role: 'owner' }, params: { id: inv._id } });
    expect(detail.body.invoice.customerBilling).toMatchObject({ legalName: 'Camille Durand', idNumber: '12345678Z' });
    const list = await call(listMyInvoices, { user: { id: b.sitter._id, role: 'sitter' } });
    expect(list.body.invoices[0].issuerBilling.legalName).toBe('Sitter SARL');
    expect(list.body.invoices[0].customerBilling.idNumber).toBe('12345678Z');
  });

  test('ancienne facture sans instantané : remplie UNE fois à la première lecture, puis figée', async () => {
    const a = seedPerson('billing+owner2@example.test');
    const b = seedPerson('billing+walker2@example.test');
    const legacy = {
      _id: mockOid(), invoiceNumber: 'HOP-2026-0001', ownerId: a.owner._id, providerId: b.walker._id,
      providerRole: 'walker', ownerName: 'Camille', providerName: 'Alex', grossAmount: 60, currency: 'EUR', status: 'paid',
    };
    mockStores.Invoice.push(legacy);

    // 1re lecture : personne n'a encore rien saisi → champs vides, rien de figé.
    let res = await call(getInvoice, { user: { id: a.owner._id, role: 'owner' }, params: { id: legacy._id } });
    expect(res.body.invoice.customerBilling).toMatchObject({ legalName: '', idNumber: '', snapshotAt: null });
    expect(res.body.invoice.issuerBilling.snapshotAt).toBeNull();

    // Le propriétaire saisit ses données → la lecture suivante remplit SON côté.
    await call(updateMyBillingInfo, { user: { id: a.owner._id, role: 'owner' }, body: { legalName: 'Camille Durand', idType: 'passport', idNumber: '19ab12345' } });
    res = await call(listMyInvoices, { user: { id: a.owner._id, role: 'owner' } });
    expect(res.body.invoices[0].customerBilling).toMatchObject({ legalName: 'Camille Durand', idType: 'passport', idNumber: '19AB12345' });
    expect(res.body.invoices[0].customerBilling.snapshotAt).toBeTruthy();
    expect(res.body.invoices[0].issuerBilling.snapshotAt).toBeNull();
    const frozenAt = mockStores.Invoice[0].customerBilling.snapshotAt;

    // Nouvelle modification : l'instantané déjà rempli ne change plus.
    await call(updateMyBillingInfo, { user: { id: a.owner._id, role: 'owner' }, body: { legalName: 'Nom Modifié', idNumber: 'ZZ000' } });
    res = await call(getInvoice, { user: { id: a.owner._id, role: 'owner' }, params: { id: legacy._id } });
    expect(res.body.invoice.customerBilling).toMatchObject({ legalName: 'Camille Durand', idNumber: '19AB12345' });
    expect(mockStores.Invoice[0].customerBilling.snapshotAt).toBe(frozenAt);
  });

  test('facture HTML : blocs Émetteur / Client traduits, identifiant « NIF : X », contenu échappé', async () => {
    const a = seedPerson('billing+owner3@example.test');
    const b = seedPerson('billing+sitter3@example.test');
    await call(updateMyBillingInfo, { user: { id: a.owner._id, role: 'owner' }, body: { legalName: '<script>x</script>', idType: 'nif', idNumber: '12345678z', address: '1 calle Mayor', postalCode: '03001', city: 'Alicante', country: 'ES' } });
    await call(updateMyBillingInfo, { user: { id: b.sitter._id, role: 'sitter' }, body: { legalName: 'Sitter SARL', idType: 'siret', idNumber: '12345678900012', vatNumber: 'FR12345678901' } });
    const inv = await createInvoiceForBooking(booking(a.owner, b.sitter));

    const fr = await call(renderInvoiceHtml, { user: { id: a.owner._id, role: 'owner' }, params: { id: inv._id }, query: { lang: 'fr' } });
    expect(fr.body).toContain('Émetteur');
    expect(fr.body).toContain('Client');
    expect(fr.body).toContain('NIF : 12345678Z');
    expect(fr.body).toContain('SIRET : 12345678900012');
    expect(fr.body).toContain('N° TVA : FR12345678901');
    expect(fr.body).toContain('1 calle Mayor, 03001 Alicante, ES');
    expect(fr.body).not.toContain('<script>x</script>');
    expect(fr.body).toContain('&lt;script&gt;x&lt;/script&gt;');

    // Sans ?lang : langue du compte (appLocale), ici le polonais.
    mockStores.Owner.find((x) => x._id === a.owner._id).appLocale = 'pl';
    const pl = await call(renderInvoiceHtml, { user: { id: a.owner._id, role: 'owner' }, params: { id: inv._id }, headers: { 'accept-language': 'fr-FR' } });
    expect(pl.body).toContain('Wystawca');
    expect(pl.body).toContain('Faktura');
  });
});
