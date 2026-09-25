// Faux serveur d'API LOCAL (données simulées, aucune donnée réelle) pour
// vérifier les pages connectées du site sans compte ni mot de passe :
// PawMap (contrat serveur v585), réservation, tableau de bord, boutique,
// réservations, messages. Utilisé par scripts/check_buttons.py.
//   node scripts/mock-api.js            (MODE=old : ancien serveur, MOCK_BOOST=1 : mon boost actif)
// MODE=old : ancien serveur (pas de roles/personIds/isFriend, double rôle =
// 2 points superposés sur /members/nearby). MODE=new : contrat 585.
const http = require("http");
const MODE = process.env.MODE || "new";
const PORT = Number(process.env.PORT || 8790);

const P = { lat: 48.8566, lng: 2.3522 };
const at = (dlat, dlng) => [P.lng + dlng, P.lat + dlat]; // [lng, lat]
const av = (n) => `http://localhost:${PORT}/av/${encodeURIComponent(n)}.svg`;

function worldNew() {
  return [
    { id: "s-john", role: "sitter", name: "John C", avatar: av("John C"), location: { coordinates: at(0.004, -0.0146) }, positionSource: "home",
      roles: [{ id: "s-john", role: "sitter", rating: 4.8, reviewsCount: 12, priceFrom: 22, currency: "EUR", isPremium: false }, { id: "o-john", role: "owner", rating: 0, reviewsCount: 0, priceFrom: 0, currency: "EUR", isPremium: false }],
      personIds: ["s-john", "o-john"], isPremium: false, isPawSpot: false, approx: true, approxKm: 1, rating: 4.8, reviewsCount: 12, priceFrom: 22, currency: "EUR", identityVerified: true },
    { id: "s-lea", role: "sitter", name: "Léa Martin", avatar: av("Léa Martin"), location: { coordinates: at(-0.0036, 0.0168) }, positionSource: "home",
      roles: [{ id: "s-lea", role: "sitter", rating: 5, reviewsCount: 3, priceFrom: 20, currency: "EUR", isPremium: true }], personIds: ["s-lea"],
      isPremium: true, isPawSpot: false, approx: true, approxKm: 1, rating: 5, reviewsCount: 3, priceFrom: 20, currency: "EUR", isBoosted: true },
    { id: "w-marc", role: "walker", name: "Marc Dubois", avatar: av("Marc Dubois"), location: { coordinates: at(0.0084, 0.0078) }, positionSource: "city",
      roles: [{ id: "w-marc", role: "walker", rating: 4.6, reviewsCount: 7, priceFrom: 12, currency: "EUR", isPremium: false }, { id: "o-marc", role: "owner", rating: 0, reviewsCount: 0, priceFrom: 0, currency: "EUR", isPremium: false }],
      personIds: ["w-marc", "o-marc"], isFriend: true, isBoosted: true, isPremium: false, isPawSpot: false, approx: true, approxKm: 1, rating: 4.6, reviewsCount: 7, priceFrom: 12, currency: "EUR" },
    { id: "w-ines", role: "walker", name: "Inès Roche", avatar: av("Inès Roche"), location: { coordinates: at(-0.0086, -0.0072) }, positionSource: "home",
      roles: [{ id: "w-ines", role: "walker", rating: 4.9, reviewsCount: 21, priceFrom: 15, currency: "EUR", isPremium: false }], personIds: ["w-ines"],
      isPremium: false, isPawSpot: false, approx: true, approxKm: 1, rating: 4.9, reviewsCount: 21, priceFrom: 15, currency: "EUR" },
    { id: "s-paul", role: "sitter", name: "Paul Petit", avatar: "", location: { coordinates: at(-0.0086, -0.0072) }, positionSource: "home",
      roles: [{ id: "s-paul", role: "sitter", rating: 0, reviewsCount: 0, priceFrom: 25, currency: "EUR", isPremium: false }], personIds: ["s-paul"],
      isPremium: false, isPawSpot: false, approx: true, approxKm: 1, priceFrom: 25, currency: "EUR" },
    { id: "o-sophie", role: "owner", name: "Sophie Laurent", avatar: av("Sophie Laurent"), location: { coordinates: at(0.0154, -0.0072) }, positionSource: "live",
      roles: [{ id: "o-sophie", role: "owner", rating: 0, reviewsCount: 0, priceFrom: 0, currency: "EUR", isPremium: false }, { id: "s-sophie", role: "sitter", rating: 4.7, reviewsCount: 5, priceFrom: 30, currency: "EUR", isPremium: false }, { id: "w-sophie", role: "walker", rating: 4.5, reviewsCount: 2, priceFrom: 14, currency: "EUR", isPremium: false }],
      personIds: ["o-sophie", "s-sophie", "w-sophie"], isPremium: false, isPawSpot: false, approx: true, approxKm: 1 },
    { id: "o-nina", role: "owner", name: "Nina Garcia", avatar: av("Nina Garcia"), location: { coordinates: at(-0.0116, 0.0178) }, positionSource: "home",
      roles: [{ id: "o-nina", role: "owner", rating: 0, reviewsCount: 0, priceFrom: 0, currency: "EUR", isPremium: false }], personIds: ["o-nina"],
      isPremium: false, isPawSpot: false, approx: true, approxKm: 1 },
  ];
}
function worldOld() {
  // Ancien serveur : 1er rôle lu = propriétaire, sans roles/personIds/isFriend.
  return worldNew().map((m) => {
    const { roles, personIds, isFriend, positionSource, ...rest } = m;
    if (m.id === "s-john") return { ...rest, id: "o-john", role: "owner", priceFrom: 0, rating: 0, reviewsCount: 0 };
    if (m.id === "w-marc") return { ...rest, id: "o-marc", role: "owner", priceFrom: 0, rating: 0, reviewsCount: 0 };
    return rest;
  });
}
function nearbyNew() {
  // Proches EXACTS : John (2 rôles) et Marc (ami, 2 rôles).
  return [
    { id: "s-john", role: "sitter", roles: [{ id: "s-john", role: "sitter" }, { id: "o-john", role: "owner" }], personIds: ["s-john", "o-john"], name: "John C", avatar: av("John C"), location: { coordinates: at(0.0041, -0.0147) }, positionSource: "home", isPremium: false, isPawSpot: false, isOnline: true, isFriend: false },
    { id: "w-marc", role: "walker", roles: [{ id: "w-marc", role: "walker" }, { id: "o-marc", role: "owner" }], personIds: ["w-marc", "o-marc"], name: "Marc Dubois", avatar: av("Marc Dubois"), location: { coordinates: at(0.0083, 0.0079) }, positionSource: "home", isPremium: false, isPawSpot: false, isOnline: false, isFriend: true },
  ];
}
function nearbyOld() {
  // Ancien serveur : un point PAR PROFIL → John = 2 ronds superposés.
  const c = at(0.0041, -0.0147);
  return [
    { id: "o-john", role: "owner", name: "John C", avatar: av("John C"), location: { coordinates: c }, isPremium: false, isPawSpot: false, isOnline: true },
    { id: "s-john", role: "sitter", name: "John C", avatar: av("John C"), location: { coordinates: c }, isPremium: false, isPawSpot: false, isOnline: true },
    { id: "o-marc", role: "owner", name: "Marc Dubois", avatar: av("Marc Dubois"), location: { coordinates: at(0.0083, 0.0079) }, isPremium: false, isPawSpot: false, isOnline: false },
  ];
}
const friends = [{ id: "f1", status: "accepted", initiatedByMe: true, mySharePosition: true, theirSharePosition: true,
  other: { id: "w-marc", model: "Walker", name: "Marc Dubois", email: "", avatar: av("Marc Dubois"), personIds: ["w-marc", "o-marc"] } }];
