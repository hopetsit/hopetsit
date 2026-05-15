// Thin client over the existing HoPetSit backend on Render.
// The website never owns business state — everything goes through the same
// REST API that the mobile app already uses, so login/signup created here
// work seamlessly inside the app and vice-versa.

const BASE = process.env.NEXT_PUBLIC_API_BASE
  ?? "https://hopetsit-backend.onrender.com/api/v1";

const TOKEN_KEY = "hopetsit_token";
const ROLE_KEY  = "hopetsit_role";
const USER_KEY  = "hopetsit_user";

type Json = Record<string, unknown>;

export type AuthRole = "owner" | "sitter" | "walker";

export type AuthUser = {
  id: string;
  name: string;
  email: string;
  role: AuthRole;
};

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public details?: unknown,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

export function getStoredToken(): string | null {
  if (typeof window === "undefined") return null;
  try { return window.localStorage.getItem(TOKEN_KEY); } catch { return null; }
}

export function getStoredUser(): AuthUser | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(USER_KEY);
    return raw ? (JSON.parse(raw) as AuthUser) : null;
  } catch { return null; }
}

function notifyAuthChange() {
  if (typeof window === "undefined") return;
  // Custom event so the same tab can react instantly (`storage` only fires
  // across other tabs). The `useAuth` hook in lib/useAuth.ts listens to both.
  try { window.dispatchEvent(new Event("hopetsit:auth-changed")); } catch { /* ignore */ }
}

function persistAuth(token: string, user: AuthUser) {
  try {
    window.localStorage.setItem(TOKEN_KEY, token);
    window.localStorage.setItem(ROLE_KEY, user.role);
    window.localStorage.setItem(USER_KEY, JSON.stringify(user));
  } catch { /* ignore */ }
  notifyAuthChange();
}

export function clearAuth() {
  try {
    window.localStorage.removeItem(TOKEN_KEY);
    window.localStorage.removeItem(ROLE_KEY);
    window.localStorage.removeItem(USER_KEY);
  } catch { /* ignore */ }
  notifyAuthChange();
}

async function request<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const token = getStoredToken();
  const headers: Record<string, string> = {
    Accept: "application/json",
    ...((init.body && !(init.body instanceof FormData))
      ? { "Content-Type": "application/json" }
      : {}),
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...((init.headers as Record<string, string>) || {}),
  };
  let res: Response;
  try {
    res = await fetch(`${BASE}${path}`, { ...init, headers });
  } catch (e) {
    throw new ApiError(
      "Network error. Please check your connection.",
      0,
      e instanceof Error ? e.message : String(e),
    );
  }
  const text = await res.text();
  let data: unknown = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }

  if (!res.ok) {
    const message =
      (data && typeof data === "object" && (data as Json).error)
        ? String((data as Json).error)
        : `Request failed (${res.status})`;
    throw new ApiError(message, res.status, data);
  }
  return data as T;
}

// ─── Auth ───────────────────────────────────────────────────────────────────

// Backend response shape (mobile app contract):
//   { role: 'owner'|'sitter'|'walker', token: '...', user: { _id|id, name, email, ... } }
// `role` lives at the top-level — Owner/Sitter/Walker collections don't
// store it as a column. We merge it into the AuthUser object before
// persisting so the rest of the website can read `user.role` directly.
type AuthRaw = {
  role: AuthRole;
  token: string;
  user: { _id?: string; id?: string; name?: string; email?: string };
};

function normalizeAuthResponse(raw: AuthRaw): { token: string; user: AuthUser } {
  const id = (raw.user?._id || raw.user?.id || "").toString();
  return {
    token: raw.token,
    user: {
      id,
      name: raw.user?.name || "",
      email: (raw.user?.email || "").toString(),
      role: raw.role,
    },
  };
}

export async function login(email: string, password: string) {
  const raw = await request<AuthRaw>(
    "/auth/login",
    { method: "POST", body: JSON.stringify({ email, password }) },
  );
  const data = normalizeAuthResponse(raw);
  persistAuth(data.token, data.user);
  return data;
}

