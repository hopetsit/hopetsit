/** 11/11/2026 (BOB) — e-mail « êtes-vous toujours libre ? » : race de l'animal + extrait nettoyé du message du propriétaire. */
process.env.NODE_ENV = 'test';
const t = require('../src/utils/sitterFreeText1011');

const post = {
  serviceTypes: ['house_sitting'], startDate: new Date('2026-12-14'), endDate: new Date('2026-12-26'), location: { city: 'Zone fictive' },
  body: 'Je cherche quelqu un pour garder mon chien, bichon frisé de 7 ans. Appelez-moi au 06 12 34 56 78 ou nina@example.test, voir www.exemple.fr',
};
const html = (o) => t.questionEmailData({ lang: 'fr', post, petNames: ['Rex'], yesLink: 'https://x.test/y', noLink: 'https://x.test/n', ...o }).candidatesHtml2610;
afterEach(() => { delete process.env.SITTER_FREE_BREED_1111; });

test('race connue : une ligne « Race », sans doublon ni valeur vide, 3 au plus', () => {
  expect(t.breedLine1111(['Bichon frisé', 'bichon frisé', '', '  Yorkshire  ', 'Carlin', 'Teckel'])).toBe('Bichon frisé, Yorkshire, Carlin');
  const h = html({ breeds: ['Bichon frisé'] });
  expect(h).toContain('>Race<');
  expect(h).toContain('Bichon frisé');
});

test('race inconnue : aucune ligne « Race » (rien d\'inventé)', () => {
  expect(html({ breeds: [] })).not.toContain('>Race<');
  expect(html({})).not.toContain('>Race<');
  expect(t.breedLine1111(null)).toBe('');
});

test('message du propriétaire : extrait court, sans e-mail, téléphone ni lien', () => {
  const n = t.noteLine1111(post);
  expect(n).toContain('bichon frisé de 7 ans');
  expect(n).not.toMatch(/@|06 12|34 56|www\.|exemple\.fr/);
  expect(t.noteLine1111({ body: 'x'.repeat(400) }).length).toBeLessThanOrEqual(160);
  expect(t.noteLine1111({ body: '   ' })).toBe('');
  expect(html({ breeds: [] })).toContain('Message du propriétaire');
  expect(t.noteLine1111({ body: 'Écrivez-moi : +33 6 12 34 56 78 / 0033612345678 / https://wa.me/33612345678' })).not.toMatch(/\d{4,}/);
});

test('balises dans le texte du propriétaire : échappées', () => {
  const h = t.questionEmailData({ lang: 'fr', post: { ...post, body: '<img src=x onerror=1> mon chat' }, breeds: ['<b>x</b>'], yesLink: 'https://x.test/y' }).candidatesHtml2610;
  expect(h).not.toContain('<img');
  expect(h).not.toContain('<b>x</b>');
});

test('9 langues : les deux libellés existent', () => {
  for (const l of ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
    const L = t.L(l).labels;
    expect(L.breed).toBeTruthy();
    expect(L.note).toBeTruthy();
  }
});

test('coupe-circuit SITTER_FREE_BREED_1111=off : e-mail comme avant', () => {
  process.env.SITTER_FREE_BREED_1111 = 'off';
  const h = html({ breeds: ['Bichon frisé'] });
  expect(h).not.toContain('>Race<');
  expect(h).not.toContain('Message du propriétaire');
});
