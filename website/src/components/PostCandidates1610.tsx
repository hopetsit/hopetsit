"use client";

// 16/10/2026 — LEO (ordre de Daniel : « en cas d'urgence quelqu'un se connecte
// sur le site et paye »). Les CANDIDATS d'une demande d'un propriétaire, sur le
// site, avec les mêmes mots et le même appel serveur que l'app
// (POST /applications/:id/respond { action }) :
//   · prénom, rôle (couleur du rôle), « Identité vérifiée », note, ville,
//     distance arrondie (~ km, jamais l'adresse), PRIX TOTAL dans la devise du
//     propriétaire ;
//   · « Choisir · 12 € » (bouton signature orange) et « Refuser » ;
//   · une fois choisi : la réservation existe → « Payer · 12 € » → /pay (pont
//     Airwallex déjà en place), exactement comme depuis /bookings ;
//   · les refus du serveur (devise différente, trop loin, déjà traitée) sont
//     affichés en clair, jamais un code brut.
// Zéro gris : encres brunes de la charte (#231715, #6E4F48), orange #C92A12.
// Tous les hooks sont en tête, avant tout retour conditionnel.

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { useT } from "@/lib/i18n/LanguageProvider";
import { AppIcon } from "@/components/AppIcon";
import { SignatureButton } from "@/components/SignatureButton";
// 620 (LEO, 24/10 — §B.2) : demande « dates à prévoir » → tarif unitaire +
// bandeau « Pose tes dates pour valider » (éditeur de dates), Choisir désactivé ;
// après les dates : totaux réels. + « Ouvrir dans l'app » (le site ramène dans l'app).
import { PostDatesEditor620 } from "@/components/PostDatesEditor620";
import { d620, unitShort620 } from "@/lib/i18n/dates620";
// 26/10 (LEO — décision de Daniel, proposition B de SAM) : « écrire d'abord, choisir ensuite,
// payer après » — cartes côte à côte, « Écrire à <prénom> » en bouton principal.
import { c2610 } from "@/lib/i18n/cand2610";
// 26/10 (ADA, proposition C de SAM) — repère « le propriétaire a ouvert ses candidats » (jamais bloquant).
import { markCandidatesViewed } from "@/lib/candidatesView2610";
import { dateModeOf620 } from "@/lib/services620";
// 2810 (SAM) — repères de l'entonnoir « candidats vus → choisir → payer » (aucune donnée perso).
import { trackSiteEvent } from "@/components/SiteAnalytics";
import {
  ApiError,
  type ApplicationItem,
  type Booking,
  type RequestPost,
  apiErrorCode,
  applicationId,
  applicationProvider,
  createBookingPaymentIntent,
  startProviderConversation,
  getMyApplications,
  respondToApplication,
} from "@/lib/api";

const ROLE = {
  sitter: { dark: "#1E4FB0", pale: "#DDEAFB" },
  walker: { dark: "#15803D", pale: "#DCEFE3" },
} as const;

function haversineKm(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const R = 6371;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((a.lat * Math.PI) / 180) * Math.cos((b.lat * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}

function point(o?: { lat?: number; lng?: number } | null): { lat: number; lng: number } | null {
  if (!o || typeof o.lat !== "number" || typeof o.lng !== "number") return null;
  if (!Number.isFinite(o.lat) || !Number.isFinite(o.lng)) return null;
  return { lat: o.lat, lng: o.lng };
}

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
    return `${v} ${currency}`;
  }
}

function fill(s: string, vars: Record<string, string | number>): string {
  return Object.entries(vars).reduce((acc, [k, v]) => acc.split(`{${k}}`).join(String(v)), s);
}

/** Réservation liée à une candidature acceptée (populée ou simple id). */
function linkedBooking(a: ApplicationItem): { id: string; paid: boolean } | null {
  const b = (a.booking || (a.bookingId && typeof a.bookingId === "object" ? (a.bookingId as Booking) : null)) as
    | (Booking & { _id?: string })
    | null;
  if (b) {
    const id = String(b.id || b._id || "");
    if (!id) return null;
    return { id, paid: String(b.paymentStatus || "").toLowerCase() === "paid" || b.status === "paid" };
  }
  if (typeof a.bookingId === "string" && a.bookingId) return { id: a.bookingId, paid: false };
  return null;
}

