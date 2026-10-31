"use client";

// 31/10/2026 — LEO (ordre de Daniel « grosse refonte, paiement plus simple », relayé par BOB).
// Mesure de BOB : 37 propriétaires sur 39 n'ont pas l'app ; ceux qui reviennent arrivent par le
// lien de l'e-mail ou du SMS, regardent, et repartent sans jamais atteindre /pay.
// → UNE SEULE PAGE (/application/<id>), mobile d'abord :
//   · la demande du propriétaire et ses candidats triés « le plus proche de chez toi » puis prix ;
//   · photo + prénom + « Identité vérifiée » + distance + note + PRIX TOTAL ;
//   · UN bouton « Choisir <prénom> et payer · prix » → le serveur accepte (POST /applications/:id/
//     respond) et renvoie l'intention Airwallex → l'encart carte Airwallex (Drop-in) se monte ICI,
//     sans tableau de bord ni autre page ; si l'encart ne vient pas (réseau, SDK), bouton de
//     repli vers /pay (même paiement, page sécurisée) ;
//   · « dates à prévoir » : l'éditeur de dates est sur la même page, pré-rempli ;
//   · garanties vraies au moment de payer (72 h, séquestre, messagerie).
// Repères : cand_vus, cand_encart, cand_choix_ok, cand_payer, cand_paye_ok (+ cand_payer_echec).
// Zéro gris : encres brunes de la charte (#231715, #6E4F48), orange #C92A12.
// Tous les hooks sont en tête, AVANT tout retour conditionnel (piège du 20/09).

import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "@/components/SiteLink";
import { useT } from "@/lib/i18n/LanguageProvider";
import { AppIcon } from "@/components/AppIcon";
import { SignatureButton } from "@/components/SignatureButton";
import { PostDatesEditor620 } from "@/components/PostDatesEditor620";
import { d620, unitShort620 } from "@/lib/i18n/dates620";
import { dateModeOf620 } from "@/lib/services620";
import { c3110 } from "@/lib/i18n/cand3110";
import { markCandidatesViewed } from "@/lib/candidatesView2610";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { countryForCurrency3110, kmOf3110, pickPostId3110, point3110, sortCandidates3110, totalOf3110 } from "@/lib/cand3110";
import {
  ApiError,
  type ApplicationItem,
  type Booking,
  type RequestPost,
  apiErrorCode,
  applicationId,
  applicationProvider,
  confirmBookingPayment,
  createBookingPaymentIntent,
  getMyApplications,
  getMyPosts,
  getStoredUser,
  postId as postIdOf,
  respondToApplication,
  startProviderConversation,
} from "@/lib/api";

const ROLE = {
  sitter: { dark: "#1E4FB0", pale: "#DDEAFB" },
  walker: { dark: "#15803D", pale: "#DCEFE3" },
} as const;

type PayStep = "idle" | "accepting" | "intent" | "card" | "paid" | "error";
type PayInfo = { intentId: string; secret: string; currency: string; amount: number; bookingId: string; name: string; appId: string };

// Le SDK Airwallex (elements.bundle) expose aussi createElement('dropIn') : encart carte dans la page.
type AwxElement = { mount: (id: string) => void; unmount?: () => void; destroy?: () => void; on?: (ev: string, cb: (e: unknown) => void) => void };
type AwxSdk = {
  init: (cfg: { env: "prod" | "demo" | "staging"; origin: string; locale?: string }) => void;
  createElement?: (type: "dropIn", opts: Record<string, unknown>) => AwxElement | null;
  destroyElement?: (type: "dropIn") => void;
};

function money(v: number, currency: string, lang: string): string {
  try {
    return new Intl.NumberFormat(lang, { style: "currency", currency, maximumFractionDigits: 2 }).format(v);
  } catch {
    return `${v.toFixed(2)} ${currency}`;
  }
}
function moneyCompact(v: number, currency: string, lang: string): string {
  try {
    return new Intl.NumberFormat(lang, { style: "currency", currency, maximumFractionDigits: Number.isInteger(v) ? 0 : 2 }).format(v);
  } catch {
    return `${v.toFixed(2)} ${currency}`;
  }
}

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

function ensureAirwallexScript(): Promise<void> {
  if (typeof window === "undefined") return Promise.resolve();
  const w = window as unknown as { Airwallex?: AwxSdk };
  if (w.Airwallex) return Promise.resolve();
  return new Promise<void>((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>('script[data-awx="elements"]');
    if (existing) {
      existing.addEventListener("load", () => resolve(), { once: true });
      existing.addEventListener("error", () => reject(new Error("sdk")), { once: true });
      return;
    }
    const s = document.createElement("script");
    s.src = "https://checkout.airwallex.com/assets/elements.bundle.min.js";
    s.async = true;
    s.dataset.awx = "elements";
    s.onload = () => resolve();
    s.onerror = () => reject(new Error("sdk"));
    document.head.appendChild(s);
  });
}