const pois = [
  { _id: "p1", title: "Clinique vétérinaire du Marais", category: "vet", location: { coordinates: at(0.0016, 0.0062) }, address: "Rue de Rivoli" },
  { _id: "p2", title: "Square du Temple", category: "park", location: { coordinates: at(0.0092, 0.0098) } },
];

function avatarSvg(name) {
  const colors = ["#C92A12", "#2563EB", "#16A34A", "#7C3AED", "#0E7490", "#A16207"];
  let h = 0; for (const ch of name) h = (h * 31 + ch.charCodeAt(0)) | 0;
  const c = colors[Math.abs(h) % colors.length];
  const ini = name.split(/\s+/).map((w) => w[0] || "").slice(0, 2).join("").toUpperCase();
  return `<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><rect width="96" height="96" fill="${c}"/><circle cx="48" cy="38" r="18" fill="#fff" opacity=".85"/><rect x="18" y="62" width="60" height="40" rx="20" fill="#fff" opacity=".85"/><text x="48" y="44" text-anchor="middle" font-family="Arial" font-weight="700" font-size="14" fill="${c}">${ini}</text></svg>`;
}

http.createServer(async (req, res) => {
  const cors = { "Access-Control-Allow-Origin": req.headers.origin || "*", "Access-Control-Allow-Credentials": "true", "Access-Control-Allow-Headers": "authorization,content-type,x-app-version,x-app-platform,accept-language", "Access-Control-Allow-Methods": "GET,POST,PATCH,PUT,DELETE,OPTIONS" };
  if (req.method === "OPTIONS") { res.writeHead(204, cors); return res.end(); }
  const u = new URL(req.url, "http://x");
  const p = u.pathname.replace(/^\/api\/v1/, "");
  if (p.startsWith("/av/")) { res.writeHead(200, { ...cors, "Content-Type": "image/svg+xml" }); return res.end(avatarSvg(decodeURIComponent(p.slice(4, -4)))); }
  const LOG = process.env.MOCK_LOG;
  if (LOG) require("fs").appendFileSync(LOG, `${req.method} ${p}\n`);
  let body = {};
  const sitter = { id: "s-lea", _id: "s-lea", name: "Léa Martin", avatar: { url: av("Léa Martin") }, bio: "Gardienne passionnée, jardin clos, 8 ans d'expérience.", hourlyRate: 6, dailyRate: 25, weeklyRate: 150, monthlyRate: 500, currency: "EUR", acceptedPetTypes: ["dog", "cat"], rating: 4.9, reviewsCount: 12, completedServicesCount: 31, responseTimeMinutes: 20, location: { city: "Paris" } };
  const walker = { id: "w-ines", _id: "w-ines", name: "Inès Roche", avatar: { url: av("Inès Roche") }, bio: "Promenades en forêt et au parc.", walkRates: [{ durationMinutes: 30, basePrice: 9, enabled: true, currency: "EUR" }, { durationMinutes: 60, basePrice: 15, enabled: true, currency: "EUR" }, { durationMinutes: 120, basePrice: 26, enabled: true, currency: "EUR" }], currency: "EUR", acceptedPetTypes: ["dog"], rating: 4.8, reviewsCount: 21, completedWalksCount: 64, location: { city: "Paris" } };
  const chunks = [];
  if (req.method === "POST" || req.method === "PATCH") {
    await new Promise((r) => { req.on("data", (c) => chunks.push(c)); req.on("end", r); });
    if (LOG) require("fs").appendFileSync(LOG, `  body ${Buffer.concat(chunks).toString().slice(0, 600)}\n`);
  }
  if (p === "/friends/members/world") body = { members: MODE === "new" ? worldNew() : worldOld(), approxKm: 1 };
  else if (p === "/friends/members/nearby") body = { members: MODE === "new" ? nearbyNew() : nearbyOld() };
  else if (p === "/friends") body = { friends };
  else if (p === "/sitters/nearby") body = { sitters: [
    { id: "s-john", name: "John C", avatar: av("John C"), location: { coordinates: at(0.0041, -0.0147) }, dailyRate: 22 },
    { id: "s-paul", name: "Paul Petit", avatar: "", location: { coordinates: at(-0.0086, -0.0072) }, dailyRate: 25 } ] };
  else if (p === "/walkers/nearby") body = { walkers: [
    { id: "w-john", name: "John C", avatar: av("John C"), location: { coordinates: at(0.0041, -0.0147) }, walkRates: [{ basePrice: 12 }] },
    { id: "w-ines", name: "Inès Roche", avatar: av("Inès Roche"), location: { coordinates: at(-0.0086, -0.0072) }, walkRates: [{ basePrice: 15 }] } ] };
  else if (p === "/friends/live-positions") body = { positions: [] };
  else if (p === "/friends/family/members") body = { members: [] };
  else if (p === "/map-pois/nearby") body = { pois };
  else if (p === "/users/me/profile") body = { profile: { name: "Camille Durand", avatar: { url: av("Camille Durand") }, preferences: { hideFromMap: false } } };
  else if (p === "/users/me/benefits") body = { premiumActive: false, pawspotActive: process.env.MOCK_SPOT === "1", pawFollowActive: true, familyActive: false, isPremium: false, boostExpiry: process.env.MOCK_BOOST === "1" ? new Date(Date.now() + 5 * 86400000).toISOString() : null, isBoosted: process.env.MOCK_BOOST === "1" };
  else if (p === "/posts/my" || p === "/posts/requests") body = { posts: [] };
  else if (p === "/map-reports/nearby") body = { reports: [] };
  else if (p === "/friends/request") body = { ok: true };
  else if (p === "/users/me/map-prefs") body = req.method === "GET" ? { hideFromMap: false, pawMap: { layers: global.__layers || {} } } : (global.__layers = { ...(global.__layers || {}), ...((JSON.parse(Buffer.concat(chunks).toString() || "{}").pawMap || {}).layers || {}) }, { ok: true });
  else if (p === "/sitters/s-lea") body = { sitter };
  else if (p === "/walkers/w-ines") body = { walker };
  else if (/^\/(sitters|walkers)\/[^/]+\/availability$/.test(p)) body = { unavailableDates: [] };
  else if (p === "/pets/me") body = { pets: [{ id: "pet-rex", petName: "Rex", breed: "Golden retriever", category: "Dog", avatar: { url: av("Rex") } }, { id: "pet-mia", petName: "Mia", breed: "Européen", category: "Cat" }] };
  else if (p === "/bookings" && req.method === "POST") body = { booking: { id: "bk-1", status: "pending" } };
  else if (p.startsWith("/bookings/my")) body = { bookings: [
    { id: "bk-1", status: "accepted", paymentStatus: "pending", serviceType: "house_sitting", serviceDate: "2026-10-10", startDate: "2026-10-10T08:00:00.000Z", endDate: "2026-10-13T08:00:00.000Z", totalAmount: 75, currency: "EUR", sitterId: "s-lea", otherParty: { id: "s-lea", name: "Léa Martin", role: "sitter", avatar: av("Léa Martin") }, pricing: { basePrice: 75, totalPrice: 75 } },
    { id: "bk-2", status: "pending", serviceType: "dog_walking", serviceDate: "2026-10-12", startDate: "2026-10-12T08:00:00.000Z", endDate: "2026-10-12T09:00:00.000Z", totalAmount: 15, currency: "EUR", walkerId: "w-ines", otherParty: { id: "w-ines", name: "Inès Roche", role: "walker", avatar: av("Inès Roche") } } ] };
  else if (p === "/conversations/list") body = { conversations: [{ id: "cv-1", lastMessage: "Bonjour Léa, Rex a hâte !", lastMessageAt: new Date().toISOString(), unreadCount: 1, participantName: "Léa Martin", participantAvatar: av("Léa Martin"), sitterId: "s-lea" }] };
  else if (/^\/conversations\/[^/]+\/messages$/.test(p)) body = { messages: [{ id: "m1", body: "Bonjour Léa, Rex a hâte !", senderRole: "owner", createdAt: new Date().toISOString() }] };
  else if (p.startsWith("/subscriptions/plans")) body = { plans: [{ id: "pawfollow_monthly", plan: "pawfollow_monthly", price: 3.99, currency: "EUR", interval: "month" }] };
  else if (p.startsWith("/boost/packages") || p.startsWith("/map-boost/packages")) body = { packages: [{ id: "bronze", tier: "bronze", days: 7, price: 4.99, currency: "EUR" }] };
  else if (p.startsWith("/socket.io")) { res.writeHead(404, cors); return res.end(); }
  res.writeHead(200, { ...cors, "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
}).listen(PORT, () => console.log(`mock ${MODE} :${PORT}`));
