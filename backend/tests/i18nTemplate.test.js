const { render } = require('../src/utils/i18nTemplate');

describe('i18nTemplate.render', () => {
  test('substitutes top-level variables', () => {
    expect(render('Hello {{name}}', { name: 'Anna' })).toBe('Hello Anna');
  });

  test('supports dotted paths', () => {
    expect(render('Pet {{pet.name}}', { pet: { name: 'Rex' } })).toBe('Pet Rex');
  });

  test('returns empty string for missing keys', () => {
    expect(render('Hi {{name}}', {})).toBe('Hi ');
  });

  test('tolerates non-string templates', () => {
    expect(render(null)).toBe('');
    expect(render(undefined)).toBe('');
  });
});
