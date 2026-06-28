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

// v498 — Daniel : page web « Supprimer mon compte » (exigence Google Play).
// Suppression RGPD complète côté backend (DELETE /users/me) : retire des amis/
// familles/map, anonymise les données financières conservées par la loi.
export async function deleteMyAccount(): Promise<void> {
  await request("/users/me", { method: "DELETE" });
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
}): Promise<{ needsVerification: boolean; email: string; token?: string; user?: AuthUser }> {
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
  // v402 — le backend /auth/signup crée le compte avec verified:false et NE
  // renvoie PAS de token (il envoie un code 6 chiffres par email). Avant, le
  // site persistait un token undefined puis filait au dashboard → user web
  // bloqué (login renvoie 403 "Email not verified", aucune UI pour saisir le
  // code). On renvoie donc needsVerification → la page d'inscription redirige
  // vers /verify-email. Si un jour le backend renvoie un token (auto-login),
  // on le gère aussi.
  const raw = await request<Partial<AuthRaw> & { message?: string }>(
    "/auth/signup",
    { method: "POST", body: JSON.stringify(body) },
  );
  if (raw && raw.token) {
    const data = normalizeAuthResponse(raw as AuthRaw);
    persistAuth(data.token, data.user);
    return { needsVerification: false, email: input.email, token: data.token, user: data.user };
  }
  return { needsVerification: true, email: input.email };
}

// v402 — vérification d'email depuis le SITE (parité app). Le backend renvoie
// un JWT seulement APRÈS vérification du code 6 chiffres reçu par email.
export async function verifyEmail(email: string, code: string) {
  const raw = await request<AuthRaw>(
    `/auth/verify?email=${encodeURIComponent(email)}`,
    { method: "POST", body: JSON.stringify({ code: code.trim() }) },
  );
  const data = normalizeAuthResponse(raw);
  persistAuth(data.token, data.user);
  return data;
}

export async function resendVerificationCode(email: string) {
  return request<{ message?: string }>(
    `/auth/resend-code?email=${encodeURIComponent(email)}`,
    { method: "POST" },
  );
}

