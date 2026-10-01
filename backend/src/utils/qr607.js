'use strict';

/**
 * 607 (NEO, 02/10/2026) — générateur de QR code SANS dépendance (le serveur
 * n'a ni `qrcode` ni `pdfkit`, et on n'ajoute rien au package.json pour une
 * affiche). Norme ISO/IEC 18004 : mode octets, correction d'erreur au choix
 * (M par défaut : ~15 % du code peut être abîmé), versions 1 à 40, masque
 * choisi par les 4 règles de pénalité. Algorithme d'après la référence
 * publique de Project Nayuki (licence MIT).
 *
 * Vérifié par tests/linkPerso607.test.js : matrice identique, module pour
 * module, à celle de la bibliothèque Python `qrcode` pour les mêmes données,
 * version, niveau et masque (fixtures générées le 02/10).
 */

const ECL = {
  L: { ord: 0, bits: 1 },
  M: { ord: 1, bits: 0 },
  Q: { ord: 2, bits: 3 },
  H: { ord: 3, bits: 2 },
};

const ECC_CODEWORDS_PER_BLOCK = [
  [-1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
  [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28],
  [-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
  [-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
];
const NUM_ERROR_CORRECTION_BLOCKS = [
  [-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25],
  [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49],
  [-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68],
  [-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81],
];

const getBit = (x, i) => ((x >>> i) & 1) !== 0;

function numRawDataModules(ver) {
  let result = (16 * ver + 128) * ver + 64;
  if (ver >= 2) {
    const numAlign = Math.floor(ver / 7) + 2;
    result -= (25 * numAlign - 10) * numAlign - 55;
    if (ver >= 7) result -= 36;
  }
  return result;
}

function numDataCodewords(ver, ecl) {
  return Math.floor(numRawDataModules(ver) / 8)
    - ECC_CODEWORDS_PER_BLOCK[ecl.ord][ver] * NUM_ERROR_CORRECTION_BLOCKS[ecl.ord][ver];
}

function rsMultiply(x, y) {
  let z = 0;
  for (let i = 7; i >= 0; i -= 1) {
    z = (z << 1) ^ ((z >>> 7) * 0x11d);
    z ^= ((y >>> i) & 1) * x;
  }
  return z & 0xff;
}

function rsDivisor(degree) {
  const result = new Array(degree).fill(0);
  result[degree - 1] = 1;
  let root = 1;
  for (let i = 0; i < degree; i += 1) {
    for (let j = 0; j < result.length; j += 1) {
      result[j] = rsMultiply(result[j], root);
      if (j + 1 < result.length) result[j] ^= result[j + 1];
    }
    root = rsMultiply(root, 0x02);
  }
  return result;
}

function rsRemainder(data, divisor) {
  const result = divisor.map(() => 0);
  for (const b of data) {
    const factor = b ^ result.shift();
    result.push(0);
    divisor.forEach((coef, i) => { result[i] ^= rsMultiply(coef, factor); });
  }
  return result;
}

function alignmentPositions(ver) {
  if (ver === 1) return [];
  const size = ver * 4 + 17;
  const numAlign = Math.floor(ver / 7) + 2;
  const step = ver === 32 ? 26 : Math.ceil((ver * 4 + 4) / (numAlign * 2 - 2)) * 2;
  const result = [6];
  for (let pos = size - 7; result.length < numAlign; pos -= step) result.splice(1, 0, pos);
  return result;
}

/**
 * @param {string} text
 * @param {{ecl?: 'L'|'M'|'Q'|'H', version?: number, mask?: number}} [opts]
 * @returns {{ size:number, version:number, mask:number, modules:boolean[][] }}
 */
function encodeQr(text, opts = {}) {
  const ecl = ECL[opts.ecl || 'M'];
  const bytes = Array.from(Buffer.from(String(text), 'utf8'));

  // Plus petite version qui contient les données.
  let ver = opts.version || 0;
  const bitsNeeded = (v) => 4 + (v <= 9 ? 8 : 16) + bytes.length * 8;
  if (!ver) {
    for (let v = 1; v <= 40; v += 1) {
      if (bitsNeeded(v) <= numDataCodewords(v, ecl) * 8) { ver = v; break; }
    }
    if (!ver) throw new Error('QR : texte trop long');
  } else if (bitsNeeded(ver) > numDataCodewords(ver, ecl) * 8) {
    throw new Error('QR : texte trop long pour cette version');
  }

  // Flux de bits : mode octets (0100), longueur, données, terminateur, bourrage.
  const bb = [];
  const push = (val, len) => { for (let i = len - 1; i >= 0; i -= 1) bb.push((val >>> i) & 1); };
  push(0x4, 4);
  push(bytes.length, ver <= 9 ? 8 : 16);
  for (const b of bytes) push(b, 8);
  const capacity = numDataCodewords(ver, ecl) * 8;
  push(0, Math.min(4, capacity - bb.length));
  push(0, (8 - (bb.length % 8)) % 8);
  for (let pad = 0xec; bb.length < capacity; pad ^= 0xec ^ 0x11) push(pad, 8);
  const data = [];
  for (let i = 0; i < bb.length; i += 8) {
    let v = 0;
    for (let j = 0; j < 8; j += 1) v = (v << 1) | bb[i + j];
    data.push(v);
  }

  // Blocs + correction d'erreur, puis entrelacement.
  const numBlocks = NUM_ERROR_CORRECTION_BLOCKS[ecl.ord][ver];
  const blockEccLen = ECC_CODEWORDS_PER_BLOCK[ecl.ord][ver];
  const rawCodewords = Math.floor(numRawDataModules(ver) / 8);
  const numShortBlocks = numBlocks - (rawCodewords % numBlocks);
  const shortBlockLen = Math.floor(rawCodewords / numBlocks);
  const divisor = rsDivisor(blockEccLen);
  const blocks = [];
  for (let i = 0, k = 0; i < numBlocks; i += 1) {
    const len = shortBlockLen - blockEccLen + (i < numShortBlocks ? 0 : 1);
    const dat = data.slice(k, k + len);
    k += len;
    const ecc = rsRemainder(dat, divisor);
    if (i < numShortBlocks) dat.push(0);
    blocks.push(dat.concat(ecc));
  }
  const codewords = [];
  for (let i = 0; i < blocks[0].length; i += 1) {
    blocks.forEach((block, j) => {
      if (i !== shortBlockLen - blockEccLen || j >= numShortBlocks) codewords.push(block[i]);
    });
  }

  // Matrice.
  const size = ver * 4 + 17;
  const modules = Array.from({ length: size }, () => new Array(size).fill(false));
  const isFn = Array.from({ length: size }, () => new Array(size).fill(false));
  const setFn = (x, y, dark) => { modules[y][x] = dark; isFn[y][x] = true; };

  for (let i = 0; i < size; i += 1) { setFn(6, i, i % 2 === 0); setFn(i, 6, i % 2 === 0); }
  const finder = (x, y) => {
    for (let dy = -4; dy <= 4; dy += 1) {
      for (let dx = -4; dx <= 4; dx += 1) {
        const dist = Math.max(Math.abs(dx), Math.abs(dy));
        const xx = x + dx; const yy = y + dy;
        if (xx >= 0 && xx < size && yy >= 0 && yy < size) setFn(xx, yy, dist !== 2 && dist !== 4);
      }
    }
  };
  finder(3, 3); finder(size - 4, 3); finder(3, size - 4);
  const ap = alignmentPositions(ver);
  const na = ap.length;
  for (let i = 0; i < na; i += 1) {
    for (let j = 0; j < na; j += 1) {
      if ((i === 0 && j === 0) || (i === 0 && j === na - 1) || (i === na - 1 && j === 0)) continue;
      for (let dy = -2; dy <= 2; dy += 1) {
        for (let dx = -2; dx <= 2; dx += 1) setFn(ap[i] + dx, ap[j] + dy, Math.max(Math.abs(dx), Math.abs(dy)) !== 1);
      }
    }
  }
  const drawFormat = (mask) => {
    const d = (ecl.bits << 3) | mask;
    let rem = d;
    for (let i = 0; i < 10; i += 1) rem = (rem << 1) ^ ((rem >>> 9) * 0x537);
    const bits = ((d << 10) | rem) ^ 0x5412;
    for (let i = 0; i <= 5; i += 1) setFn(8, i, getBit(bits, i));
    setFn(8, 7, getBit(bits, 6));
    setFn(8, 8, getBit(bits, 7));
    setFn(7, 8, getBit(bits, 8));
    for (let i = 9; i < 15; i += 1) setFn(14 - i, 8, getBit(bits, i));
    for (let i = 0; i < 8; i += 1) setFn(size - 1 - i, 8, getBit(bits, i));
    for (let i = 8; i < 15; i += 1) setFn(8, size - 15 + i, getBit(bits, i));
    setFn(8, size - 8, true);
  };
  drawFormat(0);
  if (ver >= 7) {
    let rem = ver;
    for (let i = 0; i < 12; i += 1) rem = (rem << 1) ^ ((rem >>> 11) * 0x1f25);
    const bits = (ver << 12) | rem;
    for (let i = 0; i < 18; i += 1) {
      const bit = getBit(bits, i);
      const a = size - 11 + (i % 3);
      const b = Math.floor(i / 3);
      setFn(a, b, bit); setFn(b, a, bit);
    }
  }

  // Données en zigzag.
  let bi = 0;
  for (let right = size - 1; right >= 1; right -= 2) {
    if (right === 6) right = 5;
    for (let vert = 0; vert < size; vert += 1) {
      for (let j = 0; j < 2; j += 1) {
        const x = right - j;
        const upward = ((right + 1) & 2) === 0;
        const y = upward ? size - 1 - vert : vert;
        if (!isFn[y][x] && bi < codewords.length * 8) {
          modules[y][x] = getBit(codewords[bi >>> 3], 7 - (bi & 7));
          bi += 1;
        }
      }
    }
  }

  const applyMask = (mask) => {
    for (let y = 0; y < size; y += 1) {
      for (let x = 0; x < size; x += 1) {
        let inv;
        switch (mask) {
          case 0: inv = (x + y) % 2 === 0; break;
          case 1: inv = y % 2 === 0; break;
          case 2: inv = x % 3 === 0; break;
          case 3: inv = (x + y) % 3 === 0; break;
          case 4: inv = (Math.floor(x / 3) + Math.floor(y / 2)) % 2 === 0; break;
          case 5: inv = ((x * y) % 2) + ((x * y) % 3) === 0; break;
          case 6: inv = (((x * y) % 2) + ((x * y) % 3)) % 2 === 0; break;
          default: inv = (((x + y) % 2) + ((x * y) % 3)) % 2 === 0; break;
        }
        if (!isFn[y][x] && inv) modules[y][x] = !modules[y][x];
      }
    }
  };

  const penalty = () => {
    let score = 0;
    const line = (get) => {
      // N1 (suites de 5+ de même couleur) et N3 (motif 1:1:3:1:1 bordé de 4 clairs).
      for (let a = 0; a < size; a += 1) {
        let run = 1;
        for (let b = 1; b < size; b += 1) {
          if (get(a, b) === get(a, b - 1)) {
            run += 1;
            if (run === 5) score += 3; else if (run > 5) score += 1;
          } else run = 1;
        }
        for (let b = 0; b + 7 <= size; b += 1) {
          const p = [1, 0, 1, 1, 1, 0, 1].every((v, k) => get(a, b + k) === !!v);
          if (!p) continue;
          const lightBefore = [1, 2, 3, 4].every((k) => b - k < 0 || !get(a, b - k));
          const lightAfter = [0, 1, 2, 3].every((k) => b + 7 + k >= size || !get(a, b + 7 + k));
          if (lightBefore) score += 40;
          if (lightAfter) score += 40;
        }
      }
    };
    line((a, b) => modules[a][b]);
    line((a, b) => modules[b][a]);
    // N2 : blocs 2x2.
    for (let y = 0; y < size - 1; y += 1) {
      for (let x = 0; x < size - 1; x += 1) {
        const c = modules[y][x];
        if (c === modules[y][x + 1] && c === modules[y + 1][x] && c === modules[y + 1][x + 1]) score += 3;
      }
    }
    // N4 : équilibre clair / sombre.
    let dark = 0;
    for (const row of modules) for (const m of row) if (m) dark += 1;
    const total = size * size;
    const k = Math.ceil(Math.abs(dark * 20 - total * 10) / total) - 1;
    score += Math.max(0, k) * 10;
    return score;
  };

  let mask = Number.isInteger(opts.mask) ? opts.mask : -1;
  if (mask < 0) {
    let best = Infinity;
    for (let m = 0; m < 8; m += 1) {
      applyMask(m);
      drawFormat(m);
      const p = penalty();
      if (p < best) { best = p; mask = m; }
      applyMask(m);
    }
  }
  applyMask(mask);
  drawFormat(mask);
  return { size, version: ver, mask, modules };
}

module.exports = { encodeQr };
