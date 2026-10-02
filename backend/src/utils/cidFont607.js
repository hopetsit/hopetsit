'use strict';

/**
 * 607 (NEO, 02/10/2026) — POLICE UNICODE DE L'AFFICHE (demande de Daniel :
 * « impeccable » : le polonais garde ses lettres, japonais et coréen dans leur
 * langue).
 *
 * Police : Noto Sans CJK (OpenType/CFF, licence SIL Open Font License 1.1,
 * notice et licence dans la table `name` du fichier, cf. assets/fonts/LISEZMOI).
 * Une seule police couvre les 9 langues de l'app : latin étendu (ą ę ł ś ż),
 * kana, kanji et hangeul.
 *
 * Le fichier fait 16 Mo : on n'en met dans chaque PDF qu'un SOUS-ENSEMBLE
 * (seulement les glyphes utilisés), sans aucune dépendance :
 *   · lecture des tables `cmap` (format 4 et 12), `hmtx`, `head`, `CFF ` ;
 *   · CFF CID-keyed réécrit : en-tête, Name/String/GSubr recopiés, Top DICT
 *     réencodé (offsets sur 5 octets), charset (nouveau GID → CID d'origine),
 *     FDSelect, CharStrings des seuls glyphes utilisés, FDArray + Private +
 *     sous-routines locales recopiés ;
 *   · PDF : Type0 / Identity-H, CIDFontType0 + FontFile3 (CIDFontType0C),
 *     largeurs W, et ToUnicode pour que le texte reste copiable et cherchable.
 */
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const FONT_PATH = path.join(__dirname, '..', 'assets', 'fonts', 'NotoSansCJK-Regular.otf');

// ── lecture de base ────────────────────────────────────────────────────────
function readIndex(b, p) {
  const count = b.readUInt16BE(p);
  if (count === 0) return { count: 0, start: p, end: p + 2, items: [] };
  const os = b[p + 2];
  const rd = (q) => { let v = 0; for (let k = 0; k < os; k += 1) v = v * 256 + b[q + k]; return v; };
  const offs = [];
  for (let i = 0; i <= count; i += 1) offs.push(rd(p + 3 + i * os));
  const base = p + 3 + (count + 1) * os - 1;
  return {
    count, start: p, end: base + offs[count], offs, base,
    get: (i) => b.subarray(base + offs[i], base + offs[i + 1]),
  };
}

function buildIndex(items) {
  if (!items.length) return Buffer.from([0, 0]);
  const total = items.reduce((s, x) => s + x.length, 0) + 1;
  const os = total < 0x100 ? 1 : total < 0x10000 ? 2 : total < 0x1000000 ? 3 : 4;
  const head = Buffer.alloc(3 + (items.length + 1) * os);
  head.writeUInt16BE(items.length, 0);
  head[2] = os;
  let off = 1;
  for (let i = 0; i <= items.length; i += 1) {
    for (let k = 0; k < os; k += 1) head[3 + i * os + k] = (off >>> (8 * (os - 1 - k))) & 0xff;
    if (i < items.length) off += items[i].length;
  }
  return Buffer.concat([head, ...items]);
}

/** DICT → [{ op, raw, nums }] (raw = octets des opérandes, recopiés tels quels). */
function parseDict(d) {
  const out = [];
  let i = 0; let start = 0; let nums = [];
  while (i < d.length) {
    const b0 = d[i];
    if (b0 <= 21) {
      let op = b0; let len = 1;
      if (b0 === 12) { op = 1200 + d[i + 1]; len = 2; }
      out.push({ op, raw: d.subarray(start, i), nums });
      i += len; start = i; nums = [];
    } else if (b0 === 28) { nums.push(d.readInt16BE(i + 1)); i += 3; }
    else if (b0 === 29) { nums.push(d.readInt32BE(i + 1)); i += 5; }
    else if (b0 === 30) { i += 1; while (i < d.length) { const x = d[i]; i += 1; if ((x & 0x0f) === 0x0f || (x >> 4) === 0x0f) break; } nums.push(NaN); }
    else if (b0 >= 32 && b0 <= 246) { nums.push(b0 - 139); i += 1; }
    else if (b0 >= 247 && b0 <= 250) { nums.push((b0 - 247) * 256 + d[i + 1] + 108); i += 2; }
    else if (b0 >= 251 && b0 <= 254) { nums.push(-(b0 - 251) * 256 - d[i + 1] - 108); i += 2; }
    else i += 1;
  }
  return out;
}

