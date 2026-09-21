// v576 — facture HTML/PDF : logo CARDELLI HERMANOS embarqué (data URI),
// mise en page moderne, libellés traduits dans les 9 langues via
// locales/<lang>/invoice.json, et TOUTES les informations de facturation du
// client affichées quand elles sont renseignées (jamais de libellé sans
// valeur). Aucun montant ni numéro de facture ne change : seule la
// présentation évolue.
//
// Sans base réelle : les modèles sont remplacés par un magasin en mémoire
// (même harnais que tests/billingInfo.test.js). Aucun compte ni e-mail réel.

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

const { updateMyBillingInfo } = require('../src/controllers/billingInfoController');
const {
  createInvoiceForBooking,
  renderInvoiceHtml,
  INVOICE_LOCALES,
  invoiceTexts,
  CARDELLI_LOGO_DATA_URI,
  HOPETSIT_LOGO_DATA_URI,
  sendInvoiceError,
  ISSUER_COMPANY,
} = require('../src/controllers/invoiceController');

const call = async (handler, req) => {
  const res = { statusCode: 200, body: undefined, headers: {} };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = JSON.parse(JSON.stringify(b)); return res; };
  res.send = (b) => { res.body = b; return res; };
  res.set = (k, v) => { res.headers[k] = v; return res; };
  await handler({ query: {}, params: {}, headers: {}, body: {}, ...req }, res);
  return res;
};

const seedPerson = (email, name) => {
  const owner = { _id: mockOid(), email, name };
  const sitter = { _id: mockOid(), email, name };
  const walker = { _id: mockOid(), email, name };
  mockStores.Owner.push(owner); mockStores.Sitter.push(sitter); mockStores.Walker.push(walker);
  return { owner, sitter, walker };
};

const walkBookingOf = (owner, walker) => ({
  _id: mockOid(), ownerId: owner._id, walkerId: walker._id, serviceType: 'dog_walk',
  serviceDate: new Date('2026-09-10T10:00:00Z'),
  pricing: { totalPrice: 30, commission: 5, netPayout: 25, currency: 'eur' },
  petIds: [{ petName: 'Rex' }],
});

const bookingOf = (owner, sitter) => ({
  _id: mockOid(), ownerId: owner._id, sitterId: sitter._id, serviceType: 'pet_sitting',
  serviceDate: new Date('2026-09-10T10:00:00Z'),
  pricing: { totalPrice: 120, commission: 20, netPayout: 100, currency: 'eur' },
  petIds: [{ petName: 'Rex' }],
});

/** Client entreprise espagnol (CIF + TVA + adresse complète). */
const ES_BUSINESS = {
  type: 'business', legalName: 'Mascotas Alicante SL', idType: 'cif', idNumber: 'b12345678',
  vatNumber: 'esb12345678', address: 'Calle Mayor 12', postalCode: '03001', city: 'Alicante', country: 'ES',
};

const render = (inv, user, query) => call(renderInvoiceHtml, { user, params: { id: inv._id }, query: query || {} });

beforeEach(() => { for (const k of Object.keys(mockStores)) mockStores[k].length = 0; });

describe('v576 — catalogues de libellés (9 langues)', () => {
  const dir = (l) => path.join(__dirname, '..', 'src', 'locales', l, 'invoice.json');
  const read = (l) => JSON.parse(fs.readFileSync(dir(l), 'utf8'));

  test('les 9 langues du projet ont un fichier invoice.json', () => {
    expect(INVOICE_LOCALES.slice().sort()).toEqual(['de', 'en', 'es', 'fr', 'it', 'ja', 'ko', 'pl', 'pt']);
    for (const l of INVOICE_LOCALES) expect(fs.existsSync(dir(l))).toBe(true);
  });

  test('égalité STRICTE des clés entre les 9 langues, aucune valeur vide', () => {
    const ref = Object.keys(read('en')).sort();
    expect(ref.length).toBeGreaterThan(30);
    for (const l of INVOICE_LOCALES) {
      const cat = read(l);
      expect({ lang: l, keys: Object.keys(cat).sort() }).toEqual({ lang: l, keys: ref });
      for (const [k, v] of Object.entries(cat)) {
        expect(typeof v).toBe('string');
        expect({ lang: l, key: k, empty: v.trim().length === 0 }).toEqual({ lang: l, key: k, empty: false });
      }
    }
  });

  test('les libellés obligatoires de la facture existent dans chaque langue', () => {
    const needed = [
      'invoiceLabel', 'issuer', 'customer', 'serviceProvider', 'operatedBy', 'statusPaid',
      'statusRefunded', 'vat', 'companyNumber', 'passport', 'idOther', 'business', 'individual',
      'labelSep', 'legalMentions', 'totalCharged', 'roleSitter', 'roleWalker', 'summary',
    ];
    for (const l of INVOICE_LOCALES) {
      const T = invoiceTexts(l);
      for (const k of needed) expect({ lang: l, key: k, ok: !!T[k] }).toEqual({ lang: l, key: k, ok: true });
    }
  });

  test('une langue inconnue retombe sur l’anglais, jamais sur du vide', () => {
    const T = invoiceTexts('xx');
    expect(T.invoiceLabel).toBe('Invoice');
    expect(T.statusPaid).toBe('Paid');
  });
});

