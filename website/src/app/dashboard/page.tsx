"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { ApiError, AuthUser, AuthRole, Booking, clearAuth, getConversations, getMyBookings, getMyRoles, getStoredUser, openInApp, redeemPromo, switchRole } from "@/lib/api";
import { useSocket, useSocketEvent } from "@/lib/useSocket";
import { disconnectSocket } from "@/lib/socket";
import NotificationBanner from "@/components/NotificationBanner";
import { PawMapLogo } from "@/components/PawMapLogo";
import { AppIcon, type AppIconName } from "@/components/AppIcon";
import { PageTitle } from "@/components/PageTitle";
import { ROLE_COLOR } from "@/lib/pawmapLegend";
import { FeedbackBox } from "@/components/FeedbackBox";

// v493 — barre latérale + zone principale. v562 — orange pâle au survol.
// 24/09/2026 — LOT B, étape 4 (plan de LEO validé par Daniel) : le tableau de
// bord devient un CENTRE DE RÉSERVATION, synchronisé avec l'app :
//   • icônes de l'app (AppIcon, zéro emoji), survol et page courante à la
//     COULEUR DU RÔLE (orange propriétaire, bleu gardien, vert promeneur) ;
//   • bloc « À faire aujourd'hui » : à payer / demandes à répondre / prochaine
//     garde / service en cours (suivre en direct) / messages non lus, chacun
//     cliquable ; rien d'urgent = une phrase qui propose la suite ;
//   • « you » en dur → traduit ; titre de page propre.
// Mêmes liens, mêmes handlers, mêmes routes ; aucune fonction retirée.
// ⚠️ Tous les hooks restent AVANT le `if (loading) return` (piège du 20/09).

type Tint = { bg: string; light: string; dark: string; hoverBg: string; hoverText: string; currentBg: string; currentText: string };
const TINTS: Record<AuthRole, Tint> = {
  owner: { bg: "bg-owner", light: "#FBE9E5", dark: "#9E1F0B", hoverBg: "hover:bg-owner-light", hoverText: "hover:text-owner-dark", currentBg: "bg-owner-light", currentText: "text-owner-dark" },
  sitter: { bg: "bg-sitter", light: "#E3EFFE", dark: "#0E5BC0", hoverBg: "hover:bg-sitter-light", hoverText: "hover:text-sitter-dark", currentBg: "bg-sitter-light", currentText: "text-sitter-dark" },
  walker: { bg: "bg-walker", light: "#DEF7E5", dark: "#0F7C37", hoverBg: "hover:bg-walker-light", hoverText: "hover:text-walker-dark", currentBg: "bg-walker-light", currentText: "text-walker-dark" },
};

function bookingDate(b: Booking): number {
  const d = b.startDate || b.serviceDate || b.date;
  const tms = d ? new Date(d).getTime() : NaN;
  return Number.isFinite(tms) ? tms : Infinity;
}

