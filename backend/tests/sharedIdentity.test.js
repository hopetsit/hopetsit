// v575 — « avec le même compte j'ai un profil propriétaire, pet-sitter et
// promeneur, mais les infos (nom, prénom, e-mail, téléphone, adresse) ne sont
// pas pré-enregistrées dans les autres profils » (Daniel, 21/09/2026).
//
// Une personne = jusqu'à 3 documents (Owner / Sitter / Walker) reliés par
// l'e-mail (et `oldId`). Ces tests vérifient, SANS réseau ni base :
//   • seuls les champs d'identité partagés voyagent d'un profil à l'autre ;
//   • rien de PROPRE à un rôle (bio, tarifs, IBAN, services…) ne fuit ;
//   • une valeur vide n'écrase jamais une valeur existante chez le frère ;
//   • le profil créé par « Activer » (switchRole) naît pré-rempli ;
//   • le rattrapage à la lecture complète ce qui manque, sans migration ;
//   • le changement d'e-mail met à jour les TROIS documents ensemble ;
//   • une personne sans profil frère n'est jamais affectée.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = 'a'.repeat(64);

// ─── Base en mémoire ────────────────────────────────────────────────────────
let DB;

const resetDb = () => {
  DB = {
    Owner: {
      owner1: {
        _id: 'owner1', oldId: 'owner1', email: 'daniel@example.test',
        name: 'Daniel Cardelli', firstName: 'Daniel', lastName: 'Cardelli',
        mobile: '612345678', countryCode: '+33', address: '3 rue des Lilas',
        city: 'Paris', country: 'FR', language: 'fr', appLocale: 'fr',
        currency: 'EUR', dateOfBirth: '01/01/1990',
        avatar: { url: 'https://cdn/x.jpg', publicId: 'x' },
        bio: 'Je cherche un gardien pour Rex.',
        location: { type: 'Point', coordinates: [2.35, 48.85], city: 'Paris', liveShareActive: true },
        updatedAt: new Date('2026-09-20T10:00:00Z'),
      },
    },
    Sitter: {
      sitter1: {
        _id: 'sitter1', oldId: 'owner1', email: 'daniel@example.test',
        name: 'Daniel Cardelli', firstName: '', lastName: '',
        mobile: '', countryCode: '', address: '', city: '', country: '',
        language: '', appLocale: '', currency: 'EUR', dateOfBirth: '',
        avatar: { url: '', publicId: '' },
        bio: 'Gardien passionné depuis 10 ans.',
        skills: 'Chiens, chats',
        hourlyRate: 15,
        ibanNumber: 'gcm:secret',
        updatedAt: new Date('2026-09-19T10:00:00Z'),
      },
      sitter2: {
        _id: 'sitter2', oldId: 'sitter2', email: 'autre@example.test',
        name: 'Autre Personne', mobile: '699999999', city: 'Lyon',
        updatedAt: new Date('2026-09-18T10:00:00Z'),
      },
    },
    Walker: {
      walker1: {
        _id: 'walker1', oldId: 'owner1', email: 'daniel@example.test',
        name: 'Daniel Cardelli', firstName: '', lastName: '',
        mobile: '', countryCode: '', address: 'ancienne adresse',
        city: '', country: '', language: '', appLocale: '', currency: 'EUR',
        dateOfBirth: '', avatar: { url: '', publicId: '' },
        bio: 'Promeneur sportif.',
        coverageCity: 'Boulogne',
        updatedAt: new Date('2026-09-18T09:00:00Z'),
      },
    },
  };
};
resetDb();

const clone = (o) => (o == null ? o : JSON.parse(JSON.stringify(o)));

const setDeep = (doc, path, value) => {
  const parts = path.split('.');
  let cur = doc;
  for (let i = 0; i < parts.length - 1; i += 1) {
    if (typeof cur[parts[i]] !== 'object' || cur[parts[i]] === null) cur[parts[i]] = {};
    cur = cur[parts[i]];
  }
  cur[parts[parts.length - 1]] = value;
};

const matches = (doc, query) => {
  if (!query || typeof query !== 'object') return true;
  if (query.$or) return query.$or.some((q) => matches(doc, q));
  return Object.entries(query).every(([k, v]) => {
    if (k === '_id') return String(doc._id) === String(v);
    if (v && typeof v === 'object' && v.$ne !== undefined) return doc[k] !== v.$ne;
    return doc[k] === v;
  });
};