export async function signup(input: {
  name: string;
  email: string;
  password: string;
  role: AuthRole;
}) {
  // The /auth/signup contract requires `{ role, user: {...} }` (and accepts
  // optional fields like mobile, countryCode, currency that we don't collect
  // from the website — the mobile app fills those later in the onboarding).
  const body = {
    role: input.role,
    user: {
      name: input.name,
      email: input.email,
      password: input.password,
      acceptedTerms: true,
    },
  };
  const raw = await request<AuthRaw>(
    "/auth/signup",
    { method: "POST", body: JSON.stringify(body) },
  );
  const data = normalizeAuthResponse(raw);
  persistAuth(data.token, data.user);
  return data;
}

/**
 * Exchange a Firebase ID token (issued by signInWithGooglePopup) for a
 * HoPetSit JWT. Backend creates the user under `defaultRole` if it's the
 * first time this email signs in; otherwise the existing role is kept.
 */
export async function googleSignIn(idToken: string, defaultRole: AuthRole = "owner") {
  const raw = await request<AuthRaw>(
    "/auth/google",
    {
      method: "POST",
      body: JSON.stringify({ idToken, role: defaultRole }),
    },
  );
  const data = normalizeAuthResponse(raw);
  persistAuth(data.token, data.user);
  return data;
}

// ─── Session bridge web → app (v23.1 part 146) ──────────────────────────────

// Réponse de POST /auth/one-time-token (côté backend, contrôleur
// oneTimeTokenController). Le token brut n'apparaît qu'UNE seule fois ici ;
// le backend stocke uniquement son SHA-256.
type OneTimeTokenRaw = {
  ott: string;
  expiresIn: number;
};

/**
 * Demande au backend un one-time token (OTT) lié au JWT actuel de l'utilisateur.
 * Le token expire en 60 secondes et n'est utilisable qu'UNE seule fois.
 *
 * Usage typique : juste avant d'ouvrir l'app mobile via deep link.
 *   const { ott } = await requestOneTimeToken();
 *   window.location.href = `hopetsit://auth?ott=${ott}`;
 */
export async function requestOneTimeToken(): Promise<OneTimeTokenRaw> {
  // request<T> ajoute déjà `Authorization: Bearer <token>` depuis localStorage.
  return request<OneTimeTokenRaw>("/auth/one-time-token", { method: "POST" });
}

/**
 * Ouvre l'app mobile HoPetSit en transférant la session web (auto-login).
 *
 * Comportement :
 *   - Si l'utilisateur n'est pas logué côté site → throw, l'UI doit afficher
 *     un message "Veuillez vous connecter d'abord".
 *   - Si logué → on demande un OTT, puis on redirige vers
 *     `hopetsit://auth?ott=<token>`. Sur tel avec l'app installée, le deep
 *     link ouvre l'app qui auto-login. Sans app installée, rien ne se passe
 *     visuellement (Android peut afficher un toast "Aucune app pour ouvrir
 *     ce lien"). On peut éventuellement timeout + rediriger vers le store.
 *
 * Le code appelant est responsable d'afficher un loader pendant l'attente
 * de la requête réseau (~200-500ms typiquement).
 */
export async function openInApp(): Promise<void> {
  if (typeof window === "undefined") {
    throw new ApiError("openInApp only works in the browser.", 0);
  }
  const token = getStoredToken();
  if (!token) {
    throw new ApiError("You must be logged in to open the app.", 401);
  }
  const { ott } = await requestOneTimeToken();
  // Redirection vers le scheme custom. Sur Android (avec assetlinks.json
  // déployé + Universal Links activé), l'app intercepte. Sur iOS l'app
  // intercepte aussi (Info.plist CFBundleURLTypes + Universal Links).
  // Si l'app n'est pas installée, le navigateur n'ouvre rien (pas de
  // page d'erreur 404 puisque pas de host à résoudre).
  window.location.href = `hopetsit://auth?ott=${encodeURIComponent(ott)}`;
}