export default function DashboardPage() {
  const { t, lang } = useT();
  const router = useRouter();
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [openingApp, setOpeningApp] = useState(false);
  const [openAppError, setOpenAppError] = useState<string | null>(null);
  const [openAppHint, setOpenAppHint] = useState<string | null>(null);
  const [switchingRole, setSwitchingRole] = useState<AuthRole | null>(null);
  const [switchMsg, setSwitchMsg] = useState<string | null>(null);
  const [promoCode, setPromoCode] = useState("");
  const [promoBusy, setPromoBusy] = useState(false);
  const [promoMsg, setPromoMsg] = useState<{ ok: boolean; text: string } | null>(null);

  const { connected: socketConnected } = useSocket();
  const [liveToast, setLiveToast] = useState<{ icon: AppIconName; text: string } | null>(null);
  const [premiumLabel, setPremiumLabel] = useState<string | null>(null);
  useEffect(() => {
    (async () => {
      try {
        const { getSubscriptionStatus } = await import("@/lib/api");
        const st = await getSubscriptionStatus();
        const staff = st.currentPeriodEnd ? new Date(st.currentPeriodEnd).getFullYear() >= 2090 : false;
        if (st.premiumExpiry && new Date(st.premiumExpiry) > new Date()) {
          const d = Math.ceil((new Date(st.premiumExpiry).getTime() - Date.now()) / 86400000);
          setPremiumLabel(`PawPremium · ${d} j`);
        } else if (staff) {
          setPremiumLabel("PawPremium · ∞");
        }
      } catch { /* pas connecté / pas premium → rien */ }
    })();
  }, []);
  // v574 — profils déjà activés (sur n'importe quel appareil).
  const [myRoles, setMyRoles] = useState<AuthRole[]>([]);
  useEffect(() => {
    let alive = true;
    if (!user) return;
    getMyRoles().then((r) => { if (alive) setMyRoles(r); });
    return () => { alive = false; };
  }, [user?.role]);

  const [unreadMsg, setUnreadMsg] = useState(0);
  useEffect(() => {
    (async () => {
      try {
        const convs = await getConversations();
        setUnreadMsg(convs.reduce((n, c) => n + (Number(c.unreadCount) || 0), 0));
      } catch { /* pas connecté → 0 */ }
    })();
  }, []);

  // 24/09 — « À faire aujourd'hui » : mes réservations (même source que /bookings).
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [bookingsLoaded, setBookingsLoaded] = useState(false);
  useEffect(() => {
    let alive = true;
    if (!user) return;
    getMyBookings()
      .then((list) => { if (alive) setBookings(list); })
      .catch(() => {})
      .finally(() => { if (alive) setBookingsLoaded(true); });
    return () => { alive = false; };
  }, [user?.role, user?.id]);

  const showLiveToast = (icon: AppIconName, text: string) => {
    setLiveToast({ icon, text });
    setTimeout(() => setLiveToast(null), 6000);
  };
  useSocketEvent<{ bookingId: string; status?: string }>("booking:paid", (data) => {
    showLiveToast("wallet", `${t("dash_today_to_pay")} ✓ ${data.bookingId.slice(0, 6)}…`);
  });
  useSocketEvent<{ bookingId: string; status?: string }>("booking:accepted", (data) => {
    showLiveToast("check", `${t("dash_card_bookings_title")} ✓ (${data.bookingId.slice(0, 6)}…)`);
  });
  useSocketEvent<{ applicationId: string; profileName?: string }>("application:new", (data) => {
    showLiveToast("megaphone", `${t("dash_today_requests")}${data.profileName ? ` · ${data.profileName}` : ""}`);
  });
  useSocketEvent<{ conversationId: string; body: string; senderRole?: string }>("message:new", (data) => {
    const preview = data.body.length > 40 ? `${data.body.slice(0, 40)}…` : data.body;
    showLiveToast("chat", `${t("dash_card_messages_title")} : "${preview}"`);
  });

  useEffect(() => {
    const u = getStoredUser();
    if (!u) {
      router.replace("/login");
      return;
    }
    setUser(u);
    setLoading(false);
  }, [router]);

  const role: AuthRole = user?.role === "owner" ? "owner" : user?.role === "walker" ? "walker" : "sitter";
  const tint = TINTS[role];
  const isOwner = role === "owner";
  const isProvider = role === "sitter" || role === "walker";

  // Compteurs du jour (calculés avant le retour anticipé : hooks en tête).
  const today = useMemo(() => {
    const now = Date.now();
    const startOfDay = new Date(); startOfDay.setHours(0, 0, 0, 0);
    const toPay = bookings.filter((b) => (b.status === "accepted" || b.status === "agreed") && b.paymentStatus !== "paid");
    const pendingReq = bookings.filter((b) => b.status === "pending");
    const live = bookings.find((b) => b.confirmationStatus === "in_progress" || (!!b.serviceStartedAt && !b.serviceEndedAt && b.status !== "completed" && b.status !== "cancelled"));
    const upcoming = bookings
      .filter((b) => (b.status === "paid" || b.status === "agreed" || b.status === "accepted") && bookingDate(b) >= startOfDay.getTime())
      .sort((a, b) => bookingDate(a) - bookingDate(b));
    const next = upcoming[0];
    return { toPay, pendingReq, live, next, now };
  }, [bookings]);

  if (loading) {
    return <div className="mx-auto max-w-md px-4 py-24 text-center text-ink-muted">{t("common_loading")}</div>;
  }

  function logout() {
    disconnectSocket();
    clearAuth();
    router.replace("/");
  }

  async function handleOpenApp() {
    setOpenAppError(null);
    setOpenAppHint(null);
    setOpeningApp(true);
    let appOpened = false;
    const onVisibilityChange = () => { if (document.visibilityState === "hidden") appOpened = true; };
    document.addEventListener("visibilitychange", onVisibilityChange);
    try {
      await openInApp();
      setTimeout(() => {
        document.removeEventListener("visibilitychange", onVisibilityChange);
        setOpeningApp(false);
        if (!appOpened) setOpenAppHint(t("dash_app_not_installed"));
      }, 1500);
    } catch (e) {
      document.removeEventListener("visibilitychange", onVisibilityChange);
      setOpeningApp(false);
      if (e instanceof ApiError && e.status === 401) { clearAuth(); router.replace("/login"); return; }
      setOpenAppError(e instanceof Error ? e.message : t("common_error_generic"));
    }
  }

  async function handleApplyPromo() {
    const code = promoCode.trim();
    if (!code || promoBusy) return;
    setPromoBusy(true);
    setPromoMsg(null);
    try {
      const res = await redeemPromo(code);
      const type = res.reward?.rewardType;
      setPromoMsg({ ok: true, text: type === "free_subscription" ? t("promo_ok_sub") : t("promo_ok_discount") });
      setPromoCode("");
    } catch (e) {
      setPromoMsg({ ok: false, text: e instanceof Error ? e.message : t("promo_invalid") });
    } finally {
      setPromoBusy(false);
    }
  }

  const roleIcon = (r: AuthRole): AppIconName => (r === "owner" ? "paw" : r === "sitter" ? "home" : "walker");
  const roleLabel = (r: AuthRole) => (r === "owner" ? t("signup_role_owner") : r === "sitter" ? t("signup_role_sitter") : t("signup_role_walker"));

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
      if (e instanceof ApiError && e.status === 401) { clearAuth(); router.replace("/login"); return; }
      setSwitchMsg(e instanceof ApiError ? e.message : t("dash_switch_error"));
    } finally {
      setSwitchingRole(null);
    }
  }

  const firstName = user?.name?.split(" ")[0] || t("dash_you");
  const fmtDate = (b: Booking) => {
    const d = b.startDate || b.serviceDate || b.date;
    return d ? new Date(d).toLocaleDateString(lang, { weekday: "short", day: "numeric", month: "short" }) : "";
  };

  // Tuiles « À faire aujourd'hui » (une action par tuile).
  const todo: { icon: AppIconName; count: number | null; label: string; sub?: string; href: string; cta: string; color: string; light: string }[] = [];
  if (isOwner && today.toPay.length > 0) {
    const b = today.toPay[0];
    todo.push({ icon: "wallet", count: today.toPay.length, label: t("dash_today_to_pay"), sub: `${b.otherParty?.name || ""} ${fmtDate(b)}`.trim(), href: today.toPay.length === 1 ? `/pay?bookingId=${encodeURIComponent(b.id)}` : "/bookings", cta: t("dash_pay_now"), color: ROLE_COLOR.owner, light: "#FBE9E5" });
  }
  if (isProvider && today.pendingReq.length > 0) {
    todo.push({ icon: "megaphone", count: today.pendingReq.length, label: t("dash_today_requests"), sub: `${today.pendingReq[0].otherParty?.name || ""} ${fmtDate(today.pendingReq[0])}`.trim(), href: "/bookings", cta: t("dash_answer_now"), color: tint.dark, light: tint.light });
  }
  if (today.live) {
    const b = today.live;
    todo.push({ icon: "map", count: null, label: t("dash_today_live"), sub: `${b.otherParty?.name || ""}`.trim(), href: b.walkerId ? `/walk/${b.id}` : "/map", cta: t("dash_see"), color: "#7C3AED", light: "#EDE9FE" });
  }
  if (unreadMsg > 0) {
    todo.push({ icon: "chat", count: unreadMsg, label: t("dash_today_unread"), href: "/chat", cta: t("dash_see"), color: ROLE_COLOR.sitter, light: "#E3EFFE" });
  }
  if (today.next && today.next !== today.live) {
    const b = today.next;
    todo.push({ icon: "calendar", count: null, label: t("dash_today_next"), sub: `${fmtDate(b)} · ${b.otherParty?.name || ""}`.trim(), href: "/bookings", cta: t("dash_see"), color: ROLE_COLOR.walker, light: "#DEF7E5" });
  }

  return (
    <div className="mx-auto max-w-6xl px-4 py-8 md:py-12">
      <PageTitle titleKey="page_title_dashboard" />
      {liveToast && (
        <div role="status" aria-live="polite" className="fixed left-1/2 top-6 z-50 flex -translate-x-1/2 transform items-center gap-2 rounded-full bg-ink px-5 py-3 text-sm font-medium text-white shadow-lg">
          <AppIcon name={liveToast.icon} size={16} color="#F4C04A" />
          {liveToast.text}
        </div>
      )}

      <div className="md:grid md:grid-cols-[250px_1fr] md:gap-8">
        {/* ── BARRE LATÉRALE ── identité + navigation + rôle + déconnexion. */}
        <aside className="md:sticky md:top-6 md:self-start">
          <div className="rounded-[24px] bg-[#FAF1EC] p-5">
            <div className="flex items-center gap-3">
              <div className={`grid h-11 w-11 shrink-0 place-items-center rounded-full ${tint.bg} text-white`}>
                <AppIcon name={roleIcon(role)} size={22} color="#fff" />
              </div>
              <div className="min-w-0">
                <div className="truncate text-sm font-semibold text-[#231715]">{firstName}</div>
                <div className="text-xs font-semibold" style={{ color: tint.dark }}>{user?.role ? t(`dash_role_${user.role}`) : ""}</div>
              </div>
            </div>

            {premiumLabel && (
              <a href="/boutique" className="mt-3 flex items-center gap-2 rounded-full bg-[#231715] px-3 py-1.5 text-xs font-semibold text-[#FFD34D]">
                <AppIcon name="crown" size={14} color="#F4C04A" />
                <span className="truncate">{premiumLabel}</span>
              </a>
            )}

            <nav className="mt-4 space-y-0.5">
              <SideLink href="/profile" icon="profile" label={t("dash_card_profile_title")} tint={tint} />
              <SideLink href="/bookings" icon="calendar" label={t("dash_card_bookings_title")} tint={tint} />
              <SideLink href="/posts" icon="megaphone" label={isOwner ? t("posts_my_title") : t("posts_feed_title")} tint={tint} />
              {isOwner && <SideLink href="/pets" icon="pets" label={t("dash_card_pets_title")} tint={tint} />}
              {isOwner && <SideLink href="/search" icon="search" label={t("dash_card_search_title")} tint={tint} />}
              {isProvider && <SideLink href="/sitter-setup" icon="settings" label={t("dash_card_setup_title")} tint={tint} />}
              <SideLink href="/chat" icon="chat" label={t("dash_card_messages_title")} badge={unreadMsg} tint={tint} />
              <SideLink href="/map" icon="map" label={t("dash_card_map_title")} tint={tint} />
              <SideLink href="/pawpoints" icon="coins" label={t("dash_card_pawpoints_title")} tint={tint} />
              <SideLink href="/friends" icon="friends" label={t("friends_title")} tint={tint} />
              <SideLink href="/family" icon="family" label={t("family_title")} tint={tint} />
              <SideLink href="/boutique" icon="shop" label={t("dash_card_shop_title")} tint={tint} />
              <SideLink href="#promo" icon="ticket" label={t("promo_title")} tint={tint} />
              <SideLink href="/invoices" icon="invoice" label={t("dash_card_invoices_title")} tint={tint} />
            </nav>

            <div className="mt-4 border-t border-[#EADFDC] pt-4">
              <p className="text-[11px] font-bold uppercase tracking-wide text-ink-soft">{t("dash_switch_role_title")}</p>
              <div className="mt-2 flex flex-wrap gap-2">
                {(["owner", "sitter", "walker"] as AuthRole[]).filter((r) => r !== user?.role).map((r) => (
                  <button key={r} type="button" onClick={() => handleSwitchRole(r)} disabled={switchingRole !== null} className="inline-flex min-h-[36px] items-center gap-1.5 rounded-full bg-white px-3 text-xs font-semibold text-[#231715] transition hover:bg-[#F0E3DF] disabled:opacity-60">
                    <AppIcon name={roleIcon(r)} size={14} color={ROLE_COLOR[r]} />
                    {switchingRole === r ? "…" : `${myRoles.includes(r) ? "✓ " : "+ "}${roleLabel(r)}`}
                  </button>
                ))}
              </div>
              {switchMsg && <p className="mt-2 text-xs text-ink-muted">{switchMsg}</p>}
            </div>

            <div className="mt-4 border-t border-[#EADFDC] pt-4">
              <div className="truncate text-xs text-ink-muted">{user?.email}</div>
              <button onClick={logout} className="mt-2 inline-flex min-h-[40px] w-full items-center justify-center gap-2 rounded-full bg-white px-4 text-sm font-semibold text-[#231715] transition hover:bg-[#F0E3DF]">
                <AppIcon name="logout" size={16} />{t("dash_logout")}
              </button>
            </div>
          </div>
        </aside>

        {/* ── ZONE PRINCIPALE ── */}
        <main className="mt-6 md:mt-0">
          <div className={`relative overflow-hidden rounded-[28px] ${tint.bg} p-6 text-white md:p-9`}>
            <div className="flex items-start justify-between gap-3">
              <h1 className="font-display text-2xl font-bold tracking-[-0.02em] md:text-4xl">
                {t("dash_welcome")}, {firstName}
              </h1>
              <div className="flex shrink-0 items-center gap-1.5 text-xs" title={socketConnected ? t("dash_live") : t("dash_offline")}>
                <span className={`inline-block h-2 w-2 rounded-full ${socketConnected ? "bg-[#4ADE80] animate-pulse" : "bg-[#F4C04A]"}`} aria-hidden="true" />
                <span>{socketConnected ? t("dash_live") : t("dash_offline")}</span>
              </div>
            </div>
            <p className="mt-2 max-w-md text-[15px] text-[#FDF8F7]">{t("dash_sub")}</p>
            <div className="mt-4 flex flex-wrap gap-2">
              <button type="button" onClick={handleOpenApp} disabled={openingApp} className="inline-flex min-h-[40px] items-center gap-2 rounded-full bg-white px-4 text-sm font-semibold text-[#231715] transition hover:bg-[#F0E3DF] disabled:cursor-not-allowed disabled:opacity-70">
                {openingApp ? <span className="h-4 w-4 animate-spin rounded-full border-2 border-[#231715] border-t-transparent" /> : <AppIcon name="phone" size={16} color={tint.dark} />}
                <span>{openingApp ? t("dash_opening_app") : t("dash_open_app")}</span>
              </button>
              <Link href="/download" className="inline-flex min-h-[40px] items-center gap-2 rounded-full bg-[#231715] px-4 text-sm font-semibold text-white transition hover:bg-black">
                <AppIcon name="download" size={16} color="#fff" />{t("dash_download_app")}
              </Link>
            </div>
            {(openAppError || openAppHint) && (
              <div className="mt-4 rounded-xl bg-[#231715]/30 px-4 py-3 text-sm text-white">
                {openAppError ? <span role="alert">{openAppError}</span> : <span>{openAppHint}</span>}
              </div>
            )}
          </div>

          <NotificationBanner />

          {/* ── À FAIRE AUJOURD'HUI ── */}
          <section className="mt-4 rounded-[24px] bg-[#FAF1EC] p-5">
            <div className="flex items-center gap-2">
              <span className="grid h-9 w-9 place-items-center rounded-full text-white" style={{ background: ROLE_COLOR[role] }}><AppIcon name="check" size={18} color="#fff" /></span>
              <h2 className="font-display text-lg font-bold tracking-[-0.02em] text-[#231715]">{t("dash_today_title")}</h2>
              <span className="ml-auto text-xs font-semibold text-[#6E4F48]">{new Date().toLocaleDateString(lang, { weekday: "long", day: "numeric", month: "long" })}</span>
            </div>
            {todo.length === 0 ? (
              <div className="mt-3 flex flex-wrap items-center gap-3 rounded-2xl bg-white p-4">
                <p className="min-w-0 flex-1 text-sm text-[#231715]">{bookingsLoaded ? t("dash_today_none") : t("common_loading")}</p>
                <Link href="/map" className="inline-flex min-h-[40px] items-center gap-2 rounded-full px-4 text-sm font-bold text-white" style={{ background: ROLE_COLOR[role] }}>
                  <PawMapLogo size={20} title={null} />{t("dash_card_map_title")}
                </Link>
              </div>
            ) : (
              <ul className="mt-3 grid gap-2 lg:grid-cols-2">
                {todo.map((it) => (
                  <li key={it.label}>
                    <Link href={it.href} className="flex items-center gap-3 rounded-2xl bg-white p-3 transition hover:-translate-y-0.5" style={{ boxShadow: `inset 0 0 0 1.5px ${it.color}33` }}>
                      <span className="relative grid h-11 w-11 shrink-0 place-items-center rounded-full" style={{ background: it.light }}>
                        <AppIcon name={it.icon} size={22} color={it.color} />
                        {it.count != null && it.count > 0 && (
                          <span className="absolute -right-1 -top-1 flex h-5 min-w-[20px] items-center justify-center rounded-full px-1 text-[11px] font-bold text-white" style={{ background: it.color }}>{it.count > 99 ? "99+" : it.count}</span>
                        )}
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-sm font-bold text-[#231715]">{it.label}</span>
                        {it.sub && <span className="block truncate text-xs text-[#6E4F48]">{it.sub}</span>}
                      </span>
                      <span className="shrink-0 rounded-full px-3 py-1.5 text-xs font-bold text-white" style={{ background: it.color }}>{it.cta}</span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </section>

          {/* PawMap + Réservations : les deux grandes cartes. */}
          <div className="mt-4 grid gap-3 lg:grid-cols-2">
            <Link href="/map" className={`group flex items-center gap-4 rounded-[24px] bg-[#FAF1EC] p-5 text-[#231715] transition ${tint.hoverBg}`}>
              <span className="grid h-14 w-14 shrink-0 place-items-center rounded-full bg-white"><PawMapLogo size={38} title={null} /></span>
              <span className="min-w-0 flex-1">
                <span className="block text-base font-semibold">{t("dash_card_map_title")}</span>
                <span className="block text-sm text-[#6E4F48]">{t("dash_card_map_sub")}</span>
              </span>
              <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-white transition group-hover:translate-x-1"><AppIcon name="arrow-right" size={18} color={tint.dark} /></span>
            </Link>
            <Link href="/bookings" className={`group flex items-center gap-4 rounded-[24px] bg-[#FAF1EC] p-5 text-[#231715] transition ${tint.hoverBg}`}>
              <span className="grid h-14 w-14 shrink-0 place-items-center rounded-full bg-white"><AppIcon name="calendar" size={28} color={ROLE_COLOR[role]} /></span>
              <span className="min-w-0 flex-1">
                <span className="block text-base font-semibold">{t("dash_card_bookings_title")}</span>
                <span className="block text-sm text-[#6E4F48]">{isOwner ? t("dash_card_bookings_sub_owner") : t("dash_card_bookings_sub_provider")}</span>
              </span>
              <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-white transition group-hover:translate-x-1"><AppIcon name="arrow-right" size={18} color={tint.dark} /></span>
            </Link>
          </div>

          <h2 className="mt-10 font-display text-2xl font-bold tracking-[-0.02em] text-[#231715]">{t("dash_account_section")}</h2>
          <p className="mt-1 text-[15px] text-[#6E4F48]">{t("dash_account_section_sub")}</p>
          <div className="mt-4 grid gap-3 lg:grid-cols-2">
            <NavCard href="/posts" icon="megaphone" tint={tint} title={isOwner ? t("posts_my_title") : t("posts_feed_title")} subtitle={isOwner ? t("posts_create_cta") : t("posts_contact")} />
            <NavCard href="/chat" icon="chat" tint={tint} title={t("dash_card_messages_title")} subtitle={t("dash_card_messages_sub")} badge={unreadMsg} />
            {isOwner && <NavCard href="/pets" icon="pets" tint={tint} title={t("dash_card_pets_title")} subtitle={t("dash_card_pets_sub")} />}
            {isOwner && <NavCard href="/search" icon="search" tint={tint} title={t("dash_card_search_title")} subtitle={t("dash_card_search_sub")} />}
            {isProvider && <NavCard href="/sitter-setup" icon="settings" tint={tint} title={t("dash_card_setup_title")} subtitle={t("dash_card_setup_sub")} />}
            <NavCard href="/friends" icon="friends" tint={tint} title={t("dash_card_friends_title")} subtitle={t("dash_card_friends_sub")} />
            <NavCard href="/pawpoints" icon="coins" tint={tint} title={t("dash_card_pawpoints_title")} subtitle={t("dash_card_pawpoints_sub")} />
            <NavCard href="/invoices" icon="invoice" tint={tint} title={t("dash_card_invoices_title")} subtitle={t("dash_card_invoices_sub")} />
            <NavCard href="/profile" icon="profile" tint={tint} title={t("dash_card_profile_title")} subtitle={t("dash_card_profile_sub")} />
          </div>

          <a href="/boutique" className="group mt-4 flex items-center gap-4 rounded-[24px] bg-[#231715] p-5 transition hover:bg-black">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/pawpremium_logo.svg" alt="" width={44} height={44} />
            <div className="min-w-0">
              <div className="font-display text-base font-semibold text-[#FFD34D]">PawPremium</div>
              <div className="text-xs text-[#FDF8F7]">{t("dash_premium_sub")}</div>
            </div>
            <span className="ml-auto transition group-hover:translate-x-1"><AppIcon name="arrow-right" size={18} color="#FFD34D" /></span>
          </a>

          <div id="promo" className="mt-4 scroll-mt-24 rounded-[24px] bg-[#FAF1EC] p-5">
            <p className="flex items-center gap-2 text-sm font-semibold text-[#231715]">
              <AppIcon name="ticket" size={18} color={ROLE_COLOR[role]} /> {t("promo_title")}
            </p>
            <div className="mt-3 flex flex-col gap-2 sm:flex-row">
              <input type="text" value={promoCode} onChange={(e) => setPromoCode(e.target.value)} onKeyDown={(e) => { if (e.key === "Enter") handleApplyPromo(); }} placeholder={t("promo_placeholder")} className="min-w-0 flex-1 rounded-full border border-[#EADFDC] bg-white px-4 py-2.5 text-sm uppercase tracking-wide outline-none focus:border-[#C92A12]" />
              <button type="button" onClick={handleApplyPromo} disabled={promoBusy || !promoCode.trim()} className="min-h-[44px] shrink-0 rounded-full bg-[#231715] px-6 text-sm font-semibold text-white hover:bg-black disabled:opacity-60">
                {promoBusy ? "…" : t("promo_apply")}
              </button>
            </div>
            {promoMsg && <p className={`mt-3 text-sm ${promoMsg.ok ? "text-[#0F7C37]" : "text-[#B42318]"}`}>{promoMsg.text}</p>}
          </div>

          {/* 25/09 — LOT D : « Une idée ? Un problème ? » (même formulaire que l'app). */}
          <FeedbackBox tone={role} />
        </main>
      </div>
    </div>
  );
}

function SideLink({ href, icon, label, badge, tint }: { href: string; icon: AppIconName; label: string; badge?: number; tint: Tint }) {
  const pathname = usePathname();
  const current = pathname === href || (href !== "/dashboard" && pathname?.startsWith(href + "/"));
  return (
    <Link
      href={href}
      aria-current={current ? "page" : undefined}
      className={`group flex min-h-[40px] items-center gap-3 rounded-xl px-3 py-1.5 text-sm font-medium transition ${current ? `${tint.currentBg} ${tint.currentText}` : `text-[#231715] ${tint.hoverBg} ${tint.hoverText}`}`}
    >
      <span className="relative grid h-7 w-7 place-items-center">
        <AppIcon name={icon} size={19} color={current ? tint.dark : "currentColor"} />
        {badge && badge > 0 ? (
          <span className="absolute -right-2 -top-1 flex h-4 min-w-[16px] items-center justify-center rounded-full bg-[#C92A12] px-1 text-[10px] font-bold text-white">{badge > 99 ? "99+" : badge}</span>
        ) : null}
      </span>
      <span className="flex-1 truncate">{label}</span>
      <span className="text-ink-soft transition group-hover:translate-x-0.5">›</span>
    </Link>
  );
}

function NavCard({ href, icon, title, subtitle, badge, tint }: { href: string; icon: AppIconName; title: string; subtitle: string; badge?: number; tint: Tint }) {
  return (
    <Link href={href} className={`group flex items-center gap-4 rounded-[20px] bg-[#FAF1EC] p-4 transition ${tint.hoverBg}`}>
      <span className="relative flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-white">
        <AppIcon name={icon} size={22} color={tint.dark} />
        {badge && badge > 0 ? (
          <span className="absolute -right-1.5 -top-1.5 flex h-5 min-w-[20px] items-center justify-center rounded-full bg-[#C92A12] px-1 text-[11px] font-bold text-white shadow">{badge > 99 ? "99+" : badge}</span>
        ) : null}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block text-sm font-extrabold text-ink">{title}</span>
        <span className="block text-xs text-ink-muted">{subtitle}</span>
      </span>
      <span className="transition group-hover:translate-x-1"><AppIcon name="arrow-right" size={18} color={tint.dark} /></span>
    </Link>
  );
}
