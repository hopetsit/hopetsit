// 22/09/2026 — « une demande publiée AVEC une photo doit rester une demande ».
//
// L'app appelle POST /posts/with-media sans `postType` quand le propriétaire
// joint une photo de son animal. La demande était alors enregistrée en 'media' :
// absente du feed des gardiens (filtré sur postType:'request'), absente de
// « Mes annonces », et aucune notification « nouvelle demande près de chez toi ».
// Ce test verrouille la règle de déduction ; il tourne sans réseau ni base.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const { resolveMediaPostType } = require('../src/controllers/postController');

describe('resolveMediaPostType', () => {
  test('le site, qui envoie postType=request, est respecté', () => {
    expect(resolveMediaPostType({ rawPostType: 'request' })).toBe('request');
  });

  test("une photo sociale explicite reste 'media'", () => {
    expect(resolveMediaPostType({ rawPostType: 'media', serviceTypes: ['house_sitting'] }))
      .toBe('media');
  });

  test("l'app : des dates de service sans postType ⇒ c'est une demande", () => {
    expect(resolveMediaPostType({
      startDate: '2026-10-01T09:00:00.000Z',
      endDate: '2026-10-03T09:00:00.000Z',
    })).toBe('request');
  });

  test("l'app : un type de service seul suffit", () => {
    expect(resolveMediaPostType({ serviceTypes: ['dog_walking'] })).toBe('request');
    expect(resolveMediaPostType({ serviceTypes: 'house_sitting' })).toBe('request');
  });

  test('le lieu de garde seul suffit', () => {
    expect(resolveMediaPostType({ houseSittingVenue: 'owners_home' })).toBe('request');
  });

  test("une vraie photo sans date ni service reste 'media'", () => {
    expect(resolveMediaPostType({})).toBe('media');
    expect(resolveMediaPostType({ serviceTypes: [] })).toBe('media');
    expect(resolveMediaPostType({ startDate: '2026-10-01T09:00:00.000Z' })).toBe('media');
  });
});