const chain = (value) => {
  const c = {
    select: () => c,
    lean: () => Promise.resolve(clone(value)),
    then: (fn, rej) => Promise.resolve(clone(value)).then(fn, rej),
    catch: (fn) => Promise.resolve(clone(value)).catch(fn),
  };
  return c;
};

const makeModel = (name) => ({
  modelName: name,
  findById: jest.fn((id) => chain(DB[name][String(id)] || null)),
  findOne: jest.fn((q) => chain(Object.values(DB[name]).find((d) => matches(d, q)) || null)),
  find: jest.fn((q) => chain(Object.values(DB[name]).filter((d) => matches(d, q)))),
  updateOne: jest.fn(async (filter, ops) => {
    const doc = Object.values(DB[name]).find((d) => matches(d, filter));
    if (!doc) return { matchedCount: 0, modifiedCount: 0 };
    let modified = 0;
    for (const [path, value] of Object.entries((ops && ops.$set) || {})) {
      setDeep(doc, path, value);
      modified = 1;
    }
    for (const path of Object.keys((ops && ops.$unset) || {})) {
      delete doc[path];
      modified = 1;
    }
    return { matchedCount: 1, modifiedCount: modified };
  }),
});

jest.mock('../src/models/Owner', () => makeModel('Owner'));
jest.mock('../src/models/Sitter', () => makeModel('Sitter'));
jest.mock('../src/models/Walker', () => makeModel('Walker'));

const {
  propagateSharedIdentity,
  fillMissingIdentityFromSiblings,
  buildIdentityFromSource,
  pickSharedIdentity,
  SHARED_IDENTITY_FIELDS,
} = require('../src/utils/sharedIdentity');
const {
  splitFullName, joinFullName, buildNameUpdate, deriveNameParts, hasFullName,
} = require('../src/utils/personName');

beforeEach(() => resetDb());

// ─── 1. Liste blanche ───────────────────────────────────────────────────────
describe('liste blanche des champs partagés', () => {
  test('contient exactement les champs qui décrivent la personne', () => {
    expect(SHARED_IDENTITY_FIELDS).toEqual([
      'name', 'firstName', 'lastName', 'mobile', 'countryCode', 'address',
      'city', 'country', 'language', 'appLocale', 'currency', 'dateOfBirth',
      'avatar',
    ]);
  });

  test('aucun champ propre à un rôle ne peut entrer dans le payload', () => {
    const picked = pickSharedIdentity({
      name: 'Daniel Cardelli',
      bio: 'Gardien passionné',
      skills: 'Chiens',
      hourlyRate: 15,
      walkRates: [{ durationMinutes: 30 }],
      ibanNumber: 'gcm:secret',
      paypalEmail: 'gcm:secret',
      card: { last4: '4242' },
      kycStatus: 'verified',
      isPremium: true,
      fcmTokens: ['t1'],
      password: 'hash',
      servicePricing: {},
      coverageCity: 'Boulogne',
      notificationPrefs: { sound: 'frog' },
    });
    expect(Object.keys(picked).sort()).toEqual(['firstName', 'lastName', 'name']);
  });
});

