"use client";

// 05/11/2026 (SAM, décision de Daniel du 05/11 — plan PLAN_PUB_0511.md, bloc A2) — PAGE DE
// REMERCIEMENT du formulaire Meta (pub v10) : « Publier ma demande maintenant ».
// Mesure du 05/11 : 24 contacts pub → 24 e-mails « confirme » → 2 demandes publiées ; 22 n'ont
// jamais ouvert l'e-mail. Décision de Daniel : l'e-mail d'un formulaire Meta est celui du compte
// Facebook (déjà vérifié par Meta) ; POUR CE CAS, l'appui sur ce bouton vaut confirmation.
// La personne retape son e-mail (Meta ne le transmet pas dans l'URL), le serveur retrouve son
// contact (POST /ad-leads/thanks/confirm), publie la demande et prévient les gardiens. Si le
// contact n'est pas encore relevé (le relevé Meta tourne toutes les 5 min), le serveur répond
// 202 : la page réessaie toute seule (60 s, 150 s, 300 s — 4 essais, le serveur en accepte 5
// par IP et 10 min) et rappelle que l'e-mail « un clic pour publier » fait la même chose.
// Succès → /posts/confirmer?l=<leadId> (« Ta demande est en ligne ! » + « Voir ma demande »,
// qui ouvre la session sans mot de passe). /posts est en noindex (middleware).
// Règle des hooks : tous les hooks AVANT le premier return.

import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { API_BASE } from "@/lib/api";
import { useT } from "@/lib/i18n/LanguageProvider";
import { g1011 } from "@/lib/i18n/langues1011";
import type { Lang } from "@/lib/i18n/langs";

const RETRY_MS = [60_000, 90_000, 150_000]; // après l'essai 1 : +60 s, puis +90 s, puis +150 s (= 300 s)

// 1011 (ZOE, ordre de Daniel « les pages ne sont pas à jour dans les autres langues ») — mêmes champs
// qu'avant, lus dans la table en 9 langues (français inchangé). `base` = langue du formulaire (fr/en) :
// elle choisit la ville du lien de retour et l'exemple d'adresse, comme avant.
const EMAIL_PH_1011 = { fr: "prenom@exemple.fr", en: "name@example.com" } as const;
const BACK_HREF_1011 = { fr: "/garde-animaux/paris", en: "/pet-sitting/new-york" } as const;
function txt1011(ui: Lang, base: "fr" | "en") {
  const g = (k: string, v?: Record<string, string | number>) => g1011(ui, k, v);
  return {
    kicker: g("merci_kicker"),
    title: g("merci_title"),
    intro: g("merci_intro"),
    emailLabel: g("merci_email_label"),
    emailPh: EMAIL_PH_1011[base],
    cta: g("merci_cta"),
    busy: g("conf_busy"),
    free: g("merci_free"),
    terms: g("conf_terms"),
    termsLink: g("conf_terms_link"),
    termsAfter: g("conf_terms_after"),
    pendingTitle: g("merci_pending_title"),
    pendingBody: g("merci_pending_body"),
    pendingMail: g("merci_pending_mail"),
    retry: g("merci_retry"),
    retrying: (n: number) => g("merci_retrying", { n }),
    blocked: g("merci_blocked"),
    emailErr: g("merci_email_err"),
    err: g("merci_err"),
    done: g("merci_done"),
    back: g(base === "en" ? "merci_back_nyc" : "merci_back_paris"),
    backHref: BACK_HREF_1011[base],
    steps: [g("merci_step1"), g("merci_step2"), g("merci_step3"), g("merci_step4")],
  };
}

type Status = "idle" | "pending" | "blocked" | "done";
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const NYC_RE = /^(nyc|new[-_ ]?york|ny)$/i;

