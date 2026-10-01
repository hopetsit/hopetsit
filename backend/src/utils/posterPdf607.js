'use strict';

/**
 * 607 (NEO, 02/10/2026) — AFFICHE A4 « RÉSERVE-MOI ICI » d'un gardien ou
 * d'un promeneur : nom, photo, QR vers hopetsit.com/s/<slug>, 3 lignes.
 *
 * L'outil `~/hopetsit-social/affiche_commerce.py` (reportlab + qrcode) n'est
 * pas portable sur le serveur Node (pas de Python sur Render) : même charte
 * (orange #C92A12, encre #17141F), mais PDF écrit à la main ici, sans aucune
 * dépendance — polices standard Helvetica (WinAnsi), photo JPEG insérée
 * telle quelle (DCTDecode), QR dessiné en vecteurs (net à toute taille).
 *
 * Langues : fr en es de it pt pl ; ja et ko reçoivent l'affiche en anglais
 * (les polices standard du PDF n'ont pas leurs caractères). Le polonais perd
 * ses lettres à signe (ą → a) pour la même raison. Un nom sans lettre latine
 * est remplacé par « HoPetSit » + rôle (jamais de carrés vides).
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
};

function posterLang(lang) {
  const l = String(lang || '').slice(0, 2).toLowerCase();
  return TXT[l] ? l : 'en';
}

// ── Texte : WinAnsi (cp1252) + largeurs Helvetica ──────────────────────────
const W_REG = [278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278, 556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556, 1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556, 333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556, 556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584];
const W_BOLD = [278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333, 278, 278, 556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 333, 333, 584, 584, 584, 611, 975, 722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611, 833, 722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 333, 278, 333, 584, 556, 333, 556, 611, 556, 611, 556, 333, 611, 611, 278, 278, 556, 278, 889, 611, 611, 611, 611, 389, 556, 333, 611, 556, 778, 556, 556, 500, 389, 280, 389, 584];

const CP1252_EXTRA = { '€': 0x80, '‚': 0x82, '„': 0x84, '…': 0x85, 'Œ': 0x8c, '‘': 0x91, '’': 0x92, '“': 0x93, '”': 0x94, '•': 0x95, '–': 0x96, '—': 0x97, 'œ': 0x9c, 'Ÿ': 0x9f };

/** Chaîne → octets WinAnsi ; ce qui n'existe pas perd son signe (ą → a) ou disparaît. */
function toWinAnsi(s) {
  const out = [];
  for (const ch of String(s || '')) {
    const c = ch.codePointAt(0);
    if (c >= 0x20 && c <= 0x7e) out.push(c);
    else if (c >= 0xa0 && c <= 0xff) out.push(c);
    else if (CP1252_EXTRA[ch] != null) out.push(CP1252_EXTRA[ch]);
    else {
      const base = ch.normalize('NFD').replace(/[̀-ͯ]/g, '');
      const map = { 'ł': 'l', 'Ł': 'L', 'đ': 'd', 'Đ': 'D', 'ı': 'i' };
      const b = map[ch] || base;
      if (b && b !== ch && b.length === 1 && b.codePointAt(0) < 0x7f) out.push(b.codePointAt(0));
    }
  }
  return out;
}

