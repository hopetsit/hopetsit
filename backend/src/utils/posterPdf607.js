'use strict';

/**
 * 607 (NEO, 02/10/2026) — AFFICHE A4 « RÉSERVE-MOI ICI » d'un gardien ou
 * d'un promeneur : nom, photo, QR vers hopetsit.com/s/<slug>, 3 lignes.
 *
 * L'outil `~/hopetsit-social/affiche_commerce.py` (reportlab + qrcode) n'est
 * pas portable sur le serveur Node (pas de Python sur Render) : même charte
 * (orange #C92A12, encre #17141F), mais PDF écrit à la main ici, sans aucune
 * dépendance. Photo JPEG insérée telle quelle (DCTDecode), QR en vecteurs.
 *
 * 02/10 (Daniel : « impeccable ») — polices EMBARQUÉES (sous-ensembles, licence
 * OFL, utils/cidFont607.js) : Inter (la police de l'app) pour le latin, y
 * compris ą ę ł ś ż ; Noto Sans CJK pour le japonais et le coréen. Les 9
 * langues de l'app ont leur affiche dans leur langue, noms et villes compris.
 */
const { encodeQr } = require('./qr607');

const ORANGE = [0xc9 / 255, 0x2a / 255, 0x12 / 255];
const INK = [0x17 / 255, 0x14 / 255, 0x1f / 255];
const MUTED = [0x6b / 255, 0x6b / 255, 0x6b / 255];
const SOFT = [0xfb / 255, 0xe9 / 255, 0xe5 / 255];

const TXT = {
  fr: {
    sitter: 'Garde d\'animaux', walker: 'Promenade de chiens',
    l1: 'Je garde maintenant les animaux via HoPetSit.',
    l1w: 'Je promène maintenant les chiens via HoPetSit.',
    l2: 'Paiement sécurisé, suivi en direct, avis vérifiés.',
    l3: 'Scannez le QR code pour me réserver.',
    foot: 'HoPetSit - application gratuite sur iOS et Android.',
  },
  en: {
    sitter: 'Pet sitting', walker: 'Dog walking',
    l1: 'I now look after pets through HoPetSit.',
    l1w: 'I now walk dogs through HoPetSit.',
    l2: 'Secure payment, live tracking, verified reviews.',
    l3: 'Scan the QR code to book me.',
    foot: 'HoPetSit - free app on iOS and Android.',
  },
  es: {
    sitter: 'Cuidado de mascotas', walker: 'Paseo de perros',
    l1: 'Ahora cuido mascotas a través de HoPetSit.',
    l1w: 'Ahora paseo perros a través de HoPetSit.',
    l2: 'Pago seguro, seguimiento en directo, reseñas verificadas.',
    l3: 'Escanea el código QR para reservarme.',
    foot: 'HoPetSit - app gratuita en iOS y Android.',
  },
  de: {
    sitter: 'Tierbetreuung', walker: 'Gassi-Service',
    l1: 'Ich betreue jetzt Tiere über HoPetSit.',
    l1w: 'Ich gehe jetzt über HoPetSit mit Hunden Gassi.',
    l2: 'Sichere Zahlung, Live-Verfolgung, echte Bewertungen.',
    l3: 'QR-Code scannen und mich buchen.',
    foot: 'HoPetSit - kostenlose App für iOS und Android.',
  },
  it: {
    sitter: 'Pet sitting', walker: 'Passeggiate per cani',
    l1: 'Ora mi occupo di animali tramite HoPetSit.',
    l1w: 'Ora porto a spasso i cani tramite HoPetSit.',
    l2: 'Pagamento sicuro, tracciamento in diretta, recensioni verificate.',
    l3: 'Scansiona il codice QR per prenotarmi.',
    foot: 'HoPetSit - app gratuita su iOS e Android.',
  },
  pt: {
    sitter: 'Pet sitting', walker: 'Passeios de cães',
    l1: 'Agora cuido de animais através da HoPetSit.',
    l1w: 'Agora passeio cães através da HoPetSit.',
    l2: 'Pagamento seguro, acompanhamento em direto, avaliações verificadas.',
    l3: 'Lê o código QR para me reservares.',
    foot: 'HoPetSit - app gratuita no iOS e Android.',
  },
  pl: {
    sitter: 'Opieka nad zwierzętami', walker: 'Spacery z psami',
    l1: 'Teraz opiekuję się zwierzętami przez HoPetSit.',
    l1w: 'Teraz wyprowadzam psy przez HoPetSit.',
    l2: 'Bezpieczna płatność, śledzenie na żywo, prawdziwe opinie.',
    l3: 'Zeskanuj kod QR, aby mnie zarezerwować.',
    foot: 'HoPetSit - darmowa aplikacja na iOS i Android.',
  },
  ja: {
    sitter: 'ペットシッター', walker: 'ドッグウォーキング',
    l1: 'HoPetSitでペットのお世話を始めました。',
    l1w: 'HoPetSitで犬の散歩を始めました。',
    l2: '安全なお支払い、リアルタイムで様子を確認、本物のレビュー。',
    l3: 'QRコードを読み取ってご予約ください。',
    foot: 'HoPetSit - iOS・Android対応の無料アプリ。',
  },
  ko: {
    sitter: '펫시팅', walker: '강아지 산책',
    l1: '이제 HoPetSit에서 반려동물을 돌봐요.',
    l1w: '이제 HoPetSit에서 강아지 산책을 해요.',
    l2: '안전한 결제, 실시간 확인, 진짜 후기.',
    l3: 'QR 코드를 스캔해 예약하세요.',
    foot: 'HoPetSit - iOS와 Android 무료 앱.',
  },
};

