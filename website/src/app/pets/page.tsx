"use client";

// v23.1 part 146 — Page "Mes animaux" : liste + création/édition/suppression.
// Owner only. Les autres rôles voient un message d'invitation à utiliser l'app.

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import BackLink from "@/components/BackLink";
import {
  ApiError,
  createPet,
  deletePet,
  getMyPets,
  getStoredUser,
  Pet,
  updatePet,
  uploadPetAvatar,
} from "@/lib/api";

type EditMode =
  | { mode: "closed" }
  | { mode: "new" }
  | { mode: "edit"; pet: Pet };

export default function PetsPage() {
  const { t } = useT();
  const router = useRouter();
  const [pets, setPets] = useState<Pet[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [editMode, setEditMode] = useState<EditMode>({ mode: "closed" });

  useEffect(() => {
    const user = getStoredUser();
    if (!user) {
      router.replace("/login");
      return;
    }
    if (user.role !== "owner") {
      setLoading(false);
      return;
    }
    refresh();
  }, [router]);

  async function refresh() {
    setLoading(true);
    setError(null);
    try {
      const list = await getMyPets();
      setPets(list);
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
        return;
      }
      setError(e instanceof Error ? e.message : "Failed to load pets");
    } finally {
      setLoading(false);
    }
  }

  async function handleDelete(id: string, name: string) {
    if (!confirm(`Supprimer ${name} ? Action irréversible.`)) return;
    try {
      await deletePet(id);
      setPets((p) => p.filter((x) => x.id !== id));
    } catch (e) {
      alert(e instanceof Error ? e.message : "Failed to delete");
    }
  }

  const user = getStoredUser();

  if (loading) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-24 text-center text-ink-muted">
        {t("common_loading")}
      </div>
    );
  }

  if (user?.role !== "owner") {
    return (
      <div className="mx-auto max-w-2xl px-4 py-24 text-center">
        <p className="text-lg font-semibold text-ink">Réservé aux propriétaires</p>
        <p className="mt-2 text-sm text-ink-muted">
          La gestion des animaux est disponible pour les comptes Owner uniquement.
        </p>
        <div className="mt-6">
          <BackLink href="/dashboard" label={t("nav_dashboard")} />
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl px-4 py-12 md:py-16">
      <div className="mb-6 flex items-center justify-between">
        <BackLink href="/dashboard" label={t("nav_dashboard")} />
        <button
          type="button"
          onClick={() => setEditMode({ mode: "new" })}
          className="rounded-full bg-owner px-5 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:opacity-90"
        >
          + Ajouter un animal
        </button>
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        Mes animaux
      </h1>
      <p className="mt-2 text-ink-muted">
        Tes compagnons sont aussi visibles dans l&apos;app HoPetSit.
      </p>

      {error && (
        <div className="mt-6 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {pets.length === 0 ? (
        <div className="mt-12 rounded-3xl border border-dashed border-ink/15 px-6 py-16 text-center">
          <p className="text-2xl">🐾</p>
          <p className="mt-3 font-semibold text-ink">Aucun animal pour l&apos;instant</p>
          <p className="mt-1 text-sm text-ink-muted">
            Ajoute ton premier compagnon pour pouvoir créer une réservation.
          </p>
          <button
            type="button"
            onClick={() => setEditMode({ mode: "new" })}
            className="mt-5 rounded-full bg-owner px-5 py-2.5 text-sm font-semibold text-white"
          >
            + Ajouter un animal
          </button>
        </div>
      ) : (
        <div className="mt-8 grid gap-4 md:grid-cols-2">
          {pets.map((pet) => (
            <PetCard
              key={pet.id}
              pet={pet}
              onEdit={() => setEditMode({ mode: "edit", pet })}
              onDelete={() => handleDelete(pet.id, pet.petName)}
              onPhotoChanged={(updated) => {
                setPets((list) =>
                  list.map((p) => (p.id === updated.id ? updated : p)),
                );
              }}
            />
          ))}
        </div>
      )}

      {editMode.mode !== "closed" && (
        <PetFormModal
          initial={editMode.mode === "edit" ? editMode.pet : undefined}
          onClose={() => setEditMode({ mode: "closed" })}
          onSaved={(pet) => {
            setPets((p) => {
              const idx = p.findIndex((x) => x.id === pet.id);
              if (idx >= 0) {
                const next = [...p];
                next[idx] = pet;
                return next;
              }
              return [pet, ...p];
            });
            setEditMode({ mode: "closed" });
          }}
        />
      )}
    </div>
  );
}