// v402 — changement de rôle depuis le SITE (parité app). Le backend
// (/users/switch-role) MIGRE les abonnements (Premium / PawFollow / PawFamily /
// PawSpot — il garde le max des compteurs, rien n'est perdu) et renvoie un
// NOUVEAU token + le doc du nouveau rôle. On persiste pour rester connecté sous
// le nouveau rôle. Même endpoint que l'app → aucun impact app.
export async function switchRole(targetRole: AuthRole) {
  const raw = await request<AuthRaw>(
    "/users/switch-role",
    { method: "POST", body: JSON.stringify({ targetRole }) },
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

// v409 — Daniel : bandeau de notifications sur le compte web (demandes reçues,
// acceptations, paiements). Réutilise l'API mobile GET /notifications/my.
export type AppNotification = {
  id: string;
  type: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
  readAt: string | null;
  createdAt: string;
};

export async function getMyNotifications(limit = 20): Promise<AppNotification[]> {
  const res = await request<{ notifications?: AppNotification[] }>(
    `/notifications/my?limit=${limit}`,
  );
  return res.notifications ?? [];
}

export async function markNotificationRead(id: string): Promise<void> {
  await request(`/notifications/my/${id}/read`, { method: "PATCH" });
}

export async function markAllNotificationsRead(): Promise<void> {
  await request(`/notifications/my/read-all`, { method: "PATCH" });
}

export async function deleteNotification(id: string): Promise<void> {
  await request(`/notifications/my/${id}`, { method: "DELETE" });
}

export async function clearAllNotifications(): Promise<void> {
  await request(`/notifications/my/clear`, { method: "DELETE" });
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
  // v413 — parité app : préférences + 2FA (synchro app↔web, mêmes champs).
  preferences?: {
    sendPhotosVideos?: boolean;
    quickReplies?: boolean;
    flexibleCancellation?: boolean;
    pawMapInsurance?: boolean;
    notifications?: boolean;
  };
  twoFactorEnabled?: boolean;
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

// ─── Disponibilités (sitter / walker only) ──────────────────────────────────
// Calendrier de disponibilités, mêmes champs que l'app mobile :
//   availableDates[]      → dates ponctuellement disponibles (ISO)
//   unavailableDates[]    → dates explicitement bloquées (ISO)
//   availableTimeSlots[]  → créneaux hebdo récurrents { day, startHour, endHour }
//
// Les routes sont montées sous /sitters/me/availability et
// /walkers/me/availability (au PLURIEL — contrairement à l'IBAN qui est sous
// /sitter et /walker au singulier). On dérive le bon préfixe depuis le rôle.

// Créneau horaire hebdomadaire récurrent (parité app + backend).
export type AvailabilityTimeSlot = {
  day:
    | "monday"
    | "tuesday"
    | "wednesday"
    | "thursday"
    | "friday"
    | "saturday"
    | "sunday";
  startHour: number; // 0-23
  endHour: number; // 1-24, > startHour
};

export type Availability = {
  availableDates: string[];
  unavailableDates: string[];
  availableTimeSlots: AvailabilityTimeSlot[];
};

function availabilityPath(): string {
  const u = getStoredUser();
  if (u?.role === "walker") return "/walkers/me/availability";
  return "/sitters/me/availability"; // fallback aussi pour sitter
}

// Le backend renvoie availableDates/unavailableDates en objets Date sérialisés
// (ISO strings). On normalise en string[] pour le front.
function normalizeAvailability(raw: {
  availableDates?: unknown[];
  unavailableDates?: unknown[];
  availableTimeSlots?: AvailabilityTimeSlot[];
}): Availability {
  const toIso = (list?: unknown[]): string[] =>
    Array.isArray(list)
      ? list
          .map((d) => (d instanceof Date ? d.toISOString() : String(d)))
          .filter(Boolean)
      : [];
  return {
    availableDates: toIso(raw.availableDates),
    unavailableDates: toIso(raw.unavailableDates),
    availableTimeSlots: Array.isArray(raw.availableTimeSlots)
      ? raw.availableTimeSlots
      : [],
  };
}

export async function getMyAvailability(): Promise<Availability> {
  const raw = await request<{
    availableDates?: unknown[];
    unavailableDates?: unknown[];
    availableTimeSlots?: AvailabilityTimeSlot[];
  }>(availabilityPath());
  return normalizeAvailability(raw);
}

export async function updateMyAvailability(input: {
  availableDates?: string[];
  unavailableDates?: string[];
  availableTimeSlots?: AvailabilityTimeSlot[];
}): Promise<Availability> {
  const raw = await request<{
    availableDates?: unknown[];
    unavailableDates?: unknown[];
    availableTimeSlots?: AvailabilityTimeSlot[];
  }>(availabilityPath(), {
    method: "PUT",
    body: JSON.stringify(input),
  });
  return normalizeAvailability(raw);
}

// Disponibilités PUBLIQUES d'un prestataire (vue owner avant réservation).
// GET /sitters/:id/availability ou /walkers/:id/availability (sans auth).
export async function getProviderAvailability(
  type: "sitter" | "walker",
  id: string,
): Promise<Availability> {
  try {
    const raw = await request<{
      availableDates?: unknown[];
      unavailableDates?: unknown[];
      availableTimeSlots?: AvailabilityTimeSlot[];
    }>(`/${type}s/${id}/availability`);
    return normalizeAvailability(raw);
  } catch (e) {
    // Défensif : un prestataire sans calendrier configuré ne doit pas casser
    // l'écran de réservation. On renvoie des listes vides (aucun blocage).
    if (e instanceof ApiError && (e.status === 404 || e.status === 401)) {
      return { availableDates: [], unavailableDates: [], availableTimeSlots: [] };
    }
    throw e;
  }
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
  // v413 — parité app : fiche animal enrichie (synchro app↔web, mêmes champs).
  gender?: string; // 'male' | 'female' | ''
  characterTraits?: string[];
  vaccinationStatus?: string; // 'up_to_date' | 'late' | 'unknown'
  history?: string;
  notes?: string;
  habits?: { remarks?: string; [k: string]: unknown };
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

// Tarif de promenade (walker) : { durationMinutes, basePrice, currency }.
export type WalkRate = {
  durationMinutes: number;
  basePrice: number;
  currency?: string;
  enabled?: boolean;
};

export type ProviderReview = {
  id: string;
  reviewerName?: string;
  reviewerImage?: string;
  rating: number;
  comment?: string;
  createdAt?: string;
};

export type ProviderProfile = {
  id: string;
  name: string;
  email?: string;
  bio?: string;
  skills?: string;
  service?: string;
  avatar?: { url?: string; publicId?: string };
  // Sitter : tarifs jour / semaine / mois (+ legacy hourlyRate).
  hourlyRate?: number;
  dailyRate?: number;
  weeklyRate?: number;
  monthlyRate?: number;
  // Walker : tableau de tarifs par durée (30/60/90/120 min…).
  walkRates?: WalkRate[];
  // v435 — animal supplémentaire + temps de réponse moyen (sitter & walker).
  extraPetRate?: number;
  responseTimeMinutes?: number | null;
  // Animaux acceptés (sitter) / promenés (walker) + expérience.
  acceptedPetTypes?: string[];
  experienceTags?: string[];
  rating?: number;
  averageRating?: number;
  reviewsCount?: number;
  reviews?: ProviderReview[];
  // Prestations réalisées (loyalty) : gardes (sitter) / promenades (walker).
  completedServicesCount?: number;
  completedWalksCount?: number;
  location?: { city?: string; lat?: number; lng?: number };
  isBoosted?: boolean;
  isMapBoosted?: boolean;
  // v23.1.270 — statut mérite "Top" (loyalty : 20+ services + note > 4.5),
  // distinct du boost payé. Présents dans la réponse /sitters /walkers.
  isTopSitter?: boolean;
  isTopWalker?: boolean;
  // Disponibilités (mêmes champs que l'app). Parfois inclus dans la réponse
  // /sitters/:id ; sinon récupérées via getProviderAvailability().
  availableDates?: string[];
  unavailableDates?: string[];
  availableTimeSlots?: AvailabilityTimeSlot[];
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

// v23.1.259 — flux de confirmation de service (séquestre du paiement).
//   none / awaiting_start  → provider peut "J'ai récupéré l'animal" (start)
//   in_progress            → provider peut "J'ai rendu l'animal"   (complete)
//   awaiting_confirmation  → owner peut "Tout est ok" (confirm) / "Signaler" (dispute)
//   confirmed              → paiement libéré au prestataire
//   disputed               → paiement bloqué
export type ConfirmationStatus =
  | "none"
  | "awaiting_start"
  | "in_progress"
  | "awaiting_confirmation"
  | "confirmed"
  | "disputed";

// Animal embarqué dans une réservation (renvoyé par GET /bookings/my).
export type BookingPet = {
  id: string;
  petName?: string;
  breed?: string;
  category?: string;
  avatar?: { url?: string; publicId?: string };
};

// Contrepartie d'une réservation (sitter/walker vue par l'owner, ou owner vu
// par le prestataire) telle que renvoyée par GET /bookings/my.
export type BookingOtherParty = {
  id: string;
  name: string;
  email?: string;
  avatar?: string;
  phone?: string;
  rating?: number;
  reviewsCount?: number;
  location?: string;
};

export type Booking = {
  id: string;
  ownerId?: string;
  sitterId?: string;
  walkerId?: string;
  petIds?: string[];
  pets?: BookingPet[];
  status: BookingStatus;
  serviceType?: string;
  serviceDate?: string;
  date?: string;
  timeSlot?: string;
  startDate?: string;
  endDate?: string;
  basePrice?: number;
  totalAmount?: number;
  currency?: string;
  paymentStatus?: "pending" | "paid" | "cancelled" | "refund" | "refunded";
  paidAt?: string;
  createdAt?: string;
  // v23.1.259 — confirmation de service + timestamps associés.
  confirmationStatus?: ConfirmationStatus;
  serviceStartedAt?: string | null;
  serviceEndedAt?: string | null;
  autoReleaseAt?: string | null;
  // GET /bookings/my renvoie une contrepartie agrégée + pricing détaillé.
  otherParty?: BookingOtherParty;
  pricing?: {
    basePrice?: number;
    totalPrice?: number;
    netPayout?: number;
    platformFee?: number;
    currency?: string;
  };
  houseSittingVenue?: string | null;
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

// v23.1 part 240 — Daniel : "fix le sur le site web aussi". Sur mobile la
// PawMap centrait sur la position de l'user au lieu de celle du sitter
// quand on tapait "Voir la carte". Sur le site web, /walk/:bookingId
// affichait une carte vide centree sur Paris jusqu'a recevoir un event
// socket — donc si le walker n'avait pas encore broadcast, l'owner voyait
// la France entiere au lieu de la derniere position connue.
//
// Cet helper appelle GET /bookings/:id/provider-location qui retourne :
//   { providerRole, providerName, coordinates: { lat, lng }, updatedAt }
// et qui exige : owner auth + PawFollow + booking paid. 204 => pas encore
// de position partagee ; 402 => abonnement PawFollow manquant ; 409 =>
// booking pas paye.
export type ProviderLocation = {
  providerRole: "sitter" | "walker";
  providerName: string;
  providerAvatar?: string;
  coordinates: { lat: number; lng: number };
  updatedAt?: string | null;
};

export async function getProviderLocation(
  bookingId: string,
): Promise<ProviderLocation | null> {
  try {
    const raw = await request<ProviderLocation & { error?: string; code?: string }>(
      `/bookings/${bookingId}/provider-location`,
    );
    if (!raw || !raw.coordinates) return null;
    return raw;
  } catch (e) {
    // 204 NO_LOCATION_YET / 402 PAWFOLLOW_REQUIRED / 409 not-paid : on
    // ne crashe pas la carte, on retourne null et le composant gere.
    if (e instanceof ApiError) {
      if (e.status === 204 || e.status === 402 || e.status === 409 || e.status === 404) {
        return null;
      }
    }
    throw e;
  }
}

// ─── v23.1 part 243 round 3 — PawFollow Friends side ────────────────────
// Daniel : "il faut mettre a jour le site web tout le paw follow suivre
// les utilisateurs rien nest fais". On expose la liste d'amis acceptes
// + leur derniere position connue pour pouvoir construire la page
// /friends/live (l'equivalent web de la PawMap mobile).

export type FriendOther = {
  id: string;
  model: "Owner" | "Sitter" | "Walker" | string;
  name: string;
  email: string;
  avatar: string;
  city?: string;
  deleted?: boolean;
  hasPawFollow?: boolean;
  // v23.1.280 — Daniel : "si l'ami a l'option PawSpot, anneau doré/bleu selon
  // l'option" (parité avec l'app). Tier PawSpot actif renvoyé par
  // fetchUserMini : 'bronze' | 'silver' | 'gold' | 'platinum' | null.
  pawSpotTier?: string | null;
  // v500 — Daniel : « couronne premium pas sur le web ». Le backend renvoie
  // isPremium par ami (fetchUserMini) mais le type ne l'exposait pas → la carte
  // web ne pouvait pas mettre la couronne 👑 sur un ami premium.
  isPremium?: boolean;
};

export type FriendItem = {
  id: string;
  status: "accepted" | "pending" | "declined" | "blocked_pending_cleanup";
  initiatedByMe: boolean;
  other: FriendOther;
  mySharePosition: boolean;
  theirSharePosition: boolean;
  myShareAutoByPawFollow?: boolean;
  createdAt?: string;
  acceptedAt?: string;
};

export async function getMyFriends(): Promise<FriendItem[]> {
  try {
    const raw = await request<{ friends?: FriendItem[] }>(`/friends`);
    return Array.isArray(raw?.friends) ? raw.friends : [];
  } catch (e) {
    if (e instanceof ApiError && (e.status === 401 || e.status === 404)) {
      return [];
    }
    throw e;
  }
}

export type FriendLastPosition = {
  lat: number | null;
  lng: number | null;
  otherModel?: string;
  city?: string;
};

/**
 * v23.1.366 — bulk "dernières positions amis/famille" : MÊME source que
 * l'app mobile (règles d'accès opt-out > famille > PawFollow > share flag,
 * fraîcheur < 24 h encapsulées côté serveur).
 */
export type FriendBulkPosition = {
  userId: string;
  role: string;
  lat: number;
  lng: number;
  at?: string;
  city?: string;
};
export async function getFriendsLivePositions(): Promise<FriendBulkPosition[]> {
  try {
    const raw = await request<{ positions?: FriendBulkPosition[] }>(
      `/friends/live-positions`,
    );
    return Array.isArray(raw?.positions) ? raw.positions : [];
  } catch {
    return [];
  }
}

export async function getFriendLastPosition(
  friendUserId: string,
): Promise<FriendLastPosition | null> {
  try {
    const raw = await request<FriendLastPosition>(
      `/friends/${friendUserId}/last-position`,
    );
    if (raw === null || raw === undefined) return null;
    return raw;
  } catch (e) {
    // 403 (opted out / pas autorise) / 404 / 502 → on retourne null pour
    // que la page n'affiche pas de marker mais ne crash pas.
    if (
      e instanceof ApiError &&
      (e.status === 403 || e.status === 404 || e.status === 502)
    ) {
      return null;
    }
    throw e;
  }
}

// ─── v23.1 part 246 — Family members (PawFollow Famille) ─────────────────
// Daniel : "ameliorer liste amis et famille". Le backend expose deja
// GET /friends/family/members qui retourne les 5 membres famille du
// titulaire. On l'utilise pour separer la liste cote /friends/live en
// deux sections distinctes (Famille vs Amis) + appliquer le code couleur
// violet quand on est dans la famille.

export type FamilyMember = {
  id: string;
  role: AuthRole;
  name: string;
  avatar: string;
  addedAt?: string;
  email?: string | null;
  status: "pending" | "active" | "declined" | string;
  // v23.1.399 — PawPremium actif → couronne 👑 + anneau OR sur la carte.
  isPremium?: boolean;
};

export type FamilyResponse = {
  hasActiveFamilyPlan: boolean;
  members: FamilyMember[];
  remainingSlots: number;
};

export async function getMyFamily(): Promise<FamilyResponse> {
  try {
    const raw = await request<FamilyResponse>(`/friends/family/members`);
    return {
      hasActiveFamilyPlan: !!raw?.hasActiveFamilyPlan,
      members: Array.isArray(raw?.members) ? raw.members : [],
      remainingSlots: typeof raw?.remainingSlots === "number"
        ? raw.remainingSlots
        : 0,
    };
  } catch (e) {
    if (e instanceof ApiError && (e.status === 401 || e.status === 404)) {
      return { hasActiveFamilyPlan: false, members: [], remainingSlots: 0 };
    }
    throw e;
  }
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

// ─── Paiement d'une réservation depuis le SITE (parité app) ──────────────────
// Jusqu'ici le paiement d'un booking était délégué à l'app mobile. On expose
// désormais les mêmes endpoints que l'app pour permettre à l'owner de payer
// une réservation acceptée/convenue directement sur le web :
//   POST /bookings/:id/create-payment-intent        → Airwallex (HPP via /pay)
//   POST /bookings/:id/paypal/create-order           → PayPal (approveUrl)
//   POST /bookings/:id/paypal/capture/:orderId       → capture PayPal
//   POST /bookings/:id/confirm-payment/:paymentIntentId → confirme côté backend

// Réponse de POST /bookings/:id/create-payment-intent (Airwallex). Le backend
// renvoie le couple intentId + clientSecret consommé par le pont HPP /pay.
export type BookingPaymentIntent = {
  paymentIntentId: string;
  clientSecret: string;
  amount?: number;
  currency?: string;
  commissionAmount?: number;
  netSitterAmount?: number;
  // Carte sauvegardée confirmée côté serveur → on peut sauter l'HPP.
  serverConfirmed?: boolean;
  nextActionUrl?: string | null;
  savedCardError?: string | null;
  booking?: Booking;
  message?: string;
};

/** Crée (ou réutilise) le PaymentIntent Airwallex d'une réservation. */
export async function createBookingPaymentIntent(
  bookingId: string,
): Promise<BookingPaymentIntent> {
  return await request<BookingPaymentIntent>(
    `/bookings/${bookingId}/create-payment-intent`,
    { method: "POST", body: JSON.stringify({}) },
  );
}

/** Confirme le paiement d'une réservation après retour Airwallex (HPP). */
export async function confirmBookingPayment(
  bookingId: string,
  paymentIntentId: string,
): Promise<{ booking?: Booking; paymentIntent?: Record<string, unknown> }> {
  return await request(
    `/bookings/${bookingId}/confirm-payment/${encodeURIComponent(paymentIntentId)}`,
    { method: "POST", body: JSON.stringify({}) },
  );
}

// Réponse de POST /bookings/:id/paypal/create-order. `approveUrl` (alias
// `approvalUrl`) est l'URL PayPal vers laquelle rediriger l'owner.
export type BookingPaypalOrder = {
  orderId: string;
  status?: string;
  approveUrl?: string | null;
  approvalUrl?: string | null;
  booking?: Booking;
  message?: string;
};

/** Crée (ou réutilise) une commande PayPal pour une réservation. */
export async function createBookingPaypalOrder(
  bookingId: string,
): Promise<BookingPaypalOrder> {
  return await request<BookingPaypalOrder>(
    `/bookings/${bookingId}/paypal/create-order`,
    { method: "POST", body: JSON.stringify({}) },
  );
}

/** Capture une commande PayPal approuvée → marque la réservation payée. */
export async function captureBookingPaypalPayment(
  bookingId: string,
  orderId: string,
): Promise<{ orderId: string; status?: string; booking?: Booking; message?: string }> {
  return await request(
    `/bookings/${bookingId}/paypal/capture/${encodeURIComponent(orderId)}`,
    { method: "POST", body: JSON.stringify({}) },
  );
}

// ─── Confirmation de service (v23.1.259 — parité app) ───────────────────────
// Mêmes endpoints que l'app mobile. Le flux gate la libération du paiement :
// le prestataire démarre puis termine, l'owner confirme (= "Mission terminée")
// ce qui LIBÈRE le paiement, ou signale un problème (paiement bloqué).
//
// Réponse commune : { success, confirmationStatus, ... }.
type ServiceActionResult = {
  success?: boolean;
  confirmationStatus?: ConfirmationStatus;
  serviceStartedAt?: string;
  serviceEndedAt?: string;
  autoReleaseAt?: string;
  ownerConfirmedAt?: string;
  disputedAt?: string;
  alreadyConfirmed?: boolean;
};

/** Provider (sitter/walker) : "🐾 J'ai récupéré l'animal" → confirmationStatus=in_progress. */
export async function startService(bookingId: string): Promise<ServiceActionResult> {
  return request<ServiceActionResult>(`/bookings/${bookingId}/service/start`, {
    method: "POST",
    body: JSON.stringify({}),
  });
}

/** Provider (sitter/walker) : "✅ J'ai rendu l'animal" → confirmationStatus=awaiting_confirmation. */
export async function completeService(bookingId: string): Promise<ServiceActionResult> {
  return request<ServiceActionResult>(`/bookings/${bookingId}/service/complete`, {
    method: "POST",
    body: JSON.stringify({}),
  });
}

/** Owner : "Tout est ok ✅" (Mission terminée) → confirmationStatus=confirmed + libère le paiement. */
export async function confirmService(bookingId: string): Promise<ServiceActionResult> {
  return request<ServiceActionResult>(`/bookings/${bookingId}/service/confirm`, {
    method: "POST",
    body: JSON.stringify({}),
  });
}

/** Owner : "Signaler un problème" → confirmationStatus=disputed + bloque le paiement. */
export async function disputeService(
  bookingId: string,
  reason?: string,
): Promise<ServiceActionResult> {
  return request<ServiceActionResult>(`/bookings/${bookingId}/service/dispute`, {
    method: "POST",
    body: JSON.stringify(reason ? { reason } : {}),
  });
}

// ─── Avis / Reviews (v23.1.290 — parité app) ────────────────────────────────
// L'owner note le prestataire (et inversement) APRÈS un service payé/confirmé.
// Le backend exige une réservation 'paid' ou 'completed' entre les 2 parties
// (trust-chain) + un seul avis par réservation.
export type MyReview = {
  id?: string;
  _id?: string;
  rating: number;
  comment?: string;
  bookingId?: string;
  revieweeId?: string;
  createdAt?: string;
};

/** Soumet un avis (note 1-5 + commentaire) sur le prestataire ou l'owner. */
export async function submitReview(input: {
  revieweeId: string;
  rating: number;
  comment?: string;
  bookingId?: string;
  revieweeRole?: "sitter" | "walker" | "owner";
}): Promise<{ reviewId?: string; id?: string }> {
  const body: Record<string, unknown> = {
    revieweeId: input.revieweeId,
    rating: input.rating,
    comment: input.comment || "",
  };
  if (input.bookingId) body.bookingId = input.bookingId;
  if (input.revieweeRole) body.revieweeRole = input.revieweeRole;
  return request(`/reviews`, { method: "POST", body: JSON.stringify(body) });
}

/** Récupère l'avis déjà laissé par l'utilisateur pour une réservation (ou null). */
export async function getMyReview(bookingId: string): Promise<MyReview | null> {
  try {
    const raw = await request<{ review?: MyReview | null }>(
      `/reviews/mine?bookingId=${encodeURIComponent(bookingId)}`,
    );
    return raw.review ?? null;
  } catch (e) {
    if (e instanceof ApiError && (e.status === 404 || e.status === 401)) return null;
    throw e;
  }
}

/** Modifie un avis existant (note + commentaire). */
export async function updateReview(
  reviewId: string,
  rating: number,
  comment: string,
): Promise<MyReview> {
  const raw = await request<{ review?: MyReview } & MyReview>(`/reviews/${reviewId}`, {
    method: "PUT",
    body: JSON.stringify({ rating, comment }),
  });
  return (raw.review as MyReview) || (raw as MyReview);
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
  // v23.1 part 243 round 3 — Daniel : "qd jouvre mon compte que ce soit sur
  // android web ou ios jai les memes messages partout". Le backend renvoie
  // `friendChat=true` + `otherParty` pour les chats friend-to-friend, mais
  // le web ne les modelait pas → friendChats invisibles dans la liste.
  friendChat?: boolean;
  otherParty?: {
    id: string;
    name: string;
    email: string;
    avatar: string;
    role: AuthRole;
  };
};

export type ChatMessage = {
  id: string;
  body: string;
  senderRole: AuthRole;
  senderId: string;
  createdAt: string;
  attachments?: Array<{ type?: string; url: string; publicId?: string }>;
  // v413 — suivi animal dans le chat web : type 'pawfollow_request' + metadata
  // (status pending/accepted/refused, responderRole, bookingId…).
  type?: string;
  metadata?: Record<string, unknown>;
};

// v413 — PawFamily : ajouter/retirer un membre depuis le web (réutilise le
// type FamilyMember + getMyFamily existants plus haut).
export async function inviteFamilyByEmail(
  email: string,
): Promise<{ success?: boolean; mode?: string; remainingSlots?: number; error?: string }> {
  return request("/friends/family/invite-by-email", {
    method: "POST",
    body: JSON.stringify({ email }),
  });
}

export async function removeFamilyMember(userId: string): Promise<{ success?: boolean }> {
  return request(`/friends/family/member/${userId}`, { method: "DELETE" });
}

/** v413 — Demande de suivi en direct depuis une conversation (chat web). */
export async function requestFollowByConversation(
  conversationId: string,
): Promise<{ success?: boolean; chatMessageId?: string }> {
  return request(`/conversations/${conversationId}/follow-request`, {
    method: "POST",
    body: JSON.stringify({}),
  });
}

/** v413 — Répondre à une demande de suivi (carte pawfollow_request). */
export async function respondPawfollowRequest(
  messageId: string,
  action: "accept" | "refuse",
): Promise<{ ok?: boolean }> {
  return request(`/bookings/pawfollow-request/${messageId}/respond`, {
    method: "POST",
    body: JSON.stringify({ action }),
  });
}

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

/** v413 — Envoi d'un message avec photo(s) dans le chat web (max 5). */
export async function sendMessageWithAttachments(
  conversationId: string,
  files: File[],
  body = "",
): Promise<ChatMessage> {
  const user = getStoredUser();
  if (!user) throw new ApiError("Not logged in", 401);
  const fd = new FormData();
  fd.append("senderRole", user.role);
  fd.append("senderId", user.id);
  if (body) fd.append("body", body);
  for (const f of files.slice(0, 5)) fd.append("files", f);
  const raw = await request<{ message?: ChatMessage } & ChatMessage>(
    `/conversations/${conversationId}/messages/attachments`,
    { method: "POST", body: fd },
  );
  return raw.message ?? (raw as ChatMessage);
}

// v23.1 part 248b — Daniel : "le bouton ... il faut quil ouvre un chat
// avec un amis qui choisis". Helper qui hit POST /conversations/friend
// avec { targetUserId, targetUserRole } et retourne la conversation id.
// Le backend (v23.1.200) cree la conv friendChat ou retourne l'existante
// si deja la (idempotent serveur-side). Status 200 si deja existante,
// 201 si nouvelle — on traite les 2 pareil.
export async function startFriendConversation(input: {
  targetUserId: string;
  targetUserRole: AuthRole;
}): Promise<{ conversationId: string; existed: boolean }> {
  const raw = await request<{
    conversation: { id: string };
    existed?: boolean;
  }>(`/conversations/friend`, {
    method: "POST",
    body: JSON.stringify(input),
  });
  return {
    conversationId: String(raw?.conversation?.id || ""),
    existed: !!raw?.existed,
  };
}

// v23.1 part 248 — Daniel : "dans messag il manque le bouton pour effacer
// la conversation". Backend DELETE /conversations/:id existe depuis
// v23.1 part 240 et supporte deja les friendChat (cf. la route conversation
// routes l.449). On l'expose ici en helper. La suppression est hard delete
// (messages + doc Conversation), idempotent : si deja deleted, on
// retourne quand meme success cote UI.
export async function deleteConversation(conversationId: string): Promise<boolean> {
  try {
    await request<{ deleted: boolean }>(
      `/conversations/${conversationId}`,
      { method: "DELETE" },
    );
    return true;
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) {
      return true; // deja supprime
    }
    throw e;
  }
}

// ─── Annonces / Posts (v402 — parité app, 100% additif) ─────────────────────

export type PostComment = {
  _id?: string;
  id?: string;
  comment?: string;
  body?: string;
  authorName?: string;
  name?: string;
  createdAt?: string;
};

// Animal enrichi tel que renvoyé par /posts/requests, /posts/my, /posts/by-id.
// Le backend (postController) sérialise nom/race/âge/sexe + traits de caractère
// + photos pour la carte « Caractère des animaux » et la bande animaux.
export type PostPet = {
  id?: string;
  petName?: string;
  avatar?: string;
  category?: string;
  breed?: string;
  bio?: string;
  age?: number | null;
  sex?: string; // 'male' | 'female' | ''
  characterTraits?: string[];
  vaccinationStatus?: string;
  sterilized?: boolean;
  microchipped?: boolean;
  photos?: Array<{ url?: string; publicId?: string }>;
};

export type RequestPost = {
  id?: string;
  _id?: string;
  body?: string;
  notes?: string;
  serviceTypes?: string[];
  startDate?: string;
  endDate?: string;
  timeSlot?: string;
  houseSittingVenue?: string | null;
  // v436 — lieu de garde : at_owner | at_sitter | both.
  serviceLocation?: string;
  animalCount?: number;
  animalTypes?: string[];
  postType?: string;
  status?: string;
  createdAt?: string;
  // v420 — bio owner pour la section « À propos de moi » du détail d'annonce.
  owner?: { id?: string; name?: string; email?: string; avatar?: string; bio?: string };
  ownerId?: string | { _id?: string; id?: string; name?: string };
  isOwnerBoosted?: boolean;
  ownerBoostTier?: string | null;
  likes?: Array<{ userId?: string }>;
  likesCount?: number;
  commentsCount?: number;
  comments?: PostComment[];
  pets?: PostPet[];
  media?: Array<{ url: string; type?: string }>;
  images?: Array<{ url: string }>;
};

export type CreatePostInput = {
  body: string;
  serviceTypes?: string[];
  startDate?: string;
  endDate?: string;
  houseSittingVenue?: "owners_home" | "sitters_home";
  petId?: string;
  notes?: string;
  location?: { city?: string; lat?: number; lng?: number };
  animalCount?: number;
  animalTypes?: string[];
};

// Canonical service keys (match the app + backend filtering: dog_walking is
// walker-exclusive, sitters see house_sitting / day_care).
export const POST_SERVICE_TYPES = ["house_sitting", "day_care", "dog_walking"] as const;

function postId(p: RequestPost): string {
  return String(p.id || p._id || "");
}
export { postId };

export async function createPost(input: CreatePostInput): Promise<RequestPost> {
  const raw = await request<{ post?: RequestPost } & RequestPost>("/posts", {
    method: "POST",
    body: JSON.stringify(input),
  });
  return (raw.post as RequestPost) || (raw as RequestPost);
}

// v402 — annonce AVEC photos. Le backend /posts/with-media accepte
// postType='request' (additif) → l'annonce porte ses images + apparaît dans le
// feed des demandes (et dans l'app). Champ multipart 'photos'.
export async function createPostWithMedia(input: CreatePostInput, files: File[]): Promise<RequestPost> {
  const fd = new FormData();
  fd.append("body", input.body);
  fd.append("postType", "request");
  (input.serviceTypes || []).forEach((s) => fd.append("serviceTypes", s));
  if (input.houseSittingVenue) fd.append("houseSittingVenue", input.houseSittingVenue);
  if (input.startDate) fd.append("startDate", input.startDate);
  if (input.endDate) fd.append("endDate", input.endDate);
  if (input.notes) fd.append("notes", input.notes);
  if (input.animalCount) fd.append("animalCount", String(input.animalCount));
  (input.animalTypes || []).forEach((tp) => fd.append("animalTypes", tp));
  files.forEach((f) => fd.append("photos", f));
  const raw = await request<{ post?: RequestPost } & RequestPost>("/posts/with-media", {
    method: "POST",
    body: fd,
  });
  return (raw.post as RequestPost) || (raw as RequestPost);
}

export async function getRequestPosts(): Promise<RequestPost[]> {
  const raw = await request<{ posts?: RequestPost[] }>("/posts/requests");
  return raw.posts || [];
}

export async function getMyPosts(): Promise<RequestPost[]> {
  const raw = await request<{ posts?: RequestPost[] }>("/posts/my");
  return raw.posts || [];
}

export async function getPostById(id: string): Promise<RequestPost | null> {
  const raw = await request<{ post?: RequestPost } & RequestPost>(`/posts/by-id/${id}`);
  return (raw.post as RequestPost) || (raw as RequestPost) || null;
}

export async function deletePost(id: string): Promise<boolean> {
  try {
    await request(`/posts/${id}`, { method: "DELETE" });
    return true;
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) return true;
    throw e;
  }
}

export async function toggleLikePost(id: string): Promise<void> {
  await request(`/posts/${id}/like`, { method: "POST" });
}

export async function addPostComment(id: string, comment: string): Promise<void> {
  await request(`/posts/${id}/comments`, {
    method: "POST",
    body: JSON.stringify({ comment }),
  });
}

// Démarrer une conversation avec un owner depuis une annonce (sitter/walker).
// Le backend applique la même règle d'accès que l'app : si pas de booking payé
// ni Premium/Chat add-on → 402 CHAT_ACCESS_REQUIRED (le composant montre alors
// l'upsell). Retourne l'id de conversation en cas de succès.
export async function contactOwnerAboutPost(
  ownerId: string,
  message: string,
): Promise<{ conversationId: string }> {
  const role = getStoredUser()?.role;
  const path = role === "walker" ? "start-by-walker" : "start-by-sitter";
  const raw = await request<{ conversation?: { id?: string; _id?: string } }>(
    `/conversations/${path}?ownerId=${encodeURIComponent(ownerId)}`,
    { method: "POST", body: JSON.stringify({ message }) },
  );
  return {
    conversationId: String(raw?.conversation?.id || raw?.conversation?._id || ""),
  };
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
  | "construction"
  | "food"
  | "trash"
  // v414 — nouveaux types de signalements.
  | "vet_open"
  | "leash_required"
  | "heat_hot_ground"
  | "tick_zone";

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

// v497 — Daniel : « rajoute les 4 boutons PawMap sur le web ». Création d'un
// SIGNALEMENT depuis le web (POST /map-reports). Gated côté backend (402
// PREMIUM_REQUIRED pour les types premium) → la page /map catche l'ApiError et
// propose la boutique. Position = centre de la carte.
export async function createMapReport(opts: {
  type: MapReportType;
  lat: number;
  lng: number;
  note?: string;
  city?: string;
}): Promise<void> {
  await request("/map-reports", {
    method: "POST",
    body: JSON.stringify({
      type: opts.type,
      lat: opts.lat,
      lng: opts.lng,
      note: opts.note || "",
      city: opts.city || "",
    }),
  });
}

// ─── Carte unique /map : PawSpots communautaires + itinéraire + benefits ────
// Daniel : "sur le site web, UNE SEULE carte". La page /map fusionne la
// couche amis/famille en direct (ex /friends/live), les spots communautaires
// PawSpot et l'itinéraire piéton (inclus PawFollow / PawFamily).

export type PawSpotType =
  | "path_walk"
  | "chill"
  | "playground"
  | "swimming"
  | "food_cafe"
  | "other";

export type PawSpot = {
  id: string;
  type: PawSpotType;
  name: string;
  description?: string;
  photoUrl?: string;
  lat: number;
  lng: number;
  city?: string;
  creatorName?: string;
  likesCount: number;
  validationsCount: number;
  visitsCount: number;
  commentsCount: number;
  communityValidated: boolean;
  isGolden: boolean;
  featured: boolean;
  quality: number;
};

export async function getNearbyPawSpots(opts: {
  lat: number;
  lng: number;
  radius?: number;
}): Promise<PawSpot[]> {
  const qs = new URLSearchParams({
    lat: String(opts.lat),
    lng: String(opts.lng),
  });
  if (opts.radius) qs.set("radius", String(opts.radius));
  const raw = await request<{ spots?: PawSpot[] }>(
    `/pawspots/nearby?${qs.toString()}`,
  );
  // Défensif : on écarte les spots sans coordonnées exploitables.
  return (raw.spots || []).filter(
    (s) => typeof s.lat === "number" && typeof s.lng === "number",
  );
}

// v497 — Daniel : « les notifs/emails manquent le pack langue sur le web ».
// Le site ne poussait JAMAIS la langue choisie au backend (seule l'app le
// faisait) → notifications + emails partaient dans la dernière langue connue.
// On synchronise la langue UI du site (PATCH /users/me/app-locale) → notifs +
// emails suivent désormais la langue du site. Best-effort, silencieux.
export async function syncAppLocale(locale: string): Promise<void> {
  await request("/users/me/app-locale", {
    method: "PATCH",
    body: JSON.stringify({ locale }),
  });
}

// v497 — Daniel : « je vois les utilisateurs en rose sur le web ? ». Membres
// PawMap proches (TOUS rôles, abonnés actifs) — même endpoint que l'app.
export type NearbyMember = {
  id: string;
  role: string;
  name: string;
  avatar: string;
  location: { coordinates: [number, number] };
  isPremium: boolean;
  isPawSpot: boolean;
  isOnline: boolean;
};
export async function getNearbyMembers(opts: {
  lat: number;
  lng: number;
  radiusInMeters?: number;
}): Promise<NearbyMember[]> {
  const qs = new URLSearchParams({
    lat: String(opts.lat),
    lng: String(opts.lng),
  });
  if (opts.radiusInMeters)
    qs.set("radiusInMeters", String(opts.radiusInMeters));
  const raw = await request<{ members?: NearbyMember[] }>(
    `/friends/members/nearby?${qs.toString()}`,
  );
  return (raw.members || []).filter(
    (m) =>
      Array.isArray(m.location?.coordinates) &&
      m.location.coordinates.length >= 2,
  );
}

// v497 — Daniel : « le compteur de visites du spot doit marcher sur le web ».
// POST /pawspots/:id/visit (1×/user, géré backend) → renvoie le nouveau total.
export async function visitSpot(id: string): Promise<number> {
  const r = await request<{ visitsCount?: number }>(`/pawspots/${id}/visit`, {
    method: "POST",
  });
  return typeof r?.visitsCount === "number" ? r.visitsCount : 0;
}

// v497 — création d'un PAWSPOT depuis le web (POST /pawspots). 402
// PAWSPOT_REQUIRED si quota gratuit dépassé sans abo. Position = centre carte.
export async function createPawSpot(opts: {
  type: PawSpotType;
  name: string;
  lat: number;
  lng: number;
  description?: string;
  city?: string;
}): Promise<void> {
  await request("/pawspots", {
    method: "POST",
    body: JSON.stringify({
      type: opts.type,
      name: opts.name,
      description: opts.description || "",
      lat: opts.lat,
      lng: opts.lng,
      city: opts.city || "",
    }),
  });
}

export type RouteResult = {
  points: { lat: number; lng: number }[];
  distanceMeters: number | null;
  durationSeconds: number | null;
};

// GET /pawspots/directions — itinéraire piéton (OSRM côté backend, fallback
// ligne droite avec distanceMeters/durationSeconds null). 402 + code
// PAWFOLLOW_REQUIRED si pas d'abonnement PawFollow / PawFamily : on laisse
// l'ApiError remonter pour que la page affiche le message + lien /boutique.
export async function getPawSpotDirections(opts: {
  fromLat: number;
  fromLng: number;
  toLat: number;
  toLng: number;
}): Promise<RouteResult> {
  const qs = new URLSearchParams({
    fromLat: String(opts.fromLat),
    fromLng: String(opts.fromLng),
    toLat: String(opts.toLat),
    toLng: String(opts.toLng),
  });
  const raw = await request<RouteResult>(
    `/pawspots/directions?${qs.toString()}`,
  );
  return {
    points: Array.isArray(raw?.points) ? raw.points : [],
    distanceMeters: raw?.distanceMeters ?? null,
    durationSeconds: raw?.durationSeconds ?? null,
  };
}

// GET /users/me/benefits — flags d'avantages actifs pour colorer les chips
// de la carte unique (PawFollow violet + 👑, PawSpot doré + 👑).
export type MyBenefits = {
  pawFollowActive: boolean;
  familyActive: boolean;
  pawspotActive: boolean;
  // v23.1.391 — PawPremium (bundle) + staff/abo individuel.
  premiumActive: boolean;
  isPremium: boolean;
};

export async function getMyBenefits(): Promise<MyBenefits | null> {
  try {
    const raw = await request<{
      pawFollowActive?: boolean;
      familyActive?: boolean;
      pawspotActive?: boolean;
      premiumActive?: boolean;
      isPremium?: boolean;
    }>(`/users/me/benefits`);
    return {
      premiumActive: !!raw?.premiumActive,
      isPremium: !!raw?.isPremium,
      pawFollowActive: !!raw?.pawFollowActive,
      familyActive: !!raw?.familyActive,
      pawspotActive: !!raw?.pawspotActive,
    };
  } catch {
    // Défensif : les chips restent grises (pas de crash de la carte).
    return null;
  }
}

// ─── Subscriptions (PawFollow Premium) ──────────────────────────────────────

export type SubscriptionPlan = {
  // v23.1.387 — élargi : + family_yearly, premium_monthly, premium_yearly.
  id: string;
  name?: string;
  /** Clé brute renvoyée par le backend (champ `plan`). */
  plan?: string;
  label?: string;
  amount: number;
  currency: string;
  intervalDays: number;
  amountPerDay?: number;
  features?: Record<string, boolean | number>;
};

export type SubscriptionStatus = {
  plan: string | null;
  status: "active" | "cancelled" | "expired" | "none";
  isPremium: boolean;
  // v23.1.387 — PawPremium (bundle PawFollow + PawSpot + extras).
  premiumBundleActive?: boolean;
  familyActive?: boolean;
  familyExpiry?: string | null;
  premiumExpiry?: string | null;
  pawspotExpiry?: string | null;
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
  // v23.1.387 — le backend renvoie la clé sous `plan` (pas `id`) : on
  // normalise pour que plan.id soit TOUJOURS rempli (labels, highlight,
  // filtres premium_* de la boutique).
  return (raw.plans || []).map((p) => ({
    ...p,
    id: p.id ?? p.plan ?? "",
  }));
}

export async function getSubscriptionStatus(): Promise<SubscriptionStatus> {
  return await request<SubscriptionStatus>("/subscriptions/status");
}

// ─── v414 — PawPoints : barème, badges, catalogue de récompenses (visible web).
export type PawReward = {
  id: string;
  title: string;
  description: string;
  icon: string;
  cost: number;
  kind: "discount" | "subscription" | "boost" | "badge" | "goodie";
  valueLabel: string;
  soldOut?: boolean;
};
export type PawEarnRule = { key: string; points: number; label: string; icon: string };
export type PawBadge = { key: string; emoji: string; min: number };
// v416 — niveau (palier de points à vie) + avantages.
export type PawLevel = {
  index: number;
  key: string;
  label: string;
  min: number;
  emoji: string;
  color: string;
  bonusPct: number;
  perks: string[];
};
// v416 — récompense abonnement (réduction / mois gratuit), auto-appliquée.
export type PawSubReward = {
  id: string;
  tier: number;
  cost: number;
  kind: "discount" | "free_month";
  percent?: number;
  days?: number;
  target: string;
  plan?: string;
  plans?: string[];
};
export type PawCatalog = {
  subscriptionRewards: PawSubReward[];
  rewards: PawReward[];
  levels: PawLevel[];
  earnRules: PawEarnRule[];
  goldCreatorMin: number;
};
export type MyPawPoints = {
  points: number;      // total à vie (= niveau)
  lifetime: number;
  spendable: number;   // solde dépensable
  contributions: number;
  spotsLiked: number;
  level: PawLevel | null;
  nextLevel: PawLevel | null;
  bonusPct: number;
  isGoldCreator: boolean;
  goldCreatorMin: number;
  levels: PawLevel[];
  earnRules: PawEarnRule[];
  claimedRewardKeys: string[];
};

// Public : pas besoin d'être connecté pour voir le catalogue.
export async function getPawPointsCatalog(): Promise<PawCatalog> {
  return await request<PawCatalog>("/pawpoints/catalog");
}

// Mes points (auth requise, tous rôles).
export async function getMyPawPoints(): Promise<MyPawPoints> {
  return await request<MyPawPoints>("/pawpoints/me");
}

// Échanger des points contre une récompense (id = sub_* ou ObjectId admin).
export async function redeemPawReward(
  rewardId: string,
  plan?: string,
): Promise<{ ok: boolean; newBalance: number; applied?: string; redemptionId: string }> {
  return await request(`/pawpoints/redeem/${rewardId}`, {
    method: "POST",
    body: JSON.stringify(plan ? { plan } : {}),
  });
}

// ─── Codes promo ──────────────────────────────────────────────────────────
// Vérifie un code promo (sans le consommer). Le backend renvoie le détail.
export type PromoCheck = {
  valid: boolean;
  rewardType?: string;
  plan?: string;
  intervalDays?: number;
  boostTier?: string;
  discountPercent?: number;
  campaign?: string;
};
export async function checkPromo(code: string): Promise<PromoCheck> {
  return await request("/promo/check", {
    method: "POST",
    body: JSON.stringify({ code }),
  });
}

// Échange un code promo (consomme la redemption). free_subscription est accordé
// immédiatement ; percent_discount s'applique au prochain /subscriptions/subscribe.
export type PromoRedeem = {
  ok: boolean;
  reward?: {
    rewardType?: string;
    plan?: string;
    intervalDays?: number;
    boostTier?: string;
    discountPercent?: number;
    campaign?: string;
  };
};
export async function redeemPromo(code: string): Promise<PromoRedeem> {
  return await request("/promo/redeem", {
    method: "POST",
    body: JSON.stringify({ code }),
  });
}

export async function subscribeToPlan(
  // v23.1.387 — + family_yearly, premium_monthly, premium_yearly.
  plan: string,
  currency?: string,
): Promise<{ clientSecret: string; paymentIntentId: string; amount: number; currency: string }> {
  return await request("/subscriptions/subscribe", {
    method: "POST",
    body: JSON.stringify({ plan, currency }),
  });
}

// v23.1.390 — achat PawSpot depuis le SITE (même HPP que l'app).
export async function subscribeToPawSpot(
  plan: string,
  currency?: string,
): Promise<{ clientSecret?: string; paymentIntentId?: string; amount?: number; currency?: string; activated?: boolean }> {
  return await request("/pawspots/subscribe", {
    method: "POST",
    body: JSON.stringify({ plan, currency }),
  });
}

export async function confirmPawSpot(
  plan: string,
  paymentIntentId: string,
): Promise<unknown> {
  return await request("/pawspots/confirm", {
    method: "POST",
    body: JSON.stringify({ plan, paymentIntentId }),
  });
}

export async function cancelSubscription(): Promise<SubscriptionStatus> {
  return await request("/subscriptions/cancel", { method: "POST" });
}

export async function resumeSubscription(): Promise<SubscriptionStatus> {
  return await request("/subscriptions/resume", { method: "POST" });
}

export type PaymentIntentResponse = {
  clientSecret: string;
  paymentIntentId: string;
  provider: string;
  amount: number;
  currency: string;
  // Selon le contexte :
  plan?: string;
  tier?: string;
  intervalDays?: number;
  days?: number;
};

export async function confirmSubscription(
  plan: string,
  paymentIntentId: string,
  currency?: string,
): Promise<SubscriptionStatus> {
  return await request("/subscriptions/confirm", {
    method: "POST",
    body: JSON.stringify({ plan, paymentIntentId, currency }),
  });
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

export async function purchaseBoost(
  tier: BoostTier,
  currency?: string,
): Promise<PaymentIntentResponse> {
  return await request("/boost/purchase", {
    method: "POST",
    body: JSON.stringify({ tier, currency }),
  });
}

export async function confirmBoost(
  tier: BoostTier,
  paymentIntentId: string,
  currency?: string,
): Promise<BoostStatus> {
  return await request("/boost/confirm", {
    method: "POST",
    body: JSON.stringify({ tier, paymentIntentId, currency }),
  });
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

export async function purchaseMapBoost(
  tier: BoostTier,
  currency?: string,
): Promise<PaymentIntentResponse> {
  return await request("/map-boost/purchase", {
    method: "POST",
    body: JSON.stringify({ tier, currency }),
  });
}

export async function confirmMapBoost(
  tier: BoostTier,
  paymentIntentId: string,
  currency?: string,
): Promise<BoostStatus> {
  return await request("/map-boost/confirm", {
    method: "POST",
    body: JSON.stringify({ tier, paymentIntentId, currency }),
  });
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
