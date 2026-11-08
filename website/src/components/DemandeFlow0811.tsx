"use client";

import { useEffect, useRef, useState } from "react";
import Link from "@/components/SiteLink";
import StoreBadges from "@/components/StoreBadges";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { ParisHeroForm, type HeroLeadResult0811 } from "@/components/ParisHeroForm";
import { ApiError, checkDemandeCode0811, sendDemandeCode0811 } from "@/lib/api";
import { dm } from "@/lib/i18n/demande0811";

// 08/11/2026 (NEO, ordre de Daniel 16 h 45 transmis par BOB) — PAGE DE DEMANDE DE LA PUB META (site, plus le
// formulaire Meta) : le propriétaire publie ET vérifie son e-mail D'UN COUP, sans aller cliquer dans sa boîte plus tard.
//   1. le formulaire en 1 étape du 31/10 (ParisHeroForm : service, dates obligatoires, ville/code postal, prénom,
//      e-mail, animal ; pas de mot de passe) → POST /ad-leads/site { codeFlow } : compte propriétaire créé ou
//      retrouvé, rien publié, UN e-mail « ton code » (6 chiffres + le bouton « Confirmer et publier » en filet) ;
//   2. champ « code reçu par e-mail » → POST /ad-leads/code/check : code juste = e-mail vérifié (3 profils) ET demande
//      publiée immédiatement (même chemin que le clic de l'e-mail), session ouverte sans mot de passe ;
//   3. écran de fin : « Demande publiée » + badges App Store / Google Play + « Voir mes candidats » (lien signé).
// Si la personne ferme sans taper le code : le bouton de l'e-mail et le rappel +3 h existants publient comme aujourd'hui.
// Mesure (admin › Trafic du site, repères cta_click) : demande_vue · demande_envoyee · demande_code_ok ·
// demande_publiee · demande_store_clic (+ demande_code_faux, demande_code_renvoye, demande_code_refus_<code>).
// Règle de Daniel du 31/10 maintenue : rien n'est publié sans e-mail vérifié. Tous les hooks AVANT tout retour.

type Lang = "fr" | "en";
type CityKey = "paris" | "nyc";
const CITIES: Record<CityKey, { name: string; country: string; campaign: string }> = {
  paris: { name: "Paris", country: "FR", campaign: "paris_owners" },
  nyc: { name: "New York", country: "US", campaign: "nyc_owners" },
};
const RESEND_S = 60;

