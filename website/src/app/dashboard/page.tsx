"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { ApiError, AuthUser, AuthRole, clearAuth, getConversations, getStoredUser, openInApp, switchRole } from "@/lib/api";
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
  // v402 — changement de rôle depuis le web (garde les abonnements).
  const [switchingRole, setSwitchingRole] = useState<AuthRole | null>(null);
  const [switchMsg, setSwitchMsg] = useState<string | null>(null);

  // v23.1 part 146 — socket.io temps réel.
  const { connected: socketConnected } = useSocket();
  // Toasts in-page pour les events critiques reçus.
  const [liveToast, setLiveToast] = useState<{ icon: string; text: string } | null>(null);
  // v23.1.394 — Daniel : « mettre en valeur mon compte + où est le badge
  // premium ? ». Statut Premium pour le badge 👑 et le cadre noir/or.
  const [premiumLabel, setPremiumLabel] = useState<string | null>(null);
  useEffect(() => {
    (async () => {
      try {
        const { getSubscriptionStatus } = await import("@/lib/api");
        const st = await getSubscriptionStatus();
        const staff = st.currentPeriodEnd
          ? new Date(st.currentPeriodEnd).getFullYear() >= 2090
          : false;
        if (st.premiumExpiry && new Date(st.premiumExpiry) > new Date()) {
          const d = Math.ceil((new Date(st.premiumExpiry).getTime() - Date.now()) / 86400000);
          setPremiumLabel(`👑 Paw Premium · ${d} j`);
        } else if (staff) {
          setPremiumLabel("👑 Paw Premium · illimité ⭐");
        }
      } catch { /* pas connecté / pas premium → rien */ }
    })();
  }, []);
  // v404 — Daniel : badge de messages non lus sur la carte « Mes messages ».
  const [unreadMsg, setUnreadMsg] = useState(0);
  useEffect(() => {
    (async () => {
      try {
        const convs = await getConversations();
        const total = convs.reduce(
          (n, c) => n + (Number(c.unreadCount) || 0),
          0,
        );
        setUnreadMsg(total);
      } catch { /* pas connecté → 0 */ }
    })();
  }, []);

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

  // v402 — bascule de rôle depuis le cadre orange. Le backend migre les
  // abonnements (Premium/PawFollow/PawFamily/PawSpot) et renvoie un nouveau
  // token, persisté par switchRole(). On rafraîchit ensuite le dashboard.
  const roleLabel = (r: AuthRole) =>
    r === "owner"
      ? `🐾 ${t("signup_role_owner")}`
      : r === "sitter"
        ? `🏠 ${t("signup_role_sitter")}`
        : `🚶 ${t("signup_role_walker")}`;

  async function handleSwitchRole(target: AuthRole) {
    if (!user || target === user.role || switchingRole) return;
    if (!window.confirm(t("dash_switch_confirm"))) return;
    setSwitchingRole(target);
    setSwitchMsg(null);
    try {
      const data = await switchRole(target);
      setUser(data.user);
      setSwitchMsg(t("dash_switch_done"));
      setTimeout(() => router.refresh(), 400);
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        clearAuth();
        router.replace("/login");
        return;
      }
      setSwitchMsg(e instanceof ApiError ? e.message : t("dash_switch_error"));
    } finally {
      setSwitchingRole(null);
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

      <div
        className={`rounded-3xl bg-${roleColor} p-8 text-white shadow-card md:p-12 ${
          premiumLabel
            ? "border-4 border-[#15120D] ring-4 ring-amber-400 shadow-[0_0_28px_rgba(232,160,10,0.45)]"
            : ""
        }`}
      >
        <div className="flex items-center justify-between">
          {/* v406 — Daniel : le rôle s'affichait en brut (« OWNER »). On le
              traduit (Propriétaire / Pet-sitter / Promeneur). */}
          <div className="text-sm font-medium uppercase tracking-wider opacity-80">
            {user?.role ? t(`dash_role_${user.role}`) : ""}
          </div>
          {/* v23.1 part 146 — indicateur de connexion socket temps réel.
              Vert si connecté (events live arrivent), gris sinon. */}
          <div
            className="flex items-center gap-1.5 text-xs opacity-75"
            title={socketConnected ? t("dash_live") : t("dash_offline")}
          >
            <span
              className={`inline-block h-2 w-2 rounded-full ${
                socketConnected ? "bg-green-400 animate-pulse" : "bg-white/40"
              }`}
              aria-hidden="true"
            />
            <span>{socketConnected ? t("dash_live") : t("dash_offline")}</span>
          </div>
        </div>
        <h1 className="mt-2 flex flex-wrap items-center gap-3 font-display text-3xl font-extrabold md:text-4xl">
          <span>{t("dash_welcome")}, {user?.name?.split(" ")[0] || "you"} 👋</span>
          {premiumLabel && (
            <span className="rounded-full border-2 border-amber-400 bg-gradient-to-r from-[#221C12] to-[#15120D] px-4 py-1.5 text-sm font-extrabold text-yellow-400 shadow-lg">
              {premiumLabel}
            </span>
          )}
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

        {/* v402 — Changement de rôle depuis le web. Garde tous les abonnements
            (le backend migre Premium/PawFollow/PawFamily/PawSpot). */}
        <div className="mt-6 border-t border-white/20 pt-5">
          <p className="text-sm font-semibold">{t("dash_switch_role_title")}</p>
          <p className="mt-0.5 text-xs text-white/75">{t("dash_switch_role_sub")}</p>
          <div className="mt-3 flex flex-wrap gap-2">
            {(["owner", "sitter", "walker"] as AuthRole[])
              .filter((r) => r !== user?.role)
              .map((r) => (
                <button
                  key={r}
                  type="button"
                  onClick={() => handleSwitchRole(r)}
                  disabled={switchingRole !== null}
                  className="inline-flex items-center gap-2 rounded-full bg-white/15 px-4 py-2 text-sm font-semibold text-white transition hover:bg-white/25 disabled:opacity-60"
                >
                  {switchingRole === r ? "…" : roleLabel(r)}
                </button>
              ))}
          </div>
          {switchMsg && <p className="mt-2 text-sm text-white/90">{switchMsg}</p>}
        </div>
      </div>

      {/* v23.1.394 — Daniel : « mon compte web en titre, mettre en valeur
          les boutons ». Titre de section + cards relookées (NavCard). */}
      {/* v23.1.398 — Daniel : « il manque le package langue pour Mon compte
          web ». Tous les libellés de la section passent par t() (6 langues). */}
      <h2 className="mt-10 font-display text-2xl font-extrabold text-ink">
        {t("dash_account_section")}
      </h2>
      <p className="mt-1 text-sm text-ink-muted">
        {t("dash_account_section_sub")}
      </p>
      <div className="mt-5 grid gap-3 md:grid-cols-2">
        <NavCard
          href="/profile"
          emoji="👤"
          title={t("dash_card_profile_title")}
          subtitle={t("dash_card_profile_sub")}
        />
        <NavCard
          href="/bookings"
          emoji="📅"
          title={t("dash_card_bookings_title")}
          subtitle={user?.role === "owner" ? t("dash_card_bookings_sub_owner") : t("dash_card_bookings_sub_provider")}
        />
        {/* v402 — Annonces : owner publie, sitter/walker répond. */}
        <NavCard
          href="/posts"
          emoji="📣"
          title={user?.role === "owner" ? t("posts_my_title") : t("posts_feed_title")}
          subtitle={user?.role === "owner" ? t("posts_create_cta") : t("posts_contact")}
        />
        {user?.role === "owner" && (
          <>
            <NavCard
              href="/pets"
              emoji="🐾"
              title={t("dash_card_pets_title")}
              subtitle={t("dash_card_pets_sub")}
            />
            <NavCard
              href="/search"
              emoji="🔍"
              title={t("dash_card_search_title")}
              subtitle={t("dash_card_search_sub")}
            />
          </>
        )}
        {(user?.role === "sitter" || user?.role === "walker") && (
          <NavCard
            href="/sitter-setup"
            emoji="⚙️"
            title={t("dash_card_setup_title")}
            subtitle={t("dash_card_setup_sub")}
          />
        )}
        <NavCard
          href="/chat"
          emoji="💬"
          title={t("dash_card_messages_title")}
          subtitle={t("dash_card_messages_sub")}
          badge={unreadMsg}
        />
        <NavCard
          href="/map"
          emoji="🗺️"
          title={t("dash_card_map_title")}
          subtitle={t("dash_card_map_sub")}
        />
        {/* v23.1.358 — Daniel : "efface amis en direct" — la carte « Mes
            amis en direct » est supprimée : la couche PawFollow vit dans la
            carte unique /map (chip PawFollow), déjà accessible via PawMap. */}
        <NavCard
          href="/boutique"
          emoji="🛍️"
          title={t("dash_card_shop_title")}
          subtitle={t("dash_card_shop_sub")}
        />
        {/* v23.1.394 — Daniel : « fond noir et or pour le faire ressortir ». */}
        <a
          href="/boutique"
          className="group flex items-center gap-4 rounded-2xl border-2 border-amber-400 bg-gradient-to-br from-[#221C12] to-[#15120D] p-5 shadow-card transition hover:brightness-110"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/pawpremium_logo.svg" alt="" width={44} height={44} />
          <div>
            <div className="font-display text-base font-extrabold text-yellow-400">
              Paw Premium 👑
            </div>
            <div className="text-xs text-white/75">
              {t("dash_premium_sub")}
            </div>
          </div>
          <span className="ml-auto text-yellow-400 transition group-hover:translate-x-1">→</span>
        </a>
        <NavCard
          href="/invoices"
          emoji="🧾"
          title={t("dash_card_invoices_title")}
          subtitle={t("dash_card_invoices_sub")}
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
  badge,
}: {
  href: string;
  emoji: string;
  title: string;
  subtitle: string;
  badge?: number;
}) {
  return (
    <Link
      href={href}
      className="group flex items-center gap-4 rounded-2xl border-2 border-ink/5 bg-white p-4 shadow-card transition hover:-translate-y-0.5 hover:border-owner/40 hover:shadow-xl"
    >
      <span className="relative flex h-12 w-12 items-center justify-center rounded-xl bg-gradient-to-br from-owner-light to-amber-50 text-2xl shadow-sm transition group-hover:scale-110">
        {emoji}
        {badge && badge > 0 ? (
          <span className="absolute -right-1.5 -top-1.5 flex h-5 min-w-[20px] items-center justify-center rounded-full bg-red-500 px-1 text-[11px] font-bold text-white shadow">
            {badge > 99 ? "99+" : badge}
          </span>
        ) : null}
      </span>
      <span className="flex-1">
        <span className="block text-sm font-extrabold text-ink">{title}</span>
        <span className="block text-xs text-ink-muted">{subtitle}</span>
      </span>
      <span className="text-owner transition group-hover:translate-x-1">→</span>
    </Link>
  );
}
