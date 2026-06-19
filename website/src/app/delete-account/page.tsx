"use client";

// v498 — Daniel : page « Supprimer mon compte » (exigence Google Play : URL
// publique de suppression de compte). Web-only. Publique (consultable sans être
// connecté) ; si connecté → bouton de suppression fonctionnel (DELETE /users/me).
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { clearAuth, deleteMyAccount, getStoredUser } from "@/lib/api";

export default function DeleteAccountPage() {
  const { t } = useT();
  const router = useRouter();
  const [loggedIn, setLoggedIn] = useState<boolean | null>(null);
  const [confirmed, setConfirmed] = useState(false);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setLoggedIn(!!getStoredUser());
  }, []);

  async function onDelete() {
    if (!confirmed || busy) return;
    setBusy(true);
    setError(null);
    try {
      await deleteMyAccount();
      clearAuth();
      setDone(true);
      // Laisse le message s'afficher, puis renvoie à l'accueil.
      setTimeout(() => router.replace("/"), 3500);
    } catch (e) {
      setError(e instanceof Error ? e.message : t("del_error"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto max-w-2xl px-4 py-16 md:py-20">
      <h1 className="font-display text-3xl font-extrabold text-ink md:text-4xl">
        {t("del_title")}
      </h1>
      <p className="mt-3 text-ink-muted">{t("del_subtitle")}</p>

      {/* Explication (toujours visible, publique). */}
      <div className="mt-8 rounded-2xl border border-ink/10 bg-white p-5 shadow-card">
        <p className="text-sm font-extrabold text-ink">{t("del_what")}</p>
        <ul className="mt-3 space-y-2 text-sm text-ink-muted">
          <li className="flex gap-2"><span>•</span><span>{t("del_b1")}</span></li>
          <li className="flex gap-2"><span>•</span><span>{t("del_b2")}</span></li>
          <li className="flex gap-2"><span>•</span><span>{t("del_b3")}</span></li>
        </ul>
        <p className="mt-4 rounded-xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">
          ⚠️ {t("del_irreversible")}
        </p>
      </div>

      {/* Zone d'action selon l'état de connexion. */}
      <div className="mt-6">
        {done ? (
          <div className="rounded-2xl border border-emerald-200 bg-emerald-50 p-5 text-center text-sm font-semibold text-emerald-700">
            {t("del_done")}
          </div>
        ) : loggedIn === false ? (
          <div className="rounded-2xl border border-ink/10 bg-white p-5 shadow-card">
            <p className="text-sm text-ink">{t("del_login_required")}</p>
            <Link
              href="/login?redirect=/delete-account"
              className="mt-4 inline-block rounded-full bg-owner px-6 py-2.5 text-sm font-bold text-white transition hover:bg-owner-dark"
            >
              {t("del_login_cta")} →
            </Link>
            <p className="mt-4 text-xs text-ink-muted">{t("del_app_note")}</p>
          </div>
        ) : loggedIn === true ? (
          <div className="rounded-2xl border border-red-200 bg-white p-5 shadow-card">
            <label className="flex cursor-pointer items-start gap-3 text-sm text-ink">
              <input
                type="checkbox"
                checked={confirmed}
                onChange={(e) => setConfirmed(e.target.checked)}
                className="mt-0.5 h-4 w-4 accent-red-600"
              />
              <span>{t("del_confirm_check")}</span>
            </label>
            <button
              type="button"
              onClick={onDelete}
              disabled={!confirmed || busy}
              className="mt-4 w-full rounded-full bg-red-600 px-6 py-3 text-sm font-bold text-white transition hover:bg-red-700 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {busy ? t("del_deleting") : t("del_button")}
            </button>
            {error && (
              <p className="mt-3 text-sm font-semibold text-red-700">{error}</p>
            )}
            <p className="mt-4 text-xs text-ink-muted">{t("del_app_note")}</p>
          </div>
        ) : (
          <div className="h-24 animate-pulse rounded-2xl bg-ink/5" />
        )}
      </div>
    </div>
  );
}