// ─── Profile (v23.1 part 146) ───────────────────────────────────────────────

export type UserProfile = {
  id: string;
  name: string;
  email: string;
  mobile?: string;
  countryCode?: string;
  address?: string;
  language?: string;
  bio?: string;
  avatar?: { url?: string; publicId?: string };
  verified?: boolean;
  role: AuthRole;
  // v23.1 part 146 — devise préférée (sitter facture en cette unité).
  currency?: "EUR" | "USD";
  // Sitter/Walker-specific
  hourlyRate?: number;
  weeklyRate?: number;
  monthlyRate?: number;
  skills?: string;
  service?: string;
  rating?: number;
  reviewsCount?: number;
};

/**
 * Fetch the logged-in user's full profile. The mobile app uses different
 * endpoints depending on role (`/users/me/profile` for owner, etc.); the
 * backend resolves it from the JWT.
 */
export async function getMyProfile(): Promise<UserProfile> {
  const raw = await request<{ profile?: UserProfile; user?: UserProfile }>(
    "/users/me/profile",
  );
  // Backend renvoie soit `{ profile }` soit `{ user }` selon le controller.
  return (raw.profile || raw.user) as UserProfile;
}

/**
 * Upload a new avatar image. Reuse the same endpoint as the app
 * (PUT /users/me/profile-picture, multipart field name = "avatar").
 */
export async function uploadMyAvatar(file: File): Promise<UserProfile> {
  if (!file.type.startsWith("image/")) {
    throw new ApiError("Le fichier doit être une image.", 400);
  }
  if (file.size > 10 * 1024 * 1024) {
    throw new ApiError("Image trop grande (10 Mo max).", 400);
  }
  const form = new FormData();
  form.append("avatar", file);
  const raw = await request<{ user?: UserProfile; avatar?: { url?: string } }>(
    "/users/me/profile-picture",
    { method: "PUT", body: form },
  );
  // Le backend renvoie { user } complet, sinon on bricole un patch local.
  if (raw.user) return raw.user;
  // Fallback: on patch juste l'avatar dans le user en cache et on refetch.
  return getMyProfile();
}

export async function updateMyProfile(
  patch: Partial<UserProfile>,
): Promise<UserProfile> {
  // Le backend accepte un PATCH/PUT sur l'user logué. On envoie tout sous
  // /users/me/profile pour être role-agnostic (le routeur backend dispatch).
  const raw = await request<{ user?: UserProfile; profile?: UserProfile }>(
    "/users/me/profile",
    { method: "PUT", body: JSON.stringify(patch) },
  );
  const updated = (raw.user || raw.profile) as UserProfile;
  // Sync localStorage cache pour que le dashboard reflète les changements.
  try {
    const current = getStoredUser();
    if (current) {
      const merged: AuthUser = {
        id: updated.id || current.id,
        name: updated.name ?? current.name,
        email: updated.email ?? current.email,
        role: current.role,
      };
      window.localStorage.setItem(USER_KEY, JSON.stringify(merged));
      notifyAuthChange();
    }
  } catch { /* ignore */ }
  return updated;
}

// ─── IBAN (sitter / walker only) ────────────────────────────────────────────

export type IbanInfo = {
  ibanHolder?: string;
  ibanLast4?: string; // backend renvoie un masque, pas l'IBAN complet
  ibanBic?: string;
  ibanVerified?: boolean;
  payoutMethod?: "iban" | "paypal" | "none";
};

// Le backend monte les routes IBAN sous `/sitter` ET `/walker` (même router
// pour les 2 rôles). On dérive le bon préfixe depuis le rôle stocké.
function ibanPath(): string {
  const u = getStoredUser();
  if (u?.role === "walker") return "/walker/iban";
  return "/sitter/iban"; // fallback aussi pour sitter
}