export default function DemandeFlow0811({ lang, defaultCity }: { lang: Lang; defaultCity: CityKey }) {
  const [cityKey, setCityKey] = useState<CityKey>(defaultCity);
  const [lead, setLead] = useState<HeroLeadResult0811 | null>(null);
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [info, setInfo] = useState("");
  const [wait, setWait] = useState(0);
  const [done, setDone] = useState<{ postId: string | null; notified?: number; link: string; published: boolean } | null>(null);
  const topRef = useRef<HTMLDivElement>(null);
  const codeRef = useRef<HTMLInputElement>(null);
  const seen = useRef(false);

  // ?city=paris|nyc (la pub Paris FR et New York EN partagent le composant ; les utm sont lus par SiteAnalytics).
  useEffect(() => {
    if (!seen.current) { seen.current = true; trackSiteEvent("cta_click", { label: "demande_vue" }); }
    try {
      const c = (new URLSearchParams(window.location.search).get("city") || "").toLowerCase();
      if (c === "paris" || c === "nyc") setCityKey(c);
    } catch { /* adresse exotique */ }
  }, []);

  // Compte à rebours du bouton « Renvoyer le code » (le serveur garantit aussi les 60 s).
  useEffect(() => {
    if (wait <= 0) return;
    const t = setTimeout(() => setWait((w) => w - 1), 1000);
    return () => clearTimeout(t);
  }, [wait]);

  // Étape « code » ou « fin » : on remonte la carte sous l'en-tête (leçon ZOE 31/10 : carte hors écran à 375 px).
  useEffect(() => {
    if (!lead && !done) return;
    try { topRef.current?.scrollIntoView({ block: "start", behavior: "smooth" }); } catch { /* vieux navigateur */ }
    if (lead && !done) setTimeout(() => codeRef.current?.focus(), 350);
  }, [lead, done]);

  const city = CITIES[cityKey];
  const page = lang === "fr" ? "/demande" : "/request";
  const t = (k: string, vars?: Record<string, string | number>) => dm(lang, k, vars);

  async function resend(auto = false) {
    if (!lead || busy) return;
    setErr("");
    setInfo("");
    try {
      const r = await sendDemandeCode0811(lead.id);
      setWait(r.retryAfter || RESEND_S);
      if (!auto) { setInfo(t("resent")); trackSiteEvent("cta_click", { label: "demande_code_renvoye" }); }
    } catch (e) {
      const d = e instanceof ApiError && e.details && typeof e.details === "object" ? (e.details as { code?: string; retryAfter?: number }) : {};
      if (d.code === "RESEND_TOO_SOON") { setWait(Number(d.retryAfter) || RESEND_S); setInfo(t("already_sent")); return; }
      if (d.code === "TOO_MANY") { setErr(t("many")); return; }
      setErr(t("err"));
    }
  }

  function onLead(r: HeroLeadResult0811) {
    trackSiteEvent("cta_click", { label: "demande_envoyee" });
    setLead(r);
    setCode("");
    setErr("");
    setInfo("");
    if (r.codeSent) setWait(RESEND_S);
    // Brouillon repris (< 24 h) ou demande déjà en ligne : le serveur n'a pas envoyé de code dans cet appel → on le demande.
    else void (async () => { await new Promise((ok) => setTimeout(ok, 50)); await resendFor(r.id); })();
  }
  async function resendFor(id: string) {
    try {
      const r = await sendDemandeCode0811(id);
      setWait(r.retryAfter || RESEND_S);
    } catch (e) {
      const d = e instanceof ApiError && e.details && typeof e.details === "object" ? (e.details as { code?: string; retryAfter?: number }) : {};
      if (d.code === "RESEND_TOO_SOON") { setWait(Number(d.retryAfter) || RESEND_S); setInfo(t("already_sent")); return; }
      if (d.code === "TOO_MANY") { setErr(t("many")); return; }
      setErr(t("err"));
    }
  }

  async function check() {
    if (!lead || busy) return;
    const c = code.replace(/\D/g, "");
    if (c.length !== 6) { setErr(t("code_need")); return; }
    setBusy(true);
    setErr("");
    setInfo("");
    try {
      const r = await checkDemandeCode0811(lead.id, c);
      trackSiteEvent("cta_click", { label: "demande_code_ok" });
      if (r.published) trackSiteEvent("cta_click", { label: "demande_publiee" });
      setDone({ postId: r.postId, notified: r.notified, link: r.link || "/posts", published: r.published });
    } catch (e) {
      const d = e instanceof ApiError && e.details && typeof e.details === "object" ? (e.details as { code?: string; left?: number }) : {};
      const cd = d.code || (e instanceof ApiError ? String(e.status) : "x");
      trackSiteEvent("cta_click", { label: cd === "CODE_INVALID" ? "demande_code_faux" : `demande_code_refus_${cd.toLowerCase()}` });
      if (cd === "CODE_INVALID") setErr(t("wrong", { n: d.left ?? 0 }));
      else if (cd === "CODE_EXPIRED") setErr(t("expired"));
      else if (cd === "TOO_MANY_TRIES") setErr(t("many"));
      else setErr(t("err"));
    } finally {
      setBusy(false);
    }
  }

  const card = "mt-4 scroll-mt-24 rounded-3xl bg-white p-5 md:mx-auto md:max-w-md";
  const bigBtn = "mt-4 block w-full rounded-full bg-owner px-6 py-4 text-center text-lg font-extrabold text-white shadow-card disabled:opacity-70";

  if (done) {
    return (
      <div ref={topRef} className={card} style={{ boxShadow: "0 0 0 2px #15803D, 0 14px 30px -18px rgba(35,23,21,.5)" }} data-testid="demande-done-0811">
        <p className="text-center text-[24px] font-extrabold leading-tight" style={{ color: "#15803D" }}>✓ {t("done_title")}</p>
        <p className="mt-2 text-center text-[16px] font-semibold leading-snug text-ink">
          {done.notified && done.notified > 0 ? t("done_notified", { n: done.notified }) : t("done_body")}
        </p>
        <p className="mt-3 text-center text-[15px] leading-snug text-ink">{t("done_app")}</p>
        {/* Badges App Store / Google Play (liens de /download) ; chaque clic = demande_store_clic en plus du store_click. */}
        <div className="mt-3" onClickCapture={() => trackSiteEvent("cta_click", { label: "demande_store_clic" })} data-testid="demande-stores-0811">
          <StoreBadges center />
        </div>
        <Link href={done.link} className="mt-5 inline-block w-full rounded-full border-2 border-owner px-6 py-3.5 text-center text-[16px] font-extrabold text-owner" onClick={() => trackSiteEvent("cta_click", { label: "demande_voir_candidats" })} data-testid="demande-candidats-0811">
          {t("done_link")} →
        </Link>
        <p className="mt-3 text-center text-xs text-ink-muted">{t("done_mail")}</p>
      </div>
    );
  }

  if (lead) {
    return (
      <div ref={topRef} className={card} style={{ boxShadow: "0 0 0 2px #1C1917, 0 14px 30px -18px rgba(35,23,21,.5)" }} data-testid="demande-code-0811">
        <p className="text-[20px] font-extrabold leading-tight text-ink">✉ {t("code_title")}</p>
        <p className="mt-2 text-[15px] leading-snug text-ink">{t(lead.postId && !lead.pending ? "code_body_existing" : "code_body", { email: lead.email })}</p>
        <label className="mt-4 block text-xs font-semibold text-ink">{t("code_label")}
          <input ref={codeRef} value={code} onChange={(e) => { setCode(e.target.value.replace(/\D/g, "").slice(0, 6)); setErr(""); }}
            inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]*" maxLength={6} placeholder="••••••"
            onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); void check(); } }}
            className="mt-1 w-full rounded-xl border border-ink/15 bg-white px-3 py-3 text-center text-[28px] font-extrabold tracking-[0.4em] text-ink focus:border-owner focus:outline-none" data-testid="demande-code-input" />
        </label>
        {err && <p className="mt-2 text-center text-sm font-semibold text-owner-dark" role="alert">{err}</p>}
        {!err && info && <p className="mt-2 text-center text-sm font-semibold" style={{ color: "#15803D" }} role="status">{info}</p>}
        <button type="button" onClick={() => void check()} disabled={busy} className={bigBtn} data-testid="demande-code-cta">
          {busy ? t("code_busy") : t("code_cta")}
        </button>
        <button type="button" onClick={() => void resend()} disabled={busy || wait > 0}
          className="mt-3 block w-full rounded-full border-2 border-owner px-6 py-3 text-center text-[15px] font-extrabold text-owner disabled:border-ink/15 disabled:text-ink-muted" data-testid="demande-code-resend">
          {wait > 0 ? t("resend_wait", { s: wait }) : t("resend")}
        </button>
        <p className="mt-3 text-center text-[12px] leading-snug text-ink-muted">{t("spam")}</p>
        <button type="button" onClick={() => { setLead(null); setDone(null); }} className="mt-2 block w-full text-center text-[12px] font-semibold text-ink underline underline-offset-4" data-testid="demande-back">
          {t("back")}
        </button>
      </div>
    );
  }

  return (
    <div ref={topRef} data-testid="demande-form-0811" data-demande-city={cityKey}>
      <ParisHeroForm
        key={cityKey}
        city={city.name}
        lead={t("lead")}
        note={t("note")}
        lang={lang}
        country={city.country}
        campaign={city.campaign}
        page={page}
        codeFlow
        onLead={onLead}
      />
    </div>
  );
}
