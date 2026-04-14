const { maskPhonesInText, MASK } = require('../src/utils/phoneMask');

describe('maskPhonesInText', () => {
  test('masks French mobile numbers', () => {
    expect(maskPhonesInText('call 06 12 34 56 78 please')).toContain(MASK);
  });

  test('masks +international numbers', () => {
    expect(maskPhonesInText('+33 6 12 34 56 78 ok')).toContain(MASK);
  });

  test('leaves short numbers unchanged', () => {
    // 12345 is less than 8 digits → not masked.
    expect(maskPhonesInText('code 12345 then go')).toBe('code 12345 then go');
  });

  test('leaves text without digits unchanged', () => {
    expect(maskPhonesInText('no phone here')).toBe('no phone here');
  });

  test('handles empty or non-string inputs', () => {
    expect(maskPhonesInText('')).toBe('');
    expect(maskPhonesInText(null)).toBe(null);
  });
});