describe('v576 — logo Cardelli Hermanos embarqué', () => {
  test('les deux logos sont lus depuis backend/src/assets et mis en cache en data URI', () => {
    for (const f of ['cardelli_hermanos_logo.png', 'hopetsit_logo.png']) {
      expect(fs.existsSync(path.join(__dirname, '..', 'src', 'assets', f))).toBe(true);
    }
    for (const uri of [CARDELLI_LOGO_DATA_URI, HOPETSIT_LOGO_DATA_URI]) {
      expect(uri.startsWith('data:image/png;base64,')).toBe(true);
      expect(uri.length).toBeGreaterThan(5000);
    }
    expect(HOPETSIT_LOGO_DATA_URI).not.toBe(CARDELLI_LOGO_DATA_URI);
  });

  test('le HTML embarque le logo et ne dépend d’AUCUNE ressource distante', async () => {
    const a = seedPerson('inv576+owner@example.test', 'Camille Durand');
    const b = seedPerson('inv576+sitter@example.test', 'Alex Prestataire');
    const inv = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));
    const { body } = await render(inv, { id: a.owner._id, role: 'owner' }, { lang: 'fr' });

    expect(body).toContain(`src="${CARDELLI_LOGO_DATA_URI}"`);
    // Logo HoPetSit ACTUEL (fichier de marque), plus l'ancien dessin en dur.
    expect(body).toContain(`src="${HOPETSIT_LOGO_DATA_URI}"`);
    expect(body).toContain('alt="HoPetSit"');
    expect(body).not.toContain('<svg');
    expect(body).not.toContain('#EF4324'); // ancien orange de marque
    // Aucune image, feuille de style ou police servie par le réseau :
    // le PDF imprimé hors ligne reste complet.
    expect(body).not.toMatch(/src="https?:/);
    expect(body).not.toMatch(/<link\b/);
    expect(body).not.toMatch(/@import|fonts\.googleapis|cdn\./);
    // Le seul lien restant est la page publique des conditions de remboursement.
    expect(body.match(/https?:\/\/[^"'< ]+/g)).toEqual([
      'https://hopetsit.com/refund', 'https://hopetsit.com/refund',
    ]);
  });

  test('mise en page prête pour l’impression A4 (pas de coupure en plein tableau)', async () => {
    const a = seedPerson('inv576+print-o@example.test', 'Camille Durand');
    const b = seedPerson('inv576+print-s@example.test', 'Alex Prestataire');
    const inv = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));
    const { body, headers } = await render(inv, { id: a.owner._id, role: 'owner' }, { lang: 'fr' });
    expect(headers['Content-Type']).toBe('text/html; charset=utf-8');
    expect(body).toContain('@page { size: A4; margin: 14mm; }');
    expect(body).toMatch(/table\.items[^}]*break-inside: avoid/);
    expect(body).toContain('table.items thead { display: table-header-group; }');
    // Les deux boutons « Télécharger PDF » n'entrent pas dans le PDF.
    expect(body).toMatch(/\.cta, \.download-bar \{ display: none !important; \}/);
  });
});

