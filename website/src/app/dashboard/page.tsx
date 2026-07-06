"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { ApiError, AuthUser, AuthRole, clearAuth, getConversations, getStoredUser, openInApp, redeemPromo, switchRole } from "@/lib/api";
import { useSocket, useSocketEvent } from "@/lib/useSocket";
import { disconnectSocket } from "@/lib/socket";
import NotificationBanner from "@/components/NotificationBanner";

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
  // v497 — Daniel : « rajoute l'onglet code promo dans le dashboard du web ».
  const [promoCode, setPromoCode] = useState("");
  const [promoBusy, setPromoBusy] = useState(false);
  const [promoMsg, setPromoMsg] = useState<{ ok: boolean; text: string } | null>(
    null,
  );

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
          setPremiumLabel(`👑 PawPremium · ${d} j`);
        } else if (staff) {
          setPremiumLabel("👑 PawPremium · illimité ⭐");
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

  // v497 — code promo depuis le dashboard (même endpoint /promo/redeem).
  async function handleApplyPromo() {
    const code = promoCode.trim();
    if (!code || promoBusy) return;
    setPromoBusy(true);
    setPromoMsg(null);
    try {
      const res = await redeemPromo(code);
      const type = res.reward?.rewardType;
      setPromoMsg({
        ok: true,
        text:
          type === "free_subscription"
            ? t("promo_ok_sub")
            : t("promo_ok_discount"),
      });
      setPromoCode("");
    } catch (e) {
      setPromoMsg({
        ok: false,
        text: e instanceof Error ? e.message : t("promo_invalid"),
      });
    } finally {
      setPromoBusy(false);
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

  const isOwner = user?.role === "owner";
  const isProvider = user?.role === "sitter" || user?.role === "walker";

  // v493 — Refonte design (design-only) : barre latérale persistante + zone
  // principale (PawFollow live en haut, réservations, actions rapides).
  // Aucune donnée/route/action changée — mêmes liens, mêmes handlers.
  return (
    <div className="mx-auto max-w-6xl px-4 py-10 md:py-14">
      {/* Toast live socket (inchangé). */}
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

      <div className="md:grid md:grid-cols-[250px_1fr] md:gap-8">
        {/* ── BARRE LATÉRALE ── identité + nav complète + rôle + déconnexion. */}
        <aside className="md:sticky md:top-6 md:self-start">
          <div className="rounded-[26px] border border-[#efe7e0] bg-white p-5 shadow-card">
            <div className="flex items-center gap-3">
              <div className={`grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-${roleColor} text-xl text-white`}>
                🐾
              </div>
              <div className="min-w-0">
                <div className="truncate text-sm font-extrabold text-ink">
                  {user?.name?.split(" ")[0] || "you"}
                </div>
                <div className="text-xs text-ink-muted">
                  {user?.role ? t(`dash_role_${user.role}`) : ""}
                </div>
              </div>
            </div>

            {/* Premium discret. */}
            {premiumLabel && (
              <a
                href="/boutique"
                className="mt-3 flex items-center gap-2 rounded-full border border-amber-400 bg-gradient-to-r from-[#221C12] to-[#15120D] px-3 py-1.5 text-xs font-extrabold text-yellow-400"
              >
                <span>👑</span>
                <span className="truncate">{premiumLabel}</span>
              </a>
            )}

            {/* Navigation complète (tous les liens conservés). */}
            <nav className="mt-4 space-y-0.5">
              <SideLink href="/profile" emoji="👤" label={t("dash_card_profile_title")} />
              <SideLink href="/bookings" emoji="📅" label={t("dash_card_bookings_title")} />
              <SideLink
                href="/posts"
                emoji="📣"
                label={isOwner ? t("posts_my_title") : t("posts_feed_title")}
              />
              {isOwner && <SideLink href="/pets" emoji="🐾" label={t("dash_card_pets_title")} />}
              {isOwner && <SideLink href="/search" emoji="🔍" label={t("dash_card_search_title")} />}
              {isProvider && <SideLink href="/sitter-setup" emoji="⚙️" label={t("dash_card_setup_title")} />}
              <SideLink href="/chat" emoji="💬" label={t("dash_card_messages_title")} badge={unreadMsg} />
              <SideLink href="/map" emoji="🗺️" label={t("dash_card_map_title")} />
              <SideLink href="/pawpoints" emoji="🐾" label={t("dash_card_pawpoints_title")} />
              <SideLink href="/friends" emoji="👥" label={t("friends_title")} />
              <SideLink href="/family" emoji="👨‍👩‍👧" label={t("family_title")} />
              <SideLink href="/boutique" emoji="🛍️" label={t("dash_card_shop_title")} />
              {/* v497 — onglet Code promo (ancre vers la carte ci-dessous). */}
              <SideLink href="#promo" emoji="🎟️" label={t("promo_title")} />
              <SideLink href="/invoices" emoji="🧾" label={t("dash_card_invoices_title")} />
            </nav>

            {/* Changement de rôle (discret). */}
            <div className="mt-4 border-t border-[#efe7e0] pt-4">
              <p className="text-[11px] font-bold uppercase tracking-wide text-ink-soft">
                {t("dash_switch_role_title")}
              </p>
              <div className="mt-2 flex flex-wrap gap-2">
                {(["owner", "sitter", "walker"] as AuthRole[])
                  .filter((r) => r !== user?.role)
                  .map((r) => (
                    <button
                      key={r}
                      type="button"
                      onClick={() => handleSwitchRole(r)}
                      disabled={switchingRole !== null}
                      className="rounded-full border border-ink/10 px-3 py-1.5 text-xs font-semibold text-ink transition hover:border-ink/30 disabled:opacity-60"
                    >
                      {switchingRole === r ? "…" : roleLabel(r)}
                    </button>
                  ))}
              </div>
              {switchMsg && <p className="mt-2 text-xs text-ink-muted">{switchMsg}</p>}
            </div>

            {/* Email + déconnexion. */}
            <div className="mt-4 border-t border-[#efe7e0] pt-4">
              <div className="truncate text-xs text-ink-muted">{user?.email}</div>
              <button
                onClick={logout}
                className="mt-2 w-full rounded-full border border-ink/10 px-4 py-2 text-sm font-semibold text-ink transition hover:border-ink/30"
              >
                {t("dash_logout")}
              </button>
            </div>
          </div>
        </aside>

        {/* ── ZONE PRINCIPALE ── */}
        <main className="mt-6 md:mt-0">
          {/* En-tête de bienvenue (couleur du rôle).
              v506 — design : patte en filigrane + halos doux (décoratif). */}
          <div
            className={`relative overflow-hidden rounded-[26px] bg-${roleColor} p-6 text-white shadow-card md:p-8 ${
              premiumLabel ? "ring-2 ring-amber-400" : ""
            }`}
          >
            <span
              aria-hidden
              className="pointer-events-none absolute -right-4 -top-10 rotate-12 select-none text-[130px] leading-none opacity-10"
            >
              🐾
            </span>
            <span
              aria-hidden
              className="pointer-events-none absolute -bottom-20 -left-12 h-52 w-52 rounded-full bg-white/10"
            />
            <div className="flex items-center justify-between">
              <h1 className="font-display text-2xl font-extrabold md:text-3xl">
                {t("dash_welcome")}, {user?.name?.split(" ")[0] || "you"} 👋
              </h1>
              <div
                className="flex items-center gap-1.5 text-xs opacity-80"
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
            <p className="mt-2 max-w-md text-sm text-white/85">{t("dash_sub")}</p>
            <div className="mt-5 flex flex-wrap gap-3">
              <button
                type="button"
                onClick={handleOpenApp}
                disabled={openingApp}
                className="inline-flex items-center gap-2 rounded-full bg-white px-5 py-2.5 text-sm font-semibold text-ink shadow-sm transition hover:bg-bg-soft disabled:cursor-not-allowed disabled:opacity-70"
              >
                {openingApp && (
                  <svg className="h-4 w-4 animate-spin" viewBox="0 0 24 24" fill="none" aria-hidden="true">
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
                {openAppError ? <span role="alert">{openAppError}</span> : <span>{openAppHint}</span>}
              </div>
            )}
          </div>

          <NotificationBanner />

          {/* PawFollow en direct — mis en avant tout en haut → /map.
              v507 — Daniel : « les deux gros boutons plus visibles, plus
              colorés » → cartes pleines couleur (dégradé + texte blanc). */}
          <Link
            href="/map"
            className="group relative mt-6 flex items-center gap-4 overflow-hidden rounded-[22px] bg-gradient-to-r from-walker to-emerald-500 p-5 text-white shadow-lg transition hover:-translate-y-0.5 hover:shadow-2xl"
          >
            <span
              aria-hidden
              className="pointer-events-none absolute -right-3 -top-6 rotate-12 select-none text-[80px] leading-none opacity-10"
            >
              🗺️
            </span>
            <span className="grid h-14 w-14 shrink-0 place-items-center rounded-2xl bg-white/20 text-2xl shadow-sm ring-1 ring-white/30">
              🛰️
            </span>
            <span className="flex-1">
              <span className="block text-base font-extrabold">{t("dash_card_map_title")}</span>
              <span className="block text-sm text-white/85">{t("dash_card_map_sub")}</span>
            </span>
            <span className="grid h-9 w-9 place-items-center rounded-full bg-white/20 text-lg transition group-hover:translate-x-1">→</span>
          </Link>

          {/* Réservations en cours → /bookings. */}
          <Link
            href="/bookings"
            className="group relative mt-4 flex items-center gap-4 overflow-hidden rounded-[22px] bg-gradient-to-r from-owner to-[#ff7a45] p-5 text-white shadow-lg transition hover:-translate-y-0.5 hover:shadow-2xl"
          >
            <span
              aria-hidden
              className="pointer-events-none absolute -right-3 -top-6 rotate-12 select-none text-[80px] leading-none opacity-10"
            >
              📅
            </span>
            <span className="grid h-14 w-14 shrink-0 place-items-center rounded-2xl bg-white/20 text-2xl shadow-sm ring-1 ring-white/30">
              📅
            </span>
            <span className="flex-1">
              <span className="block text-base font-extrabold">{t("dash_card_bookings_title")}</span>
              <span className="block text-sm text-white/85">
                {isOwner ? t("dash_card_bookings_sub_owner") : t("dash_card_bookings_sub_provider")}
              </span>
            </span>
            <span className="grid h-9 w-9 place-items-center rounded-full bg-white/20 text-lg transition group-hover:translate-x-1">→</span>
          </Link>

          {/* Actions rapides. */}
          <h2 className="mt-8 font-display text-xl font-extrabold text-ink">{t("dash_account_section")}</h2>
          <p className="mt-1 text-sm text-ink-muted">{t("dash_account_section_sub")}</p>
          <div className="mt-4 grid gap-3 sm:grid-cols-2">
            <NavCard
              href="/posts"
              emoji="📣"
              tint="bg-orange-50"
              title={isOwner ? t("posts_my_title") : t("posts_feed_title")}
              subtitle={isOwner ? t("posts_create_cta") : t("posts_contact")}
            />
            <NavCard
              href="/chat"
              emoji="💬"
              tint="bg-blue-50"
              title={t("dash_card_messages_title")}
              subtitle={t("dash_card_messages_sub")}
              badge={unreadMsg}
            />
            {isOwner && (
              <NavCard href="/pets" emoji="🐾" tint="bg-pink-50" title={t("dash_card_pets_title")} subtitle={t("dash_card_pets_sub")} />
            )}
            {isOwner && (
              <NavCard href="/search" emoji="🔍" tint="bg-violet-50" title={t("dash_card_search_title")} subtitle={t("dash_card_search_sub")} />
            )}
            {isProvider && (
              <NavCard href="/sitter-setup" emoji="⚙️" tint="bg-slate-100" title={t("dash_card_setup_title")} subtitle={t("dash_card_setup_sub")} />
            )}
            <NavCard
              href="/friends"
              emoji="👥"
              tint="bg-lime-50"
              title={t("dash_card_friends_title")}
              subtitle={t("dash_card_friends_sub")}
            />
            <NavCard
              href="/pawpoints"
              emoji="🐾"
              tint="bg-amber-50"
              title={t("dash_card_pawpoints_title")}
              subtitle={t("dash_card_pawpoints_sub")}
            />
            <NavCard
              href="/invoices"
              emoji="🧾"
              tint="bg-emerald-50"
              title={t("dash_card_invoices_title")}
              subtitle={t("dash_card_invoices_sub")}
            />
            <NavCard
              href="/profile"
              emoji="👤"
              tint="bg-cyan-50"
              title={t("dash_card_profile_title")}
              subtitle={t("dash_card_profile_sub")}
            />
          </div>

          {/* PawPremium — bande sombre/or (discrète, sous les actions). */}
          <a
            href="/boutique"
            className="group mt-4 flex items-center gap-4 rounded-[22px] border-2 border-amber-400 bg-gradient-to-br from-[#221C12] to-[#15120D] p-5 shadow-card transition hover:brightness-110"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/pawpremium_logo.svg" alt="" width={44} height={44} />
            <div>
              <div className="font-display text-base font-extrabold text-yellow-400">PawPremium 👑</div>
              <div className="text-xs text-white/75">{t("dash_premium_sub")}</div>
            </div>
            <span className="ml-auto text-yellow-400 transition group-hover:translate-x-1">→</span>
          </a>

          {/* v497 — Daniel : « onglet code promo dans le dashboard ». Carte
              directement utilisable (même endpoint /promo/redeem que la boutique). */}
          <div
            id="promo"
            className="mt-4 scroll-mt-24 rounded-[22px] border border-ink/10 bg-white p-5 shadow-card"
          >
            <p className="flex items-center gap-2 text-sm font-extrabold text-ink">
              <span>🎟️</span> {t("promo_title")}
            </p>
            <div className="mt-3 flex flex-col gap-2 sm:flex-row">
              <input
                type="text"
                value={promoCode}
                onChange={(e) => setPromoCode(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") handleApplyPromo();
                }}
                placeholder={t("promo_placeholder")}
                className="min-w-0 flex-1 rounded-full border border-ink/15 px-4 py-2.5 text-sm uppercase tracking-wide outline-none focus:border-amber-400"
              />
              <button
                type="button"
                onClick={handleApplyPromo}
                disabled={promoBusy || !promoCode.trim()}
                className="shrink-0 rounded-full bg-amber-500 px-6 py-2.5 text-sm font-semibold text-white hover:bg-amber-600 disabled:opacity-60"
              >
                {promoBusy ? "…" : t("promo_apply")}
              </button>
            </div>
            {promoMsg && (
              <p
                className={`mt-3 text-sm ${promoMsg.ok ? "text-emerald-700" : "text-red-700"}`}
              >
                {promoMsg.text}
              </p>
            )}
          </div>
        </main>
      </div>
    </div>
  );
}

// v493 — lien de la barre latérale (compact, badge optionnel).
function SideLink({
  href,
  emoji,
  label,
  badge,
}: {
  href: string;
  emoji: string;
  label: string;
  badge?: number;
}) {
  return (
    <Link
      href={href}
      className="group flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-semibold text-ink transition hover:bg-bg-soft"
    >
      <span className="relative text-lg">
        {emoji}
        {badge && badge > 0 ? (
          <span className="absolute -right-2 -top-1.5 flex h-4 min-w-[16px] items-center justify-center rounded-full bg-red-500 px-1 text-[10px] font-bold text-white">
            {badge > 99 ? "99+" : badge}
          </span>
        ) : null}
      </span>
      <span className="flex-1 truncate">{label}</span>
      <span className="text-ink-soft transition group-hover:translate-x-0.5">›</span>
    </Link>
  );
}

// v23.1 part 146 — Card de navigation vers une sous-page.
function NavCard({
  href,
  emoji,
  title,
  subtitle,
  badge,
  tint,
}: {
  href: string;
  emoji: string;
  title: string;
  subtitle: string;
  badge?: number;
  /** v506 — design : teinte pastel de la pastille (une couleur par carte). */
  tint?: string;
}) {
  return (
    <Link
      href={href}
      className="group flex items-center gap-4 rounded-2xl border-2 border-ink/5 bg-white p-4 shadow-card transition hover:-translate-y-0.5 hover:border-owner/40 hover:shadow-xl"
    >
      <span className={`relative flex h-12 w-12 items-center justify-center rounded-xl text-2xl shadow-sm transition group-hover:scale-110 ${tint || "bg-gradient-to-br from-owner-light to-amber-50"}`}>
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
