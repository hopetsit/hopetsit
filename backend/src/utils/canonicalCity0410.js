/**
 * 04/10/2026 (ZOE, mission BOB) — UNE VILLE = UN NOM, quelle que soit la
 * langue du téléphone.
 *
 * Relevé du 04/10 : la première vraie demande (propriétaire italien, Paris
 * 11e) est enregistrée avec la ville « Parigi ». Depuis le 610, la ville se
 * choisit dans une liste OpenStreetMap interrogée DANS LA LANGUE DE L'APP
 * (`accept-language`), et le géocodage inverse du téléphone répond lui aussi
 * dans la langue de l'appareil. Résultat : « Parigi », « París », « Paryż »,
 * « パリ »… pour la même ville.
 *
 * Mesuré le 04/10 sur Photon (le géocodeur du serveur) :
 *   « Parigi »     → Parigi, INDONÉSIE      « Londra »    → Leonora, AUSTRALIE
 *   « Marsiglia »  → Marigliano (Naples)    « Nizza »     → Nizza Monferrato
 *   « Paryż »      → Pariz, IRAN            « パリ », « 파리 », « Nueva York » → rien
 * Une demande sans coordonnées partait donc à l'autre bout du monde (personne
 * prévenu, annonce posée en Indonésie), les peluches tiraient une « ville »
 * Parigi distincte de Paris, et les compteurs « N gardiens à <ville> » et les
 * stats par ville se coupaient en deux.
 *
 * Règle : on ramène les noms étrangers (exonymes) des villes où l'app vit au
 * nom LOCAL officiel (endonyme : Paris, London, Milano, München…). Les 9
 * langues de l'app (en fr es de it pt ko ja pl) + néerlandais.
 *
 * Garde-fou : quand des coordonnées accompagnent le nom et qu'elles sont à
 * plus de 80 km du centre de la ville visée, on NE renomme PAS (c'est un autre
 * lieu du même nom : Parigi en Indonésie, Colonia en Uruguay…). Un nom absent
 * du dictionnaire n'est jamais modifié.
 */