describe('v576 — bloc ÉMETTEUR (entité qui facture) et marque HoPetSit', () => {
  test('la société, son numéro et son e-mail figurent dans l’émetteur ET en mentions légales', async () => {
    const a = seedPerson('inv576+iss-o@example.test', 'Camille Durand');
    const b = seedPerson('inv576+iss-s@example.test', 'Alex Prestataire');
    const inv = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));
    const { body } = await render(inv, { id: a.owner._id, role: 'owner' }, { lang: 'fr' });

    expect(ISSUER_COMPANY).toMatchObject({
      name: 'CARDELLI HERMANOS LIMITED', place: 'Hong Kong',
      companyNumber: 'n-2671528', email: 'contact@hopetsit.com',
    });
    expect(body).toContain('Émetteur');
    expect(body).toContain('CARDELLI HERMANOS LIMITED');
    expect(body).toContain('Hong Kong');
    expect(body).toContain("N° d&#39;entreprise : n-2671528");
    expect(body).toContain('contact@hopetsit.com');
    expect(body).toContain('Mentions légales');
    // La marque de l'app reste en tête du document.
    expect(body).toContain('<div class="brand-name">HoPetSit</div>');
    expect(body).toContain('Service exploité par CARDELLI HERMANOS LIMITED');
    // Le prestataire garde son propre bloc, avec son rôle TRADUIT
    // (la valeur brute « sitter » n'apparaît plus).
    expect(body).toContain('Prestataire');
    expect(body).toContain('Alex Prestataire');
    expect(body).toContain('<span class="pill">Gardien</span>');
    expect(body).not.toContain('>sitter<');
  });
});

describe('v576 — informations de facturation du CLIENT', () => {
  test('client entreprise espagnol : raison sociale, CIF, TVA et adresse sur la facture', async () => {
    const a = seedPerson('inv576+es-o@example.test', 'Camille Durand');
    const b = seedPerson('inv576+es-s@example.test', 'Alex Prestataire');
    await call(updateMyBillingInfo, { user: { id: a.owner._id, role: 'owner' }, body: ES_BUSINESS });
    await call(updateMyBillingInfo, {
      user: { id: b.sitter._id, role: 'sitter' },
      body: { type: 'business', legalName: 'Alex Pets SARL', idType: 'siret', idNumber: '12345678900012', vatNumber: 'fr12345678901', country: 'FR' },
    });
    const inv = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));
    const { body } = await render(inv, { id: a.owner._id, role: 'owner' }, { lang: 'fr' });

    expect(body).toContain('Mascotas Alicante SL');
    expect(body).toContain('Professionnel');
    expect(body).toContain('CIF : B12345678');
    expect(body).toContain('N° TVA : ESB12345678');
    expect(body).toContain('Calle Mayor 12, 03001 Alicante, ES');
    // Le prestataire aussi, avec son SIRET et sa TVA.
    expect(body).toContain('SIRET : 12345678900012');
    expect(body).toContain('N° TVA : FR12345678901');
  });

  test('chaque type d’identifiant porte le bon libellé, traduit', async () => {
    const cases = [
      ['nif', 'fr', 'NIF : X1234567L'], ['nie', 'es', 'NIE: X1234567L'],
      ['siret', 'fr', 'SIRET : X1234567L'], ['ein', 'en', 'EIN: X1234567L'],
      ['vat', 'de', 'USt-IdNr.: X1234567L'], ['passport', 'fr', 'Passeport : X1234567L'],
      ['company_number', 'pl', 'Nr firmy: X1234567L'], ['other', 'it', 'Identificativo: X1234567L'],
    ];
    for (const [idType, lang, expected] of cases) {
      for (const k of Object.keys(mockStores)) mockStores[k].length = 0;
      const a = seedPerson(`inv576+id-${idType}@example.test`, 'Camille Durand');
      const b = seedPerson(`inv576+ids-${idType}@example.test`, 'Alex Prestataire');
      // eslint-disable-next-line no-await-in-loop
      await call(updateMyBillingInfo, { user: { id: a.owner._id, role: 'owner' }, body: { idType, idNumber: 'x1234567l' } });
      // eslint-disable-next-line no-await-in-loop
      const inv = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));
      // eslint-disable-next-line no-await-in-loop
      const { body } = await render(inv, { id: a.owner._id, role: 'owner' }, { lang });
      expect({ idType, found: body.includes(expected) }).toEqual({ idType, found: true });
    }
  });

  test('client particulier sans informations : aucune ligne vide, aucun libellé orphelin', async () => {
    const a = seedPerson('inv576+plain-o@example.test', 'Camille Durand');
    const b = seedPerson('inv576+plain-s@example.test', 'Alex Prestataire');
    const inv = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));
    const { body } = await render(inv, { id: a.owner._id, role: 'owner' }, { lang: 'fr' });

    expect(body).toContain('Camille Durand');
    expect(body).not.toContain('N° TVA');
    expect(body).toContain("N° d&#39;entreprise : n-2671528"); // celui de l'émetteur, avec sa valeur
    expect(body).not.toContain('Professionnel');
    expect(body).not.toMatch(/(NIF|NIE|CIF|SIRET|EIN|Passeport|Identifiant)\s*:/);
    // Aucun libellé suivi d'un vide, ni ligne de bloc vide.
    expect(body).not.toMatch(/:\s*<\/div>/);
    expect(body).not.toMatch(/<div class="line">\s*<\/div>/);
    expect(body).not.toMatch(/<div class="name">\s*<\/div>/);
  });

  test('le nom légal d’un particulier identique au nom du compte n’est pas répété', async () => {
    const a = seedPerson('inv576+same-o@example.test', 'Camille Durand');
    const b = seedPerson('inv576+same-s@example.test', 'Alex Prestataire');
    await call(updateMyBillingInfo, {
      user: { id: a.owner._id, role: 'owner' },
      body: { legalName: 'camille durand', idType: 'nif', idNumber: '12345678z' },
    });
    const inv = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));
    const { body } = await render(inv, { id: a.owner._id, role: 'owner' }, { lang: 'fr' });
    expect(body).not.toContain('camille durand');
    expect(body).toContain('NIF : 12345678Z');
  });
});

