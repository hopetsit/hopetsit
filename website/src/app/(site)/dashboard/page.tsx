"use client";

import Link from "@/components/SiteLink";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError, AuthUser, AuthRole, Booking, type ApplicationItem, type RequestPost, type UserProfile,
  applicationId, applicationProvider, clearAuth, getConversations, getMyApplications, getMyBookings,
  getMyPosts, getMyProfile, getMyRoles, getRequestPosts, getStoredUser, postId as postIdOf, redeemPromo, switchRole,
} from "@/lib/api";
import { useSocket, useSocketEvent } from "@/lib/useSocket";
import { disconnectSocket } from "@/lib/socket";
import NotificationBanner from "@/components/NotificationBanner";
import { PawMapLogo } from "@/components/PawMapLogo";
import { AppIcon, type AppIconName } from "@/components/AppIcon";
import { PageTitle } from "@/components/PageTitle";
import { ROLE_COLOR } from "@/lib/pawmapLegend";
import { FeedbackBox } from "@/components/FeedbackBox";
import { SignatureButton } from "@/components/SignatureButton";
import { RankProgress611 } from "@/components/Rank611";
import { PinChips1910 } from "@/components/Pins1910";
import { RatesGrid620 } from "@/components/RatesGrid620";
import { VehicleToggle1011 } from "@/components/VehicleToggle1011";
import { parsePins1910, type Pins1910 } from "@/lib/pins1910";
import { parseRank611, type Rank611 } from "@/lib/ranks611";
import { d620 } from "@/lib/i18n/dates620";
import { dz } from "@/lib/i18n/dash3110";
import { point3110, sortCandidates3110, totalOf3110 } from "@/lib/cand3110";

// v493 — barre latérale + zone principale. 24/09 — centre de réservation (À faire aujourd'hui).
// 31/10/2026 — LEO-B (Daniel : « améliore tout le tableau de bord quand je me connecte ») :
//   • plus AUCUN « continue dans l'app » : 37 propriétaires sur 39 n'ont pas l'app et tout le
//     parcours (publier, candidats, choisir, payer) marche ici. L'app = une petite ligne.
//   • premier écran = ce qui fait payer, selon le rôle actif :
//       propriétaire → « Mes demandes » : statut vrai de chaque demande (N réponses, dates à poser,
//       à payer, réservé avec X), le candidat le plus proche (même tri que /application) et UN
//       bouton vers /application/<id> (la page en une étape) ; aucune demande → « Publier ma demande » ;
//       gardien / promeneur → « Mes candidatures » (en attente / choisi / pas retenue) + demandes
//       près de moi + profil à compléter.
//   • « À faire aujourd'hui » calculé sur ses vraies données ; « Rien d'urgent » seulement si vrai.
//   • menu regroupé (6 entrées + « Plus »), libellés sur une ligne, plus de cartes qui répètent
//     le menu ; PawPremium en carte légère ; code promo et « Une idée ? » repliés, en bas.
//   • sur téléphone, le contenu passe AVANT le menu (le menu de 14 lignes remplissait l'écran).
// Données : routes existantes seulement (/posts/my, /applications/my, /bookings/my,
// /conversations/list, /posts/requests, /users/me/profile, /users/me/roles). Aucun prix calculé ici :
// le total affiché est celui du serveur (totalOf3110, comme /application). Rien de payé ici.
// ⚠️ Tous les hooks restent AVANT le `if (loading) return` (piège du 20/09).

type Tint = { bg: string; light: string; dark: string; line: string; hoverBg: string; hoverText: string; currentBg: string; currentText: string };
const TINTS: Record<AuthRole, Tint> = {
  owner: { bg: "bg-owner", light: "#FBE9E5", dark: "#9E1F0B", line: "#F3D3CB", hoverBg: "hover:bg-owner-light", hoverText: "hover:text-owner-dark", currentBg: "bg-owner-light", currentText: "text-owner-dark" },
  sitter: { bg: "bg-sitter", light: "#E3EFFE", dark: "#0E5BC0", line: "#C9DDFB", hoverBg: "hover:bg-sitter-light", hoverText: "hover:text-sitter-dark", currentBg: "bg-sitter-light", currentText: "text-sitter-dark" },
  walker: { bg: "bg-walker", light: "#DEF7E5", dark: "#0F7C37", line: "#BFE8CC", hoverBg: "hover:bg-walker-light", hoverText: "hover:text-walker-dark", currentBg: "bg-walker-light", currentText: "text-walker-dark" },
};
const INK = "#231715";
const INK2 = "#6E4F48";

function bookingDate(b: Booking): number {
  const d = b.startDate || b.serviceDate || b.date;
  const tms = d ? new Date(d).getTime() : NaN;
  return Number.isFinite(tms) ? tms : Infinity;
}

function money(v: number, currency: string, lang: string): string {
  try {
    return new Intl.NumberFormat(lang, { style: "currency", currency: currency || "EUR", maximumFractionDigits: Number.isInteger(v) ? 0 : 2 }).format(v);
  } catch {
    return `${v} ${currency}`;
  }
}

/** Réservation liée à une candidature acceptée : id + payée ou non (même lecture que /application). */
function linkedBooking(a: ApplicationItem): { id: string; paid: boolean } | null {
  const b = (a.booking || (a.bookingId && typeof a.bookingId === "object" ? (a.bookingId as Booking) : null)) as (Booking & { _id?: string }) | null;
  if (b) {
    const id = String(b.id || b._id || "");
    if (!id) return null;
    return { id, paid: String(b.paymentStatus || "").toLowerCase() === "paid" || b.status === "paid" };
  }
  if (typeof a.bookingId === "string" && a.bookingId) return { id: a.bookingId, paid: false };
  return null;
}

type ReqState = "topay" | "cands" | "dates" | "none" | "booked";
type ReqCard = {
  pid: string;
  state: ReqState;
  svc: string;
  pet: string;
  dates: string;
  count: number;
  best: ApplicationItem | null;
  others: ApplicationItem[];
  chosenName: string;
  price: string;
  href: string;
};
const STATE_ORDER: Record<ReqState, number> = { topay: 0, cands: 1, dates: 2, none: 3, booked: 4 };