export async function getMyIban(): Promise<IbanInfo> {
  const raw = await request<IbanInfo & { iban?: IbanInfo }>(ibanPath());
  return raw.iban || raw;
}

export async function updateMyIban(input: {
  ibanHolder: string;
  ibanNumber: string;
  ibanBic?: string;
}): Promise<IbanInfo> {
  const raw = await request<{ provider?: IbanInfo; iban?: IbanInfo }>(
    ibanPath(),
    { method: "PUT", body: JSON.stringify(input) },
  );
  return raw.provider || raw.iban || (raw as IbanInfo);
}

export async function deleteMyIban(): Promise<void> {
  await request(ibanPath(), { method: "DELETE" });
}

// ─── Pets (v23.1 part 146) ──────────────────────────────────────────────────

export type Pet = {
  id: string;
  petName: string;
  category?: string;
  breed?: string;
  dob?: string;
  weight?: string;
  height?: string;
  colour?: string;
  passportNumber?: string;
  chipNumber?: string;
  medicationAllergies?: string;
  vaccination?: string;
  bio?: string;
  profileView?: "public" | "private";
  avatar?: { url?: string; publicId?: string };
};

export async function getMyPets(): Promise<Pet[]> {
  const raw = await request<{ pets?: Pet[] }>("/pets/me");
  return raw.pets || [];
}

export async function createPet(
  input: Omit<Pet, "id" | "avatar">,
): Promise<Pet> {
  const raw = await request<{ pet: Pet }>("/pets/create-pet-profile", {
    method: "POST",
    body: JSON.stringify({ pet: input }),
  });
  return raw.pet;
}

export async function updatePet(
  id: string,
  patch: Partial<Omit<Pet, "id" | "avatar">>,
): Promise<Pet> {
  const raw = await request<{ pet: Pet }>(`/pets/${id}`, {
    method: "PUT",
    body: JSON.stringify(patch),
  });
  return raw.pet;
}

export async function deletePet(id: string): Promise<void> {
  await request(`/pets/${id}`, { method: "DELETE" });
}

/**
 * Upload an avatar for a pet (multipart, field = "avatar").
 * Backend: PUT /pets/:id/media.
 */
export async function uploadPetAvatar(petId: string, file: File): Promise<Pet> {
  if (!file.type.startsWith("image/")) {
    throw new ApiError("Le fichier doit être une image.", 400);
  }
  if (file.size > 10 * 1024 * 1024) {
    throw new ApiError("Image trop grande (10 Mo max).", 400);
  }
  const form = new FormData();
  form.append("avatar", file);
  const raw = await request<{ pet?: Pet; avatar?: { url?: string } }>(
    `/pets/${petId}/media`,
    { method: "PUT", body: form },
  );
  if (raw.pet) return raw.pet;
  // Fallback: refetch la liste pour récupérer le pet avec son nouvel avatar.
  const all = await getMyPets();
  return all.find((p) => p.id === petId) || (raw as unknown as Pet);
}

// ─── Search providers (v23.1 part 146) ──────────────────────────────────────

export type ProviderProfile = {
  id: string;
  name: string;
  email?: string;
  bio?: string;
  skills?: string;
  service?: string;
  avatar?: { url?: string; publicId?: string };
  hourlyRate?: number;
  weeklyRate?: number;
  monthlyRate?: number;
  walkRates?: { walkSolo30?: number; walkSolo60?: number; walkGroup30?: number; walkGroup60?: number };
  rating?: number;
  averageRating?: number;
  reviewsCount?: number;
  location?: { city?: string; lat?: number; lng?: number };
  isBoosted?: boolean;
  isMapBoosted?: boolean;
};