export function PostCandidates1610({
  post,
  applications,
  focusId,
  chooseNow,
  onChanged,
}: {
  post: RequestPost;
  applications: ApplicationItem[];
  /** Candidature à mettre en avant (lien de l'e-mail « candidature reçue »). */
  focusId?: string;
  /** 2710 (SAM) — arrivée par le bouton « Choisir <prénom> » de l'e-mail (?choose=1) : encart
   *  en tête « Choisir <prénom> et payer », UN geste = choix confirmé puis page de paiement. */
  chooseNow?: boolean;
  onChanged?: (updated: ApplicationItem[]) => void;
}) {
  const { t, lang } = useT();
  const router = useRouter();
  const [items, setItems] = useState<ApplicationItem[]>(applications);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [payingId, setPayingId] = useState<string | null>(null);
  const [errors, setErrors] = useState<Record<string, string>>({});
  // Photo introuvable (lien mort) → initiale à la couleur du rôle, jamais l'icône cassée du navigateur.
  const [brokenAvatars, setBrokenAvatars] = useState<Record<string, boolean>>({});
  const [rejectedNow, setRejectedNow] = useState<Record<string, boolean>>({});
  // 2610 — conversation en cours d'ouverture (« Écrire à … »).
  const [writingId, setWritingId] = useState<string | null>(null);
  const sectionRef = useRef<HTMLElement | null>(null);
  const focusRef = useRef<HTMLLIElement | null>(null);
  // 620 — la demande telle qu'elle est (ses dates peuvent être posées ici même).
  const [cur, setCur] = useState<RequestPost>(post);
  const [editingDates, setEditingDates] = useState(false);
  // 2810 (BOB) — « Choisir » sur une demande sans dates : le candidat retenu est gardé, on ouvre
  // les dates, et dès qu'elles sont posées l'encart « Choisir <prénom> et payer · prix » apparaît
  // pour lui (choisir → dates → payer, un seul fil). Hooks AVANT tout retour anticipé.
  const [pickId, setPickId] = useState<string | null>(null);
  useEffect(() => setCur(post), [post]);
  // 2610 (ADA) — mesure : une ouverture par demande affichée ; provenance lue dans l'adresse
  // (?from=email / utm_medium=email, transmis par /application/<id>). Erreurs ignorées.
  const viewPostId = String(post.id || post._id || "");
  useEffect(() => {
    if (viewPostId) markCandidatesViewed({ postId: viewPostId });
  }, [viewPostId]);
  // 2810 (SAM) — une fois par demande affichée avec au moins un candidat en attente.
  const seenRef = useRef("");
  useEffect(() => {
    if (!viewPostId || seenRef.current === viewPostId) return;
    if (!applications.some((x) => x.status === "pending")) return;
    seenRef.current = viewPostId;
    trackSiteEvent("cta_click", { label: chooseNow ? "cand_vus_mail" : "cand_vus" });
  }, [viewPostId, applications, chooseNow]);

  useEffect(() => setItems(applications), [applications]);
  useEffect(() => {
    // 2610 — arrivée par l'e-mail : la page s'ouvre directement sur les candidats (le haut du bloc),
    // la candidature de l'e-mail reste entourée.
    if (focusId && items.some((x) => applicationId(x) === focusId) && sectionRef.current) {
      sectionRef.current.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }, [focusId, items]);
  useEffect(() => {
    // 2810 — lien « Choisir » de l'e-mail sur une demande sans dates : les dates s'ouvrent tout de suite.
    if (chooseNow && focusId && dateModeOf620(cur) === "tbd" && items.some((x) => applicationId(x) === focusId && x.status === "pending")) {
      setPickId(focusId);
      setEditingDates(true);
    }
  }, [chooseNow, focusId, cur, items]);

  // Un candidat refusé À L'INSTANT reste affiché (« Candidature refusée ») : retour visible
  // au clic ; au prochain chargement il disparaît, comme dans l'app.
  const visible = items
    .filter((a) => a.status === "pending" || a.status === "accepted" || rejectedNow[applicationId(a)])
    // 2610 — le candidat de l'e-mail en premier, puis l'ordre du serveur.
    .sort((x, y) => Number(!!focusId && applicationId(y) === focusId) - Number(!!focusId && applicationId(x) === focusId));
  if (visible.length === 0) return null;

  const postPoint = point(cur.location);
  const pending = visible.filter((a) => a.status === "pending").length;
  // 620 — « dates à prévoir » : tarif unitaire seul, Choisir bloqué jusqu'aux dates.
  const tbd = dateModeOf620(cur) === "tbd";
  // 2910 (BOB, ordre de Daniel « lancer la machine ») — garanties RÉELLES affichées au moment de choisir :
  // annulation gratuite jusqu'à 72 h avant (self-cancel + remboursement, bookingController) — seulement si
  // le début est à plus de 72 h — et séquestre jusqu'à la fin du service. Ligne « fêtes » seulement si les
  // dates touchent la période du 15/12 au 06/01.
  const startMs = cur.startDate ? new Date(cur.startDate).getTime() : NaN;
  const endMs = cur.endDate ? new Date(cur.endDate).getTime() : startMs;
  const freeCancel = !tbd && Number.isFinite(startMs) && startMs - Date.now() > 72 * 3600 * 1000;
  const holidays = !tbd && Number.isFinite(startMs) && (() => {
    const y = new Date(startMs).getFullYear();
    return [y - 1, y].some((yy) => startMs <= Date.UTC(yy + 1, 0, 6) && endMs >= Date.UTC(yy, 11, 15));
  })();
  const guarantees = (
    <ul className="mt-2 space-y-1" data-guarantees-2910="">
      {freeCancel && (
        <li className="flex items-start gap-1.5 text-[12px] font-bold leading-snug" style={{ color: "#15803D" }}>
          <AppIcon name="shield-check" size={14} color="#15803D" />
          <span>{c2610(lang, "g_cancel")}</span>
        </li>
      )}
      <li className="flex items-start gap-1.5 text-[12px] font-bold leading-snug" style={{ color: "#15803D" }}>
        <AppIcon name="lock" size={14} color="#15803D" />
        <span>{c2610(lang, "g_escrow")}</span>
      </li>
      {holidays && (
        <li className="text-[12px] font-semibold leading-snug" style={{ color: "#9E1F0B" }}>{c2610(lang, "g_holiday")}</li>
      )}
    </ul>
  );
  const unitOf = (a: ApplicationItem): string => {
    const u = String(a.pricing?.unit || "");
    if (u) return u;
    const svc = String(a.serviceType || cur.serviceTypes?.[0] || "");
    return svc === "home_visit" ? "visit" : svc === "dog_walking" ? "walk" : "day";
  };

  /** Dates posées : le serveur a recalculé les candidatures → on les relit. */
  async function onDatesSaved(updated: RequestPost) {
    setCur(updated);
    setEditingDates(false);
    try {
      const all = await getMyApplications();
      const mine = all.filter((x) => String(x.postId || "") === String(updated.id || updated._id || cur.id || cur._id || ""));
      if (mine.length) {
        const next = items.map((x) => mine.find((m) => applicationId(m) === applicationId(x)) || x);
        setItems(next);
        onChanged?.(next);
      }
    } catch { /* la page se rechargera avec les totaux */ }
  }

  async function respond(a: ApplicationItem, action: "accept" | "reject", opts?: { confirmed?: boolean; andPay?: boolean }) {
    const id = applicationId(a);
    const { who } = applicationProvider(a);
    const name = who?.name || t("c1610_provider");
    const question = action === "accept" ? fill(t("c1610_choose_msg"), { name }) : fill(t("c1610_reject_msg"), { name });
    // 2710 — l'encart « Choisir <prénom> et payer » EST la confirmation (texte explicite au-dessus du bouton).
    const tag = action === "accept" ? (opts?.andPay ? "cand_choisir_payer" : "cand_choisir") : "cand_refuser";
    if (!opts?.confirmed && !window.confirm(question)) { trackSiteEvent("cta_click", { label: `${tag}_annule` }); return; }
    trackSiteEvent("cta_click", { label: tag });
    setBusyId(id);
    setErrors((e) => ({ ...e, [id]: "" }));
    try {
      const res = await respondToApplication(id, action);
      const next = items.map((x) => {
        const xid = applicationId(x);
        if (xid === id) return { ...x, ...res.application, booking: res.booking || x.booking || null };
        // Le serveur refuse automatiquement les autres candidats de la même demande.
        if (action === "accept" && x.status === "pending" && x.postId === a.postId) return { ...x, status: "rejected" };
        return x;
      });
      if (action === "reject") setRejectedNow((m) => ({ ...m, [id]: true }));
      else trackSiteEvent("cta_click", { label: "cand_choix_ok" });
      setItems(next);
      onChanged?.(next);
      // 2710 — choix confirmé depuis l'encart : on enchaîne tout de suite sur le paiement.
      if (action === "accept" && opts?.andPay) {
        const chosen = next.find((x) => applicationId(x) === id);
        if (chosen && linkedBooking(chosen)) { setBusyId(null); await pay(chosen); return; }
      }
    } catch (e) {
      const code = apiErrorCode(e);
      const d = e instanceof ApiError && e.details && typeof e.details === "object" ? (e.details as Record<string, unknown>) : {};
      let msg = e instanceof Error && e.message ? e.message : t("c1610_error");
      if (code === "CURRENCY_MISMATCH") {
        msg = fill(t("c1610_currency"), {
          a: String(d.providerCurrency || "?"),
          b: String(d.ownerCurrency || a.pricing?.currency || "EUR"),
        });
      } else if (code === "DATES_REQUIRED") {
        // 620 — le serveur refuse d'accepter tant que la demande est « à prévoir ».
        msg = d620(lang, "cand_choose_blocked");
        setEditingDates(true);
      } else if (code === "TOO_FAR") {
        msg = fill(t("c1610_too_far"), { km: String(d.limitKm || 200) });
      } else if (e instanceof ApiError && e.status === 409) {
        msg = t("c1610_already");
      } else if (e instanceof ApiError && e.status === 401) {
        router.replace("/login?redirect=/posts");
        return;
      }
      trackSiteEvent("cta_click", { label: `cand_erreur_${String(code || (e instanceof ApiError ? e.status : "x")).toLowerCase()}` });
      setErrors((er) => ({ ...er, [id]: msg }));
    } finally {
      setBusyId(null);
    }
  }

  /** 2610 — « Écrire à <prénom> » : ouvre (ou retrouve) la conversation avec ce prestataire. */
  async function write(a: ApplicationItem) {
    const id = applicationId(a);
    const { role, who } = applicationProvider(a);
    const providerId = String(who?.id || who?._id || "");
    if (!providerId) { setErrors((er) => ({ ...er, [id]: c2610(lang, "write_fail") })); return; }
    trackSiteEvent("cta_click", { label: "cand_ecrire" });
    setWritingId(id);
    setErrors((er) => ({ ...er, [id]: "" }));
    try {
      const conv = await startProviderConversation(role, providerId);
      router.push(conv ? `/chat?c=${encodeURIComponent(conv)}` : "/chat");
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) { router.replace("/login?redirect=/posts"); return; }
      setErrors((er) => ({ ...er, [id]: c2610(lang, "write_fail") }));
      setWritingId(null);
    }
  }

  async function pay(a: ApplicationItem) {
    const bk = linkedBooking(a);
    if (!bk) return;
    const id = applicationId(a);
    trackSiteEvent("cta_click", { label: "cand_payer" });
    setPayingId(id);
    setErrors((e) => ({ ...e, [id]: "" }));
    try {
      const intent = await createBookingPaymentIntent(bk.id);
      if (!intent.clientSecret || !intent.paymentIntentId) throw new Error(intent.savedCardError || t("c1610_pay_fail"));
      const currency = (intent.currency || a.pricing?.currency || "EUR").toUpperCase();
      // ⚠️ `intent.amount` est en CENTIMES (mesuré le 16/10 : 2400 pour 24 €) → on affiche le
      // prix total de la candidature (en euros), jamais le montant brut de l'intention.
      const amount = a.pricing?.totalPrice ?? 0;
      const qs = new URLSearchParams({
        intent: intent.paymentIntentId,
        secret: intent.clientSecret,
        currency,
        purpose: "booking",
        booking: bk.id,
        ...(amount > 0 ? { amount: String(amount) } : {}),
      });
      trackSiteEvent("cta_click", { label: "cand_page_carte" });
      router.push(`/pay?${qs.toString()}`);
    } catch (e) {
      trackSiteEvent("cta_click", { label: "cand_payer_echec" });
      setErrors((er) => ({ ...er, [id]: e instanceof Error ? e.message : t("c1610_pay_fail") }));
      setPayingId(null);
    }
  }

  // 2710 — encart « Choisir et payer » : candidature de l'e-mail, en attente, avec un total juste.
  // 2910 (SAM) — même règle pour l'encart et pour « Choisir » sur une carte : la fenêtre du navigateur
  // (sans prix) faisait renoncer (cand_choisir_annule 1, cand_choisir 0) ; une carte payable ouvre l'encart.
  function fastFor(a: ApplicationItem | undefined) {
    if (!a || tbd || a.status !== "pending" || a.pricing?.stale === true || a.pricing?.indicative === true) return null;
    const total = a.pricing?.totalPrice ?? null;
    const rate = a.pricing?.appliedRate ?? null;
    if (total == null || !(total > 0) || (rate != null && rate > 0 && total + 0.001 < rate)) return null;
    const currency = (a.pricing?.currency || cur.budgetCurrency || cur.currency || "EUR").toUpperCase();
    const { who } = applicationProvider(a);
    const name = who?.name || t("c1610_provider");
    return { app: a, id: applicationId(a), firstName: name.split(" ")[0] || name, price: money(total, currency, lang) };
  }
  const fast = (() => {
    const fid = pickId || (chooseNow ? focusId : null);
    return fid ? fastFor(visible.find((x) => applicationId(x) === fid)) : null;
  })();

  return (
    <section
      ref={sectionRef}
      className="mt-3 scroll-mt-24 rounded-2xl p-3 sm:p-4"
      style={{ background: "#FFF6F2", boxShadow: "inset 0 0 0 1px #F6D9CF", colorScheme: "light" }}
      aria-label={c2610(lang, "title")}
      data-candidates-1610={pending}
      data-candidates-2610=""
    >
      <h3 className="flex flex-wrap items-center gap-1.5 text-[16px] font-extrabold" style={{ color: "#9E1F0B" }}>
        <AppIcon name="people" size={17} color="#C92A12" />
        {c2610(lang, "title")}
        <span className="rounded-full bg-white px-2 text-[12px] font-bold" style={{ color: "#9E1F0B" }}>
          {visible.length}
        </span>
      </h3>
      <p className="mt-1 text-[13px] leading-snug" style={{ color: "#6E4F48" }}>{c2610(lang, "sub")}</p>
      {!tbd && !fast && pending > 0 && guarantees}

      {/* 2710 (SAM, ordre de Daniel « que les propriétaires valident et paient ») — arrivée par le bouton
          « Choisir <prénom> » de l'e-mail : le candidat, son prix total (serveur) et UN bouton qui confirme
          le choix puis ouvre le paiement. Rien si dates à prévoir, tarif à venir ou total absent. */}
      {fast && (
        <div className="mt-3 rounded-xl bg-white p-3" style={{ boxShadow: "inset 0 0 0 2px #C92A12" }} data-fast-2710="">
          <p className="text-[16px] font-extrabold leading-snug" style={{ color: "#231715" }}>{c2610(lang, "fast_title", { name: fast.firstName })}</p>
          <p className="mt-1 text-[13px] leading-snug" style={{ color: "#6E4F48" }}>{c2610(lang, "fast_sub", { name: fast.firstName })}</p>
          <div className="mt-2">
            <SignatureButton
              tone="owner"
              icon="wallet"
              label={c2610(lang, "fast_cta", { name: fast.firstName })}
              price={fast.price}
              loading={busyId === fast.id || payingId === fast.id}
              disabled={busyId !== null || payingId !== null}
              earns
              onClick={() => void respond(fast.app, "accept", { confirmed: true, andPay: true })}
            />
          </div>
          {guarantees}
          <p className="mt-1.5 text-center text-[11px] font-semibold" style={{ color: "#8A6B64" }}>{t("bookings_pay_secure")}</p>
          {errors[fast.id] && (
            <p className="mt-2 rounded-xl px-3 py-2 text-[12px] font-bold" style={{ background: "#FBE9E5", color: "#9E1F0B" }} role="alert">{errors[fast.id]}</p>
          )}
        </div>
      )}

      {/* 2610 — « dates à prévoir » : encart en tête, le bouton ouvre DIRECTEMENT le choix des dates. */}
      {tbd && (
        <div className="mt-3 rounded-xl p-3" style={{ background: "#FBE9E5", boxShadow: "inset 0 0 0 1.5px #C92A12" }} data-testid="tbd-banner-620" data-tbd-2610="">
          <p className="flex items-start gap-1.5 text-[14px] font-extrabold leading-snug" style={{ color: "#9E1F0B" }}>
            <AppIcon name="calendar" size={16} color="#9E1F0B" />
            <span>{c2610(lang, "tbd_title")}</span>
          </p>
          <p className="mt-1 text-[12px] leading-snug" style={{ color: "#6E4F48" }}>{c2610(lang, "tbd_sub")}</p>
          {!editingDates && (
            <div className="mt-2">
              <SignatureButton tone="owner" icon="calendar" label={c2610(lang, "tbd_cta")} onClick={() => setEditingDates(true)} />
            </div>
          )}
          {editingDates && (
            <PostDatesEditor620 post={cur} lang={lang} onSaved={(u) => void onDatesSaved(u)} onCancel={() => setEditingDates(false)} startLabel={t("posts_start_label")} endLabel={t("posts_end_label")} />
          )}
        </div>
      )}

      <ul className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
        {visible.map((a) => {
          const id = applicationId(a);
          const { role, who } = applicationProvider(a);
          const name = who?.name || t("c1610_provider");
          const firstName = name.split(" ")[0] || name;
          const tone = ROLE[role];
          const reviews = who?.reviewCount ?? who?.reviewsCount ?? who?.totalReviews ?? 0;
          const rating = typeof who?.rating === "number" && who.rating > 0 ? who.rating : 0;
          const city = who?.city || who?.location?.city || "";
          const pp = point(who?.location);
          const km = postPoint && pp ? Math.max(1, Math.round(haversineKm(postPoint, pp))) : null;
          const total = a.pricing?.totalPrice ?? null;
          const currency = (a.pricing?.currency || cur.budgetCurrency || cur.currency || "EUR").toUpperCase();
          // 620 — indicatif (dates à prévoir) : « 12 €/visite » au lieu d'un total.
          const indicative = a.pricing?.indicative === true || (tbd && !(total != null && total > 0));
          // 620b — « tarif à venir » : aucun montant, Choisir bloqué avec l'explication.
          const stale = a.pricing?.stale === true;
          // 2610 (ZOE, ordre de Daniel) — jamais un total incohérent à l'écran : un total absent,
          // nul ou INFÉRIEUR au tarif unitaire n'est affiché ni comme total ni comme tarif.
          const rawRate = a.pricing?.appliedRate ?? null;
          const incoherent = !stale && !indicative && (total == null || !(total > 0) || (rawRate != null && rawRate > 0 && total + 0.001 < rawRate));
          // 2610b (ZOE) — demande sans dates : le tarif unitaire FRAIS COMPRIS renvoyé par le serveur
          // (`ownerUnitRate`), sinon l'ancien tarif (serveur d'avant).
          const ownerUnit = a.pricing?.ownerUnitRate != null && a.pricing.ownerUnitRate > 0 ? a.pricing.ownerUnitRate : null;
          const unitRate = stale || incoherent ? null : (ownerUnit ?? a.pricing?.appliedRate ?? a.pricing?.basePrice ?? null);
          const rateLabel = indicative && unitRate != null && unitRate > 0 ? `${moneyCompact(unitRate, currency, lang)}/${unitShort620(lang, unitOf(a))}` : "";
          const priceLabel = !stale && !indicative && !incoherent && total != null && total > 0 ? money(total, currency, lang) : "";
          // Pas de tarif unitaire sous le total : le serveur renvoie un total frais compris et un tarif
          // hors frais (FLO, 26/10) — on affiche ce que le serveur renvoie comme total, sans mélanger.
          const unitLine = priceLabel && a.pricing?.weeklyApplied === true ? c2610(lang, "weekly") : "";
          const accepted = a.status === "accepted";
          const bk = accepted ? linkedBooking(a) : null;
          const isFocus = !!focusId && focusId === id;
          const err = errors[id];
          const meta = [
            rating > 0 ? `★ ${rating.toFixed(1)}${reviews > 0 ? ` (${reviews})` : ""}` : c2610(lang, "no_reviews"),
            city,
            km != null ? fill(t("c1610_km_about"), { km }) : "",
          ].filter(Boolean).join(" · ");

          return (
            <li
              key={id}
              ref={isFocus ? focusRef : undefined}
              id={`application-${id}`}
              className="flex min-w-0 flex-col rounded-2xl bg-white p-3"
              style={{ boxShadow: isFocus ? "0 0 0 2px #C92A12, 0 6px 16px -10px rgba(35,23,21,.35)" : "0 6px 16px -10px rgba(35,23,21,.35)" }}
              data-candidate-2610={role}
            >
              <div className="flex items-start gap-3">
                {who?.avatar && !brokenAvatars[id] ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={who.avatar}
                    alt=""
                    className="h-14 w-14 shrink-0 rounded-full object-cover"
                    style={{ boxShadow: `0 0 0 2.5px ${tone.dark}` }}
                    onError={() => setBrokenAvatars((m) => ({ ...m, [id]: true }))}
                  />
                ) : (
                  <span className="grid h-14 w-14 shrink-0 place-items-center rounded-full text-lg font-bold text-white" style={{ background: tone.dark }}>
                    {firstName.slice(0, 1).toUpperCase()}
                  </span>
                )}
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[16px] font-extrabold" style={{ color: "#231715" }}>{firstName}</p>
                  <div className="mt-0.5 flex flex-wrap items-center gap-1">
                    <span className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-bold" style={{ background: tone.pale, color: tone.dark }}>
                      <AppIcon name={role === "walker" ? "walker" : "home"} size={11} color={tone.dark} />
                      {t(role === "walker" ? "role_walker" : "role_sitter")}
                    </span>
                    {who?.identityVerified && (
                      <span className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-bold" style={{ background: "#DCEFE3", color: "#15803D" }}>
                        <AppIcon name="shield-check" size={11} color="#15803D" />
                        {t("trust_id_title")}
                      </span>
                    )}
                    {isFocus && a.status === "pending" && (
                      <span className="rounded-full px-2 py-0.5 text-[11px] font-bold text-white" style={{ background: "#C92A12" }}>{t("c1610_new")}</span>
                    )}
                  </div>
                  <p className="mt-1 text-[12px] leading-snug" style={{ color: "#6E4F48" }}>{meta}</p>
                </div>
              </div>

              {/* Prix : total juste, sinon tarif indicatif (dates à prévoir), sinon « tarif à venir » expliqué. */}
              {(priceLabel || rateLabel || stale) && <div className="mt-2 flex items-baseline justify-between gap-2 rounded-xl px-3 py-2" style={{ background: "#FFF6F2" }}>
                {priceLabel ? (
                  <>
                    <span className="text-[11px] font-bold uppercase tracking-wide" style={{ color: "#8A6B64" }}>{c2610(lang, "total")}</span>
                    <span className="text-right">
                      <span className="block text-[18px] font-extrabold leading-tight" style={{ color: "#9E1F0B" }} data-total-2610="">{priceLabel}</span>
                      {unitLine && <span className="block text-[11px] font-bold" style={{ color: "#15803D" }} data-weekly-2610="">{unitLine}</span>}
                    </span>
                  </>
                ) : rateLabel ? (
                  <>
                    <span className="text-[11px] font-bold uppercase tracking-wide" style={{ color: "#8A6B64" }}>{c2610(lang, "rate")}</span>
                    <span className="text-[18px] font-extrabold leading-tight" style={{ color: "#9E1F0B" }} data-rate-620={unitRate ?? ""}>{rateLabel}</span>
                  </>
                ) : (
                  <>
                    <span className="text-[11px] font-bold uppercase tracking-wide" style={{ color: "#8A6B64" }}>{c2610(lang, "rate")}</span>
                    <span className="text-[14px] font-extrabold leading-tight" style={{ color: "#9E1F0B" }} data-stale-620="">{c2610(lang, "stale_short")}</span>
                  </>
                )}
              </div>}
              {/* « Tarif à venir » toujours expliqué ; un total incohérent (ZOE) n'affiche rien du tout. */}
              {stale && a.status === "pending" && (
                <p className="mt-1.5 text-[11.5px] font-semibold leading-snug" style={{ color: "#9E1F0B" }} data-stale-hint-620="">
                  {d620(lang, "cand_stale_hint")}
                </p>
              )}

              {a.description && a.description.trim() && (
                <p className="mt-2 line-clamp-4 whitespace-pre-wrap text-[13px] leading-snug" style={{ color: "#231715" }}>« {a.description.trim()} »</p>
              )}

              <div className="mt-auto pt-3">
                {(a.status === "pending" || accepted) && (
                  <SignatureButton
                    tone={role === "walker" ? "walker" : "sitter"}
                    icon="chat"
                    label={writingId === id ? c2610(lang, "opening") : c2610(lang, "write", { name: firstName })}
                    loading={writingId === id}
                    disabled={writingId !== null && writingId !== id}
                    onClick={() => void write(a)}
                    ariaLabel={c2610(lang, "write", { name: firstName })}
                  />
                )}

                {a.status === "pending" && (
                  <div className="mt-2 flex items-center gap-2">
                    <div className="min-w-0 flex-1">
                      <SignatureButton
                        tone="owner"
                        kind="secondary"
                        icon="check"
                        label={t("c1610_choose")}
                        price={priceLabel || undefined}
                        loading={busyId === id}
                        disabled={(busyId !== null && busyId !== id) || stale}
                        disabledReason={stale ? d620(lang, "cand_stale_hint") : undefined}
                        onClick={() => { if (stale) return; if (tbd) { trackSiteEvent("cta_click", { label: "cand_dates" }); setPickId(id); setEditingDates(true); sectionRef.current?.scrollIntoView({ behavior: "smooth", block: "start" }); return; } if (fastFor(a)) { trackSiteEvent("cta_click", { label: "cand_encart" }); setPickId(id); sectionRef.current?.scrollIntoView({ behavior: "smooth", block: "start" }); return; } void respond(a, "accept"); }}
                        ariaLabel={`${t("c1610_choose")} ${firstName}`}
                      />
                    </div>
                    <button
                      type="button"
                      disabled={busyId !== null}
                      onClick={() => respond(a, "reject")}
                      className="min-h-[44px] shrink-0 rounded-full px-3 text-[13px] font-bold underline-offset-2 hover:underline disabled:opacity-60"
                      style={{ color: "#9E1F0B" }}
                      aria-label={`${t("c1610_reject")} ${firstName}`}
                    >
                      {t("c1610_reject")}
                    </button>
                  </div>
                )}
                {/* 2810 — plus de « Choisir sera possible une fois tes dates posées » : Choisir ouvre les dates. */}

                {accepted && bk && !bk.paid && (
                  <div className="mt-2 rounded-xl p-3" style={{ background: "#FBE9E5" }}>
                    <p className="flex items-center gap-1.5 text-[13px] font-bold" style={{ color: "#9E1F0B" }}>
                      <AppIcon name="check" size={15} color="#9E1F0B" />
                      {t("c1610_booked")}
                    </p>
                    <div className="mt-2">
                      <SignatureButton
                        tone="owner"
                        icon="wallet"
                        label={t("bookings_pay")}
                        price={priceLabel || undefined}
                        loading={payingId === id}
                        earns
                        onClick={() => pay(a)}
                      />
                    </div>
                    <p className="mt-1.5 text-center text-[11px] font-semibold" style={{ color: "#8A6B64" }}>{t("bookings_pay_secure")}</p>
                  </div>
                )}

                {a.status === "rejected" && (
                  <p className="mt-2 rounded-xl px-3 py-2 text-[13px] font-bold" style={{ background: "#FBE9E5", color: "#9E1F0B" }}>
                    {t("c1610_rejected")}
                  </p>
                )}

                {accepted && bk?.paid && (
                  <p className="mt-2 flex items-center gap-1.5 rounded-xl px-3 py-2 text-[13px] font-bold" style={{ background: "#DCEFE3", color: "#15803D" }}>
                    <AppIcon name="check" size={15} color="#15803D" />
                    {t("bookings_payment_received")}
                  </p>
                )}

                {err && (
                  <p className="mt-2 rounded-xl px-3 py-2 text-[12px] font-bold" style={{ background: "#FBE9E5", color: "#9E1F0B" }} role="alert">
                    {err}
                  </p>
                )}
              </div>
            </li>
          );
        })}
      </ul>
      {/* 26/10 (retour de FLO) : plus de bloc « tout se passe dans l'app / paiement dans l'app » ici —
          faux sur le web, où l'on paie juste au-dessus. */}
      <p className="mt-3 text-center text-[12px] font-semibold" style={{ color: "#6E4F48" }}>{t("c1610_then_pay")}</p>
    </section>
  );
}

export default PostCandidates1610;