const int5 = (v) => { const x = Buffer.alloc(5); x[0] = 29; x.writeInt32BE(v, 1); return x; };
const opBytes = (op) => (op >= 1200 ? Buffer.from([12, op - 1200]) : Buffer.from([op]));

/** Réencode un DICT ; `fix[op]` = fonction(nums) → Buffer d'opérandes. */
function encodeDict(entries, fix = {}) {
  return Buffer.concat(entries.map((e) => Buffer.concat([fix[e.op] ? fix[e.op](e.nums) : e.raw, opBytes(e.op)])));
}

function cmapLookup(b, sub12, sub4) {
  return (cp) => {
    if (sub12) {
      const ng = b.readUInt32BE(sub12 + 12);
      let lo = 0; let hi = ng - 1;
      while (lo <= hi) {
        const mid = (lo + hi) >> 1; const g = sub12 + 16 + 12 * mid;
        const s = b.readUInt32BE(g); const e = b.readUInt32BE(g + 4);
        if (cp < s) hi = mid - 1; else if (cp > e) lo = mid + 1; else return b.readUInt32BE(g + 8) + (cp - s);
      }
      return 0;
    }
    if (sub4 && cp <= 0xffff) {
      const segX2 = b.readUInt16BE(sub4 + 6);
      const ends = sub4 + 14; const starts = ends + segX2 + 2; const deltas = starts + segX2; const ranges = deltas + segX2;
      for (let i = 0; i < segX2 / 2; i += 1) {
        if (cp > b.readUInt16BE(ends + 2 * i)) continue;
        const s = b.readUInt16BE(starts + 2 * i);
        if (cp < s) return 0;
        const ro = b.readUInt16BE(ranges + 2 * i);
        const d = b.readInt16BE(deltas + 2 * i);
        if (!ro) return (cp + d) & 0xffff;
        const gi = b.readUInt16BE(ranges + 2 * i + ro + 2 * (cp - s));
        return gi ? (gi + d) & 0xffff : 0;
      }
    }
    return 0;
  };
}

let _font = null;