// ─── 2. Propagation ─────────────────────────────────────────────────────────
describe('propagateSharedIdentity', () => {
  test('propage les champs d’identité vers les deux profils frères', async () => {
    const res = await propagateSharedIdentity(
      DB.Owner.owner1,
      'owner',
      { mobile: '612345678', countryCode: '+33', address: '3 rue des Lilas', city: 'Paris' },
    );
    expect(res.targets).toBe(2);
    expect(DB.Sitter.sitter1.mobile).toBe('612345678');
    expect(DB.Sitter.sitter1.countryCode).toBe('+33');
    expect(DB.Sitter.sitter1.city).toBe('Paris');
    expect(DB.Walker.walker1.mobile).toBe('612345678');
  });

  test('rien de propre au rôle ne fuit vers les frères', async () => {
    await propagateSharedIdentity(
      DB.Sitter.sitter1,
      'sitter',
      {
        name: 'Daniel Cardelli',
        bio: 'Gardien passionné depuis 10 ans.',
        skills: 'Chiens, chats',
        hourlyRate: 20,
        ibanNumber: 'gcm:secret',
      },
    );
    expect(DB.Owner.owner1.bio).toBe('Je cherche un gardien pour Rex.');
    expect(DB.Walker.walker1.bio).toBe('Promeneur sportif.');
    expect(DB.Owner.owner1.skills).toBeUndefined();
    expect(DB.Owner.owner1.hourlyRate).toBeUndefined();
    expect(DB.Owner.owner1.ibanNumber).toBeUndefined();
  });

  test('une valeur vide ne remplace jamais une valeur existante chez le frère', async () => {
    await propagateSharedIdentity(
      DB.Sitter.sitter1,
      'sitter',
      { address: '', city: '', mobile: '', countryCode: '' },
    );
    expect(DB.Owner.owner1.address).toBe('3 rue des Lilas');
    expect(DB.Owner.owner1.city).toBe('Paris');
    expect(DB.Owner.owner1.mobile).toBe('612345678');
  });

  test('vider explicitement un champ est possible via allowEmpty', async () => {
    await propagateSharedIdentity(
      DB.Sitter.sitter1, 'sitter', { address: '' }, { allowEmpty: ['address'] },
    );
    expect(DB.Owner.owner1.address).toBe('');
  });

  test('la photo se propage aux deux autres profils', async () => {
    await propagateSharedIdentity(
      DB.Owner.owner1, 'owner', { avatar: { url: 'https://cdn/new.jpg', publicId: 'new' } },
    );
    expect(DB.Sitter.sitter1.avatar.url).toBe('https://cdn/new.jpg');
    expect(DB.Walker.walker1.avatar.publicId).toBe('new');
  });

  test('la position est recopiée sans écraser l’état du partage en direct du frère', async () => {
    DB.Sitter.sitter1.location = {
      type: 'Point', coordinates: [1, 1], city: 'Lille', liveShareActive: true,
    };
    await propagateSharedIdentity(DB.Owner.owner1, 'owner', {
      location: { type: 'Point', coordinates: [2.35, 48.85], city: 'Paris' },
    });
    expect(DB.Sitter.sitter1.location.coordinates).toEqual([2.35, 48.85]);
    expect(DB.Sitter.sitter1.location.city).toBe('Paris');
    expect(DB.Sitter.sitter1.location.liveShareActive).toBe(true);
  });

  test('ne touche jamais une autre personne', async () => {
    await propagateSharedIdentity(DB.Owner.owner1, 'owner', { mobile: '612345678' });
    expect(DB.Sitter.sitter2.mobile).toBe('699999999');
  });

  test('personne sans profil frère : aucun effet, aucune erreur', async () => {
    const res = await propagateSharedIdentity(DB.Sitter.sitter2, 'sitter', { mobile: '600000000' });
    expect(res.targets).toBe(0);
    expect(res.modified).toBe(0);
  });

  test('payload sans champ partagé : ne touche à rien', async () => {
    const res = await propagateSharedIdentity(DB.Owner.owner1, 'owner', { bio: 'x', hourlyRate: 9 });
    expect(res.fields).toEqual([]);
    expect(DB.Sitter.sitter1.bio).toBe('Gardien passionné depuis 10 ans.');
  });

  test('ne lève jamais, même si le document source est absurde', async () => {
    await expect(propagateSharedIdentity(null, 'owner', { name: 'X' })).resolves.toBeTruthy();
    await expect(propagateSharedIdentity({}, 'owner', { name: 'X' })).resolves.toBeTruthy();
  });
});

// ─── 3. Création par switchRole ─────────────────────────────────────────────
describe('switchRole — pré-remplissage du profil créé', () => {
  test('le bloc d’identité est complet et sans champ de rôle', () => {
    const identity = buildIdentityFromSource(DB.Owner.owner1);
    expect(identity).toMatchObject({
      name: 'Daniel Cardelli',
      firstName: 'Daniel',
      lastName: 'Cardelli',
      mobile: '612345678',
      countryCode: '+33',
      address: '3 rue des Lilas',
      city: 'Paris',
      country: 'FR',
      language: 'fr',
      appLocale: 'fr',
      currency: 'EUR',
      dateOfBirth: '01/01/1990',
    });
    expect(identity.avatar.url).toBe('https://cdn/x.jpg');
    expect(identity.bio).toBeUndefined();
    expect(identity.skills).toBeUndefined();
    expect(identity.hourlyRate).toBeUndefined();
  });

  test('la ville est reprise de location.city quand le champ plat est vide', () => {
    const src = { name: 'A B', city: '', location: { city: 'Nice', coordinates: [7, 43] } };
    expect(buildIdentityFromSource(src).city).toBe('Nice');
  });

  test('un compte historique sans prénom/nom les reçoit dérivés de name', () => {
    const identity = buildIdentityFromSource({ name: 'Jean Pierre Martin' });
    expect(identity.firstName).toBe('Jean');
    expect(identity.lastName).toBe('Pierre Martin');
  });
});

