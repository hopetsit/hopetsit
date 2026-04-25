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

function persistAuth(token: string, user: AuthUser) {
  try {
    window.localStorage.setItem(TOKEN_KEY, token);
    window.localStorage.setItem(ROLE_KEY, user.role);
    window.localStorage.setItem(USER_KEY, JSON.stringify(user));
  } catch { /* ignore */ }
}

export function clearAuth() {
  try {
    window.localStorage.removeItem(TOKEN_KEY);
    window.localStorage.removeItem(ROLE_KEY);
    window.localStorage.removeItem(USER_KEY);
  } catch { /* ignore */ }
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

// ─── Contact form ───────────────────────────────────────────────────────────

export async function sendContactMessage(input: {
  name: string;
  email: string;
  message: string;
}) {
  // Falls back to a no-op success if the backend doesn't expose this route
  // yet — we don't want the public site to error out before that ships.
  try {
    await request<{ ok: boolean }>("/contact", {
      method: "POST",
      body: JSON.stringify(input),
    });
    return { ok: true };
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) return { ok: true };
    throw e;
  }
}
