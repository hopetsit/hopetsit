// v589 — fenêtres d'annonce de la PawMap : règles de ciblage et validation.
const a = require('../src/utils/mapAnnouncements589');

const base = { _id: 'x1', active: true, title: { fr: 'Nouvelle version', en: 'New version' }, body: { fr: 'Mets à jour', en: 'Update now' }, kind: 'update', roles: [], platforms: [], maxBuild: 589 };

test('build lu dans X-App-Version', () => {
  expect(a.buildFromHeader('23.1.578+589')).toBe(589);
  expect(a.buildFromHeader('web')).toBeNull();
  expect(a.buildFromHeader('')).toBeNull();
});

test('« mettre à jour » : visible sous le build, jamais à partir du build', () => {
  expect(a.isVisibleTo(base, { build: 588 })).toBe(true);
  expect(a.isVisibleTo(base, { build: 589 })).toBe(false);
  expect(a.isVisibleTo(base, { build: 600 })).toBe(false);
  expect(a.isVisibleTo(base, { build: null })).toBe(true);
});

test('rôle, plateforme, inactive, fenêtre de dates', () => {
  const now = new Date('2026-09-26T12:00:00Z');
  expect(a.isVisibleTo({ ...base, maxBuild: null, roles: ['sitter'] }, { role: 'owner', now })).toBe(false);
  expect(a.isVisibleTo({ ...base, maxBuild: null, roles: ['sitter'] }, { role: 'sitter', now })).toBe(true);
  expect(a.isVisibleTo({ ...base, maxBuild: null, platforms: ['ios'] }, { platform: 'android', now })).toBe(false);
  expect(a.isVisibleTo({ ...base, active: false }, { now })).toBe(false);
  expect(a.isVisibleTo({ ...base, maxBuild: null, startsAt: '2026-09-27T00:00:00Z' }, { now })).toBe(false);
  expect(a.isVisibleTo({ ...base, maxBuild: null, endsAt: '2026-09-26T11:00:00Z' }, { now })).toBe(false);
});

test('langue : demandée, sinon anglais, sinon français', () => {
  expect(a.toPublic(base, 'fr').title).toBe('Nouvelle version');
  expect(a.toPublic(base, 'de').title).toBe('New version');
  expect(a.toPublic({ ...base, title: { fr: 'Seulement FR' } }, 'ja').title).toBe('Seulement FR');
  expect(a.toPublic(base, 'fr-FR').body).toBe('Mets à jour');
});

test('validation admin', () => {
  expect(a.validate({}).error).toBeTruthy();
  expect(a.validate({ title: { fr: 'Salut' }, kind: 'link' }).error).toMatch(/lien/);
  expect(a.validate({ title: { fr: 'Salut' }, kind: 'link', url: 'http://x.com' }).error).toMatch(/https/);
  const ok = a.validate({ title: { fr: '  Salut  ', xx: 'ignoré' }, body: { en: 'Hi' }, kind: 'update', roles: ['owner', 'pirate'], platforms: ['ios'], maxBuild: '589' });
  expect(ok.value.title).toEqual({ fr: 'Salut' });
  expect(ok.value.roles).toEqual(['owner']);
  expect(ok.value.maxBuild).toBe(589);
  expect(a.validate({ active: false }, { partial: true }).value).toEqual({ active: false });
});

test('annonce réservée à quelques comptes', () => {
  const v = a.validate({ title: { fr: 'T' }, onlyEmails: 'Moi@Test.com, pas-un-mail, autre@x.fr' }).value;
  expect(v.onlyEmails).toEqual(['moi@test.com', 'autre@x.fr']);
  const ann = { ...base, maxBuild: null, onlyEmails: v.onlyEmails };
  expect(a.isVisibleTo(ann, { email: 'MOI@test.com ' })).toBe(true);
  expect(a.isVisibleTo(ann, { email: 'quelquun@x.fr' })).toBe(false);
  expect(a.isVisibleTo(ann, {})).toBe(false);
});