// canonique → { c: [lat, lng], n: [exonymes] }
const VILLES = {
  Paris: { c: [48.8566, 2.3522], n: ['Parigi', 'París', 'Paryż', 'Parijs', 'Paris (France)', 'パリ', '파리', '巴黎', 'Париж'] },
  Lyon: { c: [45.764, 4.8357], n: ['Lione', 'Lión', 'Lyons', 'Lugdunum', 'リヨン', '리옹'] },
  Marseille: { c: [43.2965, 5.3698], n: ['Marsiglia', 'Marsella', 'Marsylia', 'Marselha', 'Marseilles', 'Marseille (France)', 'マルセイユ', '마르세유'] },
  Nice: { c: [43.7102, 7.262], n: ['Nizza', 'Niza', 'Nicea', 'ニース', '니스'] },
  Toulouse: { c: [43.6047, 1.4442], n: ['Tuluza', 'トゥールーズ', '툴루즈'] },
  Bordeaux: { c: [44.8378, -0.5792], n: ['Burdeos', 'Bordeus', 'ボルドー', '보르도'] },
  Strasbourg: { c: [48.5734, 7.7521], n: ['Strasburgo', 'Estrasburgo', 'Straßburg', 'Strassburg', 'Strasburgo (Francia)', 'ストラスブール', '스트라스부르'] },
  Lille: { c: [50.6292, 3.0573], n: ['Rijsel', 'リール', '릴'] },
  Nantes: { c: [47.2184, -1.5536], n: ['ナント', '낭트'] },
  Montpellier: { c: [43.6108, 3.8767], n: ['モンペリエ', '몽펠리에'] },
  London: { c: [51.5074, -0.1278], n: ['Londres', 'Londra', 'Londyn', 'Londen', 'ロンドン', '런던', '伦敦'] },
  Milano: { c: [45.4642, 9.19], n: ['Milan', 'Milán', 'Mailand', 'Mediolan', 'Milão', 'Milaan', 'ミラノ', '밀라노'] },
  Roma: { c: [41.9028, 12.4964], n: ['Rome', 'Rom', 'Rzym', 'ローマ', '로마'] },
  Venezia: { c: [45.4408, 12.3155], n: ['Venise', 'Venice', 'Venecia', 'Venedig', 'Wenecja', 'Veneza', 'Venetië', 'ヴェネツィア', 'ベネチア', '베네치아'] },
  Firenze: { c: [43.7696, 11.2558], n: ['Florence', 'Florencia', 'Florenz', 'Florencja', 'Florença', 'フィレンツェ', '피렌체'] },
  Napoli: { c: [40.8518, 14.2681], n: ['Naples', 'Nápoles', 'Neapel', 'Neapol', 'Napels', 'ナポリ', '나폴리'] },
  Torino: { c: [45.0703, 7.6869], n: ['Turin', 'Turín', 'Turyn', 'Turijn', 'トリノ', '토리노'] },
  'München': { c: [48.1351, 11.582], n: ['Munich', 'Múnich', 'Monaco di Baviera', 'Monachium', 'Munique', 'Muenchen', 'ミュンヘン', '뮌헨'] },
  'Köln': { c: [50.9375, 6.9603], n: ['Cologne', 'Colonia', 'Kolonia', 'Keulen', 'Colónia', 'Koeln', 'ケルン', '쾰른'] },
  Wien: { c: [48.2082, 16.3738], n: ['Vienna', 'Viena', 'Wiedeń', 'Wenen', 'ウィーン', '빈 (오스트리아)'] },
  Berlin: { c: [52.52, 13.405], n: ['Berlino', 'Berlín', 'Berlim', 'ベルリン', '베를린'] },
  Bruxelles: { c: [50.8503, 4.3517], n: ['Brussels', 'Bruselas', 'Bruxelas', 'Brüssel', 'Bruksela', 'Brussel', 'ブリュッセル', '브뤼셀'] },
  'Genève': { c: [46.2044, 6.1432], n: ['Geneva', 'Ginevra', 'Ginebra', 'Genf', 'Genewa', 'Genebra', 'ジュネーブ', 'ジュネーヴ', '제네바'] },
  Lisboa: { c: [38.7223, -9.1393], n: ['Lisbon', 'Lisbonne', 'Lissabon', 'Lisbona', 'Lizbona', 'リスボン', '리스본'] },
  Warszawa: { c: [52.2297, 21.0122], n: ['Warsaw', 'Varsovie', 'Varsovia', 'Warschau', 'Varsavia', 'Varsóvia', 'ワルシャワ', '바르샤바'] },
  'Kraków': { c: [50.0647, 19.945], n: ['Cracovie', 'Cracow', 'Krakow', 'Cracovia', 'Krakau', 'Cracóvia', 'クラクフ', '크라쿠프'] },
  Barcelona: { c: [41.3874, 2.1686], n: ['Barcelone', 'Barcellona', 'バルセロナ', '바르셀로나'] },
  Sevilla: { c: [37.3891, -5.9845], n: ['Séville', 'Seville', 'Siviglia', 'Sewilla', 'Sevilha', 'セビリア', '세비야'] },
  Madrid: { c: [40.4168, -3.7038], n: ['Madryt', 'マドリード', '마드리드'] },
  'New York': { c: [40.7128, -74.006], n: ['New York City', 'NYC', 'Nueva York', 'Nova Iorque', 'Nova York', 'Nowy Jork', 'New-York', 'ニューヨーク', '뉴욕', '纽约'] },
  Dallas: { c: [32.7767, -96.797], n: ['ダラス', '댈러스'] },
  'Los Angeles': { c: [34.0522, -118.2437], n: ['Los Ángeles', 'ロサンゼルス', '로스앤젤레스'] },
  'San Francisco': { c: [37.7749, -122.4194], n: ['San Francisco (CA)', 'サンフランシスコ', '샌프란시스코'] },
};

const MAX_KM = 80;