function loadFont() {
  if (_font) return _font;
  const b = fs.readFileSync(FONT_PATH);
  const n = b.readUInt16BE(4);
  const t = {};
  for (let i = 0; i < n; i += 1) {
    const o = 12 + 16 * i;
    t[b.toString('latin1', o, o + 4)] = { off: b.readUInt32BE(o + 8), len: b.readUInt32BE(o + 12) };
  }
  const unitsPerEm = b.readUInt16BE(t.head.off + 18);
  const numHMetrics = b.readUInt16BE(t.hhea.off + 34);
  const ascender = b.readInt16BE(t.hhea.off + 4);
  const descender = b.readInt16BE(t.hhea.off + 6);
  const advance = (gid) => {
    const g = Math.min(gid, numHMetrics - 1);
    return b.readUInt16BE(t.hmtx.off + 4 * g);
  };

  // cmap : format 12 (plateforme 3 / enc 10) sinon format 4 (3 / 1).
  const cm = t.cmap.off;
  const nsub = b.readUInt16BE(cm + 2);
  let sub12 = null; let sub4 = null;
  for (let i = 0; i < nsub; i += 1) {
    const pid = b.readUInt16BE(cm + 4 + 8 * i); const eid = b.readUInt16BE(cm + 6 + 8 * i);
    const so = cm + b.readUInt32BE(cm + 8 + 8 * i);
    const fmt = b.readUInt16BE(so);
    if (fmt === 12 && pid === 3 && eid === 10) sub12 = so;
    if (fmt === 4 && pid === 3 && eid === 1) sub4 = so;
  }
  const glyphOf = cmapLookup(b, sub12, sub4);

  // CFF
  const c = t['CFF '].off;
  const cff = b.subarray(c, c + t['CFF '].len);
  const hdr = cff[2];
  const nameIdx = readIndex(cff, hdr);
  const topIdx = readIndex(cff, nameIdx.end);
  const strIdx = readIndex(cff, topIdx.end);
  const gsubIdx = readIndex(cff, strIdx.end);
  const top = parseDict(topIdx.get(0));
  const topOp = (op) => top.find((e) => e.op === op);
  if (!topOp(1230)) throw new Error('police non CID-keyed');
  const cs = readIndex(cff, topOp(17).nums[0]);
  const nGlyphs = cs.count;
  // charset : GID → CID
  const cidOf = new Uint32Array(nGlyphs);
  {
    let p = topOp(15).nums[0]; const fmt = cff[p]; p += 1; let g = 1;
    if (fmt === 0) { for (; g < nGlyphs; g += 1, p += 2) cidOf[g] = cff.readUInt16BE(p); }
    else {
      while (g < nGlyphs) {
        const first = cff.readUInt16BE(p);
        const left = fmt === 1 ? cff[p + 2] : cff.readUInt16BE(p + 2);
        p += fmt === 1 ? 3 : 4;
        for (let k = 0; k <= left && g < nGlyphs; k += 1, g += 1) cidOf[g] = first + k;
      }
    }
  }
  // FDSelect : GID → FD
  const fdOf = new Uint8Array(nGlyphs);
  {
    let p = topOp(1237).nums[0]; const fmt = cff[p]; p += 1;
    if (fmt === 0) for (let g = 0; g < nGlyphs; g += 1) fdOf[g] = cff[p + g];
    else {
      const nr = cff.readUInt16BE(p); p += 2;
      for (let r = 0; r < nr; r += 1) {
        const first = cff.readUInt16BE(p + 3 * r); const fd = cff[p + 3 * r + 2];
        const next = cff.readUInt16BE(p + 3 * (r + 1));
        for (let g = first; g < next && g < nGlyphs; g += 1) fdOf[g] = fd;
      }
    }
  }
  const fdArr = readIndex(cff, topOp(1236).nums[0]);
  const fds = [];
  for (let i = 0; i < fdArr.count; i += 1) {
    const fd = parseDict(fdArr.get(i));
    const pr = fd.find((e) => e.op === 18);
    const [size, off] = pr.nums;
    const priv = parseDict(cff.subarray(off, off + size));
    const subrsE = priv.find((e) => e.op === 19);
    const subrsIx = subrsE ? readIndex(cff, off + subrsE.nums[0]) : null;
    const subrs = subrsIx ? cff.subarray(subrsIx.start, subrsIx.end) : null;
    fds.push({ fd, priv, subrs, subrsIx });
  }
  const ros = topOp(1230).nums; // [registry SID, ordering SID, supplement]
  const sid = (s) => (s < 391 ? null : strIdx.get(s - 391).toString('latin1'));
  const bbox = (topOp(5) && topOp(5).nums) || [-1000, -1000, 3000, 1500];
  _font = {
    b, cff, nameIdx, strIdx, gsubIdx, top, cs, cidOf, fdOf, fds,
    unitsPerEm, ascender, descender, advance, glyphOf, bbox,
    registry: sid(ros[0]) || 'Adobe', ordering: sid(ros[1]) || 'Identity', supplement: ros[2] || 0,
  };
  return _font;
}


const biasOf = (n) => (n < 1240 ? 107 : n < 33900 ? 1131 : 32768);