export function OwnerCandidatesPay3110({ focusId }: { focusId?: string }) {
  const { t, lang } = useT();
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [post, setPost] = useState<RequestPost | null>(null);
  const [items, setItems] = useState<ApplicationItem[]>([]);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [writingId, setWritingId] = useState<string | null>(null);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [brokenAvatars, setBrokenAvatars] = useState<Record<string, boolean>>({});
  const [editingDates, setEditingDates] = useState(false);
  const [pickId, setPickId] = useState<string | null>(null);
  const [step, setStep] = useState<PayStep>("idle");
  const [pay, setPay] = useState<PayInfo | null>(null);
  const [payError, setPayError] = useState("");
  const [fallbackReady, setFallbackReady] = useState(false);
  // 31/10 (ZOE) — l'encart carte est réellement affiché (iframe mesurée) : le petit « Préparation… » disparaît.
  const [cardReady, setCardReady] = useState(false);
  const panelRef = useRef<HTMLDivElement | null>(null);
  const datesRef = useRef<HTMLDivElement | null>(null);
  const seenRef = useRef("");
  const elementRef = useRef<AwxElement | null>(null);
  const confirmedRef = useRef(false);

  const viewPostId = post ? String(postIdOf(post) || "") : "";

  const load = useCallback(async () => {
    const u = getStoredUser();
    if (!u) {
      const here = typeof window !== "undefined" ? window.location.pathname + window.location.search : "/posts";
      router.replace(`/login?redirect=${encodeURIComponent(here)}`);
      return;
    }
    if (u.role !== "owner") { router.replace("/posts"); return; }
    setLoading(true);
    setLoadError("");
    try {
      const [apps, posts] = await Promise.all([getMyApplications(), getMyPosts().catch(() => [] as RequestPost[])]);
      const pid = pickPostId3110(apps, focusId) || (posts[0] ? String(postIdOf(posts[0]) || "") : "");
      const p = posts.find((x) => String(postIdOf(x) || "") === pid) || posts[0] || null;
      setPost(p);
      setItems(apps.filter((a) => String(a.postId || "") === pid));
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        const here = typeof window !== "undefined" ? window.location.pathname + window.location.search : "/posts";
        router.replace(`/login?redirect=${encodeURIComponent(here)}`);
        return;
      }
      setLoadError(e instanceof Error && e.message ? e.message : c3110(lang, "error"));
    } finally {
      setLoading(false);
    }
  }, [focusId, lang, router]);

  useEffect(() => { void load(); }, [load]);

  // Mesure : ouverture (provenance ?from=email|sms lue dans l'adresse) + repère cand_vus une fois.
  useEffect(() => {
    if (!viewPostId) return;
    markCandidatesViewed({ postId: viewPostId });
    if (seenRef.current === viewPostId) return;
    seenRef.current = viewPostId;
    trackSiteEvent("cta_click", { label: "cand_vus" });
  }, [viewPostId]);

  // Encart carte : dès qu'une intention est là, on monte le Drop-in Airwallex dans la page ;
  // après 7 s sans encart, on propose la page de paiement sécurisée (même intention).
  useEffect(() => {
    if (step !== "card" || !pay) return;
    let cancelled = false;
    confirmedRef.current = false;
    // 31/10 (réserve de ZOE, feu vert BOB) — `el.on("ready")` n'arrive pas avec elements.bundle : le repli
    // s'affichait SOUS un formulaire de carte déjà prêt. L'encart est « prêt » dès que l'iframe du Drop-in a
    // une hauteur > 0 (mesurée toutes les 300 ms) ou que `onReady` arrive ; le repli n'apparaît QUE si
    // l'encart n'est vraiment pas là après 7 s (ou en cas d'erreur sans encart).
    let ready = false;
    const markReady = () => { ready = true; if (!cancelled) { setFallbackReady(false); setCardReady(true); } };
    const probe = window.setInterval(() => {
      const f = document.querySelector<HTMLIFrameElement>("#awx-dropin-3110 iframe");
      if (f && f.getBoundingClientRect().height > 40) { markReady(); window.clearInterval(probe); }
    }, 300);
    const timer = window.setTimeout(() => { if (!cancelled && !ready) setFallbackReady(true); }, 7000);
    const winReady = () => markReady();
    window.addEventListener("onReady", winReady);
    const onSuccess = async () => {
      if (confirmedRef.current) return;
      confirmedRef.current = true;
      try { await confirmBookingPayment(pay.bookingId, pay.intentId); } catch { /* le webhook serveur confirme aussi */ }
      if (cancelled) return;
      trackSiteEvent("cta_click", { label: "cand_paye_ok" });
      setStep("paid");
      setItems((prev) => prev.map((x) => (applicationId(x) === pay.appId ? { ...x, status: "accepted", booking: { ...(x.booking || { id: pay.bookingId }), id: pay.bookingId, paymentStatus: "paid" } as Booking } : x)));
    };
    const onError = (e: unknown) => {
      const msg = (e && typeof e === "object" && "detail" in e && (e as { detail?: { message?: string } }).detail?.message) || "";
      setPayError(msg ? `${c3110(lang, "pay_error")} (${msg})` : c3110(lang, "pay_error"));
      if (!ready) setFallbackReady(true);
      trackSiteEvent("cta_click", { label: "cand_payer_echec" });
    };
    const winSuccess = () => { void onSuccess(); };
    const winError = (e: Event) => onError(e);
    window.addEventListener("onSuccess", winSuccess);
    window.addEventListener("onError", winError);
    (async () => {
      try {
        await ensureAirwallexScript();
        if (cancelled) return;
        const sdk = (window as unknown as { Airwallex?: AwxSdk }).Airwallex;
        if (!sdk || typeof sdk.createElement !== "function") throw new Error("dropin");
        sdk.init({ env: "prod", origin: window.location.origin, locale: lang });
        try { sdk.destroyElement?.("dropIn"); } catch { /* rien à détruire */ }
        const el = sdk.createElement("dropIn", {
          intent_id: pay.intentId,
          client_secret: pay.secret,
          currency: pay.currency,
          country_code: countryForCurrency3110(pay.currency),
          autoCapture: true,
        });
        if (!el) throw new Error("dropin");
        elementRef.current = el;
        el.on?.("success", () => { void onSuccess(); });
        el.on?.("error", (e) => onError(e));
        el.on?.("ready", () => markReady());
        el.mount("awx-dropin-3110");
      } catch {
        if (!cancelled) setFallbackReady(true);
      }
    })();
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
      window.clearInterval(probe);
      window.removeEventListener("onReady", winReady);
      window.removeEventListener("onSuccess", winSuccess);
      window.removeEventListener("onError", winError);
      try { elementRef.current?.destroy?.(); } catch { /* déjà détruit */ }
      try { elementRef.current?.unmount?.(); } catch { /* déjà démonté */ }
      elementRef.current = null;
    };
  }, [step, pay, lang]);

  useEffect(() => {
    if ((step === "accepting" || step === "intent" || step === "card" || step === "paid") && panelRef.current) {
      panelRef.current.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }, [step]);

  // ── à partir d'ici, plus aucun hook ──────────────────────────────────────────────────────────
  const tbd = post ? dateModeOf620(post) === "tbd" : false;
  const postPoint = post ? point3110(post.location) : null;
  // « dates à prévoir » sans aucune date : l'éditeur est PRÉ-REMPLI (demain → +2 jours pour une garde,
  // demain seul pour une balade / une visite) ; le propriétaire vérifie, change s'il veut, enregistre.
  const editorPost: RequestPost | null = post && tbd && !post.startDate ? (() => {
    const d0 = new Date(); d0.setDate(d0.getDate() + 1);
    const multi = (post.serviceTypes || []).some((s) => s === "house_sitting" || s === "day_care");
    const d1 = new Date(d0); if (multi) d1.setDate(d1.getDate() + 2);
    return { ...post, startDate: d0.toISOString().slice(0, 10), endDate: d1.toISOString().slice(0, 10) };
  })() : post;
  const visible = sortCandidates3110(items.filter((a) => a.status === "pending" || a.status === "accepted"), postPoint, focusId);
  const pendingCount = visible.filter((a) => a.status === "pending").length;
  const startMs = post?.startDate ? new Date(post.startDate).getTime() : NaN;
  const freeCancel = !tbd && Number.isFinite(startMs) && startMs - Date.now() > 72 * 3600 * 1000;
  const unitOf = (a: ApplicationItem): string => {
    const u = String(a.pricing?.unit || "");
    if (u) return u;
    const svc = String(a.serviceType || post?.serviceTypes?.[0] || "");
    return svc === "home_visit" ? "visit" : svc === "dog_walking" ? "walk" : "day";
  };
  const svcLabel = (post?.serviceTypes || []).map((s) => d620(lang, `svc_${s}`)).filter((x) => !x.startsWith("svc_")).join(" · ");
  const dtLocale = lang === "en" ? "en-US" : lang;
  const dateLabel = tbd
    ? d620(lang, "card_tbd")
    : [post?.startDate, post?.endDate].filter(Boolean).map((d) => new Date(d as string).toLocaleDateString(dtLocale, { day: "numeric", month: "short" })).join(" → ");

  function nameOf(a: ApplicationItem): string {
    const { who } = applicationProvider(a);
    const n = who?.name || t("c1610_provider");
    return n.split(" ")[0] || n;
  }

  function guarantees(name: string) {
    return (
      <ul className="mt-2 space-y-1" data-guarantees-3110="">
        {freeCancel && (
          <li className="flex items-start gap-1.5 text-[12px] font-bold leading-snug" style={{ color: "#15803D" }}>
            <AppIcon name="shield-check" size={14} color="#15803D" /><span>{c3110(lang, "g_cancel")}</span>
          </li>
        )}
        <li className="flex items-start gap-1.5 text-[12px] font-bold leading-snug" style={{ color: "#15803D" }}>
          <AppIcon name="lock" size={14} color="#15803D" /><span>{c3110(lang, "g_escrow", { name })}</span>
        </li>
        <li className="flex items-start gap-1.5 text-[12px] font-bold leading-snug" style={{ color: "#15803D" }}>
          <AppIcon name="chat" size={14} color="#15803D" /><span>{c3110(lang, "g_chat", { name })}</span>
        </li>
      </ul>
    );
  }

  async function onDatesSaved(updated: RequestPost) {
    setPost(updated);
    setEditingDates(false);
    try {
      const all = await getMyApplications();
      const pid = String(postIdOf(updated) || viewPostId);
      const mine = all.filter((x) => String(x.postId || "") === pid);
      if (mine.length) setItems(mine);
    } catch { /* la page se rechargera avec les totaux */ }
  }

  /** Choisir et payer : accepte (le serveur refuse les autres), prend l'intention, monte l'encart carte. */
  async function chooseAndPay(a: ApplicationItem) {
    const id = applicationId(a);
    const name = nameOf(a);
    if (tbd) {
      trackSiteEvent("cta_click", { label: "cand_dates" });
      setPickId(id);
      setEditingDates(true);
      datesRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
      return;
    }
    const total = totalOf3110(a);
    const currency = (a.pricing?.currency || post?.budgetCurrency || post?.currency || "EUR").toUpperCase();
    trackSiteEvent("cta_click", { label: "cand_encart" });
    trackSiteEvent("cta_click", { label: "cand_choisir_payer" });
    setBusyId(id);
    setErrors((e) => ({ ...e, [id]: "" }));
    setPayError("");
    setFallbackReady(false);
    setCardReady(false);
    setPay({ intentId: "", secret: "", currency, amount: total ?? 0, bookingId: "", name, appId: id });
    setStep("accepting");
    try {
      let bookingId = "";
      let intentId = "";
      let secret = "";
      const already = a.status === "accepted" ? linkedBooking(a) : null;
      if (already) {
        bookingId = already.id;
      } else {
        const res = await respondToApplication(id, "accept");
        trackSiteEvent("cta_click", { label: "cand_choix_ok" });
        const next = items.map((x) => {
          const xid = applicationId(x);
          if (xid === id) return { ...x, ...res.application, booking: res.booking || x.booking || null };
          if (x.status === "pending") return { ...x, status: "rejected" };
          return x;
        });
        setItems(next);
        const chosen = next.find((x) => applicationId(x) === id);
        bookingId = (chosen && linkedBooking(chosen)?.id) || String(res.booking?.id || "");
        if (res.payment?.clientSecret && res.payment?.paymentIntentId) {
          intentId = res.payment.paymentIntentId;
          secret = res.payment.clientSecret;
        }
      }
      if (!bookingId) throw new Error(c3110(lang, "error"));
      setStep("intent");
      trackSiteEvent("cta_click", { label: "cand_payer" });
      if (!intentId || !secret) {
        const intent = await createBookingPaymentIntent(bookingId);
        if (!intent.clientSecret || !intent.paymentIntentId) throw new Error(intent.savedCardError || t("c1610_pay_fail"));
        intentId = intent.paymentIntentId;
        secret = intent.clientSecret;
      }
      setPay({ intentId, secret, currency, amount: total ?? 0, bookingId, name, appId: id });
      setStep("card");
    } catch (e) {
      const code = apiErrorCode(e);
      const d = e instanceof ApiError && e.details && typeof e.details === "object" ? (e.details as Record<string, unknown>) : {};
      let msg = e instanceof Error && e.message ? e.message : c3110(lang, "error");
      if (code === "CURRENCY_MISMATCH") msg = t("c1610_currency").replace("{a}", String(d.providerCurrency || "?")).replace("{b}", String(d.ownerCurrency || currency));
      else if (code === "DATES_REQUIRED") { msg = d620(lang, "cand_choose_blocked"); setEditingDates(true); }
      else if (code === "TOO_FAR") msg = t("c1610_too_far").replace("{km}", String(d.limitKm || 200));
      else if (e instanceof ApiError && e.status === 409) msg = t("c1610_already");
      else if (e instanceof ApiError && e.status === 401) { router.replace(`/login?redirect=${encodeURIComponent(window.location.pathname + window.location.search)}`); return; }
      trackSiteEvent("cta_click", { label: `cand_erreur_${String(code || (e instanceof ApiError ? e.status : "x")).toLowerCase()}` });
      setErrors((er) => ({ ...er, [id]: msg }));
      setPayError(msg);
      setStep("error");
    } finally {
      setBusyId(null);
    }
  }

  /** Repli : même intention, page de paiement sécurisée (/pay → Airwallex plein écran). */
  function openSecurePage() {
    if (!pay?.intentId || !pay.secret) return;
    trackSiteEvent("cta_click", { label: "cand_page_carte" });
    const qs = new URLSearchParams({ intent: pay.intentId, secret: pay.secret, currency: pay.currency, purpose: "booking", booking: pay.bookingId, ...(pay.amount > 0 ? { amount: String(pay.amount) } : {}) });
    router.push(`/pay?${qs.toString()}`);
  }

  async function write(a: ApplicationItem) {
    const id = applicationId(a);
    const { role, who } = applicationProvider(a);
    const providerId = String(who?.id || who?._id || "");
    if (!providerId) return;
    trackSiteEvent("cta_click", { label: "cand_ecrire" });
    setWritingId(id);
    try {
      const conv = await startProviderConversation(role, providerId);
      router.push(conv ? `/chat?c=${encodeURIComponent(conv)}` : "/chat");
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) { router.replace(`/login?redirect=${encodeURIComponent(window.location.pathname + window.location.search)}`); return; }
      setErrors((er) => ({ ...er, [id]: c3110(lang, "error") }));
      setWritingId(null);
    }
  }

  if (loading) {
    return (
      <div className="mx-auto max-w-md px-4 py-24 text-center" data-cand3110-loading="">
        <p className="text-base font-bold" style={{ color: "#231715" }}>{c3110(lang, "loading")}</p>
        <div className="mx-auto mt-5 h-2 w-40 overflow-hidden rounded-full" style={{ background: "#FBE9E5" }}>
          <div className="h-full w-1/3 animate-pulse" style={{ background: "#C92A12" }} />
        </div>
      </div>
    );
  }

  const paying = step !== "idle" && pay;

  return (
    <div className="mx-auto w-full max-w-2xl px-4 pb-28 pt-5 md:pt-8" data-cand3110="" style={{ colorScheme: "light" }}>
      <Link href="/posts" className="inline-flex items-center gap-1 text-[13px] font-bold underline-offset-2 hover:underline" style={{ color: "#9E1F0B" }}>
        ‹ {c3110(lang, "back")}
      </Link>
      <h1 className="mt-2 font-display text-[26px] font-extrabold leading-tight tracking-tight md:text-[32px]" style={{ color: "#231715" }}>
        {c3110(lang, "title")}
      </h1>
      {post && (
        <p className="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 text-[14px] font-bold" style={{ color: "#9E1F0B" }} data-cand3110-post="">
          {svcLabel && <span>{svcLabel}</span>}
          {dateLabel && <span className="rounded-full bg-white px-2 py-0.5 text-[12px]" style={{ boxShadow: "inset 0 0 0 1px #F6D9CF" }}>{dateLabel}</span>}
          {post.location?.city && <span className="text-[12px] font-semibold" style={{ color: "#6E4F48" }}>{post.location.city}</span>}
        </p>
      )}
      <p className="mt-2 text-[13px] leading-snug" style={{ color: "#6E4F48" }}>{c3110(lang, "sub")}</p>
      {loadError && (
        <p className="mt-3 rounded-xl px-3 py-2 text-[13px] font-bold" style={{ background: "#FBE9E5", color: "#9E1F0B" }} role="alert">{loadError}</p>
      )}

      {/* Paiement sur la même page : résumé, garanties, encart carte Airwallex, repli sécurisé. */}
      {paying && (
        <div ref={panelRef} className="mt-4 scroll-mt-20 rounded-2xl bg-white p-4" style={{ boxShadow: "0 0 0 2px #C92A12, 0 14px 30px -18px rgba(35,23,21,.5)" }} data-cand3110-panel={step}>
          {step === "paid" ? (
            <>
              <p className="flex items-center gap-2 text-[20px] font-extrabold" style={{ color: "#15803D" }}>
                <AppIcon name="check" size={22} color="#15803D" />{c3110(lang, "paid_title")}
              </p>
              <p className="mt-1 text-[14px] leading-snug" style={{ color: "#231715" }}>{c3110(lang, "paid_sub", { name: pay.name })}</p>
              <div className="mt-3">
                <SignatureButton tone="sitter" icon="chat" label={c3110(lang, "paid_chat", { name: pay.name })} onClick={() => { const a = items.find((x) => applicationId(x) === pay.appId); if (a) void write(a); }} />
              </div>
              <p className="mt-2 text-center text-[12px] font-semibold" style={{ color: "#6E4F48" }}>
                <Link href="/bookings" className="underline underline-offset-2">{t("bookings_title")}</Link>
              </p>
            </>
          ) : (
            <>
              <div className="flex items-baseline justify-between gap-3">
                <p className="text-[18px] font-extrabold leading-tight" style={{ color: "#231715" }}>{c3110(lang, "panel_title", { name: pay.name })}</p>
                {pay.amount > 0 && <p className="text-[22px] font-extrabold leading-none" style={{ color: "#9E1F0B" }} data-cand3110-amount="">{money(pay.amount, pay.currency, lang)}</p>}
              </div>
              <p className="mt-1 text-[13px] leading-snug" style={{ color: "#6E4F48" }}>{c3110(lang, "panel_sub", { name: pay.name })}</p>
              {guarantees(pay.name)}
              <div className="mt-3 min-h-[56px]">
                {(step === "accepting" || step === "intent") && (
                  <div className="flex items-center gap-2 text-[13px] font-bold" style={{ color: "#9E1F0B" }}>
                    <span className="inline-block h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent" />{c3110(lang, "preparing")}
                  </div>
                )}
                {step === "card" && (
                  <>
                    {!fallbackReady && !cardReady && (
                      <div className="mb-2 flex items-center gap-2 text-[12px] font-bold" style={{ color: "#8A6B64" }} data-cand3110-card-loading="">
                        <span className="inline-block h-3.5 w-3.5 animate-spin rounded-full border-2 border-current border-t-transparent" />{c3110(lang, "preparing")}
                      </div>
                    )}
                    <div id="awx-dropin-3110" className="rounded-xl" data-cand3110-dropin="" />
                  </>
                )}
                {payError && (
                  <p className="mt-2 rounded-xl px-3 py-2 text-[12px] font-bold" style={{ background: "#FBE9E5", color: "#9E1F0B" }} role="alert">{payError}</p>
                )}
                {step === "card" && fallbackReady && (
                  <div className="mt-3" data-cand3110-fallback="">
                    <p className="mb-2 text-[12px] leading-snug" style={{ color: "#6E4F48" }}>{c3110(lang, "fallback_hint")}</p>
                    <SignatureButton tone="owner" icon="wallet" label={c3110(lang, "fallback")} price={pay.amount > 0 ? money(pay.amount, pay.currency, lang) : undefined} earns onClick={openSecurePage} />
                  </div>
                )}
                {step === "error" && (
                  <div className="mt-2">
                    <SignatureButton tone="owner" kind="secondary" icon="check" label={c3110(lang, "pay")} onClick={() => { const a = items.find((x) => applicationId(x) === pay.appId); setStep("idle"); if (a && a.status !== "rejected") void chooseAndPay(a); }} />
                  </div>
                )}
              </div>
              <p className="mt-2 flex items-center justify-center gap-1 text-[11px] font-semibold" style={{ color: "#8A6B64" }}>
                <AppIcon name="lock" size={12} color="#8A6B64" />{c3110(lang, "secure")}
              </p>
            </>
          )}
        </div>
      )}

      {/* « dates à prévoir » : l'éditeur, pré-rempli par le composant, sur la même page. */}
      {post && tbd && step !== "paid" && (
        <div ref={datesRef} className="mt-4 scroll-mt-20 rounded-2xl p-3" style={{ background: "#FBE9E5", boxShadow: "inset 0 0 0 1.5px #C92A12" }} data-cand3110-dates="">
          <p className="flex items-start gap-1.5 text-[15px] font-extrabold leading-snug" style={{ color: "#9E1F0B" }}>
            <AppIcon name="calendar" size={17} color="#9E1F0B" /><span>{c3110(lang, "dates_title")}</span>
          </p>
          <p className="mt-1 text-[12px] leading-snug" style={{ color: "#6E4F48" }}>{c3110(lang, "dates_sub")}</p>
          {!editingDates ? (
            <div className="mt-2"><SignatureButton tone="owner" icon="calendar" label={c3110(lang, "dates_cta")} onClick={() => setEditingDates(true)} /></div>
          ) : (
            <PostDatesEditor620 post={editorPost || post} lang={lang} onSaved={(u) => void onDatesSaved(u)} onCancel={() => setEditingDates(false)} startLabel={t("posts_start_label")} endLabel={t("posts_end_label")} />
          )}
        </div>
      )}

      {visible.length === 0 && !loadError ? (
        <div className="mt-6 rounded-2xl bg-white p-5 text-center" style={{ boxShadow: "0 6px 16px -10px rgba(35,23,21,.35)" }} data-cand3110-empty="">
          <AppIcon name="people" size={28} color="#C92A12" />
          <p className="mt-2 text-[17px] font-extrabold" style={{ color: "#231715" }}>{c3110(lang, "none_title")}</p>
          <p className="mt-1 text-[13px] leading-snug" style={{ color: "#6E4F48" }}>{c3110(lang, "none_sub")}</p>
        </div>
      ) : (
        <>
          <p className="mt-5 flex items-center gap-1.5 text-[13px] font-extrabold" style={{ color: "#9E1F0B" }}>
            <AppIcon name="people" size={15} color="#C92A12" />
            {visible.length === 1 ? c3110(lang, "count_one") : c3110(lang, "count_many", { n: visible.length })}
            {pendingCount > 0 && pendingCount !== visible.length && <span className="font-semibold" style={{ color: "#6E4F48" }}>· {pendingCount}</span>}
          </p>
          <ul className="mt-2 grid grid-cols-1 gap-3 sm:grid-cols-2" data-cand3110-list={visible.length}>
            {visible.map((a) => {
              const id = applicationId(a);
              const { role, who } = applicationProvider(a);
              const firstName = nameOf(a);
              const tone = ROLE[role];
              const reviews = who?.reviewCount ?? who?.reviewsCount ?? who?.totalReviews ?? 0;
              const rating = typeof who?.rating === "number" && who.rating > 0 ? who.rating : 0;
              const km = kmOf3110(a, postPoint);
              const total = totalOf3110(a);
              const currency = (a.pricing?.currency || post?.budgetCurrency || post?.currency || "EUR").toUpperCase();
              const stale = a.pricing?.stale === true;
              const indicative = a.pricing?.indicative === true || (tbd && total == null);
              const ownerUnit = a.pricing?.ownerUnitRate != null && a.pricing.ownerUnitRate > 0 ? a.pricing.ownerUnitRate : null;
              const unitRate = stale ? null : (ownerUnit ?? a.pricing?.appliedRate ?? a.pricing?.basePrice ?? null);
              const rateLabel = indicative && unitRate != null && unitRate > 0 ? `${moneyCompact(unitRate, currency, lang)}/${unitShort620(lang, unitOf(a))}` : "";
              const priceLabel = total != null ? money(total, currency, lang) : "";
              const accepted = a.status === "accepted";
              const bk = accepted ? linkedBooking(a) : null;
              const isFocus = !!focusId && focusId === id;
              const isPick = pickId === id;
              const pid = String(who?.id || who?._id || "");
              const err = errors[id];
              const chosenHere = pay?.appId === id && step === "paid";
              const avatar = who?.avatar && !brokenAvatars[id] ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={who.avatar} alt="" className="h-14 w-14 shrink-0 rounded-full object-cover" style={{ boxShadow: `0 0 0 2.5px ${tone.dark}` }} onError={() => setBrokenAvatars((m) => ({ ...m, [id]: true }))} />
              ) : (
                <span className="grid h-14 w-14 shrink-0 place-items-center rounded-full text-lg font-bold text-white" style={{ background: tone.dark }}>{firstName.slice(0, 1).toUpperCase()}</span>
              );
              const canPay = !stale && (tbd || total != null) && !(bk?.paid) && !chosenHere;
              return (
                <li key={id} id={`application-${id}`} className="flex min-w-0 flex-col rounded-2xl bg-white p-3" data-candidate-3110={role} data-candidate-km={km ?? ""} data-candidate-total={total ?? ""}
                    style={{ boxShadow: isFocus || isPick ? "0 0 0 2px #C92A12, 0 6px 16px -10px rgba(35,23,21,.35)" : "0 6px 16px -10px rgba(35,23,21,.35)" }}>
                  <div className="flex items-start gap-3">
                    {pid ? <a href={`/p/${role}/${pid}`} target="_blank" rel="noopener" aria-label={firstName} className="shrink-0 rounded-full" onClick={() => trackSiteEvent("cta_click", { label: "cand_profil" })}>{avatar}</a> : avatar}
                    <div className="min-w-0 flex-1">
                      <div className="flex items-baseline justify-between gap-2">
                        <p className="truncate text-[17px] font-extrabold" style={{ color: "#231715" }}>{firstName}</p>
                        {priceLabel ? (
                          <span className="shrink-0 text-right">
                            <span className="block text-[18px] font-extrabold leading-tight" style={{ color: "#9E1F0B" }} data-total-3110="">{priceLabel}</span>
                            <span className="block text-[10px] font-bold uppercase tracking-wide" style={{ color: "#8A6B64" }}>{c3110(lang, "total")}</span>
                          </span>
                        ) : rateLabel ? (
                          <span className="shrink-0 text-right">
                            <span className="block text-[16px] font-extrabold leading-tight" style={{ color: "#9E1F0B" }} data-rate-3110="">{rateLabel}</span>
                            <span className="block text-[10px] font-bold uppercase tracking-wide" style={{ color: "#8A6B64" }}>{c3110(lang, "rate")}</span>
                          </span>
                        ) : (
                          <span className="shrink-0 text-[12px] font-extrabold" style={{ color: "#9E1F0B" }}>{c3110(lang, "stale")}</span>
                        )}
                      </div>
                      <div className="mt-0.5 flex flex-wrap items-center gap-1">
                        <span className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-bold" style={{ background: tone.pale, color: tone.dark }}>
                          <AppIcon name={role === "walker" ? "walker" : "home"} size={11} color={tone.dark} />{t(role === "walker" ? "role_walker" : "role_sitter")}
                        </span>
                        {who?.identityVerified && (
                          <span className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-bold" style={{ background: "#DCEFE3", color: "#15803D" }}>
                            <AppIcon name="shield-check" size={11} color="#15803D" />{t("trust_id_title")}
                          </span>
                        )}
                        {isFocus && a.status === "pending" && <span className="rounded-full px-2 py-0.5 text-[11px] font-bold text-white" style={{ background: "#C92A12" }}>{t("c1610_new")}</span>}
                      </div>
                      <p className="mt-1 text-[12px] font-semibold leading-snug" style={{ color: "#6E4F48" }}>
                        {[rating > 0 ? `★ ${rating.toFixed(1)}${reviews > 0 ? ` (${reviews})` : ""}` : c3110(lang, "new_here"), km != null ? c3110(lang, "km", { km }) : (who?.city || who?.location?.city || "")].filter(Boolean).join(" · ")}
                      </p>
                    </div>
                  </div>
                  {a.description && a.description.trim() && (
                    <p className="mt-2 line-clamp-3 whitespace-pre-wrap text-[13px] leading-snug" style={{ color: "#231715" }}>« {a.description.trim()} »</p>
                  )}
                  <div className="mt-auto pt-3">
                    {bk?.paid || chosenHere ? (
                      <p className="flex items-center gap-1.5 rounded-xl px-3 py-2 text-[13px] font-bold" style={{ background: "#DCEFE3", color: "#15803D" }}>
                        <AppIcon name="check" size={15} color="#15803D" />{t("bookings_payment_received")}
                      </p>
                    ) : (
                      <>
                        {accepted && <p className="mb-1.5 text-[12px] font-bold" style={{ color: "#9E1F0B" }}>{c3110(lang, "chosen")}</p>}
                        <SignatureButton
                          tone="owner"
                          icon="wallet"
                          label={accepted ? c3110(lang, "pay") : tbd ? c3110(lang, "dates_first") : c3110(lang, "choose_pay", { name: firstName })}
                          price={priceLabel || undefined}
                          loading={busyId === id}
                          disabled={!canPay || (busyId !== null && busyId !== id) || step === "card" || step === "accepting" || step === "intent"}
                          disabledReason={stale ? d620(lang, "cand_stale_hint") : undefined}
                          earns={!tbd}
                          onClick={() => void chooseAndPay(a)}
                          ariaLabel={`${c3110(lang, "choose_pay", { name: firstName })}${priceLabel ? ` · ${priceLabel}` : ""}`}
                        />
                      </>
                    )}
                    <div className="mt-2 flex items-center justify-center gap-4 text-[12px] font-bold" style={{ color: tone.dark }}>
                      <button type="button" className="min-h-[36px] underline-offset-2 hover:underline disabled:opacity-60" disabled={writingId !== null} onClick={() => void write(a)}>
                        {writingId === id ? c3110(lang, "opening") : `${c3110(lang, "write")} · ${firstName}`}
                      </button>
                      {pid && <a href={`/p/${role}/${pid}`} target="_blank" rel="noopener" className="min-h-[36px] leading-[36px] underline-offset-2 hover:underline" onClick={() => trackSiteEvent("cta_click", { label: "cand_profil" })}>{c3110(lang, "profile")}</a>}
                    </div>
                    {err && <p className="mt-2 rounded-xl px-3 py-2 text-[12px] font-bold" style={{ background: "#FBE9E5", color: "#9E1F0B" }} role="alert">{err}</p>}
                  </div>
                </li>
              );
            })}
          </ul>
          {!tbd && pendingCount > 0 && step === "idle" && (
            <div className="mt-4 rounded-2xl bg-white p-3" style={{ boxShadow: "0 6px 16px -10px rgba(35,23,21,.35)" }}>{guarantees(nameOf(visible[0]))}</div>
          )}
        </>
      )}
    </div>
  );
}

export default OwnerCandidatesPay3110;
