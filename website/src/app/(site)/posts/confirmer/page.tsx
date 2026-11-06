"use client";

// 22/10/2026 (SAM, accord de Daniel « bouton 1 clic ») — arrivée depuis
// l'e-mail envoyé aux contacts de la pub à formulaire Meta (?l=<jeton>).
// La pub promet « sans créer de compte, les gardiens vous répondent » ; mesure
// des 48 h précédentes : 11 contacts → 0 compte → 0 demande, à cause du mot de
// passe et du code exigés par /posts/create. Ici : on montre la demande déjà
// décrite dans la pub, UN bouton la publie (compte créé et vérifié par le
// serveur, session ouverte). /posts est en noindex (middleware).

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { confirmAdLead, getAdLead, updatePostDates620, type AdLeadSummary } from "@/lib/api";
// 06/11/2026 (NEO, ordre de Daniel « dates obligatoires ») — un contact de la pub qui arrive SANS dates
// (anciens formulaires Meta) pose ses dates ICI, avant de publier, au lieu de publier « à prévoir »
// (mesure de FLO : 19 demandes sur 45 avec candidats sans dates → jamais de bouton « Payer », 0 paiement).
// Après « Publier » : même route serveur que l'éditeur de dates de la page des candidats
// (PATCH /posts/:id, updatePostDates620) avec la session ouverte par la confirmation. Balade : date + heure.
import { dr, walkEndIso0611, walkStartIso0611 } from "@/lib/i18n/datesRequired0611";
import { c2610 } from "@/lib/i18n/cand2610";
import { f2 } from "@/lib/i18n/formulaire2etapes1110";
import { d620 } from "@/lib/i18n/dates620";

/** Dates proposées d'après le choix « quand » de la pub (même règle que le serveur, utils/adLeadDates2310). */
function datesFromQuand0611(quand: string): { start: string; end: string } {
  const day = (ms: number) => new Date(ms).toISOString().slice(0, 10);
  const now = Date.now();
  if (quand === "bientot") return { start: day(now + 7 * 86400000), end: day(now + 14 * 86400000) };
  if (quand === "fetes") {
    let y = new Date().getUTCFullYear();
    if (Date.UTC(y, 11, 20) < now) y += 1;
    return { start: `${y}-12-20`, end: `${y + 1}-01-03` };
  }
  return { start: "", end: "" };
}