/** Sous-routines locales réellement appelées par les glyphes (interpréteur Type 2 minimal). */
function usedSubrs(f, gids) {
  const used = new Map(); // fd → Set(index)
  for (const g of gids) {
    const fdi = f.fdOf[g];
    const local = f.fds[fdi].subrsIx;
    const lset = used.get(fdi) || new Set(); used.set(fdi, lset);
    const st = { stack: [], stems: 0, done: false };
    const run = (cs, depth) => {
      if (depth > 12) return;
      let i = 0;
      while (i < cs.length && !st.done) {
        const b0 = cs[i];
        if (b0 === 28) { st.stack.push(cs.readInt16BE(i + 1)); i += 3; continue; }
        if (b0 >= 32 && b0 <= 246) { st.stack.push(b0 - 139); i += 1; continue; }
        if (b0 >= 247 && b0 <= 250) { st.stack.push((b0 - 247) * 256 + cs[i + 1] + 108); i += 2; continue; }
        if (b0 >= 251 && b0 <= 254) { st.stack.push(-(b0 - 251) * 256 - cs[i + 1] - 108); i += 2; continue; }
        if (b0 === 255) { st.stack.push(cs.readInt32BE(i + 1) / 65536); i += 5; continue; }
        i += 1;
        switch (b0) {
          case 1: case 3: case 18: case 23:
            st.stems += st.stack.length >> 1; st.stack = []; break;
          case 19: case 20:
            st.stems += st.stack.length >> 1; st.stack = [];
            i += (st.stems + 7) >> 3; break;
          case 10: {
            const idx = st.stack.pop() + biasOf(local ? local.count : 0);
            if (local && idx >= 0 && idx < local.count) { lset.add(idx); run(local.get(idx), depth + 1); }
            break;
          }
          case 29: {
            const idx = st.stack.pop() + biasOf(f.gsubIdx.count);
            if (idx >= 0 && idx < f.gsubIdx.count) run(f.gsubIdx.get(idx), depth + 1);
            break;
          }
          case 11: return;
          case 14: st.done = true; return;
          case 12: i += 1; st.stack = []; break;
          default: st.stack = [];
        }
      }
    };
    run(f.cs.get(g), 0);
  }
  return used;
}

/** Sous-ensemble CFF des GID donnés (le 0 .notdef est toujours gardé). */
function subsetCff(f, gids) {
  const list = [0, ...[...new Set(gids)].filter((g) => g > 0 && g < f.cs.count).sort((a, b) => a - b)];
  const csItems = list.map((g) => f.cs.get(g));
  const charset = Buffer.alloc(1 + 2 * (list.length - 1));
  charset[0] = 0;
  list.slice(1).forEach((g, i) => charset.writeUInt16BE(f.cidOf[g], 1 + 2 * i));
  const fdselect = Buffer.alloc(1 + list.length);
  fdselect[0] = 0;
  list.forEach((g, i) => { fdselect[1 + i] = f.fdOf[g]; });
  const csIndex = buildIndex(csItems);
  const usedFd = new Set(list.map((g) => f.fdOf[g]));
  const callMap = usedSubrs(f, list);
  const privs = f.fds.map((x0, fdi) => {
    // FD jamais utilisé : Private minimal sans sous-routines (index FD inchangés).
    // FD utilisé : toutes les sous-routines gardent leur numéro, celles qui ne
    // sont jamais appelées sont vidées (un simple « return »).
    let x;
    if (!usedFd.has(fdi) || !x0.subrsIx) x = { ...x0, priv: x0.priv.filter((e) => e.op !== 19), subrs: null };
    else {
      const keep = callMap.get(fdi) || new Set();
      const items = [];
      for (let k = 0; k < x0.subrsIx.count; k += 1) items.push(keep.has(k) ? x0.subrsIx.get(k) : Buffer.from([11]));
      x = { ...x0, subrs: buildIndex(items) };
    }
    const pd = encodeDict(x.priv, { 19: () => int5(0) });
    const size = pd.length;
    const pdFixed = encodeDict(x.priv, { 19: () => int5(size) });
    return Buffer.concat([pdFixed, x.subrs || Buffer.alloc(0)]).length ? { dict: pdFixed, size, subrs: x.subrs } : null;
  });

  const header = Buffer.from([1, 0, 4, 4]);
  const name = f.cff.subarray(f.nameIdx.start, f.nameIdx.end);
  const strings = f.cff.subarray(f.strIdx.start, f.strIdx.end);
  const gsubrs = f.cff.subarray(f.gsubIdx.start, f.gsubIdx.end);
  // CIDCount doit rester celui d'origine (les CID gardent leur valeur).
  const topEntries = f.top.map((e) => (e.op === 1234 ? { ...e, keep: true } : e));
  const encodeTop = (o) => encodeDict(topEntries, {
    15: () => int5(o.charset), 17: () => int5(o.cs), 1237: () => int5(o.fdselect), 1236: () => int5(o.fdarray),
  });
  const topLen = buildIndex([encodeTop({ charset: 0, cs: 0, fdselect: 0, fdarray: 0 })]).length;
  let pos = header.length + name.length + topLen + strings.length + gsubrs.length;
  const o = {};
  o.charset = pos; pos += charset.length;
  o.fdselect = pos; pos += fdselect.length;
  o.cs = pos; pos += csIndex.length;
  // FDArray : dicts réencodés avec Private (taille, offset) sur 5 octets.
  const fdDictLen = f.fds.map((x) => encodeDict(x.fd, { 18: () => Buffer.concat([int5(0), int5(0)]) }).length);
  const fdIndexLen = buildIndex(fdDictLen.map((l) => Buffer.alloc(l))).length;
  o.fdarray = pos; pos += fdIndexLen;
  const privOffs = privs.map((p) => { const at = pos; pos += p.dict.length + (p.subrs ? p.subrs.length : 0); return at; });
  const fdIndex = buildIndex(f.fds.map((x, i) => encodeDict(x.fd, {
    18: () => Buffer.concat([int5(privs[i].size), int5(privOffs[i])]),
  })));
  const topIndex = buildIndex([encodeTop(o)]);
  const out = Buffer.concat([
    header, name, topIndex, strings, gsubrs, charset, fdselect, csIndex, fdIndex,
    ...privs.map((p) => Buffer.concat([p.dict, p.subrs || Buffer.alloc(0)])),
  ]);
  if (topIndex.length !== topLen || fdIndex.length !== fdIndexLen) throw new Error('CFF : tailles incohérentes');
  return out;
}


