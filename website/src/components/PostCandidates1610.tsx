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
import { AppBridge620 } from "@/components/AppBridge620";
import { PostDatesEditor620 } from "@/components/PostDatesEditor620";
import { d620, unitShort620 } from "@/lib/i18n/dates620";
import { dateModeOf620 } from "@/lib/services620";
import {
  ApiError,
  type ApplicationItem,
  type Booking,
  type RequestPost,
  apiErrorCode,
  applicationId,
  applicationProvider,
  createBookingPaymentIntent,
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
  onChanged,
}: {
  post: RequestPost;
  applications: ApplicationItem[];
  /** Candidature à mettre en avant (lien de l'e-mail « candidature reçue »). */
  focusId?: string;
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
  const focusRef = useRef<HTMLLIElement | null>(null);
  // 620 — la demande telle qu'elle est (ses dates peuvent être posées ici même).
  const [cur, setCur] = useState<RequestPost>(post);
  const [editingDates, setEditingDates] = useState(false);
  useEffect(() => setCur(post), [post]);

  useEffect(() => setItems(applications), [applications]);
  useEffect(() => {
    if (focusId && focusRef.current) {
      focusRef.current.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  }, [focusId, items.length]);

  // Un candidat refusé À L'INSTANT reste affiché (« Candidature refusée ») : retour visible
  // au clic ; au prochain chargement il disparaît, comme dans l'app.
  const visible = items.filter((a) => a.status === "pending" || a.status === "accepted" || rejectedNow[applicationId(a)]);
  if (visible.length === 0) return null;

  const postPoint = point(cur.location);
  const pending = visible.filter((a) => a.status === "pending").length;
  // 620 — « dates à prévoir » : tarif unitaire seul, Choisir bloqué jusqu'aux dates.
  const tbd = dateModeOf620(cur) === "tbd";
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

  async function respond(a: ApplicationItem, action: "accept" | "reject") {
    const id = applicationId(a);
    const { who } = applicationProvider(a);
    const name = who?.name || t("c1610_provider");
    const question = action === "accept" ? fill(t("c1610_choose_msg"), { name }) : fill(t("c1610_reject_msg"), { name });
    if (!window.confirm(question)) return;
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
      setItems(next);
      onChanged?.(next);
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
      setErrors((er) => ({ ...er, [id]: msg }));
    } finally {
      setBusyId(null);
    }
  }

  async function pay(a: ApplicationItem) {
    const bk = linkedBooking(a);
    if (!bk) return;
    const id = applicationId(a);
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
      router.push(`/pay?${qs.toString()}`);
    } catch (e) {
      setErrors((er) => ({ ...er, [id]: e instanceof Error ? e.message : t("c1610_pay_fail") }));
      setPayingId(null);
    }
  }

  return (
    <section
      className="mt-3 rounded-2xl p-3"
      style={{ background: "#FFF6F2", boxShadow: "inset 0 0 0 1px #F6D9CF" }}
      aria-label={t("c1610_title")}
      data-candidates-1610={pending}
    >
      <h3 className="flex items-center gap-1.5 text-[13px] font-bold" style={{ color: "#9E1F0B" }}>
        <AppIcon name="people" size={15} color="#C92A12" />
        {t("c1610_title")}
        <span className="rounded-full bg-white px-1.5 text-[11px]" style={{ color: "#9E1F0B" }}>
          {visible.length}
        </span>
        <span className="ml-auto text-[11px] font-semibold" style={{ color: "#6E4F48" }}>
          {t("c1610_then_pay")}
        </span>
      </h3>

      {/* 620 — « Pose tes dates pour valider » + éditeur de dates (PATCH /posts/:id). */}
      {tbd && (
        <div className="mt-2 rounded-xl p-3" style={{ background: "#FBE9E5" }} data-testid="tbd-banner-620">
          <p className="flex items-center gap-1.5 text-[13px] font-bold" style={{ color: "#9E1F0B" }}>
            <AppIcon name="calendar" size={15} color="#9E1F0B" />
            {d620(lang, "cand_banner")}
          </p>
          <p className="mt-0.5 text-[12px] leading-snug" style={{ color: "#6E4F48" }}>{d620(lang, "cand_banner_sub")}</p>
          {!editingDates && (
            <div className="mt-2">
              <SignatureButton tone="owner" icon="calendar" label={d620(lang, "cand_set_dates")} onClick={() => setEditingDates(true)} />
            </div>
          )}
        </div>
      )}
      {tbd && editingDates && (
        <PostDatesEditor620 post={cur} lang={lang} onSaved={(u) => void onDatesSaved(u)} onCancel={() => setEditingDates(false)} startLabel={t("posts_start_label")} endLabel={t("posts_end_label")} />
      )}

      <ul className="mt-2 space-y-2">
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
          const unitRate = a.pricing?.appliedRate ?? a.pricing?.basePrice ?? null;
          // Tarif unitaire compact (« 12 €/visite », jamais « 12,00 € ») ; les centimes restent s'il y en a.
          const rateLabel = indicative && unitRate != null && unitRate > 0 ? `${moneyCompact(unitRate, currency, lang)}/${unitShort620(lang, unitOf(a))}` : "";
          const priceLabel = !indicative && total != null && total > 0 ? money(total, currency, lang) : "";
          const accepted = a.status === "accepted";
          const bk = accepted ? linkedBooking(a) : null;
          const isFocus = !!focusId && focusId === id;
          const applied = a.createdAt ? new Date(a.createdAt).toLocaleDateString(lang, { day: "numeric", month: "short" }) : "";
          const err = errors[id];

          return (
            <li
              key={id}
              ref={isFocus ? focusRef : undefined}
              id={`application-${id}`}
              className="rounded-xl bg-white p-3"
              style={isFocus ? { boxShadow: "0 0 0 2px #C92A12" } : undefined}
            >
              <div className="flex items-start gap-3">
                {who?.avatar && !brokenAvatars[id] ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={who.avatar}
                    alt=""
                    className="h-11 w-11 shrink-0 rounded-full object-cover"
                    style={{ boxShadow: `0 0 0 2px ${tone.dark}` }}
                    onError={() => setBrokenAvatars((m) => ({ ...m, [id]: true }))}
                  />
                ) : (
                  <span className="grid h-11 w-11 shrink-0 place-items-center rounded-full text-base font-bold text-white" style={{ background: tone.dark }}>
                    {firstName.slice(0, 1).toUpperCase()}
                  </span>
                )}
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-1.5">
                    <p className="text-[15px] font-bold" style={{ color: "#231715" }}>{firstName}</p>
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
                  <p className="mt-0.5 text-[12px] leading-snug" style={{ color: "#6E4F48" }}>
                    {[
                      rating > 0 ? `★ ${rating.toFixed(1)}${reviews > 0 ? ` (${reviews})` : ""}` : t("c1610_no_reviews"),
                      city,
                      km != null ? fill(t("c1610_km_about"), { km }) : "",
                      applied ? fill(t("c1610_applied_on"), { date: applied }) : "",
                    ]
                      .filter(Boolean)
                      .join(" · ")}
                  </p>
                  {a.description && a.description.trim() && (
                    <p className="mt-1 whitespace-pre-wrap text-[13px]" style={{ color: "#231715" }}>{a.description.trim()}</p>
                  )}
                </div>
                {priceLabel && (
                  <div className="shrink-0 text-right">
                    <p className="text-[10px] font-bold uppercase tracking-wide" style={{ color: "#8A6B64" }}>{t("c1610_total")}</p>
                    <p className="text-[17px] font-extrabold leading-tight" style={{ color: "#9E1F0B" }}>{priceLabel}</p>
                  </div>
                )}
                {!priceLabel && rateLabel && (
                  <div className="shrink-0 text-right" data-rate-620={unitRate ?? ""}>
                    <p className="text-[10px] font-bold uppercase tracking-wide" style={{ color: "#8A6B64" }}>{d620(lang, "cand_rate_label")}</p>
                    <p className="text-[17px] font-extrabold leading-tight" style={{ color: "#9E1F0B" }}>{rateLabel}</p>
                  </div>
                )}
              </div>

              {a.status === "pending" && (
                <div className="mt-3 flex flex-col gap-2 sm:flex-row sm:items-center">
                  <div className="sm:flex-1">
                    <SignatureButton
                      tone="owner"
                      icon="check"
                      label={t("c1610_choose")}
                      price={priceLabel || rateLabel || undefined}
                      loading={busyId === id}
                      disabled={(busyId !== null && busyId !== id) || tbd}
                      disabledReason={tbd ? d620(lang, "cand_choose_blocked") : undefined}
                      onClick={() => { if (tbd) { setEditingDates(true); return; } void respond(a, "accept"); }}
                      ariaLabel={`${t("c1610_choose")} ${firstName}`}
                    />
                    {tbd && <p className="mt-1 text-center text-[11px] font-semibold" style={{ color: "#8A6B64" }} data-choose-blocked-620="">{d620(lang, "cand_choose_blocked")}</p>}
                  </div>
                  <div className="sm:w-[150px]">
                    <SignatureButton
                      tone="danger"
                      kind="secondary"
                      label={t("c1610_reject")}
                      disabled={busyId !== null}
                      onClick={() => respond(a, "reject")}
                      ariaLabel={`${t("c1610_reject")} ${firstName}`}
                    />
                  </div>
                </div>
              )}

              {accepted && bk && !bk.paid && (
                <div className="mt-3 rounded-xl p-3" style={{ background: "#FBE9E5" }}>
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
                <p className="mt-3 rounded-xl px-3 py-2 text-[13px] font-bold" style={{ background: "#FBE9E5", color: "#9E1F0B" }}>
                  {t("c1610_rejected")}
                </p>
              )}

              {accepted && bk?.paid && (
                <p className="mt-3 flex items-center gap-1.5 rounded-xl px-3 py-2 text-[13px] font-bold" style={{ background: "#DCEFE3", color: "#15803D" }}>
                  <AppIcon name="check" size={15} color="#15803D" />
                  {t("bookings_payment_received")}
                </p>
              )}

              {err && (
                <p className="mt-2 rounded-xl px-3 py-2 text-[12px] font-bold" style={{ background: "#FBE9E5", color: "#9E1F0B" }} role="alert">
                  {err}
                </p>
              )}
            </li>
          );
        })}
      </ul>
      {/* 620 (§B.5) — le site ramène dans l'app. */}
      <div className="mt-3">
        <AppBridge620 lang={lang} loggedIn compact />
      </div>
    </section>
  );
}

export default PostCandidates1610;