function posterLang(lang) {
  const l = String(lang || '').slice(0, 2).toLowerCase();
  return TXT[l] ? l : 'en';
}

// ── Texte : polices embarquées (cidFont607) ───────────────────────────────
const { createPdfFont } = require('./cidFont607');

/**
 * Jeu de polices d'UNE affiche. Chaque texte est découpé en tronçons : Inter
 * quand il a le caractère (tout le latin, ą ę ł ś ż compris), sinon Noto Sans
 * CJK (kana, kanji, hangeul). Gras CJK : contour + remplissage (la police CJK
 * embarquée n'a qu'une graisse).
 */
function makeFonts() {
  const fonts = {
    F1: createPdfFont('Inter-Regular.ttf', 'HPSREG'),
    F2: createPdfFont('Inter-Bold.ttf', 'HPSBLD'),
    F3: createPdfFont('cjk', 'HPSCJK'),
  };
  const runs = (s, bold) => {
    const latin = bold ? 'F2' : 'F1';
    const out = [];
    for (const ch of String(s || '')) {
      const key = fonts[latin].has(ch) ? latin : (fonts.F3.has(ch) ? 'F3' : null);
      if (!key) continue; // absent des deux polices : sauté, jamais de carré vide
      const last = out[out.length - 1];
      if (last && last.key === key) last.text += ch; else out.push({ key, text: ch });
    }
    return out;
  };
  const width = (s, size, bold) => runs(s, bold).reduce((w, r) => w + fonts[r.key].width(r.text, size), 0);
  return { fonts, runs, width };
}

