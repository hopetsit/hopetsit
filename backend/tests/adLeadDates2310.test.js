/** 23/10 (BOB) — dates des demandes issues de la pub : réponses libres, sinon « quand », sinon rien. */
const { datesFor, parseOne } = require('../src/utils/adLeadDates2310');
const NOW = new Date('2026-10-23T12:00:00Z');
const d = (x) => x.toISOString().slice(0, 10);

describe('parseOne', () => {
  test('français jour/mois/année, jour/mois (prochaine occurrence), nom de mois', () => {
    expect(d(parseOne('24/12/2026', 'fr', NOW))).toBe('2026-12-24');
    expect(d(parseOne('2/1', 'fr', NOW))).toBe('2027-01-02');
    expect(d(parseOne('24 décembre', 'fr', NOW))).toBe('2026-12-24');
    expect(d(parseOne('1er nov', 'fr', NOW))).toBe('2026-11-01');
  });
  test('anglais mois/jour et noms de mois', () => {
    expect(d(parseOne('12/24', 'en', NOW))).toBe('2026-12-24');
    expect(d(parseOne('Dec 24', 'en', NOW))).toBe('2026-12-24');
    expect(d(parseOne('January 2nd 2027', 'en', NOW))).toBe('2027-01-02');
  });
  test('texte illisible → null', () => {
    expect(parseOne('bientôt', 'fr', NOW)).toBeNull();
    expect(parseOne('31/02/2026', 'fr', NOW)).toBeNull();
    expect(parseOne('', 'fr', NOW)).toBeNull();
  });
});

describe('datesFor', () => {
  test('deux champs du formulaire', () => {
    const r = datesFor({ lang: 'fr', quand: 'plus_tard', startText: '24/12', endText: '02/01' }, NOW);
    expect([d(r.startDate), d(r.endDate), r.source]).toEqual(['2026-12-24', '2027-01-02', 'form']);
  });
  test('un seul champ « du … au … »', () => {
    const r = datesFor({ lang: 'fr', startText: 'du 24/12 au 2/1' }, NOW);
    expect([d(r.startDate), d(r.endDate)]).toEqual(['2026-12-24', '2027-01-02']);
  });
  test('fin avant début → repli sur « quand »', () => {
    const r = datesFor({ lang: 'fr', quand: 'fetes', startText: '02/01/2027', endText: '24/12/2026' }, NOW);
    expect([d(r.startDate), d(r.endDate), r.source]).toEqual(['2026-12-20', '2027-01-03', 'quand']);
  });
  test('bientôt → J+7 → J+14', () => {
    const r = datesFor({ lang: 'en', quand: 'bientot' }, NOW);
    expect([d(r.startDate), d(r.endDate), r.source]).toEqual(['2026-10-30', '2026-11-06', 'quand']);
  });
  test('plus tard sans dates → null (annonce sans dates, signalée)', () => {
    expect(datesFor({ lang: 'fr', quand: 'plus_tard' }, NOW)).toBeNull();
  });
});