const TXT = {
  fr: {
    hello: (p: string) => (p ? `Bonjour ${p} !` : "Bonjour !"),
    intro: "Voici la demande que tu as laissée. Publie-la et les gardiens près de chez toi sont prévenus tout de suite.",
    where: "Où se passe la garde ?",
    atOwner: "Chez moi", atOwnerSub: "Le gardien vient chez toi",
    atSitter: "Chez le gardien", atSitterSub: "Tu déposes ton animal chez lui",
    cta: "Publier ma demande — gratuit",
    busy: "Publication…",
    terms: "En publiant, tu acceptes les",
    termsLink: "conditions d'utilisation",
    noAccount: "Pas de mot de passe à créer : ton compte est ouvert avec ton e-mail.",
    done: "C'est publié !",
    already: "Ta demande est en ligne !",
    alreadySub: "Les gardiens et promeneurs près de chez toi ont été prévenus. Tu reçois les candidats avec leur prix par e-mail — tu choisis, tu paies, annulation gratuite jusqu'à 72 h avant.",
    doneSub: (n?: number) => (n && n > 0
      ? `${n} gardien${n > 1 ? "s" : ""} et promeneur${n > 1 ? "s" : ""} près de chez toi ${n > 1 ? "sont prévenus" : "est prévenu"}. Tu reçois les candidats avec leur prix par e-mail — tu choisis, tu paies, annulation gratuite jusqu'à 72 h avant.`
      : "Les gardiens et promeneurs près de chez toi sont prévenus. Tu reçois les candidats avec leur prix par e-mail — tu choisis, tu paies, annulation gratuite jusqu'à 72 h avant."),
    see: "Voir ma demande",
    app: "Télécharger l'app HoPetSit",
    appSub: "Réponses en direct et suivi de la garde dans l'app. Tu peux aussi tout faire ici, sur le site.",
    pwd: "Pour te reconnecter plus tard : « Mot de passe oublié » avec ton e-mail.",
    gone: "Ce lien n'est plus valable.",
    goneSub: "Tu peux publier ta demande en 1 minute ici :",
    goneCta: "Publier ma demande",
    err: "La publication n'a pas abouti. Réessayez dans un instant.",
    svc: { garde: "Garde", promenade: "Promenades", visites: "Visites à domicile" },
    ani: { chien: "ton chien", chat: "ton chat", autre: "ton animal" },
    when: { bientot: "dans les 15 jours", fetes: "pendant les fêtes", plus_tard: "" },
    for: "pour", in: "à",
    datesTitle: "Tes dates", from: "Du", to: "Au",
  },
  en: {
    hello: (p: string) => (p ? `Hi ${p}!` : "Hi!"),
    intro: "Here is the request you left. Publish it and sitters near you are notified right away.",
    where: "Where should the sitting happen?",
    atOwner: "At my place", atOwnerSub: "The sitter comes to your home",
    atSitter: "At the sitter's", atSitterSub: "You drop your pet off at theirs",
    cta: "Publish my request — free",
    busy: "Publishing…",
    terms: "By publishing, you accept the",
    termsLink: "terms of use",
    noAccount: "No password to create: your account opens with your email.",
    done: "It's live!",
    already: "Your request is live!",
    alreadySub: "Sitters and dog walkers near you have been notified. Their replies arrive by email and in the app.",
    doneSub: (n?: number) => (n && n > 0
      ? `${n} sitter${n > 1 ? "s and dog walkers" : " or dog walker"} near you ${n > 1 ? "were" : "was"} notified. You'll get their replies by email and in the app.`
      : "Sitters and dog walkers near you are notified. You'll get their replies by email and in the app."),
    see: "See my request",
    app: "Get the HoPetSit app",
    appSub: "Live replies and sitting tracking in the app. You can also do everything here, on the site.",
    pwd: "To sign in later: “Forgot password” with your email.",
    gone: "This link is no longer valid.",
    goneSub: "You can publish your request in 1 minute here:",
    goneCta: "Publish my request",
    err: "Publishing didn't go through. Please try again in a moment.",
    svc: { garde: "Pet sitting", promenade: "Dog walks", visites: "Drop-in visits" },
    ani: { chien: "your dog", chat: "your cat", autre: "your pet" },
    when: { bientot: "within 2 weeks", fetes: "over the holidays", plus_tard: "" },
    for: "for", in: "in",
    datesTitle: "Your dates", from: "From", to: "To",
  },
} as const;

