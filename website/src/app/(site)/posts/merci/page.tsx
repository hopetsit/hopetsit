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

const RETRY_MS = [60_000, 90_000, 150_000]; // après l'essai 1 : +60 s, puis +90 s, puis +150 s (= 300 s)

const TXT = {
  fr: {
    kicker: "Merci ! Il reste un geste.",
    title: "Dernière étape : publie ta demande",
    intro: "Appuie sur le bouton : ta demande est publiée tout de suite et les gardiens près de chez toi sont prévenus.",
    emailLabel: "Ton e-mail (celui du formulaire)",
    emailPh: "prenom@exemple.fr",
    cta: "Publier ma demande maintenant",
    busy: "Publication…",
    free: "Rien à installer, rien à payer pour publier. Tu reçois les candidats avec leur prix par e-mail — tu choisis, tu paies, annulation gratuite jusqu'à 72 h avant.",
    terms: "En publiant, tu acceptes les",
    termsLink: "conditions d'utilisation",
    pendingTitle: "Ta demande arrive…",
    pendingBody: "On récupère ta demande auprès de Facebook : ça prend jusqu'à 5 minutes. Laisse cette page ouverte, elle se publie toute seule.",
    pendingMail: "Tu reçois aussi un e-mail « un clic pour publier ta demande » : son bouton fait exactement la même chose.",
    retry: "Réessayer maintenant",
    retrying: (n: number) => `Nouvel essai automatique dans ${n} s`,
    blocked: "Trop d'essais pour l'instant. Pas de souci : l'e-mail « un clic pour publier ta demande » arrive dans ta boîte d'ici 5 minutes, et son bouton publie ta demande.",
    emailErr: "Vérifie ton adresse e-mail.",
    err: "La publication n'a pas abouti. Réessaie dans un instant.",
    done: "C'est publié ! On t'emmène vers ta demande…",
    back: "Voir les gardiens à Paris",
    backHref: "/garde-animaux/paris",
    steps: ["Ta demande est publiée.", "Les gardiens près de chez toi sont prévenus.", "Ils te proposent leur prix, tu les reçois par e-mail.", "Tu choisis. Rien n'est payé avant ton choix."],
  },
  en: {
    kicker: "Thanks! One last step.",
    title: "Last step: publish your request",
    intro: "Press the button: your request goes live right away and sitters near you are notified.",
    emailLabel: "Your email (the one from the form)",
    emailPh: "name@example.com",
    cta: "Publish my request now",
    busy: "Publishing…",
    free: "Nothing to install, nothing to pay to publish. You get the candidates with their price by email — you choose, you pay, free cancellation up to 72 h before.",
    terms: "By publishing, you accept the",
    termsLink: "terms of use",
    pendingTitle: "Your request is on its way…",
    pendingBody: "We are fetching your request from Facebook: it takes up to 5 minutes. Keep this page open, it publishes by itself.",
    pendingMail: "You also receive an email “one click to publish your request”: its button does exactly the same thing.",
    retry: "Try again now",
    retrying: (n: number) => `Automatic retry in ${n} s`,
    blocked: "Too many tries for now. No worries: the email “one click to publish your request” reaches your inbox within 5 minutes, and its button publishes your request.",
    emailErr: "Please check your email address.",
    err: "Publishing didn't go through. Please try again in a moment.",
    done: "It's live! Taking you to your request…",
    back: "See sitters in New York",
    backHref: "/pet-sitting/new-york",
    steps: ["Your request is published.", "Sitters near you are notified.", "They send you their price, you get it by email.", "You choose. Nothing is paid before you choose."],
  },
} as const;

type Status = "idle" | "pending" | "blocked" | "done";
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const NYC_RE = /^(nyc|new[-_ ]?york|ny)$/i;

export default function MerciLeadPage() {
  const [lang, setLang] = useState<"fr" | "en">("fr");
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

  const t = TXT[lang];

  const submit = useCallback(async (auto: boolean) => {
    const value = email.trim().toLowerCase();
    if (!EMAIL_RE.test(value) || value.length > 120) { setErr(t.emailErr); return; }
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
      if (res.status === 400) { setErr(t.emailErr); return; }
      setErr(t.err);
    } catch {
      setErr(t.err);
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
          {t.terms} <Link href="/terms" className="font-semibold text-owner-dark underline">{t.termsLink}</Link>.
        </p>
        <p className="mt-4 text-center text-xs">
          <Link href={t.backHref} className="font-semibold text-owner-dark underline">{t.back}</Link>
        </p>
      </div>
    </main>
  );
}