// ─── 4. Rattrapage à la lecture ─────────────────────────────────────────────
describe('rattrapage à la lecture', () => {
  test('complète les champs vides depuis le frère, en réponse ET en base', async () => {
    const sitter = clone(DB.Sitter.sitter1);
    await fillMissingIdentityFromSiblings(sitter, 'sitter');
    expect(sitter.mobile).toBe('612345678');
    expect(sitter.city).toBe('Paris');
    expect(sitter.country).toBe('FR');
    expect(sitter.appLocale).toBe('fr');
    // persisté sur CE document seulement
    expect(DB.Sitter.sitter1.mobile).toBe('612345678');
    expect(DB.Walker.walker1.mobile).toBe('');
  });

  test('ne remplace jamais une valeur déjà présente', async () => {
    const walker = clone(DB.Walker.walker1);
    await fillMissingIdentityFromSiblings(walker, 'walker');
    expect(walker.address).toBe('ancienne adresse');
    expect(walker.bio).toBe('Promeneur sportif.');
  });

  test('le frère le plus récemment modifié gagne', async () => {
    DB.Sitter.sitter1.city = 'Lyon';
    DB.Sitter.sitter1.updatedAt = new Date('2026-09-21T10:00:00Z'); // plus récent
    const walker = clone(DB.Walker.walker1);
    await fillMissingIdentityFromSiblings(walker, 'walker');
    expect(walker.city).toBe('Lyon');
  });

  test('personne sans frère : aucun effet', async () => {
    const before = clone(DB.Sitter.sitter2);
    const after = await fillMissingIdentityFromSiblings(clone(DB.Sitter.sitter2), 'sitter');
    expect(after).toEqual(before);
  });
});

// ─── 5. Prénom / nom ────────────────────────────────────────────────────────
describe('nom et prénom (utils/personName)', () => {
  test('découpage : 1er mot = prénom, le reste = nom', () => {
    expect(splitFullName('Daniel Cardelli')).toEqual({ firstName: 'Daniel', lastName: 'Cardelli' });
    expect(splitFullName('Jean Pierre de La Tour'))
      .toEqual({ firstName: 'Jean', lastName: 'Pierre de La Tour' });
    expect(splitFullName('Madonna')).toEqual({ firstName: 'Madonna', lastName: '' });
    expect(splitFullName('   ')).toEqual({ firstName: '', lastName: '' });
  });

  test('recomposition sans espace parasite', () => {
    expect(joinFullName('Daniel', 'Cardelli')).toBe('Daniel Cardelli');
    expect(joinFullName('Madonna', '')).toBe('Madonna');
    expect(joinFullName('  Daniel  ', '  Cardelli ')).toBe('Daniel Cardelli');
  });

  test('app ≥ 575 : prénom + nom envoyés → name recalculé', () => {
    const u = buildNameUpdate({ firstName: 'Daniela', lastName: 'Cardelli' }, { name: 'Daniel Cardelli' });
    expect(u).toEqual({ name: 'Daniela Cardelli', firstName: 'Daniela', lastName: 'Cardelli' });
  });

  test('un seul des deux envoyé : l’autre garde sa valeur courante', () => {
    const u = buildNameUpdate({ lastName: 'Hermanos' }, { firstName: 'Daniel', lastName: 'Cardelli' });
    expect(u).toEqual({ name: 'Daniel Hermanos', firstName: 'Daniel', lastName: 'Hermanos' });
  });

  test('ancienne app : seul name envoyé → name pris tel quel, parties re-dérivées', () => {
    const u = buildNameUpdate({ name: '  Paul   Durand ' }, { firstName: 'Daniel', lastName: 'Cardelli' });
    expect(u).toEqual({ name: 'Paul Durand', firstName: 'Paul', lastName: 'Durand' });
  });

  test('nom complet vide : refusé (name est obligatoire en base)', () => {
    expect(() => buildNameUpdate({ name: '   ' }, {})).toThrow();
    expect(() => buildNameUpdate({ firstName: '', lastName: '' }, {})).toThrow();
  });

  test('requête qui ne parle pas du nom : aucun changement', () => {
    expect(buildNameUpdate({ mobile: '612345678' }, { name: 'Daniel Cardelli' })).toBeNull();
  });

  test('compte historique : les parties sont dérivées à la lecture', () => {
    expect(deriveNameParts({ name: 'Daniel Cardelli' }))
      .toEqual({ firstName: 'Daniel', lastName: 'Cardelli' });
    expect(deriveNameParts({ name: 'Daniel Cardelli', firstName: 'Dan', lastName: 'C' }))
      .toEqual({ firstName: 'Dan', lastName: 'C' });
  });

  test('complétion : « nom » est rempli quand prénom ET nom existent', () => {
    expect(hasFullName({ name: 'Daniel Cardelli' })).toBe(true);
    expect(hasFullName({ name: 'Madonna' })).toBe(false);
    expect(hasFullName({ firstName: 'Daniel', lastName: 'Cardelli' })).toBe(true);
  });

  test('le trio name/firstName/lastName voyage ensemble vers les frères', async () => {
    DB.Sitter.sitter1.firstName = 'Daniel';
    DB.Sitter.sitter1.lastName = 'Cardelli';
    await propagateSharedIdentity(
      DB.Owner.owner1, 'owner', { name: 'Madonna', firstName: 'Madonna', lastName: '' },
    );
    expect(DB.Sitter.sitter1.name).toBe('Madonna');
    expect(DB.Sitter.sitter1.firstName).toBe('Madonna');
    expect(DB.Sitter.sitter1.lastName).toBe('');
  });

  test('ancienne app (name seul) : les parties sont propagées re-dérivées', async () => {
    await propagateSharedIdentity(DB.Owner.owner1, 'owner', { name: 'Paul Durand' });
    expect(DB.Sitter.sitter1.firstName).toBe('Paul');
    expect(DB.Sitter.sitter1.lastName).toBe('Durand');
  });
});

