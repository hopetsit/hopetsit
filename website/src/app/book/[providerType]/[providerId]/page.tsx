"use client";

// v23.1 part 146 — Page création de réservation depuis le site.
// URL: /book/sitter/<id> ou /book/walker/<id>
//
// Flow :
//   1. Charge le provider + les pets de l'owner
//   2. Owner choisit type de service, date, durée, pets concernés
//   3. POST /bookings → crée le booking en statut `pending`
//   4. Redirection vers /bookings pour suivre l'état
//   5. Le provider (sitter/walker) recevra la demande dans son app + via socket
//   6. Le paiement se fait depuis l'app (Airwallex hosted webview) une fois
//      le provider l'a acceptée. Sur le site, possible plus tard via /pay.

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError,
  createBooking,
  getMyPets,
  getProvider,
  getStoredUser,
  Pet,
  ProviderProfile,
} from "@/lib/api";

const SITTER_SERVICES = [
  { id: "Pet Sitting", label: "Pet Sitting (visites)" },
  { id: "House Sitting", label: "Garde à domicile" },
  { id: "Day Care", label: "Day Care" },
  { id: "Long Stay", label: "Long Stay" },
];

const WALKER_SERVICES = [
  { id: "Dog Walking", label: "Promenade simple" },
  { id: "Solo Walk", label: "Promenade solo" },
  { id: "Group Walk", label: "Promenade groupée" },
];

