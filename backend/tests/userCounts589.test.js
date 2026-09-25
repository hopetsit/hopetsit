// v589 — Compteurs d'utilisateurs du tableau de bord admin : même règle
// d'exclusion pour propriétaires / gardiens / promeneurs, total = somme des 3,
// personnes uniques par e-mail. Fonctions pures + lecture simulée (aucune base).
const { isInternalEmail, summarizeUsers, countUsers } = require('../src/utils/userCounts');

describe('isInternalEmail', () => {
  test.each([
    ['dadaciao84+testowner@gmail.com', true],
    ['someone+TEST@yahoo.fr', true],
    ['dadaciao84@gmail.com', true],
    ['hopetsit@gmail.com', true],
    ['probe-565@invalid.example', true],
    ['marie.dupont@gmail.com', false],
    ['test@gmail.com', false], // « test » sans « + » : une vraie adresse possible
    ['', false],
  ])('%s → %s', (email, expected) => {
    expect(isInternalEmail(email)).toBe(expected);
  });
});

describe('summarizeUsers', () => {
  const data = {
    owners: ['a@x.fr', 'b@x.fr', 'dadaciao84+testowner@gmail.com', 'probe-565@invalid.example', 'Multi@x.fr'],
    sitters: ['c@x.fr', 'multi@x.fr', 'dadaciao84+testsitter@gmail.com'],
    walkers: ['d@x.fr', 'MULTI@x.fr ', 'b@x.fr', 'dadaciao84@gmail.com'],
  };
  const r = summarizeUsers(data);

  test('même règle pour les 3 rôles', () => {
    expect(r.owners).toBe(3);
    expect(r.sitters).toBe(2);
    expect(r.walkers).toBe(3);
    expect(r.excluded).toEqual({ owners: 2, sitters: 1, walkers: 1, total: 4 });
    expect(r.raw.total).toBe(12);
  });

  test('total = somme des 3 rôles, sans double comptage', () => {
    expect(r.total).toBe(r.owners + r.sitters + r.walkers);
    expect(r.total + r.excluded.total).toBe(r.raw.total);
  });

  test('personnes uniques par e-mail (casse et espaces ignorés)', () => {
    // a, b, multi, c, d → 5 personnes ; multi (3 rôles) et b (2 rôles) = multi-profils
    expect(r.people).toBe(5);
    expect(r.multiRole).toBe(2);
  });

  test('vide → zéros', () => {
    const z = summarizeUsers({});
    expect(z).toMatchObject({ owners: 0, sitters: 0, walkers: 0, total: 0, people: 0, multiRole: 0 });
  });
});

describe('countUsers (lecture de TOUS les comptes, sans pagination)', () => {
  const fakeModel = (emails) => ({
    find: jest.fn(() => ({
      select: () => ({ lean: async () => emails.map((email) => ({ email })) }),
    })),
  });

  test('déchiffre les e-mails et compte tout (pas de limite à 20)', async () => {
    const many = Array.from({ length: 250 }, (_, i) => `enc:user${i}@x.fr`);
    const Owner = fakeModel(many);
    const Sitter = fakeModel(['enc:user1@x.fr', 'enc:dadaciao84+testsitter@gmail.com']);
    const Walker = fakeModel(['bad']);
    const decrypt = (v) => {
      if (v === 'bad') throw new Error('illisible');
      return v.replace(/^enc:/, '');
    };
    const r = await countUsers({ Owner, Sitter, Walker, decrypt });
    expect(Owner.find).toHaveBeenCalledWith({});
    expect(r.owners).toBe(250);
    expect(r.sitters).toBe(1);
    expect(r.walkers).toBe(1); // e-mail illisible : compté, personne à part
    expect(r.total).toBe(252);
    expect(r.people).toBe(251); // user1 a deux profils
    expect(r.multiRole).toBe(1);
  });
});