export type Pagination = {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

export async function listSitters(opts?: {
  page?: number;
  limit?: number;
  city?: string;
}): Promise<{ providers: ProviderProfile[]; pagination?: Pagination }> {
  const qs = new URLSearchParams();
  if (opts?.page) qs.set("page", String(opts.page));
  if (opts?.limit) qs.set("limit", String(opts.limit));
  if (opts?.city) qs.set("city", opts.city);
  const path = `/sitters${qs.toString() ? "?" + qs.toString() : ""}`;
  const raw = await request<{ sitters?: ProviderProfile[]; pagination?: Pagination }>(path);
  return { providers: raw.sitters || [], pagination: raw.pagination };
}

export async function listWalkers(opts?: {
  page?: number;
  limit?: number;
  city?: string;
}): Promise<{ providers: ProviderProfile[]; pagination?: Pagination }> {
  const qs = new URLSearchParams();
  if (opts?.page) qs.set("page", String(opts.page));
  if (opts?.limit) qs.set("limit", String(opts.limit));
  if (opts?.city) qs.set("city", opts.city);
  const path = `/walkers${qs.toString() ? "?" + qs.toString() : ""}`;
  const raw = await request<{ walkers?: ProviderProfile[]; pagination?: Pagination }>(path);
  return { providers: raw.walkers || [], pagination: raw.pagination };
}

export async function getProvider(
  type: "sitter" | "walker",
  id: string,
): Promise<ProviderProfile | null> {
  const raw = await request<{ sitter?: ProviderProfile; walker?: ProviderProfile }>(
    `/${type}s/${id}`,
  );
  return raw.sitter || raw.walker || null;
}

// ─── Bookings (v23.1 part 146) ──────────────────────────────────────────────

export type BookingStatus =
  | "pending"
  | "accepted"
  | "agreed"
  | "paid"
  | "cancelled"
  | "refunded"
  | "rejected"
  | "completed";

export type Booking = {
  id: string;
  ownerId: string;
  sitterId?: string;
  walkerId?: string;
  petIds?: string[];
  status: BookingStatus;
  serviceType?: string;
  serviceDate?: string;
  startDate?: string;
  endDate?: string;
  basePrice?: number;
  totalAmount?: number;
  currency?: string;
  paymentStatus?: "pending" | "paid" | "cancelled" | "refund";
  paidAt?: string;
  createdAt?: string;
  // Souvent populé côté backend pour faciliter l'UI :
  ownerName?: string;
  sitterName?: string;
  walkerName?: string;
};

export async function getMyBookings(
  status?: BookingStatus,
): Promise<Booking[]> {
  const qs = status ? `?status=${encodeURIComponent(status)}` : "";
  const raw = await request<{ bookings?: Booking[] }>(`/bookings/my${qs}`);
  return raw.bookings || [];
}

export async function getBookingDetail(id: string): Promise<Booking | null> {
  // GET /bookings/{id}/agreement renvoie un objet avec pricing + terms,
  // mais pour l'écran "mes bookings" la version sommaire de /bookings/my
  // suffit. Cette fonction est là si on veut le détail complet plus tard.
  const raw = await request<{ booking?: Booking; agreement?: { booking?: Booking } }>(
    `/bookings/${id}/agreement`,
  );
  return raw.booking || raw.agreement?.booking || null;
}

export async function createBooking(input: {
  providerType: "sitter" | "walker";
  providerId: string;
  petIds: string[];
  serviceType: string;
  serviceDate: string; // ISO date
  startDate?: string;
  endDate?: string;
  duration?: number; // minutes
  timeSlot?: string; // "HH:MM"
  description?: string;
  locationType?: "owner_home" | "sitter_home";
  addOns?: string[];
}): Promise<Booking> {
  const queryKey =
    input.providerType === "walker" ? "walkerId" : "sitterId";
  const body = {
    petIds: input.petIds,
    serviceType: input.serviceType,
    serviceDate: input.serviceDate,
    startDate: input.startDate || input.serviceDate,
    endDate: input.endDate,
    duration: input.duration,
    timeSlot: input.timeSlot,
    description: input.description || "",
    locationType: input.locationType,
    addOns: input.addOns || [],
  };
  const raw = await request<{ booking: Booking }>(
    `/bookings?${queryKey}=${encodeURIComponent(input.providerId)}`,
    { method: "POST", body: JSON.stringify(body) },
  );
  return raw.booking;
}

export async function respondToBooking(
  id: string,
  action: "accept" | "reject",
): Promise<Booking> {
  const raw = await request<{ booking: Booking }>(`/bookings/${id}/respond`, {
    method: "POST",
    body: JSON.stringify({ action }),
  });
  return raw.booking;
}

// ─── Invoices (v23.1 part 146) ──────────────────────────────────────────────

export type Invoice = {
  id: string;
  invoiceNumber: string;
  issuedAt: string;
  bookingId?: string;
  ownerName?: string;
  providerName?: string;
  serviceType?: string;
  total: number;
  currency: string;
  status?: "paid" | "issued" | "void";
};

export async function getMyInvoices(): Promise<Invoice[]> {
  const raw = await request<{ invoices?: Invoice[] }>("/invoices/my");
  return raw.invoices || [];
}

/**
 * URL absolue pour ouvrir la version HTML imprimable de la facture dans un
 * nouvel onglet. Le token JWT est passé en query string parce que le route
 * backend utilise `requireAuthQueryOrHeader` (les nouvelles fenêtres ne
 * transmettent pas le header `Authorization` automatiquement).
 *
 * L'utilisateur peut ensuite faire Ctrl+P pour imprimer ou enregistrer en PDF.
 */
export function getInvoiceHtmlUrl(invoiceId: string): string | null {
  const token = getStoredToken();
  if (!token) return null;
  return `${BASE}/invoices/${invoiceId}/html?token=${encodeURIComponent(token)}`;
}

// ─── Chat (v23.1 part 146) ──────────────────────────────────────────────────

export type Conversation = {
  id: string;
  ownerId?: string;
  sitterId?: string;
  walkerId?: string;
  lastMessage?: string;
  lastMessageAt?: string;
  unreadCount?: number;
  // Champs souvent populés côté backend pour la liste :
  participantName?: string;
  participantAvatar?: string;
};

export type ChatMessage = {
  id: string;
  body: string;
  senderRole: AuthRole;
  senderId: string;
  createdAt: string;
  attachments?: Array<{ type?: string; url: string; publicId?: string }>;
};

export async function getConversations(): Promise<Conversation[]> {
  const raw = await request<{ conversations?: Conversation[] }>(
    "/conversations/list",
  );
  return raw.conversations || [];
}

export async function getMessages(
  conversationId: string,
): Promise<ChatMessage[]> {
  const raw = await request<{ messages?: ChatMessage[] }>(
    `/conversations/${conversationId}/messages`,
  );
  return raw.messages || [];
}

export async function sendMessage(
  conversationId: string,
  body: string,
): Promise<ChatMessage> {
  const user = getStoredUser();
  if (!user) throw new ApiError("Not logged in", 401);
  const raw = await request<{ message: ChatMessage }>(
    `/conversations/${conversationId}/messages`,
    {
      method: "POST",
      body: JSON.stringify({
        senderRole: user.role,
        senderId: user.id,
        body,
      }),
    },
  );
  return raw.message;
}

// ─── PawMap : POI (v23.1 part 146) ──────────────────────────────────────────

export type PoiCategory =
  | "vet"
  | "shop"
  | "groomer"
  | "park"
  | "beach"
  | "water"
  | "trainer"
  | "hotel"
  | "restaurant"
  | "other";

export const POI_CATEGORY_LABELS: Record<PoiCategory, { label: string; emoji: string }> = {
  vet: { label: "Vétérinaires", emoji: "🏥" },
  shop: { label: "Animaleries", emoji: "🛍️" },
  groomer: { label: "Toiletteurs", emoji: "✂️" },
  park: { label: "Parcs canins", emoji: "🌳" },
  beach: { label: "Plages", emoji: "🏖️" },
  water: { label: "Points d'eau", emoji: "💧" },
  trainer: { label: "Éducateurs", emoji: "🦮" },
  hotel: { label: "Hôtels pet-friendly", emoji: "🏨" },
  restaurant: { label: "Restos pet-friendly", emoji: "🍽️" },
  other: { label: "Autre", emoji: "📍" },
};

export type Poi = {
  _id: string;
  title: string;
  description?: string;
  category: PoiCategory;
  location: {
    type: "Point";
    coordinates: [number, number]; // [lng, lat]
    city?: string;
    country?: string;
  };
  address?: string;
  phone?: string;
  website?: string;
  openingHours?: string;
  source?: "seed" | "user" | "admin";
  status?: "pending" | "active" | "rejected" | "inactive";
  rating?: number;
  reviewsCount?: number;
  photosCount?: number;
  createdAt?: string;
};

export async function getPoiCategories(): Promise<string[]> {
  const raw = await request<{ categories?: string[] }>("/map-pois/categories");
  return raw.categories || [];
}

export async function getNearbyPois(opts: {
  lat: number;
  lng: number;
  maxDistance?: number;
  category?: PoiCategory;
}): Promise<Poi[]> {
  const qs = new URLSearchParams({
    lat: String(opts.lat),
    lng: String(opts.lng),
  });
  if (opts.maxDistance) qs.set("maxDistance", String(opts.maxDistance));
  if (opts.category) qs.set("category", opts.category);
  const raw = await request<{ pois?: Poi[] }>(`/map-pois/nearby?${qs.toString()}`);
  return raw.pois || [];
}

export async function getMyPois(): Promise<Poi[]> {
  const raw = await request<{ pois?: Poi[] }>("/map-pois/mine");
  return raw.pois || [];
}

export async function createPoi(input: {
  title: string;
  category: PoiCategory;
  lat: number;
  lng: number;
  description?: string;
  address?: string;
  city?: string;
  country?: string;
  phone?: string;
  website?: string;
  openingHours?: string;
}): Promise<Poi> {
  const raw = await request<{ poi: Poi }>("/map-pois", {
    method: "POST",
    body: JSON.stringify(input),
  });
  return raw.poi;
}

export async function deletePoi(id: string): Promise<void> {
  await request(`/map-pois/${id}`, { method: "DELETE" });
}

// ─── PawMap : Map Reports (signalements, Premium-gated) ─────────────────────

export type MapReportType =
  | "lost_pet"
  | "aggressive_dog"
  | "water_active"
  | "found_pet"
  | "dead_animal"
  | "trap"
  | "poison"
  | "stray_pet"
  | "construction";

export type MapReport = {
  _id: string;
  type: MapReportType;
  note?: string;
  photoUrl?: string;
  location: { coordinates: [number, number]; city?: string };
  confirmationsCount?: number;
  flagsCount?: number;
  createdAt: string;
  expiresAt: string;
};

export async function getNearbyReports(opts: {
  lat: number;
  lng: number;
  maxDistance?: number;
  type?: MapReportType;
}): Promise<{ reports: MapReport[]; isPremium: boolean; freeTypes: string[] }> {
  const qs = new URLSearchParams({
    lat: String(opts.lat),
    lng: String(opts.lng),
  });
  if (opts.maxDistance) qs.set("maxDistance", String(opts.maxDistance));
  if (opts.type) qs.set("type", opts.type);
  const raw = await request<{
    reports?: MapReport[];
    isPremium?: boolean;
    freeTypes?: string[];
  }>(`/map-reports/nearby?${qs.toString()}`);
  return {
    reports: raw.reports || [],
    isPremium: raw.isPremium || false,
    freeTypes: raw.freeTypes || [],
  };
}

// ─── Subscriptions (PawFollow Premium) ──────────────────────────────────────

export type SubscriptionPlan = {
  id: "monthly" | "yearly" | "family";
  name?: string;
  amount: number;
  currency: string;
  intervalDays: number;
  features?: Record<string, boolean | number>;
};

export type SubscriptionStatus = {
  plan: string | null;
  status: "active" | "cancelled" | "expired" | "none";
  isPremium: boolean;
  features?: Record<string, boolean | number>;
  currentPeriodStart?: string;
  currentPeriodEnd?: string;
  cancelAtPeriodEnd?: boolean;
  mapBoostCreditsRemaining?: number;
};

export async function getSubscriptionPlans(
  currency?: string,
): Promise<SubscriptionPlan[]> {
  const qs = currency ? `?currency=${currency}` : "";
  const raw = await request<{ plans?: SubscriptionPlan[] }>(
    `/subscriptions/plans${qs}`,
  );
  return raw.plans || [];
}

export async function getSubscriptionStatus(): Promise<SubscriptionStatus> {
  return await request<SubscriptionStatus>("/subscriptions/status");
}

export async function subscribeToPlan(
  plan: "monthly" | "yearly" | "family",
  currency?: string,
): Promise<{ clientSecret: string; paymentIntentId: string; amount: number; currency: string }> {
  return await request("/subscriptions/subscribe", {
    method: "POST",
    body: JSON.stringify({ plan, currency }),
  });
}

export async function cancelSubscription(): Promise<SubscriptionStatus> {
  return await request("/subscriptions/cancel", { method: "POST" });
}

export async function resumeSubscription(): Promise<SubscriptionStatus> {
  return await request("/subscriptions/resume", { method: "POST" });
}

// ─── Profile Boost (annonce mise en avant) ──────────────────────────────────

export type BoostTier = "bronze" | "silver" | "gold" | "platinum";

export type BoostPackage = {
  tier: BoostTier;
  days: number;
  amount: number;
  currency: string;
  label?: string;
};

export type BoostStatus = {
  isActive: boolean;
  tier?: BoostTier;
  expiresAt?: string;
  remainingDays?: number;
  remainingHours?: number;
};

export async function getBoostPackages(
  currency?: string,
): Promise<BoostPackage[]> {
  const qs = currency ? `?currency=${currency}` : "";
  const raw = await request<{ packages?: BoostPackage[] }>(`/boost/packages${qs}`);
  return raw.packages || [];
}

export async function getBoostStatus(): Promise<BoostStatus> {
  return await request<BoostStatus>("/boost/status");
}

// ─── Map Boost (PawSpot — visibilité sur la carte) ──────────────────────────

export async function getMapBoostPackages(
  currency?: string,
): Promise<BoostPackage[]> {
  const qs = currency ? `?currency=${currency}` : "";
  const raw = await request<{ packages?: BoostPackage[] }>(
    `/map-boost/packages${qs}`,
  );
  return raw.packages || [];
}

export async function getMapBoostStatus(): Promise<
  BoostStatus & { mapBoostCreditsRemaining?: number }
> {
  return await request("/map-boost/status");
}

export async function claimMapBoostCredit(): Promise<{
  daysAdded: number;
  expiresAt: string;
  mapBoostCreditsRemaining: number;
}> {
  return await request("/map-boost/claim-credit", { method: "POST" });
}

// ─── Contact form ───────────────────────────────────────────────────────────

// Posts to the website's own /api/contact Edge route (which uses Resend to
// deliver the message to contact@hopetsit.com). No call to the Render backend
// for this — the website owns the contact channel end-to-end.
export async function sendContactMessage(input: {
  name: string;
  email: string;
  message: string;
}) {
  let res: Response;
  try {
    res = await fetch("/api/contact", {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify(input),
    });
  } catch (e) {
    throw new ApiError(
      "Network error. Please check your connection and try again.",
      0,
      e instanceof Error ? e.message : String(e),
    );
  }
  let data: { ok?: boolean; error?: string } = {};
  try { data = await res.json(); } catch { /* ignore */ }
  if (!res.ok) {
    throw new ApiError(
      data.error || "Failed to send your message. Please try again.",
      res.status,
      data,
    );
  }
  return { ok: true };
}