/** « Paryż » → « paryz », « Straßburg » → « strassburg », espaces/tirets réduits. */
function cityKeyOf(s) {
  return String(s || '')
    .replace(/ß/g, 'ss')
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[-_'’.]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

const _byKey = new Map();
for (const [canon, v] of Object.entries(VILLES)) {
  _byKey.set(cityKeyOf(canon), canon);
  for (const ex of v.n) _byKey.set(cityKeyOf(ex), canon);
}

function _km(aLat, aLng, bLat, bLng) {
  const r = (x) => (x * Math.PI) / 180;
  const dLat = r(bLat - aLat);
  const dLng = r(bLng - aLng);
  const x = Math.sin(dLat / 2) ** 2 + Math.cos(r(aLat)) * Math.cos(r(bLat)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
}

function _coordsOk(lat, lng) {
  const a = Number(lat);
  const b = Number(lng);
  return Number.isFinite(a) && Number.isFinite(b) && !(a === 0 && b === 0);
}

/**
 * Canonique connu pour ce nom exact (sans complément), ou null. Un nom qui EST
 * déjà la ville locale (« paris », « PARIS », « Paris ») renvoie null : on ne
 * réécrit jamais une graphie correcte, seulement un nom étranger.
 */
const _sameSpelling = (a, b) => String(a).trim().toLowerCase().replace(/\s+/g, ' ')
  === String(b).trim().toLowerCase().replace(/\s+/g, ' ');

function _lookup(name) {
  const canon = _byKey.get(cityKeyOf(name)) || null;
  // « París » (accent espagnol) est renommé ; « paris » ou « PARIS » non.
  if (!canon || _sameSpelling(canon, name)) return null;
  return canon;
}

/**
 * Nom canonique d'une ville. `coords` facultatif : { lat, lng }.
 *   « Parigi »          → « Paris »
 *   « Parigi 11 »       → « Paris 11 »  (arrondissement conservé)
 *   « Parigi, Francia » → « Paris »     (le complément étranger tombe)
 *   « Parigi » + coordonnées en Indonésie → « Parigi » (autre lieu, inchangé)
 *   « Boulogne-Billancourt », « Paris 15e », « Zone test » → inchangés
 * Jamais d'erreur : une valeur non texte est renvoyée telle quelle.
 */
function canonicalCityName(city, coords) {
  if (typeof city !== 'string') return city;
  const raw = city.trim();
  if (!raw) return city;

  let canon = null;
  let suffix = '';
  canon = _lookup(raw);
  if (!canon) {
    // « Parigi 11 », « Parigi 11° » : l'arrondissement suit le nom.
    const m = raw.match(/^(.*?\S)\s+(\d{1,5}\s*\S{0,4})$/);
    if (m && _lookup(m[1])) { canon = _lookup(m[1]); suffix = ` ${m[2].trim()}`; }
  }
  if (!canon) {
    // « Parigi, Francia », « Parigi (Île-de-France) »
    const head = raw.split(/[(,/]/)[0].trim();
    if (head && head !== raw && _lookup(head)) canon = _lookup(head);
  }
  if (!canon) return city;

  if (coords && _coordsOk(coords.lat, coords.lng)) {
    const [cLat, cLng] = VILLES[canon].c;
    if (_km(Number(coords.lat), Number(coords.lng), cLat, cLng) > MAX_KM) return city;
  }
  const out = `${canon}${suffix}`;
  return out === raw ? city : out;
}

/** Ce nom est-il un exonyme connu (donc à renommer) ? */
function isNonCanonicalCity(city, coords) {
  if (typeof city !== 'string' || !city.trim()) return false;
  return canonicalCityName(city, coords) !== city;
}

/** Coordonnées lisibles d'un objet location ({lat,lng} ou GeoJSON). */
function coordsOfLocation(loc) {
  if (!loc || typeof loc !== 'object') return null;
  if (_coordsOk(loc.lat, loc.lng)) return { lat: Number(loc.lat), lng: Number(loc.lng) };
  const c = loc.coordinates;
  if (Array.isArray(c) && c.length >= 2 && _coordsOk(c[1], c[0])) return { lat: Number(c[1]), lng: Number(c[0]) };
  return null;
}

module.exports = {
  canonicalCityName,
  isNonCanonicalCity,
  coordsOfLocation,
  cityKeyOf,
  CANONICAL_CITIES: VILLES,
};
