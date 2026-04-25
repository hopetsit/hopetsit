"use client";

// Tiny auth-state hook — reads the user from localStorage on mount and stays
// in sync across tabs (native `storage` event) and within the same tab
// (custom `hopetsit:auth-changed` event dispatched by api.ts).

import { useEffect, useState } from "react";
import { AuthUser, getStoredUser } from "./api";

export const AUTH_EVENT = "hopetsit:auth-changed";

export function useAuth() {
  const [user, setUser]       = useState<AuthUser | null>(null);
  const [ready, setReady]     = useState(false);

  useEffect(() => {
    setUser(getStoredUser());
    setReady(true);

    const refresh = () => setUser(getStoredUser());
    // Same-tab updates (login/logout from this app)
    window.addEventListener(AUTH_EVENT, refresh);
    // Cross-tab sync (user logs in/out from another tab)
    window.addEventListener("storage", refresh);
    return () => {
      window.removeEventListener(AUTH_EVENT, refresh);
      window.removeEventListener("storage", refresh);
    };
  }, []);

  return { user, ready };
}