// ── TrueType (Inter, police de l'app, OFL) : latin étendu ──────────────────
const _ttf = {};
function loadTtf(file) {
  if (_ttf[file]) return _ttf[file];
  const b = fs.readFileSync(path.join(__dirname, '..', 'assets', 'fonts', file));
  const n = b.readUInt16BE(4);
  const t = {};
  for (let i = 0; i < n; i += 1) {
    const o = 12 + 16 * i;
    t[b.toString('latin1', o, o + 4)] = { off: b.readUInt32BE(o + 8), len: b.readUInt32BE(o + 12) };
  }
  const tab = (k) => (t[k] ? b.subarray(t[k].off, t[k].off + t[k].len) : null);
  const head = tab('head');
  const unitsPerEm = head.readUInt16BE(18);
  const longLoca = head.readInt16BE(50) === 1;
  const numGlyphs = tab('maxp').readUInt16BE(4);
  const hhea = tab('hhea');
  const numHMetrics = hhea.readUInt16BE(34);
  const loca = tab('loca'); const glyf = tab('glyf'); const hmtx = tab('hmtx');
  const locOf = (g) => (longLoca ? loca.readUInt32BE(4 * g) : loca.readUInt16BE(2 * g) * 2);
  const advance = (g) => hmtx.readUInt16BE(4 * Math.min(g, numHMetrics - 1));
  // cmap format 4 (3/1) ou 12 (3/10), même logique que pour la police CJK.
  const cm = t.cmap.off; const nsub = b.readUInt16BE(cm + 2);
  let sub12 = null; let sub4 = null;
  for (let i = 0; i < nsub; i += 1) {
    const pid = b.readUInt16BE(cm + 4 + 8 * i); const eid = b.readUInt16BE(cm + 6 + 8 * i);
    const so = cm + b.readUInt32BE(cm + 8 + 8 * i); const fmt = b.readUInt16BE(so);
    if (fmt === 12 && pid === 3 && eid === 10) sub12 = so;
    if (fmt === 4 && pid === 3 && eid === 1) sub4 = so;
  }
  const glyphOf = cmapLookup(b, sub12, sub4);
  _ttf[file] = {
    b, t, tab, unitsPerEm, numGlyphs, locOf, glyf, advance, glyphOf,
    ascender: hhea.readInt16BE(4), descender: hhea.readInt16BE(6),
    bbox: [head.readInt16BE(36), head.readInt16BE(38), head.readInt16BE(40), head.readInt16BE(42)],
  };
  return _ttf[file];
}

function checksum(buf) {
  const p = Buffer.concat([buf, Buffer.alloc((4 - (buf.length % 4)) % 4)]);
  let s = 0;
  for (let i = 0; i < p.length; i += 4) s = (s + p.readUInt32BE(i)) >>> 0;
  return s;
}