function PetCard({
  pet,
  onEdit,
  onDelete,
  onPhotoChanged,
}: {
  pet: Pet;
  onEdit: () => void;
  onDelete: () => void;
  onPhotoChanged: (updated: Pet) => void;
}) {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);

  async function handlePhotoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    setUploadError(null);
    try {
      const updated = await uploadPetAvatar(pet.id, file);
      onPhotoChanged(updated);
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : "Upload échoué");
      setTimeout(() => setUploadError(null), 4000);
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  }

  return (
    <div className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
      <div className="flex items-start gap-4">
        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          disabled={uploading}
          className="group relative h-16 w-16 shrink-0 overflow-hidden rounded-xl bg-ink/10 transition hover:opacity-90"
          aria-label={`Changer la photo de ${pet.petName}`}
        >
          {pet.avatar?.url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={pet.avatar.url} alt="" className="h-full w-full object-cover" />
          ) : (
            <span className="flex h-full w-full items-center justify-center text-2xl">🐶</span>
          )}
          <span
            className={`absolute inset-0 flex items-center justify-center bg-black/40 text-[10px] font-semibold text-white transition ${
              uploading ? "opacity-100" : "opacity-0 group-hover:opacity-100"
            }`}
          >
            {uploading ? "…" : "📸"}
          </span>
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          onChange={handlePhotoChange}
          className="hidden"
        />
        <div className="min-w-0 flex-1">
          <div className="truncate text-base font-bold text-ink">{pet.petName}</div>
          <div className="mt-0.5 text-xs text-ink-muted">
            {pet.category}
            {pet.breed ? ` · ${pet.breed}` : ""}
          </div>
          {pet.bio && (
            <p className="mt-2 line-clamp-2 text-xs text-ink-muted">{pet.bio}</p>
          )}
        </div>
      </div>
      {uploadError && (
        <div className="mt-2 rounded-lg bg-red-50 px-3 py-1.5 text-xs text-red-700">
          {uploadError}
        </div>
      )}
      <div className="mt-4 flex gap-2">
        <button
          type="button"
          onClick={onEdit}
          className="flex-1 rounded-full border border-ink/10 px-3 py-1.5 text-xs font-semibold text-ink hover:border-ink/30"
        >
          Modifier
        </button>
        <button
          type="button"
          onClick={onDelete}
          className="rounded-full border border-red-200 px-3 py-1.5 text-xs font-semibold text-red-600 hover:bg-red-50"
        >
          Supprimer
        </button>
      </div>
    </div>
  );
}

