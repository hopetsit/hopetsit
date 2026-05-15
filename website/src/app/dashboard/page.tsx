"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { ApiError, AuthUser, clearAuth, getStoredUser, openInApp } from "@/lib/api";
import { useSocket, useSocketEvent } from "@/lib/useSocket";
import { disconnectSocket } from "@/lib/socket";

export default function DashboardPage() {
  const { t } = useT();
  const router = useRouter();
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);
  // v23.1 part 146 — états pour le bouton "Ouvrir dans l'app" (bridge OTT).
  const [openingApp, setOpeningApp] = useState(false);
  const [openAppError, setOpenAppError] = useState<string | null>(null);
  const [openAppHint, setOpenAppHint] = useState<string | null>(null);

  // v23.1 part 146 — socket.io temps réel.
  const { connected: socketConnected } = useSocket();
  // Toasts in-page pour les events critiques reçus.
  const [liveToast, setLiveToast] = useState<{ icon: string; text: string } | null>(null);
  const showLiveToast = (icon: string, text: string) => {
    setLiveToast({ icon, text });
    // Auto-dismiss après 6s.
    setTimeout(() => setLiveToast(null), 6000);
  };

  // Écoute des events les plus critiques (Phase 2 du rapport socket.io audit).
  // Phase 1 (chat) viendra avec l'UI dédiée. Phase 3 (GPS) reste mobile-only
  // pour l'instant (le site n'a pas encore d'écran tracking).
  useSocketEvent<{ bookingId: string; status?: string }>(
    "booking:paid",
    (data) => {
      showLiveToast("💰", `Paiement reçu pour ${data.bookingId.slice(0, 6)}…`);
    },
  );
  useSocketEvent<{ bookingId: string; status?: string }>(
    "booking:accepted",
    (data) => {
      showLiveToast("✅", `Réservation acceptée (${data.bookingId.slice(0, 6)}…)`);
    },
  );
  useSocketEvent<{ applicationId: string; profileName?: string }>(
    "application:new",
    (data) => {
      showLiveToast(
        "👋",
        `Nouvelle candidature${data.profileName ? ` de ${data.profileName}` : ""}`,
      );
    },
  );
  useSocketEvent<{ conversationId: string; body: string; senderRole?: string }>(
    "message:new",
    (data) => {
      const preview = data.body.length > 40 ? `${data.body.slice(0, 40)}…` : data.body;
      showLiveToast("💬", `Message : "${preview}"`);
    },
  );

  useEffect(() => {
    const u = getStoredUser();
    if (!u) {
      router.replace("/login");
      return;
    }
    setUser(u);
    setLoading(false);
  }, [router]);

  if (loading) {
    return <div className="mx-auto max-w-md px-4 py-24 text-center text-ink-muted">{t("common_loading")}</div>;
  }

  function logout() {
    // v23.1 part 146 — ferme aussi la connexion socket avant de clearAuth.
    // Sans ça le socket continuerait à recevoir des events pour le user
    // qu'on vient de déconnecter (et l'event `hopetsit:auth-changed` dispatché
    // par clearAuth s'occuperait du cleanup, mais on est plus défensif ici).
    disconnectSocket();
    clearAuth();
    router.replace("/");
  }

  /**
   * v23.1 part 146 — Ouvre l'app HoPetSit avec auto-login via bridge OTT.
   *
   * Flow :
   *   1. Appelle POST /auth/one-time-token (backend) avec le JWT actuel.
   *   2. Redirige vers `hopetsit://auth?ott=<token>` qui ouvre l'app si
   *      installée. L'app appelle ensuite /auth/exchange pour échanger
   *      l'OTT contre un JWT 30j et auto-login.
   *   3. Si l'app n'est pas installée → après 1.5s on suggère de la
   *      télécharger depuis /download.
   */
  async function handleOpenApp() {
    setOpenAppError(null);
    setOpenAppHint(null);
    setOpeningApp(true);

    // Heuristique : si la page perd le focus dans les 1.5s, c'est que
    // l'app a pris le relais. Sinon, probablement pas installée.
    let appOpened = false;
    const onVisibilityChange = () => {
      if (document.visibilityState === "hidden") appOpened = true;
    };
    document.addEventListener("visibilitychange", onVisibilityChange);

    try {
      await openInApp();
      setTimeout(() => {
        document.removeEventListener("visibilitychange", onVisibilityChange);
        setOpeningApp(false);
        if (!appOpened) {
          setOpenAppHint(t("dash_app_not_installed"));
        }
      }, 1500);
    } catch (e) {
      document.removeEventListener("visibilitychange", onVisibilityChange);
      setOpeningApp(false);
      if (e instanceof ApiError && e.status === 401) {
        // Session expirée côté site → on force re-login.
        clearAuth();
        router.replace("/login");
        return;
      }
      setOpenAppError(
        e instanceof Error ? e.message : t("common_error_generic"),
      );
    }
  }

  const roleColor = user?.role === "owner" ? "owner" : user?.role === "walker" ? "walker" : "sitter";

  return (
    <div className="mx-auto max-w-2xl px-4 py-16 md:py-24">
      {/* v23.1 part 146 — toast in-page pour les events socket reçus en live. */}
      {liveToast && (
        <div
          role="status"
          aria-live="polite"
          className="fixed left-1/2 top-6 z-50 -translate-x-1/2 transform rounded-full bg-ink px-5 py-3 text-sm font-medium text-white shadow-lg"
        >
          <span className="mr-2">{liveToast.icon}</span>
          {liveToast.text}
        </div>
      )}

      <div className={`rounded-3xl bg-${roleColor} p-8 text-white shadow-card md:p-12`}>
        <div className="flex items-center justify-between">
          <div className="text-sm font-medium uppercase tracking-wider opacity-80">
            {user?.role}
          </div>
          {/* v23.1 part 146 — indicateur de connexion socket temps réel.
              Vert si connecté (events live arrivent), gris sinon. */}
          <div
            className="flex items-center gap-1.5 text-xs opacity-75"
            title={socketConnected ? "Connecté en temps réel" : "Hors ligne"}
          >
            <span
              className={`inline-block h-2 w-2 rounded-full ${
                socketConnected ? "bg-green-400 animate-pulse" : "bg-white/40"
              }`}
              aria-hidden="true"
            />
            <span>{socketConnected ? "Live" : "Offline"}</span>
          </div>
        </div>
        <h1 className="mt-2 font-display text-3xl font-extrabold md:text-4xl">
          {t("dash_welcome")}, {user?.name?.split(" ")[0] || "you"} 👋
        </h1>
        <p className="mt-3 max-w-md text-white/85">{t("dash_sub")}</p>

        <div className="mt-7 flex flex-wrap gap-3">
          {/* v23.1 part 146 — vrai bouton bridge OTT (auto-login dans l'app)
              au lieu d'un simple <a href="hopetsit://"> qui ne faisait rien
              de plus que d'ouvrir l'app sur l'écran de splash. */}
          <button
            type="button"
            onClick={handleOpenApp}
            disabled={openingApp}
            className="inline-flex items-center gap-2 rounded-full bg-white px-5 py-2.5 text-sm font-semibold text-ink shadow-sm transition hover:bg-bg-soft disabled:cursor-not-allowed disabled:opacity-70"
          >
            {openingApp && (
              <svg
                className="h-4 w-4 animate-spin"
                viewBox="0 0 24 24"
                fill="none"
                aria-hidden="true"
              >
                <circle cx="12" cy="12" r="10" stroke="currentColor" strokeOpacity="0.25" strokeWidth="3" />
                <path d="M22 12a10 10 0 0 1-10 10" stroke="currentColor" strokeWidth="3" strokeLinecap="round" />
              </svg>
            )}
            <span>{openingApp ? t("dash_opening_app") : t("dash_open_app")}</span>
          </button>
          <Link
            href="/download"
            className="rounded-full border border-white/40 px-5 py-2.5 text-sm font-semibold text-white hover:bg-white/10"
          >
            {t("dash_download_app")}
          </Link>
        </div>

        {(openAppError || openAppHint) && (
          <div className="mt-4 rounded-xl bg-white/15 px-4 py-3 text-sm text-white">
            {openAppError ? (
              <span role="alert">{openAppError}</span>
            ) : (
              <span>{openAppHint}</span>
            )}
          </div>
        )}
      </div>

      {/* v23.1 part 146 — Navigation vers les pages portées du site.
          Cards adaptés au rôle de l'utilisateur. */}
      <div className="mt-8 grid gap-3 md:grid-cols-2">
        <NavCard
          href="/profile"
          emoji="👤"
          title="Mon profil"
          subtitle="Voir et modifier mes infos"
        />
        <NavCard
          href="/bookings"
          emoji="📅"
          title="Mes réservations"
          subtitle={user?.role === "owner" ? "Mes demandes en cours" : "Demandes reçues"}
        />
        {user?.role === "owner" && (
          <>
            <NavCard
              href="/pets"
              emoji="🐾"
              title="Mes animaux"
              subtitle="Gérer mes compagnons"
            />
            <NavCard
              href="/search"
              emoji="🔍"
              title="Rechercher un sitter"
              subtitle="Trouver et réserver un pro"
            />
          </>
        )}
        {(user?.role === "sitter" || user?.role === "walker") && (
          <NavCard
            href="/sitter-setup"
            emoji="⚙️"
            title="Mes tarifs & IBAN"
            subtitle="Configurer mon profil pro"
          />
        )}
        <NavCard
          href="/chat"
          emoji="💬"
          title="Messages"
          subtitle="Conversations en temps réel"
        />
        <NavCard
          href="/map"
          emoji="🗺️"
          title="PawMap"
          subtitle="Vétos, parcs, plages pet-friendly"
        />
        <NavCard
          href="/boutique"
          emoji="🛍️"
          title="Boutique"
          subtitle={
            user?.role === "owner"
              ? "Premium PawFollow"
              : "Premium + Boost annonce + PawSpot"
          }
        />
        <NavCard
          href="/invoices"
          emoji="🧾"
          title="Mes factures"
          subtitle="Télécharger en PDF"
        />
      </div>

      <div className="mt-8 rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-xs uppercase text-ink-soft">Email</div>
            <div className="text-sm font-semibold text-ink">{user?.email}</div>
          </div>
          <button
            onClick={logout}
            className="rounded-full border border-ink/10 px-4 py-2 text-sm font-semibold text-ink hover:border-ink/30"
          >
            {t("dash_logout")}
          </button>
        </div>
      </div>
    </div>
  );
}

// v23.1 part 146 — Card de navigation vers une sous-page.
function NavCard({
  href,
  emoji,
  title,
  subtitle,
}: {
  href: string;
  emoji: string;
  title: string;
  subtitle: string;
}) {
  return (
    <Link
      href={href}
      className="flex items-center gap-3 rounded-2xl border border-ink/5 bg-white p-4 shadow-card transition hover:border-ink/15 hover:shadow-lg"
    >
      <span className="flex h-12 w-12 items-center justify-center rounded-xl bg-bg-soft text-2xl">
        {emoji}
      </span>
      <span className="flex-1">
        <span className="block text-sm font-bold text-ink">{title}</span>
        <span className="block text-xs text-ink-muted">{subtitle}</span>
      </span>
      <span className="text-ink-muted">→</span>
    </Link>
  );
}