export default function MerciLeadPage() {
  const { lang: siteLang } = useT();
  const [lang, setLang] = useState<"fr" | "en">("fr");
  // 1011 (BOB) — vrai quand le lien choisit lui-même la langue (?lang= ou ville de New York).
  const [langFromUrl, setLangFromUrl] = useState(false);
  const [city, setCity] = useState("paris");
  const [campaign, setCampaign] = useState("paris_leads");
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<Status>("idle");
  const [err, setErr] = useState("");
  const [countdown, setCountdown] = useState(0);
  const attempts = useRef(0);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const ticker = useRef<ReturnType<typeof setInterval> | null>(null);
  const seen = useRef(false);

  // Paramètres de l'URL : ?city=paris|nyc, ?lang=fr|en, ?e=<e-mail pré-rempli>, utm_campaign.
  useEffect(() => {
    try {
      const q = new URLSearchParams(window.location.search);
      const c = (q.get("city") || "").trim().toLowerCase();
      const l = (q.get("lang") || "").trim().toLowerCase();
      const en = l === "en" || (!l && NYC_RE.test(c));
      setLang(en ? "en" : "fr");
      setLangFromUrl(!!l || NYC_RE.test(c));
      setCity(c || (en ? "nyc" : "paris"));
      const camp = (q.get("utm_campaign") || "").trim();
      if (/^[a-z0-9_-]{1,40}$/i.test(camp)) setCampaign(camp); else setCampaign(en ? "nyc_leads" : "paris_leads");
      const e = (q.get("e") || "").trim();
      if (EMAIL_RE.test(e) && e.length <= 120) setEmail(e);
    } catch { /* URL exotique */ }
    if (!seen.current) { seen.current = true; trackSiteEvent("cta_click", { label: "merci_vu" }); }
    return () => {
      if (timer.current) clearTimeout(timer.current);
      if (ticker.current) clearInterval(ticker.current);
    };
  }, []);

  const clearTimers = () => {
    if (timer.current) { clearTimeout(timer.current); timer.current = null; }
    if (ticker.current) { clearInterval(ticker.current); ticker.current = null; }
    setCountdown(0);
  };

  // 1011 (ZOE) — langue affichée : celle du site si le visiteur lit autre chose que le français ou
  // l'anglais ; sinon celle du formulaire (?lang=), comme avant. La valeur envoyée au serveur ne change pas.
  // 1011 (BOB) — sans langue dans le lien, un visiteur anglais lisait le titre en français : la page suit
  // alors la langue du site (français ou anglais).
  const ui: Lang = siteLang !== "fr" && siteLang !== "en" ? siteLang : langFromUrl ? lang : siteLang;
  const t = txt1011(ui, lang);
  const tRef = useRef(t);
  tRef.current = t;

  const submit = useCallback(async (auto: boolean) => {
    const value = email.trim().toLowerCase();
    if (!EMAIL_RE.test(value) || value.length > 120) { setErr(tRef.current.emailErr); return; }
    if (busy) return;
    clearTimers();
    setBusy(true);
    setErr("");
    attempts.current += 1;
    try {
      const res = await fetch(`${API_BASE}/ad-leads/thanks/confirm`, {
        method: "POST",
        headers: { Accept: "application/json", "Content-Type": "application/json", "X-App-Version": "web" },
        body: JSON.stringify({ email: value, city }),
      });
      const text = await res.text();
      let data: { leadId?: string; postId?: string | null; pending?: boolean; code?: string; error?: string } = {};
      try { data = text ? JSON.parse(text) : {}; } catch { data = {}; }
      if (res.status === 200 && data.leadId) {
        trackSiteEvent("cta_click", { label: "merci_publie" });
        setStatus("done");
        const qs = new URLSearchParams({ l: data.leadId, utm_source: "meta", utm_medium: "paid", utm_campaign: campaign, utm_content: "merci_ok" });
        window.location.href = `/posts/confirmer?${qs.toString()}`;
        return;
      }
      if (res.status === 202) {
        trackSiteEvent("cta_click", { label: auto ? "merci_attente_auto" : "merci_attente" });
        setStatus("pending");
        const idx = attempts.current - 1;
        if (idx < RETRY_MS.length) {
          const ms = RETRY_MS[idx];
          setCountdown(Math.round(ms / 1000));
          ticker.current = setInterval(() => setCountdown((n) => (n > 0 ? n - 1 : 0)), 1000);
          timer.current = setTimeout(() => { void submit(true); }, ms);
        }
        return;
      }
      if (res.status === 429) { trackSiteEvent("cta_click", { label: "merci_limite" }); setStatus("blocked"); return; }
      if (res.status === 400) { setErr(tRef.current.emailErr); return; }
      setErr(tRef.current.err);
    } catch {
      setErr(tRef.current.err);
    } finally {
      setBusy(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [email, busy, city, campaign, lang]);

  const card = "mx-auto w-full max-w-md rounded-[24px] bg-white p-5 shadow-sm sm:p-7";
  const bigBtn = "flex min-h-[52px] w-full items-center justify-center rounded-full bg-owner px-6 text-base font-bold text-white transition hover:bg-owner-dark disabled:opacity-60";
  const input = "mt-1 w-full rounded-2xl border-2 border-[#EADBD6] bg-white px-4 py-3 text-base text-ink outline-none focus:border-owner";

  return (
    <main className="min-h-[70vh] bg-[#FFF7F4] px-4 py-8">
      <div className={card}>
        <p className="text-sm font-semibold text-owner-dark">{t.kicker}</p>
        <h1 className="mt-1 font-display text-3xl font-extrabold leading-tight text-ink">{t.title}</h1>
        <p className="mt-2 text-[#6E4F48]">{t.intro}</p>

        {status === "pending" || status === "blocked" ? (
          <div role="status" className="mt-5 rounded-2xl border border-owner/30 bg-owner-light p-4">
            <p className="text-lg font-bold text-ink">{status === "pending" ? t.pendingTitle : t.blocked}</p>
            {status === "pending" && (
              <>
                <p className="mt-2 text-sm text-[#6E4F48]">{t.pendingBody}</p>
                <p className="mt-2 text-sm text-[#6E4F48]">{t.pendingMail}</p>
                {countdown > 0 && <p className="mt-2 text-sm font-semibold text-owner-dark">{t.retrying(countdown)}</p>}
              </>
            )}
          </div>
        ) : null}

        {status === "done" ? (
          <p role="status" className="mt-5 rounded-2xl border border-owner/30 bg-owner-light p-4 text-lg font-bold text-ink">{t.done}</p>
        ) : (
          <form
            className="mt-5"
            onSubmit={(ev) => { ev.preventDefault(); void submit(false); }}
            noValidate
          >
            <label className="block text-sm font-semibold text-ink" htmlFor="merci-email">{t.emailLabel}</label>
            <input
              id="merci-email"
              type="email"
              inputMode="email"
              autoComplete="email"
              autoCapitalize="none"
              spellCheck={false}
              className={input}
              placeholder={t.emailPh}
              value={email}
              onChange={(ev) => { setEmail(ev.target.value); setErr(""); }}
              disabled={busy || status === "blocked"}
            />
            <button type="submit" disabled={busy || status === "blocked"} className={`${bigBtn} mt-4`}>
              {busy ? t.busy : status === "pending" ? t.retry : t.cta}
            </button>
            {err && <p role="alert" className="mt-3 text-center text-sm font-semibold text-owner-dark">{err}</p>}
          </form>
        )}

        <ol className="mt-5 space-y-1 pl-5 text-sm text-[#6E4F48]" style={{ listStyle: "decimal" }}>
          {t.steps.map((s) => <li key={s}>{s}</li>)}
        </ol>
        <p className="mt-4 text-center text-xs text-[#6E4F48]">{t.free}</p>
        <p className="mt-1 text-center text-xs text-[#6E4F48]">
          {t.terms} <Link href="/terms" className="font-semibold text-owner-dark underline">{t.termsLink}</Link>{t.termsAfter}
        </p>
        <p className="mt-4 text-center text-xs">
          <Link href={t.backHref} className="font-semibold text-owner-dark underline">{t.back}</Link>
        </p>
      </div>
    </main>
  );
}