export default function DashboardPage() {
  const { t, lang } = useT();
  const router = useRouter();
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [switchingRole, setSwitchingRole] = useState<AuthRole | null>(null);
  const [switchMsg, setSwitchMsg] = useState<string | null>(null);
  const [promoCode, setPromoCode] = useState("");
  const [promoBusy, setPromoBusy] = useState(false);
  const [promoMsg, setPromoMsg] = useState<{ ok: boolean; text: string } | null>(null);

  const { connected: socketConnected } = useSocket();
  const [liveToast, setLiveToast] = useState<{ icon: AppIconName; text: string } | null>(null);
  const [premiumLeft, setPremiumLeft] = useState<number | null>(null);
  useEffect(() => {
    (async () => {
      try {
        const { getSubscriptionStatus } = await import("@/lib/api");
        const st = await getSubscriptionStatus();
        const staff = st.currentPeriodEnd ? new Date(st.currentPeriodEnd).getFullYear() >= 2090 : false;
        if (st.premiumExpiry && new Date(st.premiumExpiry) > new Date()) {
          const d = Math.ceil((new Date(st.premiumExpiry).getTime() - Date.now()) / 86400000);
          setPremiumLeft(d);
        } else if (staff) {
          setPremiumLeft(-1);
        }
      } catch { /* pas connecté / pas premium → rien */ }
    })();
  }, []);
  const [myRank, setMyRank] = useState<Rank611 | null>(null);
  const [myPins, setMyPins] = useState<Pins1910 | null>(null);
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        if (!getStoredUser()) return;
        const { getMyPawPoints } = await import("@/lib/api");
        const me = await getMyPawPoints();
        if (alive) { setMyRank(parseRank611(me?.rank)); setMyPins(parsePins1910(me?.pins)); }
      } catch { /* pas de rang */ }
    })();
    return () => { alive = false; };
  }, []);
  // v574 — profils déjà activés (règle du 31/10 : une personne = 3 profils au même e-mail).
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
      } catch { /* 0 */ }
    })();
  }, []);

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

  // Mes candidatures (le serveur filtre par rôle : candidats reçus pour un propriétaire,
  // propositions envoyées pour un gardien / promeneur) + mes demandes (propriétaire).
  const [apps, setApps] = useState<ApplicationItem[]>([]);
  const [posts, setPosts] = useState<RequestPost[]>([]);
  const [mainLoaded, setMainLoaded] = useState(false);
  const [nearbyCount, setNearbyCount] = useState<number | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  useEffect(() => {
    let alive = true;
    if (!user) return;
    setMainLoaded(false);
    const owner = user.role === "owner";
    Promise.all([
      getMyApplications().catch(() => [] as ApplicationItem[]),
      owner ? getMyPosts().catch(() => [] as RequestPost[]) : Promise.resolve([] as RequestPost[]),
    ]).then(([a, p]) => {
      if (!alive) return;
      setApps(a);
      setPosts(p);
    }).finally(() => { if (alive) setMainLoaded(true); });
    if (!owner) {
      getRequestPosts()
        .then((list) => { if (alive) setNearbyCount(list.filter((x) => (x.status || "open") !== "closed").length); })
        .catch(() => { if (alive) setNearbyCount(null); });
      getMyProfile().then((pr) => { if (alive) setProfile(pr); }).catch(() => {});
    }
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
  const accent = ROLE_COLOR[role];
  const isOwner = role === "owner";
  const isProvider = !isOwner;

  const fmtDay = (d?: string | null) => {
    if (!d) return "";
    const x = new Date(d);
    return Number.isFinite(x.getTime()) ? x.toLocaleDateString(lang, { day: "numeric", month: "short" }) : "";
  };

  // Réservations : à payer, demandes à accepter, en cours, prochaine.
  const today = useMemo(() => {
    const startOfDay = new Date(); startOfDay.setHours(0, 0, 0, 0);
    const toPay = bookings.filter((b) => (b.status === "accepted" || b.status === "agreed") && b.paymentStatus !== "paid");
    const pendingReq = bookings.filter((b) => b.status === "pending");
    const live = bookings.find((b) => b.confirmationStatus === "in_progress" || (!!b.serviceStartedAt && !b.serviceEndedAt && b.status !== "completed" && b.status !== "cancelled"));
    const upcoming = bookings
      .filter((b) => (b.status === "paid" || b.status === "agreed" || b.status === "accepted") && bookingDate(b) >= startOfDay.getTime())
      .sort((a, b) => bookingDate(a) - bookingDate(b));
    return { toPay, pendingReq, live, next: upcoming[0] };
  }, [bookings]);

  // Propriétaire : une carte par demande ouverte, avec son statut vrai.
  const reqCards: ReqCard[] = useMemo(() => {
    if (!isOwner) return [];
    const paidBookingIds = new Set(bookings.filter((b) => b.paymentStatus === "paid" || b.status === "paid" || b.status === "completed").map((b) => b.id));
    const svcOf = (types?: string[], fallback?: string) => {
      const list = (types && types.length ? types : fallback ? [fallback] : []).map((s) => d620(lang, `svc_${s}`)).filter((x) => !x.startsWith("svc_"));
      return list.join(" · ");
    };
    const out: ReqCard[] = [];
    for (const p of posts) {
      if ((p.postType && p.postType !== "request") || p.status === "closed") continue;
      const pid = String(postIdOf(p) || "");
      if (!pid) continue;
      const mine = apps.filter((a) => String(a.postId || "") === pid);
      const pet = (p.pets || []).map((x) => x.petName).filter(Boolean).join(", ");
      const tbd = (p.dateMode || "") === "tbd" || !p.startDate;
      const dates = tbd ? dz(lang, "dates_tbd") : [fmtDay(p.startDate), fmtDay(p.endDate)].filter(Boolean).filter((x, i, arr) => arr.indexOf(x) === i).join(" → ");
      const base = { pid, svc: svcOf(p.serviceTypes), pet, dates };
      const accepted = mine.find((a) => a.status === "accepted");
      if (accepted) {
        const lb = linkedBooking(accepted);
        const { who } = applicationProvider(accepted);
        const name = (who?.name || "").split(" ")[0] || "";
        const paid = !!lb && (lb.paid || paidBookingIds.has(lb.id));
        const total = accepted.pricing?.totalPrice;
        const cur = accepted.pricing?.currency || "EUR";
        out.push({
          ...base, state: paid ? "booked" : "topay", count: mine.length, best: accepted, others: [], chosenName: name,
          price: total && total > 0 ? money(total, cur, lang) : "",
          dates: paid ? fmtDay(accepted.startDate || p.startDate) : base.dates,
          href: paid ? "/bookings" : `/application/${applicationId(accepted)}`,
        });
        continue;
      }
      const pending = mine.filter((a) => a.status === "pending");
      if (pending.length) {
        const sorted = sortCandidates3110(pending, point3110(p.location || null));
        const best = sorted[0];
        const priced = pending.some((a) => totalOf3110(a) != null);
        const bt = totalOf3110(best);
        out.push({
          ...base, state: tbd || !priced ? "dates" : "cands", count: pending.length, best, others: sorted.slice(1, 4), chosenName: "",
          price: bt != null ? money(bt, best.pricing?.currency || "EUR", lang) : "",
          href: `/application/${applicationId(best)}`,
        });
        continue;
      }
      out.push({ ...base, state: "none", count: 0, best: null, others: [], chosenName: "", price: "", href: "/posts" });
    }
    return out.sort((a, b) => STATE_ORDER[a.state] - STATE_ORDER[b.state]);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isOwner, posts, apps, bookings, lang]);

  if (loading) {
    return <div className="mx-auto max-w-md px-4 py-24 text-center text-[#6E4F48]">{t("common_loading")}</div>;
  }

  function logout() {
    disconnectSocket();
    clearAuth();
    router.replace("/");
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
  const roleWord = (r: AuthRole) => dz(lang, `role_${r}`);

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
  const otherRoles = (["owner", "sitter", "walker"] as AuthRole[]).filter((r) => r !== role);
  // Le profil « frère » le plus utile à proposer : propriétaire pour un prestataire, sinon un rôle déjà activé.
  const suggestRole: AuthRole | null = isProvider ? "owner" : (otherRoles.find((r) => myRoles.includes(r)) || null);

  // Sous-titre de l'accueil : la phrase vraie du moment.
  const pendingTotal = reqCards.reduce((n, c) => n + (c.state === "cands" || c.state === "dates" ? c.count : 0), 0);
  let heroSub = dz(lang, "sub_provider");
  if (isOwner) {
    if (!mainLoaded) heroSub = "";
    else if (reqCards.length === 0) heroSub = dz(lang, "sub_owner_empty");
    else if (reqCards.some((c) => c.state === "topay")) heroSub = dz(lang, "sub_owner_topay", { name: reqCards.find((c) => c.state === "topay")?.chosenName || "" });
    else if (pendingTotal > 0) heroSub = dz(lang, pendingTotal === 1 ? "sub_owner_cands_one" : "sub_owner_cands_many", { n: pendingTotal });
    else if (reqCards.every((c) => c.state === "booked")) heroSub = dz(lang, "sub_owner_booked");
    else heroSub = dz(lang, "sub_owner_wait");
  }

  // « À faire aujourd'hui » : une action par tuile, tirée des vraies données.
  const todo: { icon: AppIconName; count: number | null; label: string; sub?: string; href: string; cta: string; color: string; light: string }[] = [];
  const OW = { color: ROLE_COLOR.owner, light: "#FBE9E5" };
  if (isOwner) {
    for (const c of reqCards.filter((x) => x.state === "topay")) {
      todo.push({ icon: "wallet", count: null, label: dz(lang, "todo_pay"), sub: `${c.chosenName} · ${c.svc}`, href: c.href, cta: dz(lang, "pay"), ...OW });
    }
    // Réservation acceptée à payer qui ne vient pas d'une demande (réservation directe).
    const fromCards = reqCards.filter((x) => x.state === "topay").length;
    if (today.toPay.length > fromCards) {
      const b = today.toPay[0];
      todo.push({ icon: "wallet", count: today.toPay.length - fromCards, label: dz(lang, "todo_pay"), sub: `${b.otherParty?.name || ""} ${fmtDate(b)}`.trim(), href: `/pay?bookingId=${encodeURIComponent(b.id)}`, cta: dz(lang, "pay"), ...OW });
    }
    for (const c of reqCards.filter((x) => x.state === "cands")) {
      todo.push({ icon: "people", count: c.count, label: dz(lang, "todo_choose"), sub: `${c.svc}${c.pet ? ` · ${c.pet}` : ""}`, href: c.href, cta: dz(lang, "see"), ...OW });
    }
    for (const c of reqCards.filter((x) => x.state === "dates")) {
      todo.push({ icon: "calendar", count: c.count, label: dz(lang, "todo_dates"), sub: dz(lang, "todo_dates_sub"), href: c.href, cta: dz(lang, "go"), ...OW });
    }
  }
  if (isProvider && today.pendingReq.length > 0) {
    todo.push({ icon: "megaphone", count: today.pendingReq.length, label: dz(lang, "todo_answer"), sub: `${today.pendingReq[0].otherParty?.name || ""} ${fmtDate(today.pendingReq[0])}`.trim(), href: "/bookings", cta: dz(lang, "see"), color: tint.dark, light: tint.light });
  }
  if (today.live) {
    const b = today.live;
    todo.push({ icon: "map", count: null, label: dz(lang, "todo_live"), sub: `${b.otherParty?.name || ""}`.trim(), href: b.walkerId ? `/walk/${b.id}` : "/map", cta: dz(lang, "see"), color: "#7C3AED", light: "#EDE9FE" });
  }
  if (unreadMsg > 0) {
    todo.push({ icon: "chat", count: unreadMsg, label: dz(lang, "todo_unread"), href: "/chat", cta: dz(lang, "see"), color: ROLE_COLOR.sitter, light: "#E3EFFE" });
  }
  const profileIncomplete = isProvider && !!profile && (!profile.avatar?.url || (profile.bio || "").trim().length < 20);
  if (profileIncomplete) {
    todo.push({ icon: "profile", count: null, label: dz(lang, "todo_profile"), sub: dz(lang, "todo_profile_sub"), href: "/profile", cta: dz(lang, "go"), color: tint.dark, light: tint.light });
  }
  if (isProvider && nearbyCount && nearbyCount > 0 && !apps.some((a) => a.status === "pending")) {
    todo.push({ icon: "megaphone", count: null, label: dz(lang, "todo_nearby", { n: nearbyCount }), sub: dz(lang, "todo_nearby_sub"), href: "/posts", cta: dz(lang, "see"), color: tint.dark, light: tint.light });
  }
  if (today.next && today.next !== today.live && !today.toPay.includes(today.next)) {
    const b = today.next;
    todo.push({ icon: "calendar", count: null, label: dz(lang, "todo_next"), sub: `${fmtDate(b)} · ${b.otherParty?.name || ""}`.trim(), href: "/bookings", cta: dz(lang, "see"), color: ROLE_COLOR.walker, light: "#DEF7E5" });
  }
  const todoReady = bookingsLoaded && mainLoaded;

  // Menu : 6 entrées principales + « Plus » (aucune carte ne les répète plus).
  const mainNav: { href: string; icon: AppIconName; label: string; badge?: number }[] = isOwner
    ? [
        { href: "/posts", icon: "megaphone", label: dz(lang, "nav_requests") },
        { href: "/bookings", icon: "calendar", label: dz(lang, "nav_bookings") },
        { href: "/chat", icon: "chat", label: dz(lang, "nav_messages"), badge: unreadMsg },
        { href: "/pets", icon: "pets", label: dz(lang, "nav_pets") },
        { href: "/profile", icon: "shield-check", label: dz(lang, "nav_profile") },
        { href: "/map", icon: "map", label: dz(lang, "nav_map") },
      ]
    : [
        { href: "/posts", icon: "megaphone", label: dz(lang, "nav_nearby") },
        { href: "/bookings", icon: "calendar", label: dz(lang, "nav_bookings") },
        { href: "/chat", icon: "chat", label: dz(lang, "nav_messages"), badge: unreadMsg },
        { href: "/sitter-setup", icon: "settings", label: dz(lang, "nav_rates") },
        { href: "/profile", icon: "shield-check", label: dz(lang, "nav_profile") },
        { href: "/map", icon: "map", label: dz(lang, "nav_map") },
      ];
  const moreNav: { href: string; icon: AppIconName; label: string }[] = [
    { href: "/pawpoints", icon: "coins", label: t("dash_card_pawpoints_title") },
    { href: "/family", icon: "family", label: t("family_title") },
    { href: "/friends", icon: "friends", label: dz(lang, "nav_friends") },
    { href: "/boutique", icon: "shop", label: t("dash_card_shop_title") },
    { href: "/invoices", icon: "invoice", label: dz(lang, "nav_invoices") },
    { href: "#promo", icon: "ticket", label: dz(lang, "nav_promo") },
  ];

  const statusLine = (c: ReqCard): { text: string; color: string; icon: AppIconName } => {
    switch (c.state) {
      case "booked": return { text: c.dates ? dz(lang, "st_booked", { name: c.chosenName, svc: c.svc.toLowerCase(), date: c.dates }) : dz(lang, "st_booked_nodate", { name: c.chosenName }), color: "#0F7C37", icon: "check" };
      case "topay": return { text: dz(lang, "st_topay", { name: c.chosenName }), color: "#9E1F0B", icon: "wallet" };
      case "cands": return { text: dz(lang, c.count === 1 ? "st_cands_one" : "st_cands_many", { n: c.count }), color: "#9E1F0B", icon: "people" };
      case "dates": return { text: `${dz(lang, c.count === 1 ? "st_cands_one" : "st_cands_many", { n: c.count })} · ${dz(lang, "st_dates")}`, color: "#9E1F0B", icon: "calendar" };
      default: return { text: dz(lang, "st_none"), color: INK2, icon: "clock" };
    }
  };
  const ctaOf = (c: ReqCard) => {
    switch (c.state) {
      case "booked": return dz(lang, "cta_booking");
      case "topay": return c.price ? dz(lang, "cta_pay", { price: c.price }) : dz(lang, "cta_pay_noprice");
      case "cands": return dz(lang, "cta_cands");
      case "dates": return dz(lang, "cta_dates");
      default: return dz(lang, "cta_post");
    }
  };

  const Avatar = ({ a, size }: { a: ApplicationItem; size: number }) => {
    const { role: r, who } = applicationProvider(a);
    const name = who?.name || "?";
    const ini = name.split(/\s+/).map((w) => w[0] || "").slice(0, 2).join("").toUpperCase();
    const ring = ROLE_COLOR[r];
    return who?.avatar ? (
      // eslint-disable-next-line @next/next/no-img-element
      <img src={who.avatar} alt="" width={size} height={size} className="shrink-0 rounded-full object-cover" style={{ width: size, height: size, boxShadow: `0 0 0 2px #fff, 0 0 0 3.5px ${ring}` }} />
    ) : (
      <span className="grid shrink-0 place-items-center rounded-full text-xs font-bold text-white" style={{ width: size, height: size, background: ring, boxShadow: "0 0 0 2px #fff" }}>{ini}</span>
    );
  };

  const appPill = (s: string) => {
    if (s === "accepted") return { text: dz(lang, "app_accepted"), bg: "#DEF7E5", fg: "#0F7C37" };
    if (s === "rejected") return { text: dz(lang, "app_rejected"), bg: "#F6E7E2", fg: "#7A4A40" };
    if (s === "cancelled") return { text: dz(lang, "app_cancelled"), bg: "#F6E7E2", fg: "#7A4A40" };
    return { text: dz(lang, "app_pending"), bg: "#FFF1DC", fg: "#8A4B00" };
  };

  return (
    <div className="mx-auto max-w-6xl px-4 py-6 md:py-10">
      <PageTitle titleKey="page_title_dashboard" />
      {liveToast && (
        <div role="status" aria-live="polite" className="fixed left-1/2 top-6 z-50 flex max-w-[92vw] -translate-x-1/2 transform items-center gap-2 rounded-full bg-[#231715] px-5 py-3 text-sm font-medium text-white shadow-lg">
          <AppIcon name={liveToast.icon} size={16} color="#F4C04A" />
          <span className="truncate">{liveToast.text}</span>
        </div>
      )}

      <div className="flex flex-col gap-6 lg:grid lg:grid-cols-[256px_minmax(0,1fr)] lg:gap-8">
        {/* ── MENU ── sur téléphone et tablette il passe APRÈS le contenu (order-2) ; à côté dès 1024 px. */}
        <aside className="order-2 lg:order-none lg:sticky lg:top-6 lg:self-start" aria-label={t("page_title_dashboard")}>
          <div className="rounded-[24px] bg-[#FAF1EC] p-4">
            <div className="flex items-center gap-3 px-1">
              <div className={`grid h-10 w-10 shrink-0 place-items-center rounded-full ${tint.bg} text-white`}>
                <AppIcon name={roleIcon(role)} size={20} color="#fff" />
              </div>
              <div className="min-w-0">
                <div className="truncate text-sm font-semibold text-[#231715]">{firstName}</div>
                <div className="text-xs font-semibold" style={{ color: tint.dark }}>{user?.role ? t(`dash_role_${user.role}`) : ""}</div>
              </div>
            </div>

            <nav className="mt-3 grid grid-cols-1 gap-0.5 sm:grid-cols-2 lg:grid-cols-1">
              {mainNav.map((n) => <SideLink key={n.href} href={n.href} icon={n.icon} label={n.label} badge={n.badge} tint={tint} />)}
            </nav>

            <details className="group/more mt-1">
              <summary className="flex min-h-[40px] cursor-pointer list-none items-center gap-3 rounded-xl px-3 text-sm font-medium text-[#231715] transition hover:bg-white [&::-webkit-details-marker]:hidden">
                <span className="grid h-7 w-7 place-items-center"><AppIcon name="layers" size={18} color={INK} /></span>
                <span className="flex-1 whitespace-nowrap">{dz(lang, "nav_more")}</span>
                <span className="text-[#9E6B5F] transition group-open/more:rotate-90">›</span>
              </summary>
              <div className="mt-0.5 grid grid-cols-1 gap-0.5 pl-2 sm:grid-cols-2 lg:grid-cols-1">
                {moreNav.map((n) => <SideLink key={n.href} href={n.href} icon={n.icon} label={n.label} tint={tint} small />)}
              </div>
            </details>

            <div className="mt-3 border-t border-[#EADFDC] pt-3">
              <p className="px-1 text-[11px] font-bold uppercase tracking-wide text-[#8A6A62]">{t("dash_switch_role_title")}</p>
              <div className="mt-2 flex flex-wrap gap-1.5">
                {otherRoles.map((r) => (
                  <button key={r} type="button" onClick={() => handleSwitchRole(r)} disabled={switchingRole !== null} className="inline-flex min-h-[34px] items-center gap-1.5 whitespace-nowrap rounded-full bg-white px-3 text-xs font-semibold text-[#231715] transition hover:bg-[#F0E3DF] disabled:opacity-60">
                    <AppIcon name={roleIcon(r)} size={14} color={ROLE_COLOR[r]} />
                    {switchingRole === r ? "…" : `${myRoles.includes(r) ? "✓ " : "+ "}${t(`dash_role_${r}`)}`}
                  </button>
                ))}
              </div>
              {switchMsg && <p className="mt-2 text-xs text-[#6E4F48]">{switchMsg}</p>}
            </div>

            <div className="mt-3 border-t border-[#EADFDC] pt-3">
              <div className="truncate px-1 text-xs text-[#6E4F48]">{user?.email}</div>
              <button onClick={logout} className="mt-2 inline-flex min-h-[40px] w-full items-center justify-center gap-2 rounded-full bg-white px-4 text-sm font-semibold text-[#231715] transition hover:bg-[#F0E3DF]">
                <AppIcon name="logout" size={16} />{t("dash_logout")}
              </button>
            </div>
          </div>
        </aside>

        {/* ── CONTENU ── */}
        <main className="order-1 min-w-0 lg:order-none">
          {/* Accueil : bonjour + la phrase vraie du moment. L'app n'est qu'une petite ligne. */}
          <section className="rounded-[28px] bg-white p-5 md:p-7" style={{ boxShadow: `inset 0 0 0 1.5px ${tint.line}` }} data-dash="hello">
            <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
              <h1 className="font-display text-[26px] font-bold leading-tight tracking-[-0.02em] text-[#231715] md:text-4xl">
                {dz(lang, "hello", { name: firstName })}
              </h1>
              <span className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full px-3 py-1 text-xs font-bold" style={{ background: tint.light, color: tint.dark }}>
                <AppIcon name={roleIcon(role)} size={14} color={tint.dark} />{user?.role ? t(`dash_role_${user.role}`) : ""}
              </span>
              {socketConnected && (
                <span className="ml-auto inline-flex items-center gap-1.5 text-xs font-semibold text-[#0F7C37]">
                  <span className="inline-block h-2 w-2 animate-pulse rounded-full bg-[#16A34A]" aria-hidden="true" />{dz(lang, "live")}
                </span>
              )}
            </div>
            {heroSub && <p className="mt-2 max-w-2xl text-[15px] leading-relaxed text-[#6E4F48]">{heroSub}</p>}
            <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2">
              {suggestRole && (
                <span className="inline-flex flex-wrap items-center gap-x-2 gap-y-1">
                  {myRoles.includes(suggestRole) && <span className="text-[13px] font-semibold text-[#6E4F48]">{dz(lang, "switch_to", { role: roleWord(suggestRole) })}</span>}
                  <button type="button" onClick={() => handleSwitchRole(suggestRole)} disabled={switchingRole !== null} className="inline-flex min-h-[36px] items-center gap-1.5 whitespace-nowrap rounded-full px-3 text-[13px] font-bold transition disabled:opacity-60" style={{ background: TINTS[suggestRole].light, color: TINTS[suggestRole].dark }} data-dash="switch">
                    <AppIcon name={roleIcon(suggestRole)} size={14} color={TINTS[suggestRole].dark} />
                    {myRoles.includes(suggestRole) ? dz(lang, "switch_cta", { role: roleWord(suggestRole) }) : dz(lang, "switch_add", { role: roleWord(suggestRole) })}
                  </button>
                </span>
              )}
              <Link href="/download" className="inline-flex items-center gap-1.5 whitespace-nowrap text-[13px] font-semibold" style={{ color: tint.dark }}>
                <AppIcon name="phone" size={14} color={tint.dark} />{dz(lang, "also_app")}
              </Link>
            </div>
          </section>

          <NotificationBanner />

          {/* ── PROPRIÉTAIRE : MES DEMANDES ── */}
          {isOwner && (
            <section className="mt-4" data-dash="requests">
              {!mainLoaded ? (
                <div className="rounded-[24px] bg-[#FAF1EC] p-5 text-sm text-[#6E4F48]" aria-busy="true">{dz(lang, "loading")}</div>
              ) : reqCards.length === 0 ? (
                <div className="relative overflow-hidden rounded-[28px] p-6 text-white md:p-8" style={{ background: "linear-gradient(135deg,#D83C28 0%,#B92425 100%)" }} data-dash="empty">
                  <AppIcon name="paw" size={120} color="#E8705F" className="pointer-events-none absolute -right-4 -top-4 rotate-12" />
                  <h2 className="relative font-display text-2xl font-bold tracking-[-0.02em] md:text-3xl">{dz(lang, "empty_title")}</h2>
                  <p className="relative mt-2 max-w-xl text-[15px] leading-relaxed text-[#FFF3EF]">{dz(lang, "empty_sub")}</p>
                  <Link href="/posts/create" className="relative mt-5 inline-flex min-h-[52px] items-center justify-center gap-2 whitespace-nowrap rounded-full bg-white px-7 text-base font-extrabold text-[#9E1F0B] shadow-[0_6px_18px_rgba(120,20,8,0.25)] transition hover:-translate-y-0.5">
                    <AppIcon name="megaphone" size={18} color="#C92A12" />{dz(lang, "empty_cta")}
                  </Link>
                  <p className="relative mt-3 text-xs font-semibold text-[#FFE1D8]">{dz(lang, "empty_note")}</p>
                </div>
              ) : (
                <>
                  <div className="flex flex-wrap items-end justify-between gap-2">
                    <div>
                      <h2 className="font-display text-xl font-bold tracking-[-0.02em] text-[#231715] md:text-2xl">{dz(lang, "my_requests")}</h2>
                      <p className="text-[13px] text-[#6E4F48]">{dz(lang, "my_requests_sub")}</p>
                    </div>
                    <Link href="/posts/create" className="inline-flex min-h-[36px] items-center gap-1.5 whitespace-nowrap rounded-full bg-[#FBE9E5] px-3 text-[13px] font-bold text-[#9E1F0B] transition hover:bg-[#F7D9D2]">
                      <span aria-hidden="true">+</span>{dz(lang, "new_request")}
                    </Link>
                  </div>
                  <ul className="mt-3 space-y-3">
                    {reqCards.map((c) => {
                      const st = statusLine(c);
                      const primary = c.state !== "none" && c.state !== "booked";
                      const best = c.best;
                      const bw = best ? applicationProvider(best).who : null;
                      return (
                        <li key={c.pid} className="rounded-[24px] bg-white p-4 md:p-5" style={{ boxShadow: `inset 0 0 0 1.5px ${c.state === "booked" ? "#BFE8CC" : "#F3D3CB"}` }} data-dash-state={c.state}>
                          <div className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
                            <p className="text-[15px] font-bold text-[#231715]">{c.svc}{c.pet ? <span className="font-semibold text-[#6E4F48]"> · {c.pet}</span> : null}</p>
                            {c.state !== "booked" && <p className="inline-flex items-center gap-1 whitespace-nowrap text-xs font-semibold text-[#6E4F48]"><AppIcon name="calendar" size={13} color={INK2} />{c.dates}</p>}
                          </div>
                          <p className="mt-1.5 flex items-start gap-1.5 text-sm font-bold" style={{ color: st.color }}>
                            <AppIcon name={st.icon} size={16} color={st.color} className="mt-0.5 shrink-0" />{st.text}
                          </p>
                          <div className="mt-3 flex flex-col gap-3 sm:flex-row sm:items-center">
                            {best && c.state !== "none" && (
                              <div className="flex min-w-0 flex-1 items-center gap-3">
                                <Avatar a={best} size={44} />
                                <div className="min-w-0">
                                  <p className="flex items-center gap-1.5 truncate text-sm font-bold text-[#231715]">
                                    {(bw?.name || "").split(" ")[0]}
                                    {(c.state === "cands" || c.state === "dates") && c.count > 1 && <span className="whitespace-nowrap rounded-full bg-[#FBE9E5] px-2 py-0.5 text-[10px] font-bold uppercase text-[#9E1F0B]">{dz(lang, "best")}</span>}
                                  </p>
                                  <p className="flex flex-wrap items-center gap-x-2 text-xs text-[#6E4F48]">
                                    {bw?.rating ? <span className="text-[#8A4B00]">★ {Number(bw.rating).toFixed(1)}</span> : null}
                                    {bw?.identityVerified ? <span className="inline-flex items-center gap-0.5 text-[#0F7C37]"><AppIcon name="shield-check" size={12} color="#0F7C37" />{dz(lang, "verified")}</span> : null}
                                    {c.price ? <span className="font-bold text-[#231715]">{dz(lang, "total", { price: c.price })}</span> : null}
                                  </p>
                                </div>
                                {c.others.length > 0 && (
                                  <div className="ml-1 hidden -space-x-2 sm:flex" aria-hidden="true">
                                    {c.others.map((o) => <Avatar key={applicationId(o)} a={o} size={28} />)}
                                  </div>
                                )}
                              </div>
                            )}
                            {!best && <div className="flex-1" />}
                            <Link
                              href={c.href}
                              className={`inline-flex min-h-[48px] w-full items-center justify-center gap-2 whitespace-nowrap rounded-full px-5 text-[15px] font-extrabold transition hover:-translate-y-0.5 sm:w-auto ${primary ? "text-white shadow-[0_6px_16px_rgba(201,42,18,0.28)]" : ""}`}
                              style={primary ? { background: "linear-gradient(90deg,#D83C28,#B92425)" } : { background: c.state === "booked" ? "#DEF7E5" : "#FBE9E5", color: c.state === "booked" ? "#0F7C37" : "#9E1F0B" }}
                              data-dash-cta={c.state}
                            >
                              {ctaOf(c)}<AppIcon name="arrow-right" size={16} color={primary ? "#fff" : c.state === "booked" ? "#0F7C37" : "#9E1F0B"} />
                            </Link>
                          </div>
                        </li>
                      );
                    })}
                  </ul>
                </>
              )}
            </section>
          )}

          {/* ── GARDIEN / PROMENEUR : CANDIDATURES + DEMANDES PRÈS DE MOI ── */}
          {isProvider && (
            <section className="mt-4 grid gap-3 lg:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)]" data-dash="provider">
              <div className="rounded-[24px] bg-white p-4 md:p-5" style={{ boxShadow: `inset 0 0 0 1.5px ${tint.line}` }}>
                <h2 className="font-display text-xl font-bold tracking-[-0.02em] text-[#231715]">{dz(lang, "my_apps")}</h2>
                <p className="text-[13px] text-[#6E4F48]">{dz(lang, "my_apps_sub")}</p>
                {!mainLoaded ? (
                  <p className="mt-3 text-sm text-[#6E4F48]" aria-busy="true">{t("common_loading")}</p>
                ) : apps.length === 0 ? (
                  <p className="mt-3 rounded-2xl bg-[#FAF1EC] p-4 text-sm text-[#231715]">{dz(lang, "my_apps_empty")}</p>
                ) : (
                  <ul className="mt-3 divide-y divide-[#F3E6E2]">
                    {apps.slice(0, 6).map((a) => {
                      const pill = appPill(a.status);
                      const owner = (a as ApplicationItem & { owner?: { name?: string } }).owner;
                      const svc = a.serviceType ? d620(lang, `svc_${a.serviceType}`) : "";
                      const when = fmtDay(a.startDate || a.serviceDate);
                      return (
                        <li key={applicationId(a)}>
                          <Link href={a.status === "accepted" ? "/bookings" : "/posts"} className="flex items-center gap-3 py-2.5">
                            <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full text-xs font-bold text-white" style={{ background: ROLE_COLOR.owner }}>{(owner?.name || "?").slice(0, 1).toUpperCase()}</span>
                            <span className="min-w-0 flex-1">
                              <span className="block truncate text-sm font-bold text-[#231715]">{dz(lang, "app_for", { name: (owner?.name || "").split(" ")[0] || "—", svc: svc.startsWith("svc_") ? "" : svc })}</span>
                              <span className="block truncate text-xs text-[#6E4F48]">{[a.petName, when].filter(Boolean).join(" · ")}</span>
                            </span>
                            <span className="shrink-0 whitespace-nowrap rounded-full px-2.5 py-1 text-[11px] font-bold" style={{ background: pill.bg, color: pill.fg }}>{pill.text}</span>
                          </Link>
                        </li>
                      );
                    })}
                  </ul>
                )}
              </div>
              <div className="flex flex-col rounded-[24px] p-4 md:p-5" style={{ background: tint.light }}>
                <h2 className="font-display text-xl font-bold tracking-[-0.02em]" style={{ color: tint.dark }}>{dz(lang, "nearby_title")}</h2>
                <p className="mt-1 text-sm text-[#231715]">{nearbyCount ? dz(lang, "nearby_sub_n", { n: nearbyCount }) : dz(lang, "nearby_sub_0")}</p>
                <div className="mt-auto pt-4">
                  <Link href="/posts" className="inline-flex min-h-[48px] w-full items-center justify-center gap-2 whitespace-nowrap rounded-full px-5 text-[15px] font-extrabold text-white" style={{ background: accent }}>
                    {dz(lang, "nearby_cta")}<AppIcon name="arrow-right" size={16} color="#fff" />
                  </Link>
                </div>
              </div>
            </section>
          )}

          {/* ── À FAIRE AUJOURD'HUI ── (masqué pour un propriétaire sans demande : la grande carte EST l'action) */}
          {!(isOwner && mainLoaded && reqCards.length === 0 && todo.length === 0) && (
          <section className="mt-4 rounded-[24px] bg-[#FAF1EC] p-4 md:p-5" data-dash="todo">
            <div className="flex items-center gap-2">
              <span className="grid h-8 w-8 place-items-center rounded-full text-white" style={{ background: accent }}><AppIcon name="check" size={16} color="#fff" /></span>
              <h2 className="font-display text-lg font-bold tracking-[-0.02em] text-[#231715]">{dz(lang, "todo_title")}</h2>
              <span className="ml-auto hidden text-xs font-semibold text-[#6E4F48] sm:inline">{new Date().toLocaleDateString(lang, { weekday: "long", day: "numeric", month: "long" })}</span>
            </div>
            {todo.length === 0 ? (
              <p className="mt-3 rounded-2xl bg-white p-4 text-sm text-[#231715]">{todoReady ? dz(lang, "todo_none") : t("common_loading")}</p>
            ) : (
              <ul className="mt-3 grid grid-cols-1 gap-2 lg:grid-cols-2">
                {todo.map((it, i) => (
                  <li key={`${it.label}-${i}`} className="min-w-0">
                    <Link href={it.href} className="flex items-center gap-3 rounded-2xl bg-white p-3 transition hover:-translate-y-0.5">
                      <span className="relative grid h-10 w-10 shrink-0 place-items-center rounded-full" style={{ background: it.light }}>
                        <AppIcon name={it.icon} size={20} color={it.color} />
                        {it.count != null && it.count > 0 && (
                          <span className="absolute -right-1 -top-1 flex h-5 min-w-[20px] items-center justify-center rounded-full px-1 text-[11px] font-bold text-white" style={{ background: it.color }}>{it.count > 99 ? "99+" : it.count}</span>
                        )}
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-sm font-bold leading-tight text-[#231715]">{it.label}</span>
                        {it.sub && <span className="block truncate text-xs text-[#6E4F48]">{it.sub}</span>}
                      </span>
                      <span className="shrink-0 whitespace-nowrap rounded-full px-3 py-1.5 text-xs font-bold text-white" style={{ background: it.color }}>{it.cta}</span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </section>
          )}

          {isProvider && <RatesGrid620 role={role as "sitter" | "walker"} lang={lang} />}
          {/* 1011 — « J'ai un véhicule » (badge « Véhiculé » côté propriétaire). */}
          {isProvider && <VehicleToggle1011 role={role as "sitter" | "walker"} lang={lang} className="mt-3" />}

          {/* PawMap : la raison de venir sur grand écran (une seule carte, pas de doublon du menu). */}
          <Link href="/map" className={`group mt-4 flex items-center gap-4 rounded-[24px] bg-[#FAF1EC] p-4 text-[#231715] transition md:p-5 ${tint.hoverBg}`}>
            <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-white"><PawMapLogo size={34} title={null} /></span>
            <span className="min-w-0 flex-1">
              <span className="block text-base font-semibold">{dz(lang, "map_title")}</span>
              <span className="block text-sm text-[#6E4F48]">{dz(lang, "map_sub")}</span>
            </span>
            <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-white transition group-hover:translate-x-1"><AppIcon name="arrow-right" size={18} color={tint.dark} /></span>
          </Link>

          {premiumLeft != null && (
            <Link href="/boutique" className="group mt-3 flex items-center gap-3 rounded-[20px] bg-[#FFF8E6] p-3.5 transition hover:bg-[#FFF1CC]" style={{ boxShadow: "inset 0 0 0 1.5px #F4D98A" }} data-dash="premium">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src="/pawpremium_logo.svg" alt="" width={34} height={34} />
              <span className="min-w-0 flex-1">
                <span className="block text-sm font-bold text-[#6B4A00]">PawPremium</span>
                <span className="block truncate text-xs text-[#8A6100]">{dz(lang, "premium_sub", { left: premiumLeft < 0 ? dz(lang, "unlimited") : dz(lang, "days", { n: premiumLeft }) })}</span>
              </span>
              <span className="whitespace-nowrap text-xs font-bold text-[#8A6100]">{dz(lang, "premium_cta")} ›</span>
            </Link>
          )}

          {myRank && (
            <Link href="/pawpoints" className="mt-6 block transition hover:-translate-y-px" data-dash-rank="">
              <RankProgress611 rank={myRank} showHow={false} />
              {myPins && <PinChips1910 pins={myPins} className="mt-2" />}
            </Link>
          )}

          {/* Code promo et « Une idée ? » : repliés, en bas. */}
          <div className="mt-6 grid gap-3 lg:grid-cols-2">
            <details id="promo" className="scroll-mt-24 rounded-[20px] bg-[#FAF1EC] p-4 [&_summary::-webkit-details-marker]:hidden">
              <summary className="flex cursor-pointer list-none items-center gap-2 text-sm font-semibold text-[#231715]">
                <AppIcon name="ticket" size={16} color={accent} />{dz(lang, "promo_q")}<span className="ml-auto text-[#9E6B5F]">›</span>
              </summary>
              <div className="mt-3 flex flex-col gap-2 sm:flex-row">
                <input type="text" value={promoCode} onChange={(e) => setPromoCode(e.target.value)} onKeyDown={(e) => { if (e.key === "Enter") handleApplyPromo(); }} placeholder={dz(lang, "promo_ph")} aria-label={dz(lang, "promo_ph")} className="min-w-0 flex-1 rounded-full border border-[#EADFDC] bg-white px-4 py-2.5 text-sm tracking-wide text-[#231715] outline-none placeholder:text-[#9E6B5F] focus:border-[#C92A12]" />
                <div className="shrink-0 sm:w-40">
                  <SignatureButton label={t("promo_apply")} icon="ticket" tone={role} onClick={handleApplyPromo} disabled={!promoCode.trim()} loading={promoBusy} />
                </div>
              </div>
              {promoMsg && <p className={`mt-3 text-sm ${promoMsg.ok ? "text-[#0F7C37]" : "text-[#B42318]"}`}>{promoMsg.text}</p>}
            </details>
            <details className="rounded-[20px] bg-[#FAF1EC] p-4 [&_summary::-webkit-details-marker]:hidden">
              <summary className="flex cursor-pointer list-none items-center gap-2 text-sm font-semibold text-[#231715]">
                <AppIcon name="megaphone" size={16} color={accent} />{dz(lang, "feedback_q")}<span className="ml-auto text-[#9E6B5F]">›</span>
              </summary>
              <div className="-mx-1 [&>section]:mt-2 [&>section]:bg-white">
                <FeedbackBox tone={role} />
              </div>
            </details>
          </div>
        </main>
      </div>
    </div>
  );
}

function SideLink({ href, icon, label, badge, tint, small }: { href: string; icon: AppIconName; label: string; badge?: number; tint: Tint; small?: boolean }) {
  const pathname = usePathname();
  const current = pathname === href || (href !== "/dashboard" && !href.startsWith("#") && pathname?.startsWith(href + "/"));
  return (
    <Link
      href={href}
      aria-current={current ? "page" : undefined}
      className={`group flex ${small ? "min-h-[36px]" : "min-h-[40px]"} items-center gap-3 rounded-xl px-3 py-1 text-sm font-medium transition ${current ? `${tint.currentBg} ${tint.currentText}` : `text-[#231715] ${tint.hoverBg} ${tint.hoverText}`}`}
    >
      <span className="relative grid h-7 w-7 shrink-0 place-items-center">
        <AppIcon name={icon} size={small ? 17 : 19} color={current ? tint.dark : "currentColor"} />
        {badge && badge > 0 ? (
          <span className="absolute -right-2 -top-1 flex h-4 min-w-[16px] items-center justify-center rounded-full bg-[#C92A12] px-1 text-[10px] font-bold text-white">{badge > 99 ? "99+" : badge}</span>
        ) : null}
      </span>
      <span className="min-w-0 flex-1 truncate whitespace-nowrap">{label}</span>
    </Link>
  );
}