export default function BookPage() {
  const params = useParams<{ providerType: string; providerId: string }>();
  const providerType = params.providerType === "walker" ? "walker" : "sitter";
  const providerId = params.providerId;

  const { t } = useT();
  const router = useRouter();
  const [provider, setProvider] = useState<ProviderProfile | null>(null);
  const [pets, setPets] = useState<Pet[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);

  // Form state
  const services =
    providerType === "walker" ? WALKER_SERVICES : SITTER_SERVICES;
  const [serviceType, setServiceType] = useState(services[0].id);
  const [serviceDate, setServiceDate] = useState("");
  const [timeSlot, setTimeSlot] = useState("10:00");
  const [duration, setDuration] = useState(60);
  const [selectedPetIds, setSelectedPetIds] = useState<string[]>([]);
  const [description, setDescription] = useState("");

  useEffect(() => {
    const u = getStoredUser();
    if (!u) {
      router.replace("/login");
      return;
    }
    if (u.role !== "owner") {
      router.replace("/dashboard");
      return;
    }
    (async () => {
      try {
        const [p, myPets] = await Promise.all([
          getProvider(providerType, providerId),
          getMyPets(),
        ]);
        if (!p) {
          setError("Profil introuvable.");
          return;
        }
        setProvider(p);
        setPets(myPets);
        if (myPets.length === 1) {
          setSelectedPetIds([myPets[0].id]);
        }
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }
        setError(e instanceof Error ? e.message : "Loading failed");
      } finally {
        setLoading(false);
      }
    })();
  }, [router, providerType, providerId]);

  function togglePet(id: string) {
    setSelectedPetIds((curr) =>
      curr.includes(id) ? curr.filter((x) => x !== id) : [...curr, id],
    );
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!provider || selectedPetIds.length === 0) {
      setError("Sélectionne au moins un animal.");
      return;
    }
    setCreating(true);
    setError(null);
    try {
      await createBooking({
        providerType,
        providerId: provider.id,
        petIds: selectedPetIds,
        serviceType,
        serviceDate,
        startDate: serviceDate,
        duration,
        timeSlot,
        description: description.trim(),
      });
      // Redirige vers /bookings — le provider verra la demande dans son
      // app (notification push + socket booking:new dans /bookings).
      router.push("/bookings");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to create booking");
    } finally {
      setCreating(false);
    }
  }

  if (loading) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-24 text-center text-ink-muted">
        {t("common_loading")}
      </div>
    );
  }

  if (!provider) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-24">
        <Link href="/search" className="text-sm text-ink-muted hover:text-ink">
          ← Recherche
        </Link>
        <p className="mt-6 text-center text-ink-muted">{error || "Profil introuvable"}</p>
      </div>
    );
  }

  const color = providerType === "walker" ? "walker" : "sitter";
  const startingPrice =
    providerType === "walker"
      ? provider.walkRates?.walkSolo30 || provider.hourlyRate
      : provider.hourlyRate;

  return (
    <div className="mx-auto max-w-2xl px-4 py-12 md:py-16">
      <div className="mb-6">
        <Link href="/search" className="text-sm text-ink-muted hover:text-ink">
          ← Retour à la recherche
        </Link>
      </div>

      {/* Profil provider */}
      <div className={`rounded-3xl bg-${color} p-6 text-white shadow-card`}>
        <div className="flex items-start gap-4">
          <div className="flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-full bg-white/20 text-2xl font-bold">
            {provider.avatar?.url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={provider.avatar.url} alt="" className="h-full w-full object-cover" />
            ) : (
              provider.name?.charAt(0).toUpperCase() || "?"
            )}
          </div>
          <div className="min-w-0 flex-1">
            <div className="text-xs uppercase tracking-wider opacity-80">
              {providerType}
            </div>
            <div className="truncate text-xl font-bold">{provider.name}</div>
            {provider.location?.city && (
              <div className="text-xs opacity-90">📍 {provider.location.city}</div>
            )}
            {startingPrice && (
              <div className="mt-1 text-sm">
                À partir de <span className="font-bold">{startingPrice} €</span>
              </div>
            )}
          </div>
        </div>
        {provider.bio && (
          <p className="mt-4 text-sm text-white/90">{provider.bio}</p>
        )}
      </div>

      <h1 className="mt-8 font-display text-2xl font-extrabold md:text-3xl">
        Détails de la réservation
      </h1>

      {error && (
        <div className="mt-4 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {pets.length === 0 ? (
        <div className="mt-6 rounded-2xl border border-amber-200 bg-amber-50 px-5 py-4 text-sm text-amber-900">
          Tu n&apos;as pas encore d&apos;animaux enregistrés.{" "}
          <Link href="/pets" className="font-semibold underline">
            Ajoute ton premier compagnon
          </Link>{" "}
          puis reviens ici.
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="mt-6 space-y-5">
          {/* Pets selection */}
          <Field label="Animal(aux) concerné(s) *">
            <div className="space-y-2">
              {pets.map((pet) => (
                <label
                  key={pet.id}
                  className={`flex cursor-pointer items-center gap-3 rounded-xl border px-3 py-2 transition ${
                    selectedPetIds.includes(pet.id)
                      ? `border-${color} bg-${color}/5`
                      : "border-ink/15 hover:border-ink/30"
                  }`}
                >
                  <input
                    type="checkbox"
                    checked={selectedPetIds.includes(pet.id)}
                    onChange={() => togglePet(pet.id)}
                    className="h-4 w-4"
                  />
                  <span className="flex h-10 w-10 items-center justify-center overflow-hidden rounded-lg bg-ink/10 text-lg">
                    {pet.avatar?.url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={pet.avatar.url} alt="" className="h-full w-full object-cover" />
                    ) : (
                      "🐶"
                    )}
                  </span>
                  <span className="flex-1 text-sm font-semibold text-ink">
                    {pet.petName}
                    {pet.breed && <span className="ml-1 font-normal text-ink-muted">· {pet.breed}</span>}
                  </span>
                </label>
              ))}
            </div>
          </Field>

          <Field label="Type de service *">
            <select
              value={serviceType}
              onChange={(e) => setServiceType(e.target.value)}
              className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-walker focus:outline-none focus:ring-2 focus:ring-walker/20"
            >
              {services.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.label}
                </option>
              ))}
            </select>
          </Field>

          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Date *">
              <input
                type="date"
                value={serviceDate}
                onChange={(e) => setServiceDate(e.target.value)}
                required
                min={new Date().toISOString().split("T")[0]}
                className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-walker focus:outline-none focus:ring-2 focus:ring-walker/20"
              />
            </Field>
            <Field label="Heure">
              <input
                type="time"
                value={timeSlot}
                onChange={(e) => setTimeSlot(e.target.value)}
                className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-walker focus:outline-none focus:ring-2 focus:ring-walker/20"
              />
            </Field>
          </div>

          <Field label="Durée (minutes)">
            <input
              type="number"
              value={duration}
              onChange={(e) => setDuration(parseInt(e.target.value, 10) || 60)}
              min="15"
              step="15"
              className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-walker focus:outline-none focus:ring-2 focus:ring-walker/20"
            />
          </Field>

          <Field label="Message au provider (optionnel)">
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={3}
              placeholder="Précise tes consignes, habitudes de ton animal…"
              className="w-full resize-none rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-walker focus:outline-none focus:ring-2 focus:ring-walker/20"
            />
          </Field>

          <div className="rounded-xl bg-bg-soft px-4 py-3 text-xs text-ink-muted">
            ℹ️ Cette demande sera envoyée à <span className="font-semibold">{provider.name}</span>.
            Une fois acceptée, tu pourras payer depuis l&apos;app HoPetSit. Le provider est notifié en temps réel.
          </div>

          <button
            type="submit"
            disabled={creating || selectedPetIds.length === 0}
            className={`w-full rounded-full bg-${color} px-5 py-3 text-sm font-semibold text-white shadow-sm disabled:cursor-not-allowed disabled:opacity-60`}
          >
            {creating ? "Envoi…" : `Envoyer la demande à ${provider.name}`}
          </button>
        </form>
      )}
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-xs font-semibold uppercase tracking-wider text-ink-muted">
        {label}
      </span>
      {children}
    </label>
  );
}