export default function ConfirmLeadPage() {
  const [id, setId] = useState("");
  const [lead, setLead] = useState<AdLeadSummary | null>(null);
  const [gone, setGone] = useState(false);
  const [lieu, setLieu] = useState<"at_owner" | "at_sitter" | "">("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [done, setDone] = useState<{ postId: string | null; notified?: number } | null>(null);
  // 23/10 (BOB, accord de Daniel) — `next` : cible interne (ex. /application/<id>) demandée par
  // le bouton d'un e-mail (candidature, réservation, message). Si la demande est déjà en ligne,
  // on ouvre la session sans mot de passe et on y va tout seul, sans clic.
  const [next, setNext] = useState("");
  const [opening, setOpening] = useState(false);
  // 0611 (NEO) — dates OBLIGATOIRES avant de publier (pré-remplies si la pub les connaît, sinon vides).
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [walkTime, setWalkTime] = useState("10:00");
  const [datesWarn, setDatesWarn] = useState("");
  const seen = useRef(false);
  const auto = useRef(false);

  useEffect(() => {
    let l = "";
    let n = "";
    try {
      const q = new URLSearchParams(window.location.search);
      l = (q.get("l") || "").trim();
      n = (q.get("next") || "").trim();
    } catch { /* URL exotique */ }
    setId(l);
    // chemin interne seulement : commence par un seul « / », jamais « // » ni « http »
    if (/^\/(?!\/)[^\s]*$/.test(n)) setNext(n);
    if (!/^[a-f0-9]{32}$/.test(l)) { setGone(true); return; }
    getAdLead(l)
      .then((d) => {
        setLead(d);
        // 0611 — le serveur peut renvoyer startDate/endDate (AAAA-MM-JJ) quand la pub les a ; sinon on propose
        // les dates déduites du choix « quand » (même règle que le serveur), et rien pour « plus tard ».
        const ext = d as AdLeadSummary & { startDate?: string; endDate?: string };
        const pre = /^\d{4}-\d{2}-\d{2}/.test(String(ext.startDate || "")) ? { start: String(ext.startDate).slice(0, 10), end: String(ext.endDate || ext.startDate).slice(0, 10) } : datesFromQuand0611(d.quand);
        setStartDate(pre.start);
        setEndDate(pre.end);
        if (!seen.current) { seen.current = true; trackSiteEvent("cta_click", { label: "lead_vu" }); }
      })
      .catch(() => setGone(true));
  }, []);

  useEffect(() => {
    if (!lead || !lead.confirmed || !next || auto.current) return;
    auto.current = true;
    setOpening(true);
    confirmAdLead(id)
      .then(() => { trackSiteEvent("cta_click", { label: "lead_next" }); window.location.href = next; })
      .catch(() => { setOpening(false); setErr(TXT[lead.lang === "en" ? "en" : "fr"].err); });
  }, [lead, next, id]);

  const t = TXT[lead?.lang === "en" ? "en" : "fr"];
  const lang = lead?.lang === "en" ? "en" : "fr";
  const needsLieu = lead?.service === "garde";
  const isWalk = lead?.service === "promenade";
  const today = new Date().toISOString().slice(0, 10);

  async function onConfirm() {
    if (!lead || busy) return;
    // 0611 — dates obligatoires : balade = date + heure ; sinon début et fin, début ≤ fin.
    if (isWalk ? !(startDate && /^\d{2}:\d{2}$/.test(walkTime)) : !(startDate && endDate)) {
      trackSiteEvent("cta_click", { label: "lead_sans_dates" });
      setErr(isWalk ? dr(lang, "walk_required") : f2(lang, "dates_required")); return;
    }
    if (!isWalk && endDate < startDate) { setErr(d620(lang, "dates_order")); return; }
    if (needsLieu && !lieu) { setErr(t.where); return; }
    setBusy(true);
    setErr("");
    try {
      const r = await confirmAdLead(id, needsLieu ? (lieu || undefined) : undefined);
      trackSiteEvent("cta_click", { label: "lead_confirme" });
      // 0611 — les dates posées ici partent par la même route que l'éditeur de la page des candidats
      // (PATCH /posts/:id), avec la session que la confirmation vient d'ouvrir. Jamais bloquant.
      if (r.postId) {
        const sIso = isWalk ? walkStartIso0611(startDate, walkTime) : new Date(startDate).toISOString();
        const eIso = isWalk ? walkEndIso0611(sIso) : new Date(endDate).toISOString();
        try {
          await updatePostDates620(r.postId, { dateMode: "exact", startDate: sIso, endDate: eIso });
          trackSiteEvent("cta_click", { label: "lead_dates_posees" });
        } catch {
          setDatesWarn(dr(lang, "dates_fail"));
          trackSiteEvent("cta_click", { label: "lead_dates_echec" });
        }
      }
      setDone({ postId: r.postId, notified: r.notified });
      try { window.scrollTo({ top: 0, behavior: "smooth" }); } catch { /* ignore */ }
    } catch {
      setErr(t.err);
    } finally {
      setBusy(false);
    }
  }

  // 23/10 : /post/<id> exige une session. Depuis l'e-mail « votre demande est en ligne », le
  // contact n'en a pas : ce bouton rejoue confirmAdLead (idempotent : même demande, session
  // ouverte avec son e-mail) puis ouvre la demande. Pas de mot de passe à saisir.
  async function onSeePost(postId: string | null) {
    if (busy) return;
    setBusy(true);
    setErr("");
    try {
      const r = await confirmAdLead(id);
      const target = r.postId || postId;
      window.location.href = next || (target ? `/post/${target}` : "/posts");
    } catch {
      setErr(t.err);
      setBusy(false);
    }
  }

  const card = "mx-auto w-full max-w-md rounded-[24px] bg-white p-5 shadow-sm sm:p-7";
  const bigBtn = "flex min-h-[52px] w-full items-center justify-center rounded-full bg-owner px-6 text-base font-bold text-white transition hover:bg-owner-dark disabled:opacity-60";

  if (gone) {
    return (
      <main className="min-h-[70vh] bg-[#FFF7F4] px-4 py-10">
        <div className={card}>
          <h1 className="font-display text-2xl font-extrabold text-ink">{t.gone}</h1>
          <p className="mt-2 text-[#6E4F48]">{t.goneSub}</p>
          <Link href="/posts/create" className={`${bigBtn} mt-5`}>{t.goneCta}</Link>
        </div>
      </main>
    );
  }

  if (!lead || opening) {
    return <main className="min-h-[70vh] bg-[#FFF7F4] px-4 py-10"><div className={`${card} h-64 animate-pulse`} /></main>;
  }

  if (done || lead.confirmed) {
    // 23/10 (SAM, consigne de Daniel) : le suivi publie la demande dès le formulaire rempli ;
    // le lien de l'e-mail arrive donc le plus souvent sur une demande déjà en ligne.
    const postId = done?.postId || lead.postId || null;
    return (
      <main className="min-h-[70vh] bg-[#FFF7F4] px-4 py-10">
        <div className={`${card} text-center`}>
          <div className="text-5xl" aria-hidden>🐾</div>
          <h1 className="mt-2 font-display text-3xl font-extrabold text-ink">{done ? t.done : t.already}</h1>
          <p className="mt-3 text-[#6E4F48]">{done ? t.doneSub(done.notified) : t.alreadySub}</p>
          {postId && (
            <button type="button" onClick={() => onSeePost(postId)} disabled={busy} className={`${bigBtn} mt-6`}>
              {busy ? t.busy : t.see}
            </button>
          )}
          {err && <p role="alert" className="mt-3 text-sm font-semibold text-owner-dark">{err}</p>}
          {datesWarn && <p role="alert" data-testid="dates-warn-0611" className="mt-3 rounded-xl bg-owner-light px-3 py-2 text-sm font-semibold text-owner-dark">{datesWarn}</p>}
          {/* 23/10 (BOB, demande de Daniel) — l'app mise en avant : c'est là que l'on répond, suit et paie. */}
          <Link href="/download?utm_source=email&utm_medium=lead&utm_campaign=app" className="mt-3 flex min-h-[48px] w-full items-center justify-center rounded-full border-2 border-owner bg-white px-6 text-base font-bold text-owner-dark transition hover:bg-owner-light">
            📲 {t.app}
          </Link>
          <p className="mt-2 text-xs text-[#6E4F48]">{t.appSub}</p>
          <p className="mt-4 text-xs text-[#6E4F48]">{t.pwd}</p>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-[70vh] bg-[#FFF7F4] px-4 py-8">
      <div className={card}>
        <h1 className="font-display text-3xl font-extrabold leading-tight text-ink">{t.hello(lead.firstName)}</h1>
        <p className="mt-2 text-[#6E4F48]">{t.intro}</p>

        <div className="mt-5 rounded-2xl border border-owner/30 bg-owner-light p-4">
          <p className="text-lg font-bold text-ink">
            {t.svc[lead.service]} {t.for} {t.ani[lead.animal]}
          </p>
          <p className="mt-1 text-sm text-[#6E4F48]">📍 {lead.city}{t.when[lead.quand] ? ` · 🗓 ${t.when[lead.quand]}` : ""}</p>
        </div>

        {/* 0611 (NEO, ordre de Daniel) — les dates, obligatoires, AVANT de publier. */}
        <fieldset className="mt-5" data-testid="lead-dates-0611">
          <legend className="mb-2 text-sm font-semibold text-ink">🗓 {t.datesTitle}</legend>
          {isWalk ? (
            <div className="grid grid-cols-2 gap-2">
              <label className="block text-xs font-semibold text-ink">{c2610(lang, "date_label")} *
                <input type="date" required min={today} value={startDate} onChange={(e) => { setStartDate(e.target.value); setEndDate(e.target.value); setErr(""); }} data-testid="lead-start-0611"
                  className="mt-1 w-full rounded-xl border border-[#EADBD6] bg-[#FFF9F6] px-3 py-2.5 text-[15px] text-ink focus:border-owner focus:outline-none" />
              </label>
              <label className="block text-xs font-semibold text-ink">{c2610(lang, "time_label")} *
                <input type="time" required step={900} value={walkTime} onChange={(e) => { setWalkTime(e.target.value); setErr(""); }} data-testid="lead-time-0611"
                  className="mt-1 w-full rounded-xl border border-[#EADBD6] bg-[#FFF9F6] px-3 py-2.5 text-[15px] text-ink focus:border-owner focus:outline-none" />
              </label>
            </div>
          ) : (
            <div className="grid grid-cols-2 gap-2">
              <label className="block text-xs font-semibold text-ink">{t.from} *
                <input type="date" required min={today} value={startDate} onChange={(e) => { const v = e.target.value; setStartDate(v); if (v && (!endDate || endDate < v)) setEndDate(v); setErr(""); }} data-testid="lead-start-0611"
                  className="mt-1 w-full rounded-xl border border-[#EADBD6] bg-[#FFF9F6] px-3 py-2.5 text-[15px] text-ink focus:border-owner focus:outline-none" />
              </label>
              <label className="block text-xs font-semibold text-ink">{t.to} *
                <input type="date" required min={startDate || today} value={endDate} onChange={(e) => { setEndDate(e.target.value); setErr(""); }} data-testid="lead-end-0611"
                  className="mt-1 w-full rounded-xl border border-[#EADBD6] bg-[#FFF9F6] px-3 py-2.5 text-[15px] text-ink focus:border-owner focus:outline-none" />
              </label>
            </div>
          )}
          <p className="mt-1.5 text-xs leading-snug text-[#6E4F48]" data-testid="lead-dates-hint-0611">{dr(lang, "hint")}</p>
        </fieldset>

        {needsLieu && (
          <fieldset className="mt-5">
            <legend className="mb-2 text-sm font-semibold text-ink">{t.where}</legend>
            <div className="grid gap-2">
              {([["at_owner", t.atOwner, t.atOwnerSub, "🏠"], ["at_sitter", t.atSitter, t.atSitterSub, "🐾"]] as const).map(([v, label, sub, icon]) => (
                <button
                  key={v}
                  type="button"
                  aria-pressed={lieu === v}
                  onClick={() => { setLieu(v); setErr(""); }}
                  className={`flex min-h-[56px] items-center gap-3 rounded-2xl border-2 px-4 py-2 text-left transition ${lieu === v ? "border-owner bg-owner-light" : "border-[#EADBD6] bg-white"}`}
                >
                  <span className="text-xl" aria-hidden>{icon}</span>
                  <span>
                    <span className="block font-bold text-ink">{label}</span>
                    <span className="block text-xs text-[#6E4F48]">{sub}</span>
                  </span>
                </button>
              ))}
            </div>
          </fieldset>
        )}

        <button type="button" onClick={onConfirm} disabled={busy} className={`${bigBtn} mt-6`}>
          {busy ? t.busy : t.cta}
        </button>
        {err && <p role="alert" className="mt-3 text-center text-sm font-semibold text-owner-dark">{err}</p>}
        <p className="mt-4 text-center text-xs text-[#6E4F48]">{t.noAccount}</p>
        <p className="mt-1 text-center text-xs text-[#6E4F48]">
          {t.terms} <Link href="/terms" className="font-semibold text-owner-dark underline">{t.termsLink}</Link>.
        </p>
      </div>
    </main>
  );
}
