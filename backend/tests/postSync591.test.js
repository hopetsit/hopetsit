// v591 — audit « annonces bien reliées » du 26/09.
const { parsePetIds } = require('../src/utils/petIdList591');

test('petIds : tableau, texte JSON (multipart de l\'app), liste à virgules', () => {
  expect(parsePetIds(['a', 'b'])).toEqual(['a', 'b']);
  expect(parsePetIds('["a","b"]')).toEqual(['a', 'b']);
  expect(parsePetIds('"a"')).toEqual(['a']);
  expect(parsePetIds('a, b')).toEqual(['a', 'b']);
  expect(parsePetIds('')).toEqual([]);
  expect(parsePetIds(undefined)).toEqual([]);
});