/** Reste-t-il quelque chose de lisible ? (nom/ville sans aucun glyphe → '') */
function printable(F, s) {
  const t = String(s || '').trim();
  const shown = F.runs(t, false).map((r) => r.text).join('').replace(/[\s.\-']/g, '');
  return shown.length >= 1 ? t : '';
}

/** Coupe en lignes : par mots, puis par caractères (japonais, sans espaces). */
function wrap(F, text, size, bold, maxW) {
  const words = String(text || '').split(/\s+/).filter(Boolean);
  const lines = [];
  let cur = '';
  const push = (w) => {
    const t = cur ? `${cur} ${w}` : w;
    if (F.width(t, size, bold) <= maxW) { cur = t; return; }
    if (cur) { lines.push(cur); cur = ''; }
    if (F.width(w, size, bold) <= maxW) { cur = w; return; }
    let part = '';
    for (const ch of w) {
      if (F.width(part + ch, size, bold) > maxW && part) { lines.push(part); part = ch; } else part += ch;
    }
    cur = part;
  };
  words.forEach(push);
  if (cur) lines.push(cur);
  return lines;
}

// ── JPEG : dimensions et nombre de composantes (marqueur SOF) ──────────────
function jpegInfo(buf) {
  if (!Buffer.isBuffer(buf) || buf.length < 4 || buf[0] !== 0xff || buf[1] !== 0xd8) return null;
  let i = 2;
  while (i + 9 < buf.length) {
    if (buf[i] !== 0xff) { i += 1; continue; }
    const marker = buf[i + 1];
    if (marker === 0xd8 || marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) { i += 2; continue; }
    const len = buf.readUInt16BE(i + 2);
    if ((marker >= 0xc0 && marker <= 0xc3) || (marker >= 0xc5 && marker <= 0xc7) || (marker >= 0xc9 && marker <= 0xcb) || (marker >= 0xcd && marker <= 0xcf)) {
      return { height: buf.readUInt16BE(i + 5), width: buf.readUInt16BE(i + 7), components: buf[i + 9] };
    }
    i += 2 + len;
  }
  return null;
}

/**
 * @param {object} p
 * @param {string} p.name      « Sasha B. »
 * @param {'sitter'|'walker'} p.role
 * @param {string} p.city
 * @param {string} p.url       lien complet hopetsit.com/s/<slug>
 * @param {Buffer|null} [p.photoJpeg]
 * @param {string} [p.lang]
 * @returns {Buffer} PDF
 */
function buildPosterPdf({ name, role, city, url, photoJpeg = null, lang = 'fr' }) {
  const T = TXT[posterLang(lang)];
  const F = makeFonts();
  const W = 595.28; const H = 841.89;
  const ops = [];
  const rgb = (c, stroke = false) => `${c.map((v) => v.toFixed(3)).join(' ')} ${stroke ? 'RG' : 'rg'}`;
  const text = (s, x, y, size, bold, color) => {
    let cx = x;
    for (const r of F.runs(s, bold)) {
      const font = F.fonts[r.key];
      const fake = bold && r.key === 'F3' ? ` 2 Tr ${rgb(color, true)} ${(size * 0.035).toFixed(2)} w` : ' 0 Tr';
      ops.push(`BT ${rgb(color)}${fake} /${r.key} ${size} Tf ${cx.toFixed(2)} ${y.toFixed(2)} Td ${font.hex(r.text)} Tj ET`);
      cx += font.width(r.text, size);
    }
  };
  const centered = (s, y, size, bold, color) => {
    text(s, (W - F.width(s, size, bold)) / 2, y, size, bold, color);
  };

  // Fond blanc + bandeau orange.
  ops.push(`1 1 1 rg 0 0 ${W} ${H} re f`);
  const bandH = 250;
  ops.push(`${rgb(ORANGE)} 0 ${H - bandH} ${W} ${bandH} re f`);
  text('HoPetSit', 40, H - 52, 22, true, [1, 1, 1]);

  // Photo ronde (si JPEG lisible), sinon un rond clair avec l'initiale.
  const info = photoJpeg ? jpegInfo(photoJpeg) : null;
  const usePhoto = !!(info && (info.components === 1 || info.components === 3));
  const r = 70; const cx = 40 + r; const cy = H - 150;
  const circ = (rad) => {
    const k = 0.5523 * rad;
    return `${cx + rad} ${cy} m ${cx + rad} ${cy + k} ${cx + k} ${cy + rad} ${cx} ${cy + rad} c `
      + `${cx - k} ${cy + rad} ${cx - rad} ${cy + k} ${cx - rad} ${cy} c `
      + `${cx - rad} ${cy - k} ${cx - k} ${cy - rad} ${cx} ${cy - rad} c `
      + `${cx + k} ${cy - rad} ${cx + rad} ${cy - k} ${cx + rad} ${cy} c`;
  };
  const circle = circ(r);
  ops.push(`q 1 1 1 rg ${circ(r + 4)} f Q`);
  const shownName = printable(F, name) || 'HoPetSit';
  if (usePhoto) {
    const side = 2 * r;
    const scale = Math.max(side / info.width, side / info.height);
    const iw = info.width * scale; const ih = info.height * scale;
    ops.push(`q ${circle} W n ${iw.toFixed(2)} 0 0 ${ih.toFixed(2)} ${(cx - iw / 2).toFixed(2)} ${(cy - ih / 2).toFixed(2)} cm /Im1 Do Q`);
  } else {
    ops.push(`q ${rgb(SOFT)} ${circle} f Q`);
    const initial = Array.from(shownName)[0].toUpperCase();
    text(initial, cx - F.width(initial, 64, true) / 2, cy - 22, 64, true, ORANGE);
  }

  // Nom + rôle + ville, à droite de la photo.
  const tx = cx + r + 28; const maxW = W - tx - 36;
  let shown = shownName;
  let size = 38;
  while (size > 20 && F.width(shown, size, true) > maxW) size -= 2;
  while (F.width(shown, size, true) > maxW && shown.length > 4) shown = `${Array.from(shown).slice(0, -2).join('')}…`;
  text(shown, tx, cy + 18, size, true, [1, 1, 1]);
  const roleLine = [role === 'walker' ? T.walker : T.sitter, printable(F, city)].filter(Boolean).join(' - ');
  wrap(F, roleLine, 16, false, maxW).slice(0, 2).forEach((l, i) => text(l, tx, cy - 12 - i * 20, 16, false, [1, 1, 1]));

  // Les 3 lignes.
  let y = H - bandH - 58;
  for (const [s, sz, bold, col] of [[role === 'walker' ? T.l1w : T.l1, 21, true, INK], [T.l2, 15, false, MUTED], [T.l3, 15, false, MUTED]]) {
    for (const l of wrap(F, s, sz, bold, W - 80)) { centered(l, y, sz, bold, col); y -= sz + 8; }
    y -= 6;
  }

  // QR code (vecteurs), cadre clair autour.
  const qr = encodeQr(url, { ecl: 'M' });
  const qrSide = 250; const quiet = 4;
  const mod = qrSide / (qr.size + 2 * quiet);
  const qx = (W - qrSide) / 2; const qy = y - 20 - qrSide;
  ops.push(`${rgb(SOFT)} ${qx - 12} ${qy - 12} ${qrSide + 24} ${qrSide + 24} re f`);
  ops.push(`1 1 1 rg ${qx} ${qy} ${qrSide} ${qrSide} re f`);
  const rects = [];
  for (let row = 0; row < qr.size; row += 1) {
    for (let col = 0; col < qr.size; col += 1) {
      if (!qr.modules[row][col]) continue;
      const x0 = qx + (col + quiet) * mod;
      const y0 = qy + qrSide - (row + quiet + 1) * mod;
      rects.push(`${x0.toFixed(3)} ${y0.toFixed(3)} ${mod.toFixed(3)} ${mod.toFixed(3)} re`);
    }
  }
  ops.push(`0 0 0 rg ${rects.join(' ')} f`);
  const shortUrl = String(url).replace(/^https?:\/\/(www\.)?/, '');
  centered(shortUrl, qy - 34, 16, true, ORANGE);

  // Pied.
  ops.push(`${rgb(ORANGE)} 0 0 ${W} 6 re f`);
  centered(T.foot, 30, 11, false, MUTED);

  const content = Buffer.from(ops.join('\n'), 'latin1');

  // ── Assemblage des objets PDF ──
  // 1 catalogue, 2 pages, 3 page, 4 contenu, puis 5 objets par police utilisée, puis la photo.
  const usedKeys = Object.keys(F.fonts).filter((k) => F.fonts[k].usedCount > 0);
  const objs = [];
  objs.push(Buffer.from('<< /Type /Catalog /Pages 2 0 R >>'));
  objs.push(Buffer.from('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'));
  const fontIds = {}; let next = 5;
  for (const k of usedKeys) { fontIds[k] = next; next += 5; }
  const imgId = next;
  const fontRes = usedKeys.map((k) => `/${k} ${fontIds[k]} 0 R`).join(' ');
  const xobj = usePhoto ? ` /XObject << /Im1 ${imgId} 0 R >>` : '';
  objs.push(Buffer.from(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${W} ${H}] /Resources << /Font << ${fontRes} >>${xobj} >> /Contents 4 0 R >>`));
  objs.push(Buffer.concat([Buffer.from(`<< /Length ${content.length} >>\nstream\n`), content, Buffer.from('\nendstream')]));
  for (const k of usedKeys) objs.push(...F.fonts[k].objects(fontIds[k]));
  if (usePhoto) {
    const cs = info.components === 1 ? '/DeviceGray' : '/DeviceRGB';
    objs.push(Buffer.concat([
      Buffer.from(`<< /Type /XObject /Subtype /Image /Width ${info.width} /Height ${info.height} /ColorSpace ${cs} /BitsPerComponent 8 /Filter /DCTDecode /Length ${photoJpeg.length} >>\nstream\n`),
      photoJpeg, Buffer.from('\nendstream'),
    ]));
  }
  const parts = [Buffer.from('%PDF-1.6\n%\xE2\xE3\xCF\xD3\n', 'latin1')];
  let offset = parts[0].length;
  const offsets = [];
  objs.forEach((o, i) => {
    const head = Buffer.from(`${i + 1} 0 obj\n`);
    const tail = Buffer.from('\nendobj\n');
    offsets.push(offset);
    parts.push(head, o, tail);
    offset += head.length + o.length + tail.length;
  });
  let xref = `xref\n0 ${objs.length + 1}\n0000000000 65535 f \n`;
  for (const off of offsets) xref += `${String(off).padStart(10, '0')} 00000 n \n`;
  xref += `trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\nstartxref\n${offset}\n%%EOF\n`;
  parts.push(Buffer.from(xref));
  return Buffer.concat(parts);
}

/**
 * Texte d'une page produite par buildPosterPdf, relu DEPUIS LE PDF (codes
 * <hex> Tj traduits par les ToUnicode embarqués) — sert aux tests.
 */
function extractPosterText(pdf) {
  const s = pdf.toString('latin1');
  const objAt = (id) => {
    const m = new RegExp(`(?:^|\\n)${id} 0 obj\\n`).exec(s);
    return m ? s.slice(m.index + m[0].length, s.indexOf('\nendobj', m.index + m[0].length)) : '';
  };
  const page = objAt(3);
  const maps = {};
  for (const m of page.matchAll(/\/(F\d) (\d+) 0 R/g)) {
    const toU = /\/ToUnicode (\d+) 0 R/.exec(objAt(Number(m[2])));
    const cm = objAt(Number(toU[1]));
    const map = {};
    for (const x of cm.matchAll(/<([0-9a-f]{4})> <([0-9a-f]+)>/g)) {
      map[x[1]] = Buffer.from(x[2], 'hex').swap16().toString('utf16le');
    }
    maps[m[1]] = map;
  }
  const content = objAt(4);
  const lines = [];
  let lastY = null;
  for (const m of content.matchAll(/\/(F\d) [\d.]+ Tf [\d.-]+ ([\d.-]+) Td <([0-9a-f]*)> Tj/g)) {
    const str = (m[3].match(/.{4}/g) || []).map((h) => maps[m[1]][h] || '').join('');
    if (lastY === m[2]) lines[lines.length - 1] += str; else lines.push(str);
    lastY = m[2];
  }
  return lines;
}

module.exports = { buildPosterPdf, posterLang, jpegInfo, extractPosterText, TXT };