describe('v576 — traductions de la facture', () => {
  const expectedLabel = {
    en: ['Invoice', 'Paid'], fr: ['Facture', 'Payée'], es: ['Factura', 'Pagada'],
    de: ['Rechnung', 'Bezahlt'], it: ['Fattura', 'Pagata'], pt: ['Fatura', 'Paga'],
    ko: ['청구서', '결제 완료'], ja: ['請求書', '支払済み'], pl: ['Faktura', 'Opłacona'],
  };

  test('les 9 langues rendent leurs propres libellés et leur statut traduit', async () => {
    const a = seedPerson('inv576+lang-o@example.test', 'Camille Durand');
    const b = seedPerson('inv576+lang-s@example.test', 'Alex Prestataire');
    const inv = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));
    for (const lang of INVOICE_LOCALES) {
      // eslint-disable-next-line no-await-in-loop
      const { body } = await render(inv, { id: a.owner._id, role: 'owner' }, { lang });
      const [label, status] = expectedLabel[lang];
      expect({ lang, html: body.includes(`<html lang="${lang}">`) }).toEqual({ lang, html: true });
      expect({ lang, label: body.includes(label) }).toEqual({ lang, label: true });
      expect({ lang, status: body.includes(`>${status}</span>`) }).toEqual({ lang, status: true });
    }
  });

  test('facture française : aucun mot anglais en dur (le statut « paid » brut a disparu)', async () => {
    const a = seedPerson('inv576+fr-o@example.test', 'Camille Durand');
    const b = seedPerson('inv576+fr-s@example.test', 'Alex Prestataire');
    const inv = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));
    const { body } = await render(inv, { id: a.owner._id, role: 'owner' }, { lang: 'fr' });
    // Texte visible seulement (le script embarqué garde ses noms anglais).
    const visible = body.replace(/<script[\s\S]*?<\/script>/g, '').replace(/<style[\s\S]*?<\/style>/g, '');
    for (const word of ['Operated by', 'Bill to', 'Service provider', 'Gross amount', 'Company No.', '>paid<', '>Invoice<']) {
      expect({ word, found: visible.includes(word) }).toEqual({ word, found: false });
    }
    expect(body).toContain('Payée');
  });

  test('statut remboursé traduit (plus de « refunded » brut)', async () => {
    const a = seedPerson('inv576+ref-o@example.test', 'Camille Durand');
    const b = seedPerson('inv576+ref-s@example.test', 'Alex Prestataire');
    const inv = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));
    mockStores.Invoice.find((x) => x._id === inv._id).status = 'refunded';
    const { body } = await render(inv, { id: a.owner._id, role: 'owner' }, { lang: 'fr' });
    expect(body).toContain('>Remboursée</span>');
    expect(body).toContain('class="status refunded"');
  });

  test('sans ?lang : la langue du COMPTE prime sur celle du navigateur', async () => {
    const a = seedPerson('inv576+acc-o@example.test', 'Camille Durand');
    const b = seedPerson('inv576+acc-s@example.test', 'Alex Prestataire');
    const inv = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));
    mockStores.Owner.find((x) => x._id === a.owner._id).appLocale = 'ja';
    const res = await call(renderInvoiceHtml, {
      user: { id: a.owner._id, role: 'owner' }, params: { id: inv._id },
      headers: { 'accept-language': 'fr-FR' },
    });
    expect(res.body).toContain('<html lang="ja">');
    expect(res.body).toContain('請求書');
  });
});

