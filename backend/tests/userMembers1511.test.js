// 15/11/2026 (BOB, demande de Daniel) — « le vrai nombre de gens dans l'app, en
// comptant les désinscrits » : inscrits depuis le début − désinscrits = présents.
const { summarizeMembers, countUsers } = require('../src/utils/userCounts');

const now = new Date('2026-11-15T12:00:00Z');
const ago = (days) => new Date(now.getTime() - days * 86400000);

describe('summarizeMembers', () => {
  const accounts = [
    { role: 'owner', email: 'a@x.fr', createdAt: ago(0.5), verified: true, status: 'active', lastSeenAt: ago(1) },
    { role: 'owner', email: 'b@x.fr', createdAt: ago(3), verified: false, adLead: true, status: 'active' },
    { role: 'sitter', email: 'c@x.fr', createdAt: ago(20), verified: true, status: 'suspended', lastSeenAt: ago(10) },
    { role: 'walker', email: 'd@x.fr', createdAt: ago(200), verified: false, status: 'banned' },
    { role: 'owner', email: 'dadaciao84+testowner@gmail.com', createdAt: ago(1), verified: true },
  ];
  const deletions = [
    { role: 'owner', email: 'parti@x.fr', deletedAt: ago(2), source: 'user' },
    { role: 'sitter', email: 'efface@x.fr', deletedAt: ago(40), source: 'admin' },
    { role: 'owner', email: 'revenu@x.fr', deletedAt: ago(5), source: 'admin', restoredAt: ago(4) },
    { role: 'owner', email: 'dadaciao84+test2@gmail.com', deletedAt: ago(1), source: 'user' },
  ];
  const m = summarizeMembers({ accounts, deletions, now });

  test('présents = comptes réels encore en base (tests exclus)', () => {
    expect(m.current).toBe(4);
  });
  test('désinscrits : restaurés et comptes de test non comptés', () => {
    expect(m.deleted).toBe(2);
    expect(m.deletedByUser).toBe(1);
    expect(m.deletedByAdmin).toBe(1);
    expect(m.deletedByRole).toEqual({ owners: 1, sitters: 1, walkers: 0 });
  });
  test('inscrits depuis le début = présents + désinscrits', () => {
    expect(m.everRegistered).toBe(m.current + m.deleted);
    expect(m.everRegistered).toBe(6);
  });
  test('vérifiés / non vérifiés / bloqués', () => {
    expect(m.verified).toBe(2);
    expect(m.unverified).toBe(2);
    expect(m.verified + m.unverified).toBe(m.current);
    expect(m.unverifiedAdLead).toBe(1);
    expect(m.blocked).toBe(2);
  });
  test('mouvements par période', () => {
    expect(m.d1).toEqual({ joined: 1, left: 0, net: 1 });
    expect(m.d7).toEqual({ joined: 2, left: 1, net: 1 });
    expect(m.d30).toEqual({ joined: 3, left: 1, net: 2 });
  });
  test('vus récemment', () => {
    expect(m.seen7d).toBe(1);
    expect(m.seen30d).toBe(2);
  });
  test('vide → zéros, pas de plantage', () => {
    const z = summarizeMembers({});
    expect(z).toMatchObject({ current: 0, everRegistered: 0, deleted: 0, deletionsSince: null });
  });
});

describe('countUsers avec le journal des désinscriptions', () => {
  const model = (rows) => ({ find: jest.fn(() => ({ select: () => ({ lean: async () => rows }) })) });
  test('members rempli, anciens compteurs inchangés', async () => {
    const r = await countUsers({
      Owner: model([{ email: 'a@x.fr', verified: true, createdAt: ago(1) }]),
      Sitter: model([{ email: 'b@x.fr', createdAt: ago(1) }]),
      Walker: model([]),
      decrypt: (v) => v,
      DeletedAccount: model([{ role: 'owner', email: 'z@x.fr', deletedAt: ago(1), source: 'user' }]),
      now,
    });
    expect(r.total).toBe(2);
    expect(r.members).toMatchObject({ current: 2, deleted: 1, everRegistered: 3, verified: 1, journal: true });
  });
  test('journal illisible → members null, total servi quand même', async () => {
    const r = await countUsers({
      Owner: model([{ email: 'a@x.fr' }]), Sitter: model([]), Walker: model([]), decrypt: (v) => v,
      DeletedAccount: { find: () => { throw new Error('base coupée'); } }, now,
    });
    expect(r.total).toBe(1);
    expect(r.members).toBeNull();
  });
});
