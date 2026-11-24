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
// 05/11/2026 (LEO, plan B1 de BOB — ordre de Daniel « je veux réussir mes transactions ») : mesure sur 14 j =
// 15 propriétaires ont ouvert leurs candidats, 0 ont payé ; on demandait 240 à 900 € sans jamais avoir pu parler
// au gardien. → sur CHAQUE carte, AVANT de payer, « Poser une question à <prénom> » : 3 questions prêtes + champ
// libre, envoi = conversation créée ou retrouvée (POST /conversations/start, même route que l'app, gratuite en
// phase de lancement) + message (POST /conversations/:id/messages → push + e-mail différé au prestataire, comme
// tout message) ; le propriétaire voit « Question envoyée · la réponse arrive par e-mail » + « Voir la
// conversation ». Aucune page à part, aucun mot de passe (session ouverte par le lien de l'e-mail).
// Repères : cand_question_ouvrir, cand_question_envoyer, cand_question_ok, cand_question_echec, cand_question_conv.
// 22/11/2026 — « Proposer mon prix » (mesure : 55 propriétaires voient leurs candidats en 30 j, 2 cliquent « Choisir et
// payer », 0 paie ; deux étaient d'accord avec le gardien sur un prix plus bas, que rien ne permettait d'enregistrer).
// Sous chaque candidat en attente dont le total est connu, un lien discret « Proposer mon prix » → un champ montant
// (total payé, frais compris, devise de la candidature) + « Envoyer ma proposition » (POST /applications/:id/price-offer).
// Le gardien accepte ou refuse par e-mail ; accepté, le serveur renvoie le nouveau `pricing` : le total et le bouton
// « Choisir <prénom> et payer » prennent le nouveau prix sans rien calculer ici. Le lien n'apparaît que si le serveur
// l'autorise (`priceOffer2211View.canOffer` ; PRICE_OFFER_2211=off le masque).
// Repères : cand_prix_ouvrir, cand_prix_envoyer, cand_prix_ok, cand_prix_echec.
// 22/11/2026 (lot A, même mesure : 13 ouvrent un profil, 6 posent une question, 0 paie) — site seul :
//   · « Lui parler avant de réserver » : nouveau libellé du bouton de question ; un message prêt de plus, en tête
//     (« Pouvons-nous nous parler 10 minutes avant que je réserve ? ») ; un toucher remplit le champ, modifiable
//     avant l'envoi. Repère : cand_parler_pret ;
//   · ordre « confiance d'abord » : photo, puis identité vérifiée, puis du plus proche au plus loin (lib/cand3110) ;
//   · promenade / visite à domicile : les candidats à plus de 10 km passent après les autres, sous l'intertitre
//     « Plus loin de chez toi ». Aucun candidat n'est masqué.
// 22/11/2026 (lot B) — « Réserver <prénom>, payer plus tard » : sous le bouton principal (inchangé), un bouton plus
// discret → texte de confirmation sur place (« <prénom> sera prévenu(e). Tu as 48 h pour payer… Rien n'est débité
// maintenant. ») + « Confirmer la réservation » → POST /applications/:id/respond { action:'accept', payLater:true }
// (aucune intention de paiement). La carte passe à « Réservé jusqu'au <date heure> · Payer maintenant » (même
// parcours de paiement qu'une candidature déjà acceptée, via `linkedBooking`) + « Lui écrire ». Le bouton n'apparaît
// que si le serveur l'autorise (`payLater2211View.canReserve` ; PAY_LATER_2211=off le masque).
// Repères : cand_reserver_plus_tard, cand_reserver_ok, cand_reserver_echec.