function PetFormModal({
  initial,
  onClose,
  onSaved,
}: {
  initial?: Pet;
  onClose: () => void;
  onSaved: (pet: Pet) => void;
}) {
  const [petName, setPetName] = useState(initial?.petName || "");
  const [category, setCategory] = useState(initial?.category || "Dog");
  const [breed, setBreed] = useState(initial?.breed || "");
  const [vaccination, setVaccination] = useState(initial?.vaccination || "");
  const [bio, setBio] = useState(initial?.bio || "");
  // v413 — parité app : fiche animal enrichie (synchro app↔web).
  const [gender, setGender] = useState(initial?.gender || "");
  const [weight, setWeight] = useState(initial?.weight || "");
  const [height, setHeight] = useState(initial?.height || "");
  const [character, setCharacter] = useState((initial?.characterTraits || []).join(", "));
  const [vaccinationStatus, setVaccinationStatus] = useState(initial?.vaccinationStatus || "");
  const [allergies, setAllergies] = useState(initial?.medicationAllergies || "");
  const [history, setHistory] = useState(initial?.history || "");
  const [habitsRemarks, setHabitsRemarks] = useState(
    (initial?.habits?.remarks as string) || "",
  );
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    try {
      const payload = {
        petName: petName.trim(),
        category: category.trim() || "Dog",
        breed: breed.trim() || undefined,
        vaccination: vaccination.trim() || "Up to date",
        bio: bio.trim() || undefined,
        // v413 — champs enrichis (mêmes clés que l'app → synchro).
        gender: gender || undefined,
        weight: weight.trim() || undefined,
        height: height.trim() || undefined,
        characterTraits: character.trim()
          ? character.split(",").map((s) => s.trim()).filter(Boolean)
          : undefined,
        vaccinationStatus: vaccinationStatus || undefined,
        medicationAllergies: allergies.trim() || undefined,
        history: history.trim() || undefined,
        habits: habitsRemarks.trim() ? { remarks: habitsRemarks.trim() } : undefined,
      };
      const saved = initial
        ? await updatePet(initial.id, payload)
        : await createPet(payload);
      onSaved(saved);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to save");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 p-0 md:items-center md:p-4"
      onClick={onClose}
    >
      <div
        className="w-full max-w-md rounded-t-3xl bg-white p-6 shadow-xl md:rounded-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-bold text-ink">
            {initial ? "Modifier l'animal" : "Nouvel animal"}
          </h2>
          <button
            type="button"
            onClick={onClose}
            className="text-2xl leading-none text-ink-muted hover:text-ink"
            aria-label="Fermer"
          >
            ×
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <Field label="Nom *">
            <input
              type="text"
              value={petName}
              onChange={(e) => setPetName(e.target.value)}
              required
              className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
          </Field>
          <Field label="Espèce *">
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            >
              <option value="Dog">Chien</option>
              <option value="Cat">Chat</option>
              <option value="Bird">Oiseau</option>
              <option value="Rabbit">Lapin</option>
              <option value="Reptile">Reptile</option>
              <option value="Other">Autre</option>
            </select>
          </Field>
          <Field label="Race">
            <input
              type="text"
              value={breed}
              onChange={(e) => setBreed(e.target.value)}
              placeholder="Labrador, Persan…"
              className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
          </Field>
          <Field label="Vaccinations">
            <input
              type="text"
              value={vaccination}
              onChange={(e) => setVaccination(e.target.value)}
              placeholder="À jour, rappel rage 2024…"
              className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
          </Field>
          <Field label="Description">
            <textarea
              value={bio}
              onChange={(e) => setBio(e.target.value)}
              rows={3}
              placeholder="Présentation de l'animal…"
              className="w-full resize-none rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
          </Field>

          {/* v413 — parité app : caractère / santé / habitudes (synchro). */}
          <div className="grid grid-cols-2 gap-3">
            <Field label="Sexe">
              <select
                value={gender}
                onChange={(e) => setGender(e.target.value)}
                className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
              >
                <option value="">—</option>
                <option value="male">Mâle</option>
                <option value="female">Femelle</option>
              </select>
            </Field>
            <Field label="Statut vaccinal">
              <select
                value={vaccinationStatus}
                onChange={(e) => setVaccinationStatus(e.target.value)}
                className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
              >
                <option value="">—</option>
                <option value="up_to_date">À jour</option>
                <option value="late">En retard</option>
                <option value="unknown">Inconnu</option>
              </select>
            </Field>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <Field label="Poids (kg)">
              <input
                type="text"
                value={weight}
                onChange={(e) => setWeight(e.target.value)}
                placeholder="ex. 12"
                className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
              />
            </Field>
            <Field label="Taille (cm)">
              <input
                type="text"
                value={height}
                onChange={(e) => setHeight(e.target.value)}
                placeholder="ex. 45"
                className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
              />
            </Field>
          </div>
          <Field label="Caractère (traits séparés par des virgules)">
            <input
              type="text"
              value={character}
              onChange={(e) => setCharacter(e.target.value)}
              placeholder="Affectueux, joueur, protecteur…"
              className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
          </Field>
          <Field label="Allergies / traitements">
            <input
              type="text"
              value={allergies}
              onChange={(e) => setAllergies(e.target.value)}
              placeholder="Aucune allergie connue…"
              className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
          </Field>
          <Field label="Histoire">
            <textarea
              value={history}
              onChange={(e) => setHistory(e.target.value)}
              rows={2}
              placeholder="Comment il est arrivé, son passé…"
              className="w-full resize-none rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
          </Field>
          <Field label="Habitudes / remarques">
            <textarea
              value={habitsRemarks}
              onChange={(e) => setHabitsRemarks(e.target.value)}
              rows={2}
              placeholder="Niveau d'énergie, alimentation, ce qu'il aime…"
              className="w-full resize-none rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
          </Field>

          {error && (
            <div className="rounded-xl bg-red-50 px-3 py-2 text-xs text-red-700">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={saving}
            className="w-full rounded-full bg-owner px-5 py-2.5 text-sm font-semibold text-white disabled:opacity-60"
          >
            {saving ? "Enregistrement…" : initial ? "Mettre à jour" : "Créer"}
          </button>
        </form>
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1 block text-xs font-semibold uppercase tracking-wider text-ink-muted">
        {label}
      </span>
      {children}
    </label>
  );
}
