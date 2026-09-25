"use client";

// v23.1 part 146 — Page création de réservation depuis le site.
// URL: /book/sitter/<id> ou /book/walker/<id> (?service=… &duration=…)
//
// 25/09/2026 (PawMap 585, lot 2 — bug 16, capture de Daniel) :
//   · le <select> natif « Type de service » s'ouvrait en GRIS FONCÉ → liste
//     maison (components/SelectMenu) ;
//   · « Pet Sitting (visites) », « Day Care », « Long Stay », « Message au
//     provider » : tout passe par les traductions (9 langues), plus aucun
//     texte en dur ;
//   · les valeurs envoyées étaient « Pet Sitting », « House Sitting »… et
//     « House Sitting » était REFUSÉ par le serveur (400 : houseSittingVenue
//     requis) → valeurs canoniques du serveur, lieu demandé pour la garde à
//     domicile ;
//   · même formulaire que l'app : gardien = garde à domicile / visites /
//     garderie / long séjour ; promeneur = 30 min / 1 h / 2 h ;
//   · prix estimé (port du calcul serveur, lib/bookingEstimate.ts).
//
// Flow inchangé : POST /bookings → statut `pending` → /bookings ; le
// prestataire reçoit la demande (push + socket) ; paiement après acceptation.

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import BackLink from "@/components/BackLink";
import { AppIcon, type AppIconName } from "@/components/AppIcon";
import { SelectMenu } from "@/components/SelectMenu";
import { SignatureButton } from "@/components/SignatureButton";
import {
  ApiError,
  createBooking,
  getMyPets,
  getProvider,
  getProviderAvailability,
  getStoredUser,
  Pet,
  ProviderProfile,
} from "@/lib/api";
import { formatMoney, providerCurrency, providerFrom } from "@/lib/providerRates";
import {
  SITTER_SERVICES,
  VISIT_DURATIONS,
  WALK_DURATIONS,
  bookingWindow,
  daysBetween,
  estimateBooking,
  type BookService,
} from "@/lib/bookingEstimate";

const ROLE = {
  sitter: { accent: "#2563EB", dark: "#1E4FB0", pale: "#DCE8FD", grad: "linear-gradient(135deg,#2F6FD6,#1E4FB0)" },
  walker: { accent: "#16A34A", dark: "#15803D", pale: "#D9F5E3", grad: "linear-gradient(135deg,#2FAE4E,#15803D)" },
} as const;

const SERVICE_ICON: Record<BookService, AppIconName> = {
  house_sitting: "home",
  home_visit: "clock",
  day_care: "pets",
  long_stay: "calendar",
  dog_walking: "walker",
};

const todayIso = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
};
const addDaysIso = (iso: string, n: number) => {
  const d = new Date(`${iso}T12:00:00`);
  d.setDate(d.getDate() + n);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
};