/** TrueType réduit aux glyphes utilisés (+ composants), numéros de glyphes inchangés. */
function subsetTtf(f, gids) {
  const keep = new Set([0, ...gids]);
  const todo = [...keep];
  while (todo.length) {
    const g = todo.pop();
    const a = f.locOf(g); const z = f.locOf(g + 1);
    if (z - a < 10 || f.glyf.readInt16BE(a) >= 0) continue;
    let p = a + 10; let flags;
    do {
      flags = f.glyf.readUInt16BE(p); const comp = f.glyf.readUInt16BE(p + 2);
      if (!keep.has(comp)) { keep.add(comp); todo.push(comp); }
      p += 4 + ((flags & 1) ? 4 : 2);
      if (flags & 8) p += 2; else if (flags & 0x40) p += 4; else if (flags & 0x80) p += 8;
    } while (flags & 0x20);
  }
  const parts = []; const loca = Buffer.alloc(4 * (f.numGlyphs + 1)); let off = 0;
  for (let g = 0; g < f.numGlyphs; g += 1) {
    loca.writeUInt32BE(off, 4 * g);
    if (keep.has(g)) {
      const d = f.glyf.subarray(f.locOf(g), f.locOf(g + 1));
      const pad = Buffer.alloc((4 - (d.length % 4)) % 4);
      parts.push(d, pad); off += d.length + pad.length;
    }
  }
  loca.writeUInt32BE(off, 4 * f.numGlyphs);
  const head = Buffer.from(f.tab('head'));
  head.writeUInt32BE(0, 8); head.writeInt16BE(1, 50);
  const tables = { head, hhea: f.tab('hhea'), hmtx: f.tab('hmtx'), maxp: f.tab('maxp'), loca, glyf: Buffer.concat(parts) };
  for (const k of ['cvt ', 'fpgm', 'prep']) if (f.tab(k)) tables[k] = f.tab(k);
  const names = Object.keys(tables).sort();
  const dir = Buffer.alloc(12 + 16 * names.length);
  dir.writeUInt32BE(0x00010000, 0); dir.writeUInt16BE(names.length, 4);
  let pos = dir.length; const bodies = [];
  names.forEach((k, i) => {
    const d = tables[k]; const o = 12 + 16 * i;
    dir.write(k, o, 'latin1'); dir.writeUInt32BE(checksum(d), o + 4);
    dir.writeUInt32BE(pos, o + 8); dir.writeUInt32BE(d.length, o + 12);
    const pad = Buffer.alloc((4 - (d.length % 4)) % 4);
    bodies.push(d, pad); pos += d.length + pad.length;
  });
  const out = Buffer.concat([dir, ...bodies]);
  const headPos = dir.readUInt32BE(12 + 16 * names.indexOf('head') + 8);
  out.writeUInt32BE((0xb1b0afba - checksum(out)) >>> 0, headPos + 8);
  return out;
}

/**
 * Prépare une police pour un PDF.
 *   kind 'cjk'            → Noto Sans CJK (CFF, CIDFontType0)
 *   kind 'Inter-Regular.ttf' / 'Inter-Bold.ttf' → TrueType (CIDFontType2)
 * `has(texte)`, `width(texte, taille)`, `hex(texte)` (codes Identity-H) et
 * `objects(premierId)` → 5 objets PDF (Type0, CIDFont, descripteur, fichier, ToUnicode).
 */