// ─── 6. Changement d'e-mail : les 3 documents ensemble ──────────────────────
// L'e-mail est la CLÉ DE LIAISON entre les trois profils : s'il ne change que
// sur un document, la personne perd ses deux autres profils.
describe('changement d’e-mail', () => {
  const loadController = () => {
    jest.resetModules();
    jest.doMock('../src/models/Owner', () => makeModel('Owner'));
    jest.doMock('../src/models/Sitter', () => makeModel('Sitter'));
    jest.doMock('../src/models/Walker', () => makeModel('Walker'));
    jest.doMock('../src/models/VerificationCode', () => ({ deleteMany: jest.fn(async () => ({})) }));
    jest.doMock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn() }));
    jest.doMock('../src/services/loyaltyService', () => ({ getOwnerStats: jest.fn() }));
    jest.doMock('../src/services/referralService', () => ({ getMyReferrals: jest.fn() }));
    jest.doMock('../src/utils/code', () => ({
      generateVerificationCode: () => '123456',
      hashCode: (c) => `h:${c}`,
      compareCode: (c, h) => h === `h:${c}`,
    }));
    return require('../src/controllers/userController');
  };

  test('confirmer le code met à jour les 3 documents', async () => {
    for (const d of [DB.Owner.owner1, DB.Sitter.sitter1, DB.Walker.walker1]) {
      d.pendingEmail = 'nouveau@example.test';
      d.pendingEmailCodeHash = 'h:123456';
      d.pendingEmailExpiresAt = new Date(Date.now() + 3600 * 1000);
    }
    const { confirmEmailChange } = loadController();
    let body = null;
    let status = 200;
    await confirmEmailChange(
      { user: { id: 'sitter1', role: 'sitter' }, body: { code: '123456' } },
      { status(c) { status = c; return this; }, json(b) { body = b; return this; } },
    );
    expect(status).toBe(200);
    expect(body.ok).toBe(true);
    expect(DB.Owner.owner1.email).toBe('nouveau@example.test');
    expect(DB.Sitter.sitter1.email).toBe('nouveau@example.test');
    expect(DB.Walker.walker1.email).toBe('nouveau@example.test');
    // Une autre personne n'est jamais touchée.
    expect(DB.Sitter.sitter2.email).toBe('autre@example.test');
  });

  test('code faux : aucun document modifié', async () => {
    for (const d of [DB.Owner.owner1, DB.Sitter.sitter1, DB.Walker.walker1]) {
      d.pendingEmail = 'nouveau@example.test';
      d.pendingEmailCodeHash = 'h:123456';
      d.pendingEmailExpiresAt = new Date(Date.now() + 3600 * 1000);
    }
    const { confirmEmailChange } = loadController();
    let status = 200;
    await confirmEmailChange(
      { user: { id: 'owner1', role: 'owner' }, body: { code: '000000' } },
      { status(c) { status = c; return this; }, json() { return this; } },
    );
    expect(status).toBe(400);
    expect(DB.Owner.owner1.email).toBe('daniel@example.test');
    expect(DB.Walker.walker1.email).toBe('daniel@example.test');
  });
});