import { Fragment, useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "@/components/SiteLink";
import { useT } from "@/lib/i18n/LanguageProvider";
import { AppIcon } from "@/components/AppIcon";
import { SignatureButton } from "@/components/SignatureButton";
import { PostDatesEditor620 } from "@/components/PostDatesEditor620";
import { d620, qtyLabel620, unitShort620 } from "@/lib/i18n/dates620";
import { dateModeOf620 } from "@/lib/services620";
import { c3110 } from "@/lib/i18n/cand3110";
import { markCandidatesViewed } from "@/lib/candidatesView2610";
import { MagicLinkBox0611 } from "@/components/MagicLinkBox0611";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { k1011 } from "@/lib/i18n/conclure1011";
import { FAR_KM_2211, countryForCurrency3110, isFar2211, kmOf3110, pickPostId3110, point3110, sortCandidates3110, totalOf3110 } from "@/lib/cand3110";
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
  proposeApplicationPrice,
  respondToApplication,
  sendMessage as sendChatMessage,
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
  // 05/11 — « Poser une question » : carte dont la zone est ouverte, texte saisi, envoi en cours,
  // et conversation créée par carte (candidature → id de conversation) pour « Voir la conversation ».
  const [askId, setAskId] = useState<string | null>(null);
  const [askText, setAskText] = useState("");
  const [askBusy, setAskBusy] = useState(false);
  const [askSent, setAskSent] = useState<Record<string, string>>({});
  // 06/11 (LEO, mesure de FLO) — pas de session (adresse tapée, favori, jeton périmé) : au lieu de renvoyer
  // vers le mot de passe, on montre ICI l'encart « Pas de mot de passe ? Reçois ton lien par e-mail ».
  const [needLink, setNeedLink] = useState("");
  // 22/11 — « Proposer mon prix » : carte dont le champ est ouvert, montant saisi, envoi en cours.
  const [offerId, setOfferId] = useState<string | null>(null);
  const [offerText, setOfferText] = useState("");
  const [offerBusy, setOfferBusy] = useState(false);
  // 22/11 (lot B) — « Réserver, payer plus tard » : carte dont la confirmation est ouverte, envoi en cours.
  const [laterId, setLaterId] = useState<string | null>(null);
  const [laterBusy, setLaterBusy] = useState(false);
  const offerRef = useRef<HTMLInputElement | null>(null);
  const askRef = useRef<HTMLTextAreaElement | null>(null);
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
      setNeedLink(here);
      setLoading(false);
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
        setNeedLink(here);
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

  // 31/10 soir (LEO, demande BOB — relance d'ADA « Pose tes dates ») : sur une demande « dates à prévoir », l'éditeur
  // (pré-rempli) s'ouvre d'office quand l'adresse porte `dates=1`, ou quand on arrive d'un e-mail (`from=email`, posé
  // par emailLinkBuilder sur tout lien /application/<id> d'un propriétaire) ; on fait défiler jusqu'à lui et on
  // place le curseur dans le 1er champ. Une seule fois par visite (« Annuler » le referme pour de bon).
  // 24/11 (BOB) — lien « Écrire à <prénom> avant de réserver » de l'e-mail (?ask=1) : la zone de question du candidat
  // visé s'ouvre toute seule, une seule fois par visite. Une propriétaire avait répondu à l'e-mail en croyant écrire à la gardienne.
  const autoAskRef = useRef<"pending" | "done">("pending");
  useEffect(() => {
    if (autoAskRef.current === "done" || loading || !focusId || !items.length) return;
    autoAskRef.current = "done";
    let q: URLSearchParams | null = null;
    try { q = new URLSearchParams(window.location.search); } catch { q = null; }
    if (!q || q.get("ask") !== "1") return;
    const a = items.find((x) => applicationId(x) === focusId && x.status === "pending");
    if (!a) return;
    setAskId(focusId);
    setAskText("");
    trackSiteEvent("cta_click", { label: "cand_question_auto" });
    window.setTimeout(() => {
      try { document.getElementById(`application-${focusId}`)?.scrollIntoView({ behavior: "smooth", block: "center" }); askRef.current?.focus({ preventScroll: true }); } catch { /* sans focus */ }
    }, 300);
  }, [loading, focusId, items]);
  const autoDatesRef = useRef<"pending" | "done">("pending");
  useEffect(() => {
    if (autoDatesRef.current === "done" || !post || step === "paid") return;
    if (dateModeOf620(post) !== "tbd") { autoDatesRef.current = "done"; return; }
    let q: URLSearchParams | null = null;
    try { q = new URLSearchParams(window.location.search); } catch { q = null; }
    autoDatesRef.current = "done";
    if (!q || !(q.get("dates") === "1" || q.get("from") === "email")) return;
    setEditingDates(true);
    trackSiteEvent("cta_click", { label: "cand_dates_auto" });
    // Pas de nettoyage : si `post`/`step` changent dans les 120 ms, le défilement doit quand même avoir lieu.
    window.setTimeout(() => {
      const box = datesRef.current;
      if (!box) return;
      box.scrollIntoView({ behavior: "smooth", block: "start" });
      const field = box.querySelector<HTMLElement>("input[type=date]") || box.querySelector<HTMLElement>("input:not([type=hidden]),select,button");
      try { field?.focus({ preventScroll: true }); } catch { /* sans focus */ }
    }, 120);
  }, [post, step]);

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
  const visible = sortCandidates3110(items.filter((a) => a.status === "pending" || a.status === "accepted"), postPoint, focusId, post?.serviceTypes);
  // 22/11 — promenade / visite : 1er candidat « plus loin » (hors candidat du lien, traité à part) → intertitre avant lui.
  const firstFarId = (() => {
    const f = visible.find((a) => !(focusId && applicationId(a) === focusId) && isFar2211(a, postPoint, post?.serviceTypes));
    return f && visible.some((a) => !isFar2211(a, postPoint, post?.serviceTypes)) ? applicationId(f) : "";
  })();
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

  /** 05/11 — les questions prêtes : expérience avec mon animal (garde / promenade), le rencontrer avant, les dates.
   *  22/11 — en tête, « se parler 10 minutes avant que je réserve » (c'est ce que les propriétaires demandent). */
  function questionsFor(a: ApplicationItem): string[] {
    const { role } = applicationProvider(a);
    const kind = String(post?.animalTypes?.[0] || post?.pets?.[0]?.category || "").toLowerCase();
    const animalKey = kind.startsWith("dog") || kind === "chien" ? "animal_dog" : kind.startsWith("cat") || kind === "chat" ? "animal_cat" : "animal_other";
    const animal = c3110(lang, animalKey);
    return [
      c3110(lang, "q_call"),
      c3110(lang, role === "walker" ? "q_exp_walk" : "q_exp", { animal }),
      c3110(lang, "q_meet"),
      c3110(lang, tbd ? "q_dates_tbd" : "q_dates"),
    ];
  }

  /** 05/11 — ouvre la zone de question sous la carte (une seule à la fois) et place le curseur. */
  function askOpen(a: ApplicationItem) {
    const id = applicationId(a);
    setOfferId(null);
    setLaterId(null);
    setAskId(id);
    setAskText("");
    setErrors((er) => ({ ...er, [id]: "" }));
    trackSiteEvent("cta_click", { label: "cand_question_ouvrir" });
    window.setTimeout(() => { try { askRef.current?.focus({ preventScroll: true }); } catch { /* sans focus */ } }, 60);
  }

  /** 05/11 — envoie la question : conversation créée ou retrouvée (même route que l'app), puis le message
   *  (notification habituelle du prestataire : push + e-mail différé). La réponse arrive au propriétaire par e-mail. */
  async function askSend(a: ApplicationItem) {
    const id = applicationId(a);
    const text = askText.trim();
    if (!text || askBusy) return;
    const { role, who } = applicationProvider(a);
    const providerId = String(who?.id || who?._id || "");
    if (!providerId) return;
    setAskBusy(true);
    setErrors((er) => ({ ...er, [id]: "" }));
    trackSiteEvent("cta_click", { label: "cand_question_envoyer" });
    try {
      const conv = askSent[id] || (await startProviderConversation(role, providerId));
      if (!conv) throw new Error("conversation");
      await sendChatMessage(conv, text);
      setAskSent((m) => ({ ...m, [id]: conv }));
      setAskId(null);
      setAskText("");
      trackSiteEvent("cta_click", { label: "cand_question_ok" });
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) { router.replace(`/login?redirect=${encodeURIComponent(window.location.pathname + window.location.search)}`); return; }
      trackSiteEvent("cta_click", { label: "cand_question_echec" });
      setErrors((er) => ({ ...er, [id]: c3110(lang, "ask_error") }));
    } finally {
      setAskBusy(false);
    }
  }

  /** 22/11 — ouvre le champ « Proposer mon prix » sous la carte (une seule zone ouverte à la fois). */
  function offerOpen(a: ApplicationItem) {
    const id = applicationId(a);
    setAskId(null);
    setLaterId(null);
    setOfferId(id);
    setOfferText("");
    setErrors((er) => ({ ...er, [id]: "" }));
    trackSiteEvent("cta_click", { label: "cand_prix_ouvrir" });
    window.setTimeout(() => { try { offerRef.current?.focus({ preventScroll: true }); } catch { /* sans focus */ } }, 60);
  }

  /** 22/11 — envoie la proposition : le serveur vérifie les bornes, écrit au gardien (conversation + e-mail avec
   *  lien de réponse) et renvoie l'état à afficher. Le prix de la carte ne change qu'après l'accord du gardien. */
  async function offerSend(a: ApplicationItem) {
    const id = applicationId(a);
    if (offerBusy) return;
    const amount = Number(offerText.replace(",", ".").replace(/[^0-9.]/g, ""));
    const currency = (a.pricing?.currency || post?.budgetCurrency || post?.currency || "EUR").toUpperCase();
    const min = a.priceOffer2211View?.minAmount ?? null;
    const max = a.priceOffer2211View?.currentTotal ?? totalOf3110(a);
    const lowMsg = min != null ? c3110(lang, "offer_err_low", { min: money(min, currency, lang) }) : c3110(lang, "offer_err");
    const highMsg = max != null ? c3110(lang, "offer_err_high", { max: money(max, currency, lang) }) : c3110(lang, "offer_err");
    if (!Number.isFinite(amount) || !(amount > 0)) { setErrors((er) => ({ ...er, [id]: lowMsg })); return; }
    if (max != null && amount >= max) { setErrors((er) => ({ ...er, [id]: highMsg })); return; }
    if (min != null && amount < min) { setErrors((er) => ({ ...er, [id]: lowMsg })); return; }
    setOfferBusy(true);
    setErrors((er) => ({ ...er, [id]: "" }));
    trackSiteEvent("cta_click", { label: "cand_prix_envoyer" });
    try {
      const res = await proposeApplicationPrice(id, Math.round(amount * 100) / 100);
      const view = res.priceOffer2211View || { status: "pending" as const, amount, currency, canOffer: false };
      setItems((prev) => prev.map((x) => (applicationId(x) === id ? { ...x, priceOffer2211View: view } : x)));
      setOfferId(null);
      setOfferText("");
      trackSiteEvent("cta_click", { label: "cand_prix_ok" });
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) { router.replace(`/login?redirect=${encodeURIComponent(window.location.pathname + window.location.search)}`); return; }
      const code = apiErrorCode(e);
      trackSiteEvent("cta_click", { label: "cand_prix_echec" });
      const msg = code === "OFFER_TOO_LOW" ? lowMsg : code === "OFFER_NOT_LOWER" ? highMsg : code === "OFFER_LIMIT" ? c3110(lang, "offer_err_limit") : c3110(lang, "offer_err");
      setErrors((er) => ({ ...er, [id]: msg }));
      // Limite atteinte ou fonction coupée côté serveur : le lien disparaît de cette carte.
      if (code === "OFFER_LIMIT" || code === "OFFER_DISABLED") {
        setItems((prev) => prev.map((x) => (applicationId(x) === id ? { ...x, priceOffer2211View: { ...(x.priceOffer2211View || {}), canOffer: false } } : x)));
        setOfferId(null);
      }
    } finally {
      setOfferBusy(false);
    }
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

  /** Refus du serveur à l'acceptation → message dans la langue du propriétaire (null : session perdue, on part se reconnecter). */
  function acceptErrorMsg(e: unknown, currency: string): string | null {
    const code = apiErrorCode(e);
    const d = e instanceof ApiError && e.details && typeof e.details === "object" ? (e.details as Record<string, unknown>) : {};
    if (code === "CURRENCY_MISMATCH") return t("c1610_currency").replace("{a}", String(d.providerCurrency || "?")).replace("{b}", String(d.ownerCurrency || currency));
    if (code === "DATES_REQUIRED") { setEditingDates(true); return d620(lang, "cand_choose_blocked"); }
    if (code === "TOO_FAR") return t("c1610_too_far").replace("{km}", String(d.limitKm || 200));
    if (e instanceof ApiError && e.status === 409 && !code.startsWith("PAY_LATER_")) return t("c1610_already");
    if (e instanceof ApiError && e.status === 401) { router.replace(`/login?redirect=${encodeURIComponent(window.location.pathname + window.location.search)}`); return null; }
    return e instanceof Error && e.message ? e.message : c3110(lang, "error");
  }

  /** 22/11 (lot B) — ouvre la confirmation « payer plus tard » sous le bouton (une seule zone ouverte à la fois). */
  function laterOpen(a: ApplicationItem) {
    const id = applicationId(a);
    setAskId(null);
    setOfferId(null);
    setLaterId(id);
    setErrors((er) => ({ ...er, [id]: "" }));
    trackSiteEvent("cta_click", { label: "cand_reserver_plus_tard" });
  }

  /** 22/11 (lot B) — réserve sans carte : le serveur accepte la candidature, pose l'échéance et prévient le gardien.
   *  Aucune intention de paiement n'est créée ; « Payer maintenant » reprend ensuite le parcours de paiement habituel. */
  async function laterConfirm(a: ApplicationItem) {
    const id = applicationId(a);
    if (laterBusy || busyId !== null) return;
    const currency = (a.pricing?.currency || post?.budgetCurrency || post?.currency || "EUR").toUpperCase();
    setLaterBusy(true);
    setErrors((er) => ({ ...er, [id]: "" }));
    try {
      const res = await respondToApplication(id, "accept", { payLater: true });
      const view = { enabled: true, canReserve: false, status: "waiting" as const, deadline: res.payLater2211?.deadline ?? null, at: res.payLater2211?.at ?? null, holdHours: res.payLater2211?.holdHours ?? null };
      setItems((prev) => prev.map((x) => {
        const xid = applicationId(x);
        if (xid === id) return { ...x, ...res.application, booking: res.booking || x.booking || null, payLater2211View: view };
        // Comme pour « Choisir et payer » : seul un ancien choix non payé est libéré par le serveur.
        if (x.status === "accepted" && !linkedBooking(x)?.paid) return { ...x, status: "rejected" };
        return x;
      }));
      setLaterId(null);
      trackSiteEvent("cta_click", { label: "cand_reserver_ok" });
    } catch (e) {
      const code = apiErrorCode(e);
      trackSiteEvent("cta_click", { label: "cand_reserver_echec" });
      let msg: string | null;
      if (code.startsWith("PAY_LATER_")) {
        // Refusé par le serveur (éteint, service trop proche, déjà libérée une fois) : il ne reste que « Choisir et payer ».
        msg = c3110(lang, code === "PAY_LATER_TOO_LATE" ? "later_err_late" : "later_err");
        setItems((prev) => prev.map((x) => (applicationId(x) === id ? { ...x, payLater2211View: { ...(x.payLater2211View || {}), canReserve: false } } : x)));
        setLaterId(null);
      } else {
        msg = acceptErrorMsg(e, currency);
        if (msg == null) return;
        if (!(e instanceof ApiError)) msg = c3110(lang, "later_err");
      }
      setErrors((er) => ({ ...er, [id]: msg || c3110(lang, "later_err") }));
    } finally {
      setLaterBusy(false);
    }
  }

  /** Choisir et payer : accepte (les autres candidats restent jusqu'au paiement, 1011), prend l'intention, monte l'encart carte. */
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
    setLaterId(null);
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
          // 1011 — le serveur GARDE les autres candidats jusqu'au paiement (siblings1011) : ils restent
          // visibles. Seul un ancien choix non payé est libéré quand on choisit quelqu'un d'autre.
          if (x.status === "accepted" && !linkedBooking(x)?.paid) return { ...x, status: "rejected" };
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
      const msg = acceptErrorMsg(e, currency);
      if (msg == null) return;
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

  if (needLink) {
    return (
      <div className="mx-auto w-full max-w-md px-4 pb-20 pt-6 md:pt-10" data-cand3110-magic="" style={{ colorScheme: "light" }}>
        <h1 className="font-display text-[24px] font-extrabold leading-tight tracking-tight md:text-[30px]" style={{ color: "#231715" }}>
          {c3110(lang, "title")}
        </h1>
        <div className="mt-4">
          <MagicLinkBox0611 next={needLink} lang={lang} onHasPassword={() => router.push(`/login?redirect=${encodeURIComponent(needLink)}&pwd=1`)} />
        </div>
      </div>
    );
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
                <SignatureButton tone="sitter" icon="chat" label={c3110(lang, "paid_chat", { name: pay.name })} loading={writingId !== null} onClick={() => { const a = items.find((x) => applicationId(x) === pay.appId); if (a) void write(a); }} />
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
              // 24/11 (BOB, question d'un propriétaire : « 184,80 € correspond à quoi ? ») — le total expliqué :
              // « 11 jours × 16,80 € » (tarif frais compris). Rien sans dates, pour une seule unité, ou si le tarif est à venir.
              const qty = Number(a.pricing?.quantity);
              const perUnit = total != null && !indicative && !stale && Number.isInteger(qty) && qty > 1 ? Math.round((total / qty) * 100) / 100 : null;
              const detailLabel = perUnit != null && perUnit > 0
                ? `${Math.abs(perUnit * qty - (total as number)) < 0.005 ? "" : "≈ "}${qtyLabel620(lang, qty, unitOf(a))} × ${money(perUnit, currency, lang)}`
                : "";
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
              // 22/11 — « Proposer mon prix » : seulement sur une candidature en attente au total connu, si le serveur l'autorise.
              const offer = a.priceOffer2211View || null;
              const offerPrice = offer?.amount != null && offer.amount > 0 ? money(offer.amount, (offer.currency || currency).toUpperCase(), lang) : "";
              const canOffer = offer?.canOffer === true && a.status === "pending" && !tbd && total != null && !stale && !(bk?.paid || chosenHere);
              const offerNote = !offer?.status || accepted || bk?.paid || chosenHere ? ""
                : offer.status === "pending" ? (offerPrice ? c3110(lang, "offer_pending", { name: firstName, price: offerPrice }) : c3110(lang, "offer_sent", { name: firstName }))
                : offer.status === "accepted" ? c3110(lang, "offer_accepted", { name: firstName, price: offerPrice })
                : offer.status === "declined" ? c3110(lang, "offer_declined", { name: firstName })
                : offer.status === "expired" ? c3110(lang, "offer_expired", { price: offerPrice })
                : offer.status === "cancelled" ? c3110(lang, "offer_cancelled") : "";
              const offerGood = offer?.status === "pending" || offer?.status === "accepted";
              // 22/11 (lot B) — « payer plus tard » : bouton si le serveur l'autorise ; état « réservé jusqu'au … » ensuite.
              const later = a.payLater2211View || null;
              const held = accepted && later?.status === "waiting" && !!later.deadline && !(bk?.paid || chosenHere);
              const heldDate = held && later?.deadline ? new Date(later.deadline).toLocaleString(dtLocale, { weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" }) : "";
              const canLater = later?.canReserve === true && a.status === "pending" && !tbd && total != null && !stale && !(bk?.paid || chosenHere);
              const payBusy = step === "card" || step === "accepting" || step === "intent";
              return (
                <Fragment key={id}>
                {firstFarId === id && (
                  <li className="col-span-full mt-1 flex items-center gap-1.5 text-[13px] font-extrabold" style={{ color: "#6E4F48" }} data-cand3110-far="">
                    <AppIcon name="pin" size={15} color="#6E4F48" />{c3110(lang, "far_title", { km: FAR_KM_2211 })}
                  </li>
                )}
                <li id={`application-${id}`} className="flex min-w-0 flex-col rounded-2xl bg-white p-3" data-candidate-3110={role} data-candidate-km={km ?? ""} data-candidate-total={total ?? ""}
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
                            {detailLabel && <span className="block text-[11px] font-bold" style={{ color: "#6E4F48" }} data-detail-2411="">{detailLabel}</span>}
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
                        {/* 1011 — « Véhiculé » : seulement si le gardien l'a dit (true). Demande « sans voiture » → mis en avant. */}
                        {who?.hasVehicle === true && (
                          post?.ownerNoCar === true ? (
                            <span data-vehicle-1011="pickup" className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-extrabold text-white" style={{ background: "#C92A12" }}>
                              <span aria-hidden>🚗</span>{k1011(lang, "vehicle_pickup")}
                            </span>
                          ) : (
                            <span data-vehicle-1011="badge" className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-bold" style={{ background: "#FFE9E2", color: "#9E1F0B" }}>
                              <span aria-hidden>🚗</span>{k1011(lang, "vehicle_badge")}
                            </span>
                          )
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
                        {accepted && !held && <p className="mb-1.5 text-[12px] font-bold" style={{ color: "#9E1F0B" }}>{c3110(lang, "chosen")}</p>}
                        {held && (
                          <div className="mb-2 rounded-xl px-3 py-2" style={{ background: "#DCEFE3" }} data-later-2211="held">
                            <p className="flex items-start gap-1.5 text-[13px] font-extrabold leading-snug" style={{ color: "#15803D" }}>
                              <AppIcon name="check" size={15} color="#15803D" /><span>{c3110(lang, "later_held", { date: heldDate })}</span>
                            </p>
                            <p className="mt-0.5 text-[11px] font-semibold leading-snug" style={{ color: "#6E4F48" }}>{c3110(lang, "later_held_sub", { name: firstName })}</p>
                          </div>
                        )}
                        <SignatureButton
                          tone="owner"
                          icon="wallet"
                          label={held ? c3110(lang, "later_pay") : accepted ? c3110(lang, "pay") : tbd ? c3110(lang, "dates_first") : c3110(lang, "choose_pay", { name: firstName })}
                          price={priceLabel || undefined}
                          loading={busyId === id}
                          disabled={!canPay || (busyId !== null && busyId !== id) || payBusy || laterBusy}
                          disabledReason={stale ? d620(lang, "cand_stale_hint") : undefined}
                          earns={!tbd}
                          onClick={() => void chooseAndPay(a)}
                          ariaLabel={`${held ? c3110(lang, "later_pay") : c3110(lang, "choose_pay", { name: firstName })}${priceLabel ? ` · ${priceLabel}` : ""}`}
                        />
                        {/* 22/11 (lot B) — second bouton, plus discret : réserver sans carte, payer dans le délai annoncé. */}
                        {canLater && laterId !== id && (
                          <div className="mt-2" data-later-2211="btn">
                            <SignatureButton tone="owner" kind="secondary" icon="calendar" label={c3110(lang, "later_btn", { name: firstName })} disabled={busyId !== null || payBusy || laterBusy} onClick={() => laterOpen(a)} />
                          </div>
                        )}
                        {canLater && laterId === id && (
                          <div className="mt-2 rounded-xl p-3" style={{ background: "#FBE9E5" }} data-later-2211="confirm">
                            <p className="text-[13px] font-bold leading-snug" style={{ color: "#231715" }}>{c3110(lang, "later_text", { name: firstName, hours: later?.holdHours ?? 48 })}</p>
                            <div className="mt-2 flex items-center gap-3">
                              <div className="min-w-0 flex-1">
                                <SignatureButton tone="owner" icon="check" label={laterBusy ? c3110(lang, "later_busy") : c3110(lang, "later_confirm")} loading={laterBusy} disabled={laterBusy || busyId !== null || payBusy} onClick={() => void laterConfirm(a)} />
                              </div>
                              <button type="button" className="min-h-[36px] shrink-0 text-[12px] font-bold underline-offset-2 hover:underline" style={{ color: "#6E4F48" }} disabled={laterBusy} onClick={() => setLaterId(null)}>{c3110(lang, "ask_close")}</button>
                            </div>
                          </div>
                        )}
                        {later?.status === "released" && a.status === "pending" && (
                          <p className="mt-2 rounded-xl px-3 py-2 text-[12px] font-bold leading-snug" style={{ background: "#FBE9E5", color: "#9E1F0B" }} data-later-2211="released">{c3110(lang, "later_released")}</p>
                        )}
                      </>
                    )}
                    {/* 05/11 — « Poser une question à <prénom> » AVANT de payer : bouton → zone sous la carte (3 questions prêtes +
                        champ libre) → « Question envoyée · la réponse arrive par e-mail » + « Voir la conversation ». */}
                    {!(bk?.paid || chosenHere) && (askId === id ? (
                      <div className="mt-2 rounded-xl p-3" style={{ background: tone.pale }} data-ask-3110="open">
                        <p className="text-[13px] font-extrabold leading-snug" style={{ color: tone.dark }}>{c3110(lang, "ask_title", { name: firstName })}</p>
                        <p className="mt-0.5 text-[11px] font-semibold leading-snug" style={{ color: "#6E4F48" }}>{c3110(lang, "ask_hint", { name: firstName })}</p>
                        <div className="mt-2 flex flex-wrap gap-1.5" data-ask-3110-questions="">
                          {questionsFor(a).map((q) => (
                            <button key={q} type="button" className="min-h-[36px] max-w-full rounded-2xl bg-white px-3 py-1.5 text-left text-[12px] font-bold leading-snug" style={{ color: tone.dark, boxShadow: askText === q ? `0 0 0 2px ${tone.dark}` : `inset 0 0 0 1px ${tone.dark}` }} onClick={() => { setAskText(q); trackSiteEvent("cta_click", { label: "cand_parler_pret" }); try { askRef.current?.focus({ preventScroll: true }); } catch { /* sans focus */ } }}>
                              {q}
                            </button>
                          ))}
                        </div>
                        <textarea ref={askRef} value={askText} onChange={(e) => setAskText(e.target.value)} rows={2} maxLength={1000} placeholder={c3110(lang, "ask_placeholder")} aria-label={c3110(lang, "ask_title", { name: firstName })}
                          className="mt-2 w-full resize-none rounded-xl bg-white px-3 py-2 text-[14px] leading-snug outline-none placeholder:text-[#8A6B64]" style={{ color: "#231715", boxShadow: `inset 0 0 0 1px ${tone.dark}` }} data-ask-3110-input="" />
                        <div className="mt-2 flex items-center gap-3">
                          <div className="min-w-0 flex-1">
                            <SignatureButton tone={role} icon="chat" label={askBusy ? c3110(lang, "ask_sending") : c3110(lang, "ask_send")} loading={askBusy} disabled={!askText.trim() || askBusy} onClick={() => void askSend(a)} />
                          </div>
                          <button type="button" className="min-h-[36px] shrink-0 text-[12px] font-bold underline-offset-2 hover:underline" style={{ color: "#6E4F48" }} onClick={() => { setAskId(null); setAskText(""); }}>{c3110(lang, "ask_close")}</button>
                        </div>
                      </div>
                    ) : askSent[id] ? (
                      <div className="mt-2 rounded-xl px-3 py-2" style={{ background: "#DCEFE3" }} data-ask-3110="sent">
                        <p className="flex items-start gap-1.5 text-[12px] font-bold leading-snug" style={{ color: "#15803D" }}>
                          <AppIcon name="check" size={14} color="#15803D" /><span>{c3110(lang, "ask_sent")}</span>
                        </p>
                        <p className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-[12px] font-bold" style={{ color: tone.dark }}>
                          <Link href={`/chat?c=${encodeURIComponent(askSent[id])}`} className="min-h-[32px] leading-[32px] underline underline-offset-2" onClick={() => trackSiteEvent("cta_click", { label: "cand_question_conv" })}>{c3110(lang, "ask_see")}</Link>
                          <button type="button" className="min-h-[32px] underline-offset-2 hover:underline" onClick={() => askOpen(a)}>{c3110(lang, "ask_again")}</button>
                        </p>
                      </div>
                    ) : held ? (
                      // ZOE 22/11 — déjà réservé : « Lui parler avant de réserver » n'a plus de sens ; un seul bouton « Lui écrire ».
                      pid ? (
                        <div className="mt-2" data-later-2211="write">
                          <SignatureButton tone={role} kind="secondary" icon="chat" label={c3110(lang, "later_write")} loading={writingId === id} disabled={writingId !== null} onClick={() => void write(a)} />
                        </div>
                      ) : null
                    ) : (
                      <div className="mt-2" data-ask-3110="btn">
                        <SignatureButton tone={role} kind="secondary" icon="chat" label={c3110(lang, "ask_btn", { name: firstName })} disabled={askBusy} onClick={() => askOpen(a)} />
                      </div>
                    ))}
                    {/* 22/11 — état de la proposition de prix (en attente / acceptée / refusée / sans réponse). */}
                    {offerNote && (
                      <p className="mt-2 flex items-start gap-1.5 rounded-xl px-3 py-2 text-[12px] font-bold leading-snug" style={offerGood ? { background: "#DCEFE3", color: "#15803D" } : { background: "#FBE9E5", color: "#9E1F0B" }} data-offer-2211={offer?.status || ""}>
                        {offerGood && <AppIcon name="check" size={14} color="#15803D" />}<span>{offerNote}</span>
                      </p>
                    )}
                    {canOffer && offerId === id && (
                      <div className="mt-2 rounded-xl p-3" style={{ background: tone.pale }} data-offer-2211="open">
                        <p className="text-[13px] font-extrabold leading-snug" style={{ color: tone.dark }}>{c3110(lang, "offer_title", { name: firstName })}</p>
                        <p className="mt-0.5 text-[11px] font-semibold leading-snug" style={{ color: "#6E4F48" }}>
                          {c3110(lang, "offer_hint", { name: firstName, min: money(offer?.minAmount ?? 0, currency, lang), max: money(offer?.currentTotal ?? total ?? 0, currency, lang) })}
                        </p>
                        <div className="mt-2 flex items-center gap-2 rounded-xl bg-white px-3" style={{ boxShadow: `inset 0 0 0 1px ${tone.dark}` }}>
                          <input ref={offerRef} value={offerText} onChange={(e) => setOfferText(e.target.value)} onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); void offerSend(a); } }}
                            type="text" inputMode="decimal" autoComplete="off" maxLength={9} placeholder={c3110(lang, "offer_label")} aria-label={c3110(lang, "offer_label")}
                            className="min-h-[44px] w-full min-w-0 flex-1 bg-transparent text-[16px] font-bold outline-none placeholder:font-semibold placeholder:text-[#8A6B64]" style={{ color: "#231715" }} data-offer-2211-input="" />
                          <span className="shrink-0 text-[13px] font-extrabold" style={{ color: tone.dark }}>{currency}</span>
                        </div>
                        <div className="mt-2 flex items-center gap-3">
                          <div className="min-w-0 flex-1">
                            <SignatureButton tone={role} icon="wallet" label={offerBusy ? c3110(lang, "offer_sending") : c3110(lang, "offer_send")} loading={offerBusy} disabled={!offerText.trim() || offerBusy} onClick={() => void offerSend(a)} />
                          </div>
                          <button type="button" className="min-h-[36px] shrink-0 text-[12px] font-bold underline-offset-2 hover:underline" style={{ color: "#6E4F48" }} onClick={() => { setOfferId(null); setOfferText(""); setErrors((er) => ({ ...er, [id]: "" })); }}>{c3110(lang, "ask_close")}</button>
                        </div>
                      </div>
                    )}
                    <div className="mt-2 flex flex-wrap items-center justify-center gap-x-4 gap-y-0 text-[12px] font-bold" style={{ color: tone.dark }}>
                      {pid && <a href={`/p/${role}/${pid}`} target="_blank" rel="noopener" className="min-h-[36px] leading-[36px] underline-offset-2 hover:underline" onClick={() => trackSiteEvent("cta_click", { label: "cand_profil" })}>{c3110(lang, "profile")}</a>}
                      {canOffer && offerId !== id && (
                        <button type="button" className="min-h-[36px] underline underline-offset-2" disabled={offerBusy || busyId !== null} onClick={() => offerOpen(a)} data-offer-2211="btn">{c3110(lang, "offer_btn")}</button>
                      )}
                    </div>
                    {err && <p className="mt-2 rounded-xl px-3 py-2 text-[12px] font-bold" style={{ background: "#FBE9E5", color: "#9E1F0B" }} role="alert">{err}</p>}
                  </div>
                </li>
                </Fragment>
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