function createPdfFont(kind = 'cjk', tag = 'HPSAAA') {
  const isCjk = kind === 'cjk';
  const f = isCjk ? loadFont() : loadTtf(kind);
  const cidOf = (g) => (isCjk ? f.cidOf[g] : g);
  const used = new Map(); // gid → caractère
  const k = 1000 / f.unitsPerEm;
  const glyphs = (s) => {
    const out = [];
    for (const ch of String(s || '')) {
      const cp = ch.codePointAt(0);
      if (cp < 0x20) continue;
      const g = f.glyphOf(cp);
      if (!g) continue; // absent de la police : sauté (has() permet d'éviter ce cas)
      if (!used.has(g)) used.set(g, ch);
      out.push(g);
    }
    return out;
  };
  const baseName = isCjk ? 'NotoSansCJK-Regular' : kind.replace(/\.ttf$/, '');
  return {
    kind,
    has: (s) => [...String(s || '')].every((ch) => ch.codePointAt(0) < 0x20 || f.glyphOf(ch.codePointAt(0)) > 0),
    width: (s, size) => glyphs(s).reduce((w, g) => w + f.advance(g) * k, 0) * size / 1000,
    hex: (s) => `<${glyphs(s).map((g) => cidOf(g).toString(16).padStart(4, '0')).join('')}>`,
    get usedCount() { return used.size; },
    objects(firstId) {
      const gids = [...used.keys()];
      const raw = isCjk ? subsetCff(f, gids) : subsetTtf(f, gids);
      const ff = zlib.deflateSync(raw);
      const idCid = firstId + 1; const idDesc = firstId + 2; const idFile = firstId + 3; const idToU = firstId + 4;
      const entries = gids.map((g) => ({ g, cid: cidOf(g), ch: used.get(g) })).sort((x, y) => x.cid - y.cid);
      const widths = entries.map((e) => `${e.cid} [${Math.round(f.advance(e.g) * k)}]`).join(' ');
      const hex4 = (n) => n.toString(16).padStart(4, '0');
      const u16 = (t) => Buffer.from(t, 'utf16le').swap16().toString('hex');
      const bf = entries.map((e) => `<${hex4(e.cid)}> <${u16(e.ch)}>`);
      const chunks = [];
      for (let i = 0; i < bf.length; i += 100) chunks.push(`${Math.min(100, bf.length - i)} beginbfchar\n${bf.slice(i, i + 100).join('\n')}\nendbfchar`);
      const cmap = Buffer.from(`/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def\n/CMapName /Adobe-Identity-UCS def\n/CMapType 2 def\n1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n${chunks.join('\n')}\nendcmap\nCMapName currentdict /CMap defineresource pop\nend\nend`, 'latin1');
      const base = `${tag}+${baseName}`;
      const bb = f.bbox.map((v) => Math.round(v * k)).join(' ');
      const sysInfo = isCjk
        ? `<< /Registry (${f.registry}) /Ordering (${f.ordering}) /Supplement ${f.supplement} >>`
        : '<< /Registry (Adobe) /Ordering (Identity) /Supplement 0 >>';
      const cidFont = isCjk
        ? `<< /Type /Font /Subtype /CIDFontType0 /BaseFont /${base} /CIDSystemInfo ${sysInfo} /FontDescriptor ${idDesc} 0 R /DW 1000 /W [${widths}] >>`
        : `<< /Type /Font /Subtype /CIDFontType2 /BaseFont /${base} /CIDSystemInfo ${sysInfo} /FontDescriptor ${idDesc} 0 R /DW 1000 /W [${widths}] /CIDToGIDMap /Identity >>`;
      const fileDict = isCjk
        ? `<< /Subtype /CIDFontType0C /Filter /FlateDecode /Length ${ff.length} >>`
        : `<< /Filter /FlateDecode /Length ${ff.length} /Length1 ${raw.length} >>`;
      return [
        Buffer.from(`<< /Type /Font /Subtype /Type0 /BaseFont /${base} /Encoding /Identity-H /DescendantFonts [${idCid} 0 R] /ToUnicode ${idToU} 0 R >>`),
        Buffer.from(cidFont),
        Buffer.from(`<< /Type /FontDescriptor /FontName /${base} /Flags 32 /FontBBox [${bb}] /ItalicAngle 0 /Ascent ${Math.round(f.ascender * k)} /Descent ${Math.round(f.descender * k)} /CapHeight 700 /StemV 80 /${isCjk ? 'FontFile3' : 'FontFile2'} ${idFile} 0 R >>`),
        Buffer.concat([Buffer.from(`${fileDict}\nstream\n`), ff, Buffer.from('\nendstream')]),
        Buffer.concat([Buffer.from(`<< /Length ${cmap.length} >>\nstream\n`), cmap, Buffer.from('\nendstream')]),
      ];
    },
  };
}

module.exports = { createPdfFont, loadFont, loadTtf, subsetCff, subsetTtf, FONT_PATH };
