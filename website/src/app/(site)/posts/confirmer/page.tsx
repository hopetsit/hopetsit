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
// 1011 (ZOE, ordre de Daniel « les pages ne sont pas à jour dans les autres langues ») — textes en 9 langues.
import { useT } from "@/lib/i18n/LanguageProvider";
import { g1011 } from "@/lib/i18n/langues1011";
import type { Lang } from "@/lib/i18n/langs";

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

/** 1011 (ZOE) — mêmes champs qu'avant, lus dans la table en 9 langues (le français est inchangé). */
function txt1011(lang: Lang) {
  const g = (k: string, v?: Record<string, string | number>) => g1011(lang, k, v);
  return {
    hello: (p: string) => (p ? g("conf_hello_name", { p }) : g("conf_hello")),
    intro: g("conf_intro"),
    where: g("conf_where"),
    atOwner: g("conf_at_owner"), atOwnerSub: g("conf_at_owner_sub"),
    atSitter: g("conf_at_sitter"), atSitterSub: g("conf_at_sitter_sub"),
    cta: g("conf_cta"),
    busy: g("conf_busy"),
    terms: g("conf_terms"),
    termsLink: g("conf_terms_link"),
    termsAfter: g("conf_terms_after"),
    noAccount: g("conf_no_account"),
    done: g("conf_done"),
    already: g("conf_already"),
    alreadySub: g("conf_already_sub"),
    doneSub: (n?: number) => (n && n > 0
      ? g(n > 1 ? "conf_done_sub_many" : "conf_done_sub_one", { n })
      : g("conf_done_sub_none")),
    see: g("conf_see"),
    app: g("conf_app"),
    appSub: g("conf_app_sub"),
    pwd: g("conf_pwd"),
    gone: g("conf_gone"),
    goneSub: g("conf_gone_sub"),
    goneCta: g("conf_gone_cta"),
    err: g("conf_err"),
    summary: (service: string, animal: string) =>
      g("conf_summary", { svc: g(`conf_svc_${service}`), ani: g(`conf_ani_${animal}`) }),
    when: (quand: string) => (quand === "bientot" || quand === "fetes" ? g(`conf_when_${quand}`) : ""),
    datesTitle: g("conf_dates_title"), from: g("conf_from"), to: g("conf_to"),
  };
}

export default function ConfirmLeadPage() {
  const { lang: siteLang } = useT();
  const langRef = useRef<Lang>("fr");
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
      .catch(() => { setOpening(false); setErr(g1011(langRef.current, "conf_err")); });
  }, [lead, next, id]);

  // 1011 (ZOE) — langue affichée : celle du site quand le visiteur lit une autre langue que le français
  // ou l'anglais ; sinon celle du contact de la pub (fr/en), comme avant.
  const lang: Lang = siteLang !== "fr" && siteLang !== "en" ? siteLang : (lead?.lang === "en" ? "en" : "fr");
  langRef.current = lang;
  const t = txt1011(lang);
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
            {t.summary(lead.service, lead.animal)}
          </p>
          <p className="mt-1 text-sm text-[#6E4F48]">📍 {lead.city}{t.when(lead.quand) ? ` · 🗓 ${t.when(lead.quand)}` : ""}</p>
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
          {t.terms} <Link href="/terms" className="font-semibold text-owner-dark underline">{t.termsLink}</Link>{t.termsAfter}
        </p>
      </div>
    </main>
  );
}
