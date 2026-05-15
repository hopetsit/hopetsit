"use client";

// v23.1 part 146 — Onboarding sitter/walker depuis le site.
// 2 sections :
//   1. Tarifs (hourly / weekly / monthly + skills + service)
//   2. IBAN payout (mandatory pour recevoir les paiements)
// Owner ne devrait pas accéder à cette page → redirect.

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError,
  AuthUser,
  deleteMyIban,
  getMyIban,
  getMyProfile,
  getStoredUser,
  IbanInfo,
  updateMyIban,
  updateMyProfile,
  UserProfile,
} from "@/lib/api";

export default function SitterSetupPage() {
  const { t } = useT();
  const router = useRouter();
  const [user, setUser] = useState<AuthUser | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [iban, setIban] = useState<IbanInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Rates form
  const [hourlyRate, setHourlyRate] = useState("");
  const [weeklyRate, setWeeklyRate] = useState("");
  const [monthlyRate, setMonthlyRate] = useState("");
  const [skills, setSkills] = useState("");
  const [savingRates, setSavingRates] = useState(false);
  const [ratesSavedAt, setRatesSavedAt] = useState<number | null>(null);

  // IBAN form
  const [ibanHolder, setIbanHolder] = useState("");
  const [ibanNumber, setIbanNumber] = useState("");
  const [ibanBic, setIbanBic] = useState("");
  const [savingIban, setSavingIban] = useState(false);
  const [ibanSavedAt, setIbanSavedAt] = useState<number | null>(null);
  const [ibanError, setIbanError] = useState<string | null>(null);

  useEffect(() => {
    const u = getStoredUser();
    if (!u) {
      router.replace("/login");
      return;
    }
    if (u.role === "owner") {
      router.replace("/dashboard");
      return;
    }
    setUser(u);
    (async () => {
      try {
        const [p, ib] = await Promise.all([
          getMyProfile(),
          getMyIban().catch(() => null), // peut renvoyer 404 si pas encore configuré
        ]);
        setProfile(p);
        setHourlyRate(p.hourlyRate ? String(p.hourlyRate) : "");
        setWeeklyRate(p.weeklyRate ? String(p.weeklyRate) : "");
        setMonthlyRate(p.monthlyRate ? String(p.monthlyRate) : "");
        setSkills(p.skills || "");
        if (ib) {
          setIban(ib);
          setIbanHolder(ib.ibanHolder || p.name || "");
          setIbanBic(ib.ibanBic || "");
        } else {
          setIbanHolder(p.name || "");
        }
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }
        setError(e instanceof Error ? e.message : "Failed to load");
      } finally {
        setLoading(false);
      }
    })();
  }, [router]);

  async function handleSaveRates(e: React.FormEvent) {
    e.preventDefault();
    setSavingRates(true);
    setError(null);
    try {
      const patch: Partial<UserProfile> = {
        hourlyRate: hourlyRate ? Number(hourlyRate) : undefined,
        weeklyRate: weeklyRate ? Number(weeklyRate) : undefined,
        monthlyRate: monthlyRate ? Number(monthlyRate) : undefined,
        skills: skills.trim() || undefined,
      };
      const updated = await updateMyProfile(patch);
      setProfile(updated);
      setRatesSavedAt(Date.now());
      setTimeout(() => setRatesSavedAt(null), 3000);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to save rates");
    } finally {
      setSavingRates(false);
    }
  }

  async function handleSaveIban(e: React.FormEvent) {
    e.preventDefault();
    setSavingIban(true);
    setIbanError(null);
    try {
      const updated = await updateMyIban({
        ibanHolder: ibanHolder.trim(),
        ibanNumber: ibanNumber.replace(/\s+/g, ""),
        ibanBic: ibanBic.trim() || undefined,
      });
      setIban(updated);
      setIbanNumber(""); // on ne ré-affiche jamais l'IBAN complet
      setIbanSavedAt(Date.now());
      setTimeout(() => setIbanSavedAt(null), 3000);
    } catch (e) {
      setIbanError(e instanceof Error ? e.message : "Failed to save IBAN");
    } finally {
      setSavingIban(false);
    }
  }

  async function handleDeleteIban() {
    if (!confirm("Supprimer ton IBAN ? Tu ne pourras plus recevoir de paiements jusqu'à ce que tu en saisisses un nouveau.")) {
      return;
    }
    try {
      await deleteMyIban();
      setIban(null);
      setIbanHolder(profile?.name || "");
      setIbanBic("");
    } catch (e) {
      alert(e instanceof Error ? e.message : "Failed to delete IBAN");
    }
  }

  if (loading) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-24 text-center text-ink-muted">
        {t("common_loading")}
      </div>
    );
  }

  const roleColor =
    user?.role === "walker" ? "walker" : "sitter";

  return (
    <div className="mx-auto max-w-2xl px-4 py-12 md:py-16">
      <div className="mb-6 flex items-center justify-between">
        <Link href="/dashboard" className="text-sm text-ink-muted hover:text-ink">
          ← Dashboard
        </Link>
        <span className={`rounded-full bg-${roleColor} px-3 py-1 text-xs font-semibold uppercase tracking-wider text-white`}>
          {user?.role}
        </span>
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        Configuration {user?.role}
      </h1>
      <p className="mt-2 text-ink-muted">
        Définis tes tarifs et tes coordonnées bancaires pour pouvoir recevoir
        des réservations payantes.
      </p>

      {error && (
        <div className="mt-6 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* ── TARIFS ───────────────────────────────────────────── */}
      <section className="mt-8 rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
        <h2 className="text-lg font-bold text-ink">Mes tarifs</h2>
        <p className="mt-1 text-xs text-ink-muted">
          Au moins le tarif horaire est obligatoire. Les tarifs hebdomadaire et
          mensuel sont optionnels (utiles pour les longs séjours).
        </p>

        <form onSubmit={handleSaveRates} className="mt-5 space-y-4">
          <div className="grid gap-4 sm:grid-cols-3">
            <RateField
              label="Heure"
              value={hourlyRate}
              onChange={setHourlyRate}
              required
              currency={profile?.currency || "EUR"}
            />
            <RateField
              label="Semaine"
              value={weeklyRate}
              onChange={setWeeklyRate}
              currency={profile?.currency || "EUR"}
            />
            <RateField
              label="Mois"
              value={monthlyRate}
              onChange={setMonthlyRate}
              currency={profile?.currency || "EUR"}
            />
          </div>

          <label className="block">
            <span className="mb-1 block text-xs font-semibold uppercase tracking-wider text-ink-muted">
              Spécialités
            </span>
            <input
              type="text"
              value={skills}
              onChange={(e) => setSkills(e.target.value)}
              placeholder="Dressage, chats âgés, médication…"
              className={`w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-${roleColor} focus:outline-none focus:ring-2 focus:ring-${roleColor}/20`}
            />
          </label>

          {ratesSavedAt && (
            <div className="rounded-xl bg-green-50 px-4 py-2 text-xs text-green-700">
              ✓ Tarifs enregistrés
            </div>
          )}

          <button
            type="submit"
            disabled={savingRates}
            className={`rounded-full bg-${roleColor} px-5 py-2 text-sm font-semibold text-white disabled:opacity-60`}
          >
            {savingRates ? "Enregistrement…" : "Enregistrer les tarifs"}
          </button>
        </form>
      </section>

      {/* ── IBAN ─────────────────────────────────────────────── */}
      <section className="mt-6 rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
        <h2 className="text-lg font-bold text-ink">Compte bancaire (IBAN)</h2>
        <p className="mt-1 text-xs text-ink-muted">
          Tes paiements seront virés sur ce compte après chaque réservation
          honorée. L&apos;IBAN est stocké chiffré côté serveur — jamais en clair.
        </p>

        {iban && iban.ibanLast4 && (
          <div className="mt-4 flex items-center justify-between rounded-xl bg-bg-soft px-4 py-3 text-sm">
            <div>
              <div className="font-semibold text-ink">
                {iban.ibanHolder || "—"}
              </div>
              <div className="font-mono text-xs text-ink-muted">
                •••• •••• •••• {iban.ibanLast4}
              </div>
              {iban.ibanVerified ? (
                <div className="mt-1 text-xs font-semibold text-green-600">
                  ✓ Vérifié
                </div>
              ) : (
                <div className="mt-1 text-xs font-semibold text-amber-600">
                  En attente de vérification
                </div>
              )}
            </div>
            <button
              type="button"
              onClick={handleDeleteIban}
              className="rounded-full border border-red-200 px-3 py-1.5 text-xs font-semibold text-red-600 hover:bg-red-50"
            >
              Supprimer
            </button>
          </div>
        )}

        <form onSubmit={handleSaveIban} className="mt-5 space-y-4">
          <label className="block">
            <span className="mb-1 block text-xs font-semibold uppercase tracking-wider text-ink-muted">
              Titulaire du compte
            </span>
            <input
              type="text"
              value={ibanHolder}
              onChange={(e) => setIbanHolder(e.target.value)}
              required
              placeholder="Jean Dupont"
              className={`w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-${roleColor} focus:outline-none focus:ring-2 focus:ring-${roleColor}/20`}
            />
          </label>
          <label className="block">
            <span className="mb-1 block text-xs font-semibold uppercase tracking-wider text-ink-muted">
              IBAN {iban ? "(nouveau — remplacera l'ancien)" : ""}
            </span>
            <input
              type="text"
              value={ibanNumber}
              onChange={(e) => setIbanNumber(e.target.value.toUpperCase())}
              required={!iban}
              placeholder="FR76 1234 5678 9012 3456 7890 123"
              className={`w-full rounded-xl border border-ink/15 px-3 py-2 font-mono text-sm focus:border-${roleColor} focus:outline-none focus:ring-2 focus:ring-${roleColor}/20`}
            />
          </label>
          <label className="block">
            <span className="mb-1 block text-xs font-semibold uppercase tracking-wider text-ink-muted">
              BIC (optionnel)
            </span>
            <input
              type="text"
              value={ibanBic}
              onChange={(e) => setIbanBic(e.target.value.toUpperCase())}
              placeholder="BNPAFRPPXXX"
              className={`w-full rounded-xl border border-ink/15 px-3 py-2 font-mono text-sm focus:border-${roleColor} focus:outline-none focus:ring-2 focus:ring-${roleColor}/20`}
            />
          </label>

          {ibanError && (
            <div className="rounded-xl bg-red-50 px-3 py-2 text-xs text-red-700">
              {ibanError}
            </div>
          )}
          {ibanSavedAt && (
            <div className="rounded-xl bg-green-50 px-4 py-2 text-xs text-green-700">
              ✓ IBAN enregistré
            </div>
          )}

          <button
            type="submit"
            disabled={savingIban}
            className={`rounded-full bg-${roleColor} px-5 py-2 text-sm font-semibold text-white disabled:opacity-60`}
          >
            {savingIban ? "Enregistrement…" : iban ? "Mettre à jour l'IBAN" : "Enregistrer l'IBAN"}
          </button>
        </form>
      </section>
    </div>
  );
}

function RateField({
  label,
  value,
  onChange,
  required,
  currency,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  required?: boolean;
  currency: string;
}) {
  return (
    <label className="block">
      <span className="mb-1 block text-xs font-semibold uppercase tracking-wider text-ink-muted">
        {label} {required && "*"}
      </span>
      <div className="relative">
        <input
          type="number"
          min="0"
          step="0.01"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          required={required}
          className="w-full rounded-xl border border-ink/15 px-3 py-2 pr-10 text-sm focus:border-walker focus:outline-none focus:ring-2 focus:ring-walker/20"
        />
        <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-xs text-ink-muted">
          {currency}
        </span>
      </div>
    </label>
  );
}
