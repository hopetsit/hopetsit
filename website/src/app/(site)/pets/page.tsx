"use client";

// v23.1 part 146 — Page "Mes animaux" : liste + création/édition/suppression.
// Owner only. Les autres rôles voient un message d'invitation à utiliser l'app.

import Link from "@/components/SiteLink";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
// 1011 (ZOE, ordre de Daniel « les pages ne sont pas à jour dans les autres langues ») — textes en 9 langues.
import { g1011 } from "@/lib/i18n/langues1011";
import { k1011 } from "@/lib/i18n/conclure1011";
import { breedSuggestions639 } from "@/lib/breeds639";
import { SelectMenu } from "@/components/SelectMenu";
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
  const { t, lang } = useT();
  const g = (k: string, vars?: Record<string, string | number>) => g1011(lang, k, vars);
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
    if (!confirm(g("pets_del_confirm", { name }))) return;
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
        <p className="text-lg font-semibold text-ink">{g("pets_owner_only")}</p>
        <p className="mt-2 text-sm text-ink-muted">
          {g("pets_owner_only_sub")}
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
          {g("pets_add")}
        </button>
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        {g("pets_title")}
      </h1>
      <p className="mt-2 text-ink-muted">
        {g("pets_sub")}
      </p>

      {error && (
        <div className="mt-6 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {pets.length === 0 ? (
        <div className="mt-12 rounded-3xl border border-dashed border-ink/15 px-6 py-16 text-center">
          <p className="text-2xl">🐾</p>
          <p className="mt-3 font-semibold text-ink">{g("pets_empty")}</p>
          <p className="mt-1 text-sm text-ink-muted">
            {g("pets_empty_sub")}
          </p>
          <button
            type="button"
            onClick={() => setEditMode({ mode: "new" })}
            className="mt-5 rounded-full bg-owner px-5 py-2.5 text-sm font-semibold text-white"
          >
            {g("pets_add")}
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
  const { lang } = useT();
  const g = (k: string, vars?: Record<string, string | number>) => g1011(lang, k, vars);
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
      setUploadError(err instanceof Error ? err.message : g("pets_upload_failed"));
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
          aria-label={g("pets_photo_aria", { name: pet.petName })}
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
          {g("common_edit")}
        </button>
        <button
          type="button"
          onClick={onDelete}
          className="rounded-full border border-red-200 px-3 py-1.5 text-xs font-semibold text-red-600 hover:bg-red-50"
        >
          {g("common_delete")}
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
  const { t, lang } = useT();
  const g = (k: string, vars?: Record<string, string | number>) => g1011(lang, k, vars);
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
      {/* 639 — la fiche dépasse la hauteur d'un téléphone (1 096 px mesurés) : sans hauteur maximale ni
          défilement, le haut du formulaire (nom, espèce) sortait de l'écran et restait inatteignable.
          La hauteur laisse 72 px en haut : le titre et la croix restent sous l'en-tête du site, jamais derrière. */}
      <div
        className="max-h-[calc(100vh-4.5rem)] w-full max-w-md overflow-y-auto overscroll-contain rounded-t-3xl bg-white p-6 shadow-xl supports-[height:100dvh]:max-h-[calc(100dvh-4.5rem)] md:max-h-[calc(100vh-9rem)] md:rounded-2xl md:supports-[height:100dvh]:max-h-[calc(100dvh-9rem)]"
        onClick={(e) => e.stopPropagation()}
        data-testid="pet-form-panel-639"
      >
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-bold text-ink">
            {initial ? g("pets_form_edit") : g("pets_form_new")}
          </h2>
          <button
            type="button"
            onClick={onClose}
            className="text-2xl leading-none text-ink-muted hover:text-ink"
            aria-label={g("common_close")}
          >
            ×
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <Field label={g("pets_f_name")}>
            <input
              type="text"
              value={petName}
              onChange={(e) => setPetName(e.target.value)}
              required
              className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
          </Field>
          <Field label={g("pets_f_species")}>
            <SelectMenu
              ariaLabel={g("pets_f_species_aria")}
              value={category}
              onChange={setCategory}
              tone="owner"
              options={[
                { value: "Dog", label: t("posts_animal_dog") },
                { value: "Cat", label: t("posts_animal_cat") },
                { value: "Bird", label: t("posts_animal_bird") },
                { value: "Rabbit", label: t("pet_cat_rabbit") },
                { value: "Reptile", label: t("posts_animal_reptile") },
                { value: "Other", label: t("posts_animal_other") },
              ]}
            />
          </Field>
          <Field label={g("pets_f_breed")}>
            {/* 639 (CONTRATS §3) — races courantes en suggestion (chien / chat selon l'espèce) ; la saisie
                reste libre et facultative, rien n'est validé contre la liste. */}
            <input
              type="text"
              value={breed}
              onChange={(e) => setBreed(e.target.value)}
              placeholder={g("pets_f_breed_ph")}
              list={breedSuggestions639(category, lang).length ? "pet-breeds-639" : undefined}
              autoComplete="off"
              data-testid="pet-breed-639"
              className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
            {breedSuggestions639(category, lang).length > 0 && (
              <>
                <datalist id="pet-breeds-639">
                  {breedSuggestions639(category, lang).map((b) => (
                    <option key={b} value={b} />
                  ))}
                </datalist>
                <span className="mt-1 block text-xs leading-snug text-[#6E4F48]" data-testid="pet-breed-hint-639">
                  {k1011(lang, "f639_breed_suggest")}
                </span>
              </>
            )}
          </Field>
          <Field label={g("pets_f_vacc")}>
            <input
              type="text"
              value={vaccination}
              onChange={(e) => setVaccination(e.target.value)}
              placeholder={g("pets_f_vacc_ph")}
              className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
          </Field>
          <Field label={g("pets_f_desc")}>
            <textarea
              value={bio}
              onChange={(e) => setBio(e.target.value)}
              rows={3}
              placeholder={g("pets_f_desc_ph")}
              className="w-full resize-none rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
          </Field>

          {/* v413 — parité app : caractère / santé / habitudes (synchro). */}
          <div className="grid grid-cols-2 gap-3">
            <Field label={g("pets_f_sex")}>
              <SelectMenu
                ariaLabel={g("pets_f_sex")}
                value={gender}
                onChange={setGender}
                tone="owner"
                options={[
                  { value: "", label: "—" },
                  { value: "male", label: t("pet_gender_male") },
                  { value: "female", label: t("pet_gender_female") },
                ]}
              />
            </Field>
            <Field label={g("pets_f_vacc_status")}>
              <SelectMenu
                ariaLabel={g("pets_f_vacc_status")}
                value={vaccinationStatus}
                onChange={setVaccinationStatus}
                tone="owner"
                options={[
                  { value: "", label: "—" },
                  { value: "up_to_date", label: t("pet_vacc_up_to_date") },
                  { value: "late", label: t("pet_vacc_late") },
                  { value: "unknown", label: t("pet_vacc_unknown") },
                ]}
              />
            </Field>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <Field label={g("pets_f_weight")}>
              <input
                type="text"
                value={weight}
                onChange={(e) => setWeight(e.target.value)}
                placeholder={g("pets_f_weight_ph")}
                className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
              />
            </Field>
            <Field label={g("pets_f_height")}>
              <input
                type="text"
                value={height}
                onChange={(e) => setHeight(e.target.value)}
                placeholder={g("pets_f_height_ph")}
                className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
              />
            </Field>
          </div>
          <Field label={g("pets_f_traits")}>
            <input
              type="text"
              value={character}
              onChange={(e) => setCharacter(e.target.value)}
              placeholder={g("pets_f_traits_ph")}
              className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
          </Field>
          <Field label={g("pets_f_allergies")}>
            <input
              type="text"
              value={allergies}
              onChange={(e) => setAllergies(e.target.value)}
              placeholder={g("pets_f_allergies_ph")}
              className="w-full rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
          </Field>
          <Field label={g("pets_f_story")}>
            <textarea
              value={history}
              onChange={(e) => setHistory(e.target.value)}
              rows={2}
              placeholder={g("pets_f_story_ph")}
              className="w-full resize-none rounded-xl border border-ink/15 px-3 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
          </Field>
          <Field label={g("pets_f_habits")}>
            <textarea
              value={habitsRemarks}
              onChange={(e) => setHabitsRemarks(e.target.value)}
              rows={2}
              placeholder={g("pets_f_habits_ph")}
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
            {saving ? g("common_saving") : initial ? g("pets_update") : g("pets_create")}
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
