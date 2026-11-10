"use client";

// v23.1 part 146 — Onboarding sitter/walker depuis le site.
// 2 sections :
//   1. Tarifs (hourly / weekly / monthly + skills + service)
//   2. IBAN payout (mandatory pour recevoir les paiements)
// Owner ne devrait pas accéder à cette page → redirect.

import Link from "@/components/SiteLink";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
// 1011 (ZOE, ordre de Daniel « les pages ne sont pas à jour dans les autres langues ») — textes en 9 langues.
import { g1011 } from "@/lib/i18n/langues1011";
import { SelectMenu } from "@/components/SelectMenu";
import BackLink from "@/components/BackLink";
import { VehicleToggle1011 } from "@/components/VehicleToggle1011";
import {
  ApiError,
  Availability,
  AvailabilityTimeSlot,
  AuthUser,
  deleteMyIban,
  getMyAvailability,
  getMyIban,
  getMyProfile,
  getStoredUser,
  IbanInfo,
  updateMyAvailability,
  updateMyIban,
  updateMyProfile,
  UserProfile,
} from "@/lib/api";

export default function SitterSetupPage() {
  const { t, lang } = useT();
  const g = (k: string, vars?: Record<string, string | number>) => g1011(lang, k, vars);
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

  // Availability form (calendrier de disponibilités, parité app).
  // Dates ISO (YYYY-MM-DD) explicitement bloquées + créneaux hebdo récurrents.
  const [unavailableDates, setUnavailableDates] = useState<string[]>([]);
  const [availableDates, setAvailableDates] = useState<string[]>([]);
  const [timeSlots, setTimeSlots] = useState<AvailabilityTimeSlot[]>([]);
  const [newBlockedDate, setNewBlockedDate] = useState("");
  const [savingAvailability, setSavingAvailability] = useState(false);
  const [availabilitySavedAt, setAvailabilitySavedAt] = useState<number | null>(null);
  const [availabilityError, setAvailabilityError] = useState<string | null>(null);

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
        const [p, ib, av] = await Promise.all([
          getMyProfile(),
          getMyIban().catch(() => null), // peut renvoyer 404 si pas encore configuré
          getMyAvailability().catch(() => null), // idem si pas encore configuré
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
        if (av) {
          // On normalise en YYYY-MM-DD pour l'input type=date.
          setUnavailableDates((av.unavailableDates || []).map(isoToDateInput));
          setAvailableDates((av.availableDates || []).map(isoToDateInput));
          setTimeSlots(av.availableTimeSlots || []);
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
    if (!confirm(g("setup_iban_confirm"))) {
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

  function addBlockedDate() {
    if (!newBlockedDate) return;
    setUnavailableDates((curr) =>
      curr.includes(newBlockedDate)
        ? curr
        : [...curr, newBlockedDate].sort(),
    );
    setNewBlockedDate("");
  }

  function removeBlockedDate(d: string) {
    setUnavailableDates((curr) => curr.filter((x) => x !== d));
  }

  function toggleSlotDay(day: AvailabilityTimeSlot["day"]) {
    setTimeSlots((curr) => {
      const exists = curr.some((s) => s.day === day);
      if (exists) return curr.filter((s) => s.day !== day);
      // Créneau par défaut 09h-18h, éditable ensuite.
      return [...curr, { day, startHour: 9, endHour: 18 }];
    });
  }

  function updateSlotHour(
    day: AvailabilityTimeSlot["day"],
    field: "startHour" | "endHour",
    value: number,
  ) {
    setTimeSlots((curr) =>
      curr.map((s) => (s.day === day ? { ...s, [field]: value } : s)),
    );
  }

  async function handleSaveAvailability(e: React.FormEvent) {
    e.preventDefault();
    setSavingAvailability(true);
    setAvailabilityError(null);
    try {
      // Le backend ne valide que startHour < endHour ; on filtre les créneaux
      // incohérents côté client pour éviter un 400 silencieux.
      const slots = timeSlots.filter(
        (s) => Number.isInteger(s.startHour) && Number.isInteger(s.endHour) && s.endHour > s.startHour,
      );
      const updated = await updateMyAvailability({
        // On envoie des dates ISO (le backend les normalise en minuit UTC).
        unavailableDates: unavailableDates.map(dateInputToIso),
        availableDates: availableDates.map(dateInputToIso),
        availableTimeSlots: slots,
      });
      setUnavailableDates((updated.unavailableDates || []).map(isoToDateInput));
      setAvailableDates((updated.availableDates || []).map(isoToDateInput));
      setTimeSlots(updated.availableTimeSlots || []);
      setAvailabilitySavedAt(Date.now());
      setTimeout(() => setAvailabilitySavedAt(null), 3000);
    } catch (e) {
      setAvailabilityError(e instanceof Error ? e.message : "Failed to save availability");
    } finally {
      setSavingAvailability(false);
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
        <BackLink href="/dashboard" label={t("nav_dashboard")} />
        <span className={`rounded-full bg-${roleColor} px-3 py-1 text-xs font-semibold uppercase tracking-wider text-white`}>
          {user?.role}
        </span>
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        {g("setup_title", { role: user?.role ?? "" })}
      </h1>
      <p className="mt-2 text-ink-muted">
        {g("setup_intro")}
      </p>

      {error && (
        <div className="mt-6 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* ── TARIFS ───────────────────────────────────────────── */}
      <section className="mt-8 rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
        <h2 className="text-lg font-bold text-ink">{g("setup_rates_title")}</h2>
        <p className="mt-1 text-xs text-ink-muted">
          {g("setup_rates_help")}
        </p>

        <form onSubmit={handleSaveRates} className="mt-5 space-y-4">
          <div className="grid gap-4 sm:grid-cols-3">
            <RateField
              label={g("setup_hour")}
              value={hourlyRate}
              onChange={setHourlyRate}
              required
              currency={profile?.currency || "EUR"}
            />
            <RateField
              label={g("setup_week")}
              value={weeklyRate}
              onChange={setWeeklyRate}
              currency={profile?.currency || "EUR"}
            />
            <RateField
              label={g("setup_month")}
              value={monthlyRate}
              onChange={setMonthlyRate}
              currency={profile?.currency || "EUR"}
            />
          </div>

          <label className="block">
            <span className="mb-1 block text-xs font-semibold uppercase tracking-wider text-ink-muted">
              {g("setup_skills")}
            </span>
            <input
              type="text"
              value={skills}
              onChange={(e) => setSkills(e.target.value)}
              placeholder={g("setup_skills_ph")}
              className={`w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-${roleColor} focus:outline-none focus:ring-2 focus:ring-${roleColor}/20`}
            />
          </label>

          {ratesSavedAt && (
            <div className="rounded-xl bg-green-50 px-4 py-2 text-xs text-green-700">
              {g("setup_rates_saved")}
            </div>
          )}

          <button
            type="submit"
            disabled={savingRates}
            className={`rounded-full bg-${roleColor} px-5 py-2 text-sm font-semibold text-white disabled:opacity-60`}
          >
            {savingRates ? g("common_saving") : g("setup_rates_save")}
          </button>
        </form>
      </section>

      {/* 1011 — « J'ai un véhicule » (badge « Véhiculé » côté propriétaire). */}
      <VehicleToggle1011 role={roleColor} lang={lang} className="mt-6" />

      {/* ── IBAN ─────────────────────────────────────────────── */}
      <section className="mt-6 rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
        <h2 className="text-lg font-bold text-ink">{g("setup_iban_title")}</h2>
        <p className="mt-1 text-xs text-ink-muted">
          {g("setup_iban_help")}
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
                  {g("setup_iban_verified")}
                </div>
              ) : (
                <div className="mt-1 text-xs font-semibold text-amber-600">
                  {g("setup_iban_pending")}
                </div>
              )}
            </div>
            <button
              type="button"
              onClick={handleDeleteIban}
              className="rounded-full border border-red-200 px-3 py-1.5 text-xs font-semibold text-red-600 hover:bg-red-50"
            >
              {g("common_delete")}
            </button>
          </div>
        )}

        <form onSubmit={handleSaveIban} className="mt-5 space-y-4">
          <label className="block">
            <span className="mb-1 block text-xs font-semibold uppercase tracking-wider text-ink-muted">
              {g("setup_iban_holder")}
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
              IBAN {iban ? g("setup_iban_new") : ""}
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
              {g("setup_bic")}
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
              {g("setup_iban_saved")}
            </div>
          )}

          <button
            type="submit"
            disabled={savingIban}
            className={`rounded-full bg-${roleColor} px-5 py-2 text-sm font-semibold text-white disabled:opacity-60`}
          >
            {savingIban ? g("common_saving") : iban ? g("setup_iban_update") : g("setup_iban_save")}
          </button>
        </form>
      </section>

      {/* ── DISPONIBILITÉS ───────────────────────────────────── */}
      <section className="mt-6 rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
        <h2 className="text-lg font-bold text-ink">{g("setup_avail_title")}</h2>
        <p className="mt-1 text-xs text-ink-muted">
          {g("setup_avail_help")}
        </p>

        <form onSubmit={handleSaveAvailability} className="mt-5 space-y-6">
          {/* Créneaux hebdomadaires récurrents. */}
          <div>
            <span className="mb-2 block text-xs font-semibold uppercase tracking-wider text-ink-muted">
              {g("setup_slots")}
            </span>
            <div className="space-y-2">
              {DAYS.map(({ key }) => {
                const slot = timeSlots.find((s) => s.day === key);
                const active = !!slot;
                return (
                  <div
                    key={key}
                    className={`flex flex-wrap items-center gap-3 rounded-xl border px-3 py-2 transition ${
                      active
                        ? `border-${roleColor} bg-${roleColor}/5`
                        : "border-ink/15"
                    }`}
                  >
                    <label className="flex min-w-[120px] cursor-pointer items-center gap-2 text-sm font-semibold text-ink">
                      <input
                        type="checkbox"
                        checked={active}
                        onChange={() => toggleSlotDay(key)}
                        className="h-4 w-4"
                      />
                      {g(`day_${key}`)}
                    </label>
                    {active && slot && (
                      <div className="flex items-center gap-2 text-sm text-ink-muted">
                        <HourSelect
                          value={slot.startHour}
                          onChange={(v) => updateSlotHour(key, "startHour", v)}
                          min={0}
                          max={23}
                        />
                        <span>→</span>
                        <HourSelect
                          value={slot.endHour}
                          onChange={(v) => updateSlotHour(key, "endHour", v)}
                          min={1}
                          max={24}
                        />
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>

          {/* Jours bloqués (indisponibilités ponctuelles). */}
          <div>
            <span className="mb-2 block text-xs font-semibold uppercase tracking-wider text-ink-muted">
              {g("setup_blocked")}
            </span>
            <div className="flex flex-wrap items-end gap-2">
              <input
                type="date"
                value={newBlockedDate}
                min={new Date().toISOString().split("T")[0]}
                onChange={(e) => setNewBlockedDate(e.target.value)}
                className={`rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-${roleColor} focus:outline-none focus:ring-2 focus:ring-${roleColor}/20`}
              />
              <button
                type="button"
                onClick={addBlockedDate}
                disabled={!newBlockedDate}
                className="rounded-full border border-ink/15 px-4 py-2 text-sm font-semibold text-ink hover:border-ink/30 disabled:opacity-50"
              >
                {g("setup_block_btn")}
              </button>
            </div>
            {unavailableDates.length > 0 ? (
              <div className="mt-3 flex flex-wrap gap-2">
                {unavailableDates.map((d) => (
                  <span
                    key={d}
                    className="inline-flex items-center gap-1.5 rounded-full bg-red-50 px-3 py-1 text-xs font-medium text-red-700"
                  >
                    {new Date(d).toLocaleDateString(undefined, {
                      day: "numeric",
                      month: "short",
                      year: "numeric",
                    })}
                    <button
                      type="button"
                      onClick={() => removeBlockedDate(d)}
                      className="text-red-500 hover:text-red-700"
                      aria-label={g("common_remove")}
                    >
                      ✕
                    </button>
                  </span>
                ))}
              </div>
            ) : (
              <p className="mt-2 text-xs text-ink-soft">
                {g("setup_no_blocked")}
              </p>
            )}
          </div>

          {availabilityError && (
            <div className="rounded-xl bg-red-50 px-3 py-2 text-xs text-red-700">
              {availabilityError}
            </div>
          )}
          {availabilitySavedAt && (
            <div className="rounded-xl bg-green-50 px-4 py-2 text-xs text-green-700">
              {g("setup_avail_saved")}
            </div>
          )}

          <button
            type="submit"
            disabled={savingAvailability}
            className={`rounded-full bg-${roleColor} px-5 py-2 text-sm font-semibold text-white disabled:opacity-60`}
          >
            {savingAvailability ? g("common_saving") : g("setup_avail_save")}
          </button>
        </form>
      </section>
    </div>
  );
}

// Jours de la semaine (clés alignées sur le backend : minuscules anglaises).
// 1011 — le libellé affiché vient de la table en 9 langues (clé `day_<key>`).
const DAYS: { key: AvailabilityTimeSlot["day"] }[] = [
  { key: "monday" },
  { key: "tuesday" },
  { key: "wednesday" },
  { key: "thursday" },
  { key: "friday" },
  { key: "saturday" },
  { key: "sunday" },
];

// Conversion ISO (renvoyé par le backend) → valeur d'input type=date (YYYY-MM-DD).
function isoToDateInput(iso: string): string {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return "";
  return d.toISOString().split("T")[0];
}

// Conversion valeur d'input type=date → ISO (le backend re-normalise en minuit UTC).
function dateInputToIso(dateInput: string): string {
  if (!dateInput) return "";
  const d = new Date(`${dateInput}T00:00:00.000Z`);
  if (isNaN(d.getTime())) return dateInput;
  return d.toISOString();
}

function HourSelect({
  value,
  onChange,
  min,
  max,
}: {
  value: number;
  onChange: (v: number) => void;
  min: number;
  max: number;
}) {
  const options: number[] = [];
  for (let h = min; h <= max; h++) options.push(h);
  // 25/09 (585, lot 2) — liste maison (le menu natif s'ouvrait en gris foncé).
  return (
    <SelectMenu
      size="sm"
      ariaLabel="h"
      className="w-[86px]"
      value={String(value)}
      onChange={(v) => onChange(parseInt(v, 10))}
      tone="sitter"
      options={options.map((h) => ({ value: String(h), label: `${String(h).padStart(2, "0")}h` }))}
    />
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
