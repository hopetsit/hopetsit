"use client";

// 03/11/2026 — Daniel : « dans le site, rajoute signaler un bug, qui sera aussi connecté à
// l'admin ». Page publique (lien du pied de page) : un visiteur laisse son e-mail pour qu'on
// lui réponde ; connecté, le signalement est rattaché à son compte. Envoi →
// POST /bug-reports/public → admin › Bugs (même liste, même réponse par e-mail) + boîte
// hopetsit@gmail.com. Champ piège invisible contre les robots.

import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { bug0311 } from "@/lib/i18n/bug0311";
import { getStoredUser, sendPublicBugReport, type FeedbackKind } from "@/lib/api";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

export default function BugReportPage() {
  const { lang } = useT();
  const tx = bug0311(lang);
  const [loggedIn, setLoggedIn] = useState(false);
  const [kind, setKind] = useState<FeedbackKind>("problem");
  const [text, setText] = useState("");
  const [email, setEmail] = useState("");
  const [name, setName] = useState("");
  const [trap, setTrap] = useState("");
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [from, setFrom] = useState("");

  useEffect(() => {
    setLoggedIn(!!getStoredUser());
    try {
      const ref = document.referrer ? new URL(document.referrer) : null;
      if (ref && ref.host === window.location.host) setFrom(ref.pathname);
    } catch { /* rien */ }
  }, []);

  const min = kind === "idea" ? 3 : 10;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (busy) return;
    setError(null);
    if (text.trim().length < min) { setError(tx.short); return; }
    if (!loggedIn && !EMAIL_RE.test(email.trim())) { setError(tx.emailError); return; }
    setBusy(true);
    try {
      await sendPublicBugReport({
        kind, description: text, email, name, website: trap,
        screen: `web:${from || "/bug-report"} ${typeof window !== "undefined" && window.innerWidth < 768 ? "(mobile)" : "(desktop)"}`,
      });
      setSent(true);
      setText("");
    } catch {
      setError(tx.error);
    } finally {
      setBusy(false);
    }
  }

  const pill = (k: FeedbackKind, label: string) => (
    <button
      type="button"
      onClick={() => { setKind(k); setError(null); }}
      aria-pressed={kind === k}
      className={`min-h-[40px] rounded-full px-4 text-sm font-bold transition ${kind === k ? "bg-owner text-white" : "bg-white text-ink ring-1 ring-ink/10 hover:bg-owner-light"}`}
    >
      {label}
    </button>
  );

  return (
    <div className="mx-auto max-w-2xl px-4 py-16 md:py-20">
      <h1 className="font-display text-3xl font-extrabold text-ink md:text-4xl">{tx.title}</h1>
      <p className="mt-3 text-ink-muted">{tx.sub}</p>

      {sent ? (
        <div role="status" className="mt-8 rounded-2xl border border-emerald-200 bg-emerald-50 p-5 text-center text-sm font-semibold text-emerald-700">
          ✓ {tx.thanks}
        </div>
      ) : (
        <form onSubmit={submit} className="mt-8 rounded-2xl border border-ink/10 bg-white p-5 shadow-card" noValidate>
          <div className="flex flex-wrap gap-2">
            {pill("problem", tx.kindProblem)}
            {pill("idea", tx.kindIdea)}
          </div>
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            rows={6}
            maxLength={4000}
            required
            placeholder={kind === "idea" ? tx.phIdea : tx.phProblem}
            aria-label={tx.title}
            className="mt-4 w-full resize-y rounded-xl border border-ink/15 bg-white px-4 py-3 text-base text-ink outline-none focus:border-owner"
          />
          {!loggedIn && (
            <div className="mt-4 grid gap-3 sm:grid-cols-2">
              <label className="block text-sm font-semibold text-ink">
                {tx.email}
                <input
                  type="email" inputMode="email" autoComplete="email" required
                  value={email} onChange={(e) => setEmail(e.target.value)}
                  className="mt-1 w-full rounded-xl border border-ink/15 px-4 py-2.5 text-base font-normal outline-none focus:border-owner"
                />
                <span className="mt-1 block text-xs font-normal text-ink-muted">{tx.emailHint}</span>
              </label>
              <label className="block text-sm font-semibold text-ink">
                {tx.name}
                <input
                  type="text" autoComplete="given-name" maxLength={80}
                  value={name} onChange={(e) => setName(e.target.value)}
                  className="mt-1 w-full rounded-xl border border-ink/15 px-4 py-2.5 text-base font-normal outline-none focus:border-owner"
                />
              </label>
            </div>
          )}
          {/* Champ piège : invisible pour un humain, rempli par les robots. */}
          <input
            type="text" name="website" tabIndex={-1} autoComplete="off" aria-hidden="true"
            value={trap} onChange={(e) => setTrap(e.target.value)}
            style={{ position: "absolute", left: "-9999px", width: 1, height: 1, opacity: 0 }}
          />
          {error && <p className="mt-3 text-sm font-semibold text-red-700" role="alert">{error}</p>}
          <button
            type="submit"
            disabled={busy}
            className="mt-5 w-full rounded-full bg-owner px-6 py-3 text-sm font-bold text-white transition hover:bg-owner-dark disabled:opacity-60 sm:w-auto"
          >
            {busy ? tx.sending : tx.send}
          </button>
        </form>
      )}
    </div>
  );
}