export default function BookPage() {
  const params = useParams<{ providerType: string; providerId: string }>();
  const providerType: "sitter" | "walker" = params.providerType === "walker" ? "walker" : "sitter";
  const providerId = params.providerId;
  const c = ROLE[providerType];

  const { t, lang } = useT();
  const router = useRouter();
  const [provider, setProvider] = useState<ProviderProfile | null>(null);
  const [pets, setPets] = useState<Pet[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);

  // ── Formulaire (pré-rempli : ?service= / ?duration= depuis la carte ou la fiche).
  const [service, setService] = useState<BookService>(providerType === "walker" ? "dog_walking" : "house_sitting");
  const [venue, setVenue] = useState<"" | "owners_home" | "sitters_home">("owners_home");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [startTime, setStartTime] = useState("10:00");
  const [duration, setDuration] = useState<number>(60);
  const [selectedPetIds, setSelectedPetIds] = useState<string[]>([]);
  const [description, setDescription] = useState("");
  const [blockedDates, setBlockedDates] = useState<Set<string>>(new Set());

  useEffect(() => {
    try {
      const qs = new URLSearchParams(window.location.search);
      const s = qs.get("service");
      if (providerType === "sitter" && s && (SITTER_SERVICES as string[]).includes(s)) setService(s as BookService);
      const d = parseInt(qs.get("duration") || "", 10);
      if (Number.isFinite(d) && d > 0) setDuration(d);
    } catch { /* ignore */ }
  }, [providerType]);

  useEffect(() => {
    const u = getStoredUser();
    if (!u) {
      router.replace(`/login?next=${encodeURIComponent(`/book/${providerType}/${providerId}`)}`);
      return;
    }
    if (u.role !== "owner") {
      router.replace("/dashboard");
      return;
    }
    (async () => {
      try {
        const [p, myPets, availability] = await Promise.all([
          getProvider(providerType, providerId),
          getMyPets(),
          getProviderAvailability(providerType, providerId).catch(() => null),
        ]);
        if (!p) {
          setError(t("book_not_found"));
          return;
        }
        setProvider(p);
        setPets(myPets);
        if (myPets.length === 1) setSelectedPetIds([myPets[0].id]);
        const blocked = new Set<string>(
          (availability?.unavailableDates || [])
            .map((iso) => {
              const d = new Date(iso);
              return isNaN(d.getTime()) ? "" : d.toISOString().split("T")[0];
            })
            .filter(Boolean),
        );
        setBlockedDates(blocked);
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }
        setError(t("book_err_generic"));
      } finally {
        setLoading(false);
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [router, providerType, providerId]);

  const multiDay = service === "house_sitting" || service === "long_stay";
  // La durée proposée dépend du service (promenade 30/60/120, visite 30/60).
  const durations: readonly number[] = service === "dog_walking" ? WALK_DURATIONS : service === "home_visit" ? VISIT_DURATIONS : [];
  useEffect(() => {
    if (durations.length && !durations.includes(duration)) setDuration(durations.includes(60) ? 60 : durations[0]);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [service]);
  // Long séjour : une semaine par défaut dès que la date de début est choisie.
  useEffect(() => {
    if (!multiDay || !startDate) return;
    if (!endDate || endDate <= startDate) setEndDate(addDaysIso(startDate, service === "long_stay" ? 7 : 1));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [startDate, service]);

  const currency = provider ? providerCurrency(provider) : "EUR";
  const estimate = useMemo(() => {
    if (!provider) return null;
    return estimateBooking(provider, {
      role: providerType,
      service,
      startDate,
      startTime,
      endDate: multiDay ? endDate : undefined,
      durationMinutes: durations.length ? duration : undefined,
      pets: Math.max(1, selectedPetIds.length),
    });
  }, [provider, providerType, service, startDate, startTime, endDate, multiDay, duration, durations.length, selectedPetIds.length]);
  const hasAnyRate = !!provider && (providerType === "walker"
    ? (provider.walkRates || []).some((r) => r.enabled !== false && (r.basePrice || 0) > 0) || (provider.hourlyRate || 0) > 0
    : [provider.hourlyRate, provider.dailyRate, provider.weeklyRate, provider.monthlyRate].some((x) => (x || 0) > 0));

  function togglePet(id: string) {
    setSelectedPetIds((curr) => (curr.includes(id) ? curr.filter((x) => x !== id) : [...curr, id]));
  }

  function validate(): string | null {
    if (selectedPetIds.length === 0) return t("book_err_pick_pet");
    if (!startDate) return t("book_err_date");
    if (blockedDates.has(startDate)) return t("book_date_unavailable");
    if (service === "house_sitting" && !venue) return t("book_err_venue");
    if (multiDay && (!endDate || endDate <= startDate)) return t("book_err_dates");
    return null;
  }

  async function handleSubmit() {
    if (!provider) return;
    const v = validate();
    if (v) { setError(v); return; }
    const win = bookingWindow({ role: providerType, service, startDate, startTime, endDate: multiDay ? endDate : undefined, durationMinutes: durations.length ? duration : undefined, pets: selectedPetIds.length });
    if (!win) { setError(t("book_err_dates")); return; }
    setCreating(true);
    setError(null);
    try {
      await createBooking({
        providerType,
        providerId: provider.id,
        petIds: selectedPetIds,
        serviceType: service,
        serviceDate: startDate,
        startDate: win.start.toISOString(),
        endDate: win.end.toISOString(),
        duration: durations.length ? duration : undefined,
        timeSlot: startTime,
        description: description.trim(),
        houseSittingVenue: service === "house_sitting" ? venue || undefined : undefined,
      });
      router.push("/bookings");
    } catch (e) {
      const msg = e instanceof Error ? e.message : "";
      const code = e instanceof ApiError ? String((e.details as { code?: string } | undefined)?.code || "") : "";
      if (code === "MIN_DURATION_DAY_CARE") setError(t("book_err_min5h"));
      else if (code === "INVALID_WALK_DURATION") setError(t("book_err_walk_duration"));
      else if (/at least one (walk )?rate/i.test(msg)) setError(t("book_err_no_rate"));
      else if (e instanceof ApiError && e.status === 401) router.replace("/login");
      else setError(t("book_err_generic"));
    } finally {
      setCreating(false);
    }
  }

  if (loading) {
    return <div className="mx-auto max-w-2xl px-4 py-24 text-center text-[#6E4F48]">{t("common_loading")}</div>;
  }

  if (!provider) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-24">
        <BackLink href="/search" label={t("book_back_search")} />
        <p className="mt-6 text-center text-[#6E4F48]">{error || t("book_not_found")}</p>
      </div>
    );
  }

  const from = providerFrom(providerType, provider);
  const completed = providerType === "walker" ? provider.completedWalksCount ?? provider.completedServicesCount : provider.completedServicesCount;
  const animalLabels: Record<string, string> = {
    dog: t("posts_animal_dog"), cat: t("posts_animal_cat"), nac: t("posts_animal_nac"), small: t("posts_animal_nac"),
    bird: t("posts_animal_bird"), reptile: t("posts_animal_reptile"), other: t("posts_animal_other"),
  };
  const serviceIds: BookService[] = providerType === "walker" ? ["dog_walking"] : SITTER_SERVICES;
  const serviceOptions = serviceIds.map((s) => ({
    value: s,
    label: t(`book_svc_${s}`),
    sub: t(`book_svc_${s}_sub`),
    icon: <span className="grid h-8 w-8 place-items-center rounded-full" style={{ background: c.pale }}><AppIcon name={SERVICE_ICON[s]} size={17} color={c.dark} /></span>,
  }));
  const durLabel = (m: number) => (m === 30 ? t("unit_30") : m === 60 ? t("unit_60") : m === 120 ? t("unit_120") : `${m} min`);
  const nights = multiDay && startDate && endDate ? daysBetween(startDate, endDate) : 0;
  const inputCls = "w-full min-h-[46px] rounded-[14px] border border-[#EAD6CB] bg-white px-3.5 text-sm font-semibold text-[#231715] outline-none transition focus:border-current focus:ring-2";
  const minDate = todayIso();
  const firstName = (provider.name || "").split(" ")[0] || provider.name;

  return (
    <div className="mx-auto max-w-2xl px-4 py-10 md:py-14">
      <div className="mb-6">
        <BackLink href="/search" label={t("book_back_search")} />
      </div>

      {/* Profil du prestataire. */}
      <div className="rounded-[26px] p-5 text-white shadow-[0_18px_40px_-18px_rgba(30,79,176,0.55)] md:p-6" style={{ background: c.grad }}>
        <div className="flex items-start gap-4">
          <div className="grid h-16 w-16 shrink-0 place-items-center overflow-hidden rounded-full border-[3px] border-white text-2xl font-bold" style={{ background: c.dark }}>
            {provider.avatar?.url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={provider.avatar.url} alt="" className="h-full w-full object-cover" />
            ) : (
              provider.name?.charAt(0).toUpperCase() || "?"
            )}
          </div>
          <div className="min-w-0 flex-1">
            <div className="text-xs font-bold uppercase tracking-wider text-white">{t(`role_${providerType}`)}</div>
            <div className="truncate font-display text-xl font-bold">{provider.name}</div>
            {provider.location?.city && (
              <div className="mt-0.5 inline-flex items-center gap-1 text-xs font-semibold text-white"><AppIcon name="pin" size={13} color="#fff" />{provider.location.city}</div>
            )}
            {from && (
              <div className="mt-1 text-sm font-semibold">
                {t("book_from").replace("{price}", `${formatMoney(from.value, currency, lang)}/${t(from.unitKey)}`)}
              </div>
            )}
          </div>
        </div>
        {provider.bio && <p className="mt-4 text-sm leading-relaxed text-white">{provider.bio}</p>}
      </div>

      {/* Stats + animaux acceptés. */}
      <div className="mt-4 space-y-4">
        {(completed || provider.responseTimeMinutes != null || (provider.reviewsCount ?? 0) > 0) && (
          <div className="grid grid-cols-3 gap-3">
            <Stat value={completed ? String(completed) : "—"} label={providerType === "walker" ? t("book_stat_walks") : t("book_stat_services")} />
            <Stat value={provider.responseTimeMinutes != null ? t("book_response_under").replace("@n", String(provider.responseTimeMinutes)) : "—"} label={t("book_stat_response")} />
            <Stat
              value={(provider.averageRating ?? provider.rating ?? 0) > 0 ? `★ ${(provider.averageRating ?? provider.rating ?? 0).toFixed(1)}` : "—"}
              label={provider.reviewsCount ? t("book_stat_reviews").replace("@n", String(provider.reviewsCount)) : t("book_stat_rating")}
            />
          </div>
        )}
        {(provider.acceptedPetTypes || []).length > 0 && (
          <div className="rounded-[20px] bg-white p-4 shadow-[0_10px_28px_-18px_rgba(120,53,15,0.4)]">
            <p className="mb-2 text-sm font-bold text-[#231715]">{providerType === "walker" ? t("book_walked_animals") : t("book_accepted_animals")}</p>
            <div className="flex flex-wrap gap-1.5">
              {(provider.acceptedPetTypes || []).map((a) => (
                <span key={a} className="rounded-full px-2.5 py-1 text-xs font-semibold" style={{ background: c.pale, color: c.dark }}>{animalLabels[a] || a}</span>
              ))}
            </div>
          </div>
        )}
      </div>

      <h1 className="mt-8 font-display text-2xl font-extrabold text-[#231715] md:text-3xl">{t("book_reservation_details")}</h1>

      {pets.length === 0 ? (
        <div className="mt-6 rounded-[20px] bg-[#FFF4E5] px-5 py-4 text-sm text-[#7A3E06]">
          {t("book_no_pets")}{" "}
          <Link href="/pets" className="font-bold underline">{t("book_add_pet_cta")}</Link>
        </div>
      ) : (
        <form onSubmit={(e) => { e.preventDefault(); void handleSubmit(); }} className="mt-6 space-y-5" noValidate>
          {/* Animaux. */}
          <Field label={`${t("book_pets_label")} *`}>
            <div className="space-y-2">
              {pets.map((pet) => {
                const on = selectedPetIds.includes(pet.id);
                return (
                  <button
                    type="button"
                    key={pet.id}
                    onClick={() => togglePet(pet.id)}
                    aria-pressed={on}
                    className="flex min-h-[56px] w-full items-center gap-3 rounded-[16px] border-[1.5px] bg-white px-3 py-2 text-left transition"
                    style={{ borderColor: on ? c.accent : "#EAD6CB", background: on ? c.pale : "#FFFFFF" }}
                  >
                    <span className="grid h-6 w-6 shrink-0 place-items-center rounded-md border-2" style={{ borderColor: on ? c.accent : "#D9C2B7", background: on ? c.accent : "#fff" }}>
                      {on && <AppIcon name="check" size={14} color="#fff" />}
                    </span>
                    <span className="grid h-10 w-10 shrink-0 place-items-center overflow-hidden rounded-xl" style={{ background: c.pale }}>
                      {pet.avatar?.url ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={pet.avatar.url} alt="" className="h-full w-full object-cover" />
                      ) : (
                        <AppIcon name="paw" size={20} color={c.dark} />
                      )}
                    </span>
                    <span className="min-w-0 flex-1 truncate text-sm font-bold text-[#231715]">
                      {pet.petName}
                      {pet.breed && <span className="ml-1 font-medium text-[#6E4F48]">· {pet.breed}</span>}
                    </span>
                  </button>
                );
              })}
            </div>
          </Field>

          {/* Service. */}
          <Field label={`${t("book_service_label")} *`} id="svc">
            <SelectMenu labelledBy="svc-label" value={service} onChange={(v) => setService(v as BookService)} options={serviceOptions} tone={providerType} />
          </Field>

          {service === "house_sitting" && (
            <Field label={`${t("book_venue_label")} *`}>
              <div className="grid grid-cols-2 gap-2">
                {(["owners_home", "sitters_home"] as const).map((vn) => (
                  <button key={vn} type="button" onClick={() => setVenue(vn)} aria-pressed={venue === vn} className="min-h-[46px] rounded-[14px] border-[1.5px] px-3 text-sm font-bold transition" style={venue === vn ? { background: c.accent, borderColor: c.accent, color: "#fff" } : { background: "#fff", borderColor: "#EAD6CB", color: c.dark }}>
                    {vn === "owners_home" ? t("book_venue_owner") : t("book_venue_sitter")}
                  </button>
                ))}
              </div>
            </Field>
          )}

          {durations.length > 0 && (
            <Field label={t("book_duration_label")}>
              <div className="grid grid-cols-3 gap-2">
                {durations.map((m) => (
                  <button key={m} type="button" onClick={() => setDuration(m)} aria-pressed={duration === m} className="min-h-[46px] rounded-[14px] border-[1.5px] px-3 text-sm font-bold transition" style={duration === m ? { background: c.accent, borderColor: c.accent, color: "#fff" } : { background: "#fff", borderColor: "#EAD6CB", color: c.dark }}>
                    {durLabel(m)}
                  </button>
                ))}
              </div>
            </Field>
          )}

          {/* Dates. */}
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label={`${multiDay ? t("book_start_date") : t("book_date")} *`}>
              <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} min={minDate} className={inputCls} style={{ color: "#231715", borderColor: startDate && blockedDates.has(startDate) ? "#D32F2F" : undefined }} />
              {startDate && blockedDates.has(startDate) && <p className="mt-1 text-xs font-semibold text-[#B42318]">{t("book_date_unavailable")}</p>}
              {blockedDates.size > 0 && <p className="mt-1 text-[11px] text-[#8A6B64]">{t("book_unavailable_hint")}</p>}
            </Field>
            {multiDay ? (
              <Field label={`${t("book_end_date")} *`}>
                <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} min={startDate ? addDaysIso(startDate, 1) : minDate} className={inputCls} />
                {nights > 0 && <p className="mt-1 text-[11px] font-semibold" style={{ color: c.dark }}>{t("book_nights").replace("{n}", String(nights))}</p>}
              </Field>
            ) : (
              <Field label={t("book_time")}>
                <input type="time" value={startTime} onChange={(e) => setStartTime(e.target.value)} className={inputCls} />
              </Field>
            )}
          </div>

          <Field label={providerType === "walker" ? t("book_message_walker") : t("book_message_sitter")}>
            <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3} placeholder={t("book_message_ph")} className="w-full resize-none rounded-[14px] border border-[#EAD6CB] bg-white px-3.5 py-3 text-sm text-[#231715] outline-none placeholder:text-[#B08F84] focus:ring-2" />
          </Field>

          {/* Prix estimé. */}
          <div className="rounded-[20px] p-4" style={{ background: c.pale }}>
            <div className="flex items-baseline justify-between gap-3">
              <span className="text-sm font-bold" style={{ color: c.dark }}>{t("book_estimate_label")}</span>
              <span className="font-display text-2xl font-extrabold" style={{ color: c.dark }}>{estimate != null ? formatMoney(estimate, currency, lang) : "—"}</span>
            </div>
            <p className="mt-1 text-xs leading-snug" style={{ color: c.dark }}>
              {!hasAnyRate
                ? t("book_estimate_none").replace(/\{name\}/g, firstName)
                : estimate == null
                  ? t("book_estimate_missing")
                  : t("book_estimate_note").replace(/\{name\}/g, firstName)}
            </p>
          </div>

          <p className="rounded-[16px] bg-[#FFF7F2] px-4 py-3 text-xs leading-snug text-[#6E4F48]">
            {t("book_info_sent").replace("{name}", firstName)}
          </p>

          {error && <div role="alert" className="rounded-[14px] bg-[#FDE8E4] px-4 py-3 text-sm font-semibold text-[#9E1F0B]">{error}</div>}

          <SignatureButton
            type="submit"
            tone={providerType}
            icon="calendar"
            earns
            loading={creating}
            label={creating ? t("book_sending") : t("book_submit").replace("{name}", firstName)}
            price={estimate != null && !creating ? formatMoney(estimate, currency, lang) : undefined}
          />
        </form>
      )}
    </div>
  );
}

function Field({ label, children, id }: { label: string; children: React.ReactNode; id?: string }) {
  return (
    <div className="block">
      <span id={id ? `${id}-label` : undefined} className="mb-1.5 block text-xs font-bold uppercase tracking-wider text-[#6E4F48]">{label}</span>
      {children}
    </div>
  );
}

function Stat({ value, label }: { value: string; label: string }) {
  return (
    <div className="rounded-[18px] bg-white p-3 text-center shadow-[0_10px_28px_-18px_rgba(120,53,15,0.4)]">
      <p className="text-base font-extrabold text-[#231715]">{value}</p>
      <p className="mt-0.5 text-[11px] leading-tight text-[#6E4F48]">{label}</p>
    </div>
  );
}