describe('v576 — montants et numéro de facture inchangés', () => {
  test('la refonte ne touche ni le numéro, ni les montants, ni la base', async () => {
    const a = seedPerson('inv576+amt-o@example.test', 'Camille Durand');
    const b = seedPerson('inv576+amt-s@example.test', 'Alex Prestataire');
    await call(updateMyBillingInfo, { user: { id: a.owner._id, role: 'owner' }, body: ES_BUSINESS });
    const inv = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));

    // Même règle de numérotation et mêmes montants qu'avant la v576.
    expect(inv.invoiceNumber).toBe(`HOP-${new Date().getFullYear()}-0001`);
    expect(inv.grossAmount).toBe(120);
    expect(inv.commission).toBe(20);
    expect(inv.netPayout).toBe(100);
    expect(inv.currency).toBe('EUR');

    const before = JSON.stringify(mockStores.Invoice[0]);
    const { body } = await render(inv, { id: a.owner._id, role: 'owner' }, { lang: 'fr' });

    expect(body).toContain(`HOP-${new Date().getFullYear()}-0001`);
    expect(body).toContain('120.00 EUR'); // brut et total facturé
    expect(body).toContain('20.00 EUR'); // commission 20 %
    expect(body).toContain('100.00 EUR'); // net prestataire
    expect(body).toContain('Rex');
    expect(body).toContain('2026-09-10');
    // Le rendu est en LECTURE seule : la facture stockée est identique.
    expect(JSON.stringify(mockStores.Invoice[0])).toBe(before);
  });

  test('accès refusé à un tiers, 404 sur identifiant invalide (comportement conservé)', async () => {
    const a = seedPerson('inv576+acl-o@example.test', 'Camille Durand');
    const b = seedPerson('inv576+acl-s@example.test', 'Alex Prestataire');
    const c = seedPerson('inv576+acl-x@example.test', 'Intrus');
    const inv = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));

    const denied = await render(inv, { id: c.owner._id, role: 'owner' }, { lang: 'fr' });
    expect(denied.statusCode).toBe(403);
    const bad = await call(renderInvoiceHtml, { params: { id: 'undefined' } });
    expect(bad.statusCode).toBe(404);
  });
});