/** Le texte reste-t-il lisible en WinAnsi ? Sinon '' (nom japonais, ville en coréen…). */
function latinOrEmpty(s) {
  const bytes = toWinAnsi(s);
  const letters = bytes.filter((b) => (b >= 65 && b <= 90) || (b >= 97 && b <= 122) || b >= 0xc0).length;
  const total = Array.from(String(s || '').replace(/[\s.\-']/g, '')).length;
  // Moins de la moitié des lettres survit : on n'affiche pas un nom mutilé.
  if (letters < 2 || letters * 2 < total) return '';
  return String(s || '').trim();
}

function widthOf(bytes, size, bold) {
  const tbl = bold ? W_BOLD : W_REG;
  let w = 0;
  for (const b of bytes) {
    if (b >= 32 && b <= 126) w += tbl[b - 32];
    else if (b >= 0xc0) {
      // Lettre accentuée : même largeur que sa lettre de base.
      const base = String.fromCharCode(b).normalize('NFD').charCodeAt(0);
      w += base >= 32 && base <= 126 ? tbl[base - 32] : 556;
    } else w += b === 0x85 || b === 0x97 ? 1000 : 556;
  }
  return (w * size) / 1000;
}

function pdfStr(bytes) {
  let s = '(';
  for (const b of bytes) {
    if (b === 0x28 || b === 0x29 || b === 0x5c) s += `\\${String.fromCharCode(b)}`;
    else if (b < 0x20 || b > 0x7e) s += `\\${b.toString(8).padStart(3, '0')}`;
    else s += String.fromCharCode(b);
  }
  return `${s})`;
}

/** Coupe un texte en lignes qui tiennent dans `maxW`. */
function wrap(text, size, bold, maxW) {
  const words = String(text || '').split(/\s+/).filter(Boolean);
  const lines = [];
  let cur = '';
  for (const w of words) {
    const t = cur ? `${cur} ${w}` : w;
    if (widthOf(toWinAnsi(t), size, bold) <= maxW || !cur) cur = t;
    else { lines.push(cur); cur = w; }
  }
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
  const W = 595.28; const H = 841.89;
  const ops = [];
  const rgb = (c, stroke = false) => `${c.map((v) => v.toFixed(3)).join(' ')} ${stroke ? 'RG' : 'rg'}`;
  const text = (s, x, y, size, bold, color) => {
    ops.push(`BT ${rgb(color)} /${bold ? 'F2' : 'F1'} ${size} Tf ${x.toFixed(2)} ${y.toFixed(2)} Td ${pdfStr(toWinAnsi(s))} Tj ET`);
  };
  const centered = (s, y, size, bold, color) => {
    const w = widthOf(toWinAnsi(s), size, bold);
    text(s, (W - w) / 2, y, size, bold, color);
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
  // Anneau blanc autour de la photo.
  ops.push(`q 1 1 1 rg ${circ(r + 4)} f Q`);
  if (usePhoto) {
    // Recadrage carré centré : l'image remplit le rond.
    const side = 2 * r;
    const scale = Math.max(side / info.width, side / info.height);
    const iw = info.width * scale; const ih = info.height * scale;
    ops.push(`q ${circle} W n ${iw.toFixed(2)} 0 0 ${ih.toFixed(2)} ${(cx - iw / 2).toFixed(2)} ${(cy - ih / 2).toFixed(2)} cm /Im1 Do Q`);
  } else {
    ops.push(`q ${rgb(SOFT)} ${circle} f Q`);
    const initial = (latinOrEmpty(name)[0] || 'H').toUpperCase();
    const iw = widthOf(toWinAnsi(initial), 64, true);
    text(initial, cx - iw / 2, cy - 22, 64, true, ORANGE);
  }

  // Nom + rôle + ville, à droite de la photo.
  const tx = cx + r + 28; const maxW = W - tx - 36;
  let shown = latinOrEmpty(name) || 'HoPetSit';
  let size = 38;
  while (size > 20 && widthOf(toWinAnsi(shown), size, true) > maxW) size -= 2;
  if (widthOf(toWinAnsi(shown), size, true) > maxW) shown = `${shown.slice(0, 18)}…`;
  text(shown, tx, cy + 18, size, true, [1, 1, 1]);
  const roleLine = [role === 'walker' ? T.walker : T.sitter, latinOrEmpty(city)].filter(Boolean).join(' - ');
  wrap(roleLine, 16, false, maxW).slice(0, 2).forEach((l, i) => text(l, tx, cy - 12 - i * 20, 16, false, [1, 1, 1]));

  // Les 3 lignes.
  let y = H - bandH - 58;
  for (const [s, sz, bold, col] of [[role === 'walker' ? T.l1w : T.l1, 21, true, INK], [T.l2, 15, false, MUTED], [T.l3, 15, false, MUTED]]) {
    for (const l of wrap(s, sz, bold, W - 80)) { centered(l, y, sz, bold, col); y -= sz + 8; }
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
  const objs = [];
  objs.push(Buffer.from('<< /Type /Catalog /Pages 2 0 R >>'));
  objs.push(Buffer.from('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'));
  const xobj = usePhoto ? ' /XObject << /Im1 7 0 R >>' : '';
  objs.push(Buffer.from(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${W} ${H}] /Resources << /Font << /F1 4 0 R /F2 5 0 R >>${xobj} >> /Contents 6 0 R >>`));
  objs.push(Buffer.from('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'));
  objs.push(Buffer.from('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>'));
  objs.push(Buffer.concat([Buffer.from(`<< /Length ${content.length} >>\nstream\n`), content, Buffer.from('\nendstream')]));
  if (usePhoto) {
    const cs = info.components === 1 ? '/DeviceGray' : '/DeviceRGB';
    objs.push(Buffer.concat([
      Buffer.from(`<< /Type /XObject /Subtype /Image /Width ${info.width} /Height ${info.height} /ColorSpace ${cs} /BitsPerComponent 8 /Filter /DCTDecode /Length ${photoJpeg.length} >>\nstream\n`),
      photoJpeg, Buffer.from('\nendstream'),
    ]));
  }
  const parts = [Buffer.from('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n', 'latin1')];
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

module.exports = { buildPosterPdf, posterLang, jpegInfo, toWinAnsi, latinOrEmpty, TXT };