describe('v576 — parcours « Télécharger la facture » (3 rôles)', () => {
  test('le bouton intégré à la page parle au BON canal JS (bug du téléchargement)', async () => {
    const a = seedPerson('inv576+js-o@example.test', 'Camille Durand');
    const b = seedPerson('inv576+js-s@example.test', 'Alex Prestataire');
    const inv = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));
    const { body } = await render(inv, { id: a.owner._id, role: 'owner' }, { lang: 'fr' });

    // L'app enregistre le canal « Hopetsit » (invoice_viewer_screen.dart) :
    // la page DOIT l'essayer, sinon le tap ne déclenche rien sur Android.
    expect(body).toMatch(/typeof Hopetsit !== 'undefined'/);
    expect(body).toMatch(/typeof HoPetSit !== 'undefined'/); // compatibilité
    expect(body).toContain("ch.postMessage('download')");
    // Les deux points d'entrée (bandeau du haut, barre du bas) appellent bien
    // la même fonction.
    expect(body.match(/onclick="downloadInvoice\(\)"/g)).toHaveLength(2);
  });

  test('propriétaire, gardien ET promeneur ouvrent chacun leur facture', async () => {
    const a = seedPerson('inv576+r-o@example.test', 'Camille Durand');
    const b = seedPerson('inv576+r-s@example.test', 'Alex Gardien');
    const c = seedPerson('inv576+r-w@example.test', 'Sam Promeneur');

    const invSitter = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));
    const invWalker = await createInvoiceForBooking(walkBookingOf(a.owner, c.walker));
    expect(invWalker.providerRole).toBe('walker');

    const cases = [
      [invSitter, { id: a.owner._id, role: 'owner' }, 'Gardien'],
      [invSitter, { id: b.sitter._id, role: 'sitter' }, 'Gardien'],
      [invWalker, { id: a.owner._id, role: 'owner' }, 'Promeneur'],
      // Le piège récurrent du projet : une page pensée pour le gardien et
      // réutilisée telle quelle, qui exclut le promeneur.
      [invWalker, { id: c.walker._id, role: 'walker' }, 'Promeneur'],
    ];
    for (const [inv, user, roleLabel] of cases) {
      // eslint-disable-next-line no-await-in-loop
      const res = await render(inv, user, { lang: 'fr' });
      expect({ role: user.role, status: res.statusCode }).toEqual({ role: user.role, status: 200 });
      expect(res.headers['Content-Type']).toBe('text/html; charset=utf-8');
      expect(res.body).toContain(inv.invoiceNumber);
      expect(res.body).toContain(`<span class="pill">${roleLabel}</span>`);
    }
  });

  test('un tiers reçoit une page d’erreur TRADUITE, pas une phrase anglaise', async () => {
    const a = seedPerson('inv576+err-o@example.test', 'Camille Durand');
    const b = seedPerson('inv576+err-s@example.test', 'Alex Prestataire');
    const c = seedPerson('inv576+err-x@example.test', 'Intrus');
    const inv = await createInvoiceForBooking(bookingOf(a.owner, b.sitter));

    const denied = await render(inv, { id: c.owner._id, role: 'owner' }, { lang: 'fr' });
    expect(denied.statusCode).toBe(403);
    expect(denied.headers['Content-Type']).toBe('text/html; charset=utf-8');
    expect(denied.body).toContain('Tu n&#39;as pas accès à cette facture.');
    expect(denied.body).not.toContain('Access denied');

    // Identifiant absent / « undefined » / mal formé : jamais de plantage.
    for (const id of ['undefined', '', 'null', '123', `${inv._id}xx`]) {
      // eslint-disable-next-line no-await-in-loop
      const res = await call(renderInvoiceHtml, { params: { id }, query: { lang: 'fr' } });
      expect({ id, status: res.statusCode }).toEqual({ id, status: 404 });
      expect(res.body).toContain('Cette facture n&#39;existe pas ou n&#39;est plus disponible.');
    }
    // Facture introuvable mais id bien formé.
    const gone = await call(renderInvoiceHtml, { params: { id: '0'.repeat(24) }, query: { lang: 'es' } });
    expect(gone.statusCode).toBe(404);
    expect(gone.body).toContain('Esta factura no existe o ya no está disponible.');
  });

  test('la page d’erreur suit la langue demandée, en repli sur le navigateur', async () => {
    const pl = await call(renderInvoiceHtml, {
      params: { id: 'undefined' }, headers: { 'accept-language': 'pl-PL,pl;q=0.9' },
    });
    expect(pl.body).toContain('<html lang="pl">');
    expect(pl.body).toContain('Ta faktura nie istnieje lub nie jest już dostępna.');
    const en = await call(renderInvoiceHtml, { params: { id: 'undefined' }, headers: {} });
    expect(en.body).toContain('<html lang="en">');
  });

  test('sendInvoiceError sert aussi les 401 du middleware (session expirée)', async () => {
    const res = await call((req, r) => sendInvoiceError(req, r, 401, 'errorAuth'), { query: { lang: 'fr' } });
    expect(res.statusCode).toBe(401);
    expect(res.headers['Content-Type']).toBe('text/html; charset=utf-8');
    expect(res.body).toContain('Ta session a expiré');
    expect(res.body).not.toContain('Authorization token is required');
  });
});
