"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError,
  createPost,
  createPostWithMedia,
  getStoredUser,
  POST_SERVICE_TYPES,
} from "@/lib/api";

// v402 — Owner publie une annonce depuis le SITE (parité app). Endpoint
// existant POST /posts (owner only). Aucun impact app.
/** Brouillon gardé le temps de l'inscription (ce navigateur seulement). */
const DRAFT_KEY = "hopetsit_post_draft_v1";

export default function CreatePostPage() {
  const { t } = useT();
  const router = useRouter();

  const [role, setRole] = useState<string | null>(null);
  // 22/09/2026 — LE FORMULAIRE D'ABORD, LE COMPTE À LA FIN.
  // Mesure du 22/09 : 33 inscriptions en 7 jours, 12 e-mails vérifiés (36 %).
  // On demandait à un inconnu de créer un compte PUIS d'aller chercher un code
  // dans sa boîte mail avant même de pouvoir décrire son besoin — et aucune
  // demande n'a jamais été publiée. Désormais on écrit la demande, puis on
  // crée le compte : le brouillon est gardé et repris après la vérification.
  const [invite, setInvite] = useState(false);
  // La ville est OBLIGATOIRE : c'est elle qui déclenche l'alerte « nouvelle
  // demande près de chez toi » chez les gardiens. Sans elle, une demande
  // publiée depuis le site ne prévenait PERSONNE.
  const [city, setCity] = useState("");
  const [body, setBody] = useState("");
  const [services, setServices] = useState<string[]>([]);
  const [venue, setVenue] = useState<"owners_home" | "sitters_home">("owners_home");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [notes, setNotes] = useState("");
  const [animalCount, setAnimalCount] = useState(1);
  const [animalTypes, setAnimalTypes] = useState<string[]>([]);
  const [photos, setPhotos] = useState<File[]>([]);

  // v404 — types d'animaux concernés par l'annonce (clés stables + emoji).
  const ANIMAL_TYPES: { key: string; emoji: string }[] = [
    { key: "dog", emoji: "🐶" },
    { key: "cat", emoji: "🐱" },
    { key: "nac", emoji: "🐹" },
    { key: "bird", emoji: "🐦" },
    { key: "reptile", emoji: "🦎" },
    { key: "other", emoji: "🐾" },
  ];
  function toggleAnimalType(k: string) {
    setAnimalTypes((prev) => (prev.includes(k) ? prev.filter((x) => x !== k) : [...prev, k]));
  }
  const animalTypeLabel = (k: string) =>
    ({ dog: t("posts_animal_dog"), cat: t("posts_animal_cat"), nac: t("posts_animal_nac"), bird: t("posts_animal_bird"), reptile: t("posts_animal_reptile"), other: t("posts_animal_other") } as Record<string, string>)[k] || k;
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");

  function addPhotos(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files || []);
    if (!files.length) return;
    setPhotos((prev) => [...prev, ...files].slice(0, 10)); // max 10
    e.target.value = ""; // permet de re-sélectionner le même fichier
  }

  function removePhoto(idx: number) {
    setPhotos((prev) => prev.filter((_, i) => i !== idx));
  }

  useEffect(() => {
    const u = getStoredUser();
    setInvite(!u);
    if (u) setRole(u.role);

    // Ville pré-remplie par la page ville d'où l'on vient (?city=Paris).
    try {
      const q = new URLSearchParams(window.location.search);
      const c = (q.get("city") || "").trim();
      if (c) setCity(c);
    } catch { /* URL exotique */ }

    // Brouillon laissé avant l'inscription : on le remet tel quel.
    try {
      const brut = window.localStorage.getItem(DRAFT_KEY);
      if (!brut) return;
      const d = JSON.parse(brut) as Record<string, unknown>;
      if (typeof d.body === "string") setBody(d.body);
      if (Array.isArray(d.services)) setServices(d.services as string[]);
      if (d.venue === "owners_home" || d.venue === "sitters_home") setVenue(d.venue);
      if (typeof d.startDate === "string") setStartDate(d.startDate);
      if (typeof d.endDate === "string") setEndDate(d.endDate);
      if (typeof d.notes === "string") setNotes(d.notes);
      if (typeof d.animalCount === "number") setAnimalCount(d.animalCount);
      if (Array.isArray(d.animalTypes)) setAnimalTypes(d.animalTypes as string[]);
      if (typeof d.city === "string" && d.city) setCity(d.city);
    } catch { /* brouillon illisible → on repart d'une page vierge */ }
  }, [router]);

  const svcLabel = (s: string) =>
    s === "house_sitting"
      ? t("posts_svc_house_sitting")
      : s === "day_care"
        ? t("posts_svc_day_care")
        : t("posts_svc_dog_walking");

  function toggleService(s: string) {
    // v404 — Daniel : UN SEUL service par annonce (avant on pouvait cocher les
    // 3). Évite aussi les annonces mixant dog_walking + autres qui brouillent
    // le filtrage walker/sitter. Re-cliquer le service actif le désélectionne.
    setServices((prev) => (prev.includes(s) ? [] : [s]));
  }

  const needsVenue = services.includes("house_sitting");

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!body.trim()) {
      setErr(t("posts_error_body"));
      return;
    }
    if (!city.trim()) {
      setErr(t("signup_city_required"));
      return;
    }

    // Invité : rien n'est envoyé au serveur (il refuserait, et c'est très
    // bien : aucune annonce d'un compte qui n'existe pas). On met la demande
    // de côté et on va créer le compte ; au retour, le formulaire est rempli.
    if (invite) {
      try {
        window.localStorage.setItem(DRAFT_KEY, JSON.stringify({
          body, services, venue, startDate, endDate, notes,
          animalCount, animalTypes, city,
        }));
      } catch { /* navigation privée : on continue sans mémoriser */ }
      router.push(
        `/signup?role=owner&city=${encodeURIComponent(city.trim())}`
        + `&next=${encodeURIComponent("/posts/create")}`,
      );
      return;
    }

    setBusy(true);
    setErr("");
    try {
      const input = {
        body: body.trim(),
        serviceTypes: services,
        houseSittingVenue: needsVenue ? venue : undefined,
        startDate: startDate ? new Date(startDate).toISOString() : undefined,
        endDate: endDate ? new Date(endDate).toISOString() : undefined,
        notes: notes.trim() || undefined,
        animalCount: animalCount > 0 ? animalCount : undefined,
        animalTypes: animalTypes.length ? animalTypes : undefined,
        // Sans ville, aucun gardien n'est prévenu (cf. le commentaire plus haut).
        location: { city: city.trim() },
      };
      // Avec photos → /posts/with-media (postType=request) ; sinon → /posts.
      if (photos.length > 0) {
        await createPostWithMedia(input, photos);
      } else {
        await createPost(input);
      }
      try { window.localStorage.removeItem(DRAFT_KEY); } catch { /* ignore */ }
      router.push("/posts");
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        // Session expirée pendant la saisie : on garde le travail de la
        // personne plutôt que de le jeter avec elle vers /login.
        try {
          window.localStorage.setItem(DRAFT_KEY, JSON.stringify({
            body, services, venue, startDate, endDate, notes,
            animalCount, animalTypes, city,
          }));
        } catch { /* ignore */ }
        router.replace(`/login?next=${encodeURIComponent("/posts/create")}`);
        return;
      }
      setErr(e instanceof ApiError ? e.message : t("posts_error"));
    } finally {
      setBusy(false);
    }
  }

  // Les owners seuls publient des annonces (le backend renvoie 403 sinon).
  if (role && role !== "owner") {
    return (
      <div className="mx-auto max-w-md px-4 py-24 text-center">
        <p className="text-sm text-ink-muted">{t("posts_owner_only")}</p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-lg px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-3xl font-extrabold tracking-tight md:text-4xl">
        {t("posts_create_title")}
      </h1>

      <form
        onSubmit={onSubmit}
        className="mt-10 space-y-5 rounded-3xl border border-ink/5 bg-white p-7 shadow-card"
      >
        <div>
          <label className="block text-sm font-medium text-ink">{t("posts_city_label")}</label>
          <input
            value={city}
            onChange={(e) => setCity(e.target.value)}
            required
            autoComplete="address-level2"
            placeholder={t("posts_city_ph")}
            className="mt-1.5 w-full rounded-xl border border-ink/15 bg-bg-soft px-3.5 py-2.5 text-sm text-ink focus:border-owner focus:outline-none"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-ink">{t("posts_body_label")}</label>
          <textarea
            value={body}
            onChange={(e) => setBody(e.target.value)}
            required
            rows={4}
            placeholder={t("posts_body_ph")}
            className="mt-1.5 w-full rounded-xl border border-ink/15 bg-bg-soft px-3.5 py-2.5 text-sm text-ink focus:border-owner focus:outline-none"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-ink">{t("posts_services_label")}</label>
          <div className="mt-2 flex flex-wrap gap-2">
            {POST_SERVICE_TYPES.map((s) => (
              <button
                key={s}
                type="button"
                onClick={() => toggleService(s)}
                className={`rounded-full border px-4 py-2 text-sm font-semibold transition max-lg:min-h-[44px] ${
                  services.includes(s)
                    ? "border-owner bg-owner-light text-owner-dark"
                    : "border-ink/15 bg-white text-ink hover:border-ink/30"
                }`}
              >
                {svcLabel(s)}
              </button>
            ))}
          </div>
        </div>

        {needsVenue && (
          <div>
            <label className="block text-sm font-medium text-ink">{t("posts_venue_label")}</label>
            <div className="mt-2 flex gap-2">
              {(["owners_home", "sitters_home"] as const).map((v) => (
                <button
                  key={v}
                  type="button"
                  onClick={() => setVenue(v)}
                  className={`flex-1 rounded-xl border px-3 py-2 text-sm font-semibold transition max-lg:min-h-[44px] ${
                    venue === v
                      ? "border-owner bg-owner-light text-owner-dark"
                      : "border-ink/15 bg-white text-ink hover:border-ink/30"
                  }`}
                >
                  {v === "owners_home" ? t("posts_venue_owner") : t("posts_venue_sitter")}
                </button>
              ))}
            </div>
          </div>
        )}

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="block text-sm font-medium text-ink">{t("posts_start_label")}</label>
            <input
              type="date"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              className="mt-1.5 w-full rounded-xl border border-ink/15 bg-bg-soft px-3 py-2.5 text-sm text-ink focus:border-owner focus:outline-none"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-ink">{t("posts_end_label")}</label>
            <input
              type="date"
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
              className="mt-1.5 w-full rounded-xl border border-ink/15 bg-bg-soft px-3 py-2.5 text-sm text-ink focus:border-owner focus:outline-none"
            />
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-ink">{t("posts_notes_label")}</label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={2}
            placeholder={t("posts_notes_ph")}
            className="mt-1.5 w-full rounded-xl border border-ink/15 bg-bg-soft px-3.5 py-2.5 text-sm text-ink focus:border-owner focus:outline-none"
          />
        </div>

        {/* v404 — Animaux concernés : nombre + types */}
        <div>
          <label className="block text-sm font-medium text-ink">{t("posts_animals_label")}</label>
          <div className="mt-2 flex items-center gap-3">
            <input
              type="number"
              min={1}
              max={50}
              value={animalCount}
              onChange={(e) => setAnimalCount(Math.max(1, Math.min(50, Number(e.target.value) || 1)))}
              className="w-20 rounded-xl border border-ink/15 bg-bg-soft px-3 py-2.5 text-center text-sm text-ink focus:border-owner focus:outline-none"
            />
            <span className="text-sm text-ink-muted">{t("posts_animals_count_hint")}</span>
          </div>
          <div className="mt-3 flex flex-wrap gap-2">
            {ANIMAL_TYPES.map((a) => (
              <button
                key={a.key}
                type="button"
                onClick={() => toggleAnimalType(a.key)}
                className={`rounded-full border px-3.5 py-2 text-sm font-semibold transition max-lg:min-h-[44px] ${
                  animalTypes.includes(a.key)
                    ? "border-owner bg-owner-light text-owner-dark"
                    : "border-ink/15 bg-white text-ink hover:border-ink/30"
                }`}
              >
                {a.emoji} {animalTypeLabel(a.key)}
              </button>
            ))}
          </div>
        </div>

        {/* v402 — Photos de l'annonce (ajouter / supprimer avant publication).
            Masquées à l'invité : un fichier choisi ici ne survivrait pas au
            passage par l'inscription, et on ne fait pas travailler quelqu'un
            pour rien. */}
        <div className={invite ? "hidden" : undefined}>
          <label className="block text-sm font-medium text-ink">{t("posts_photos_label")}</label>
          <div className="mt-2 flex flex-wrap gap-3">
            {photos.map((f, i) => (
              <div key={i} className="relative h-20 w-20 overflow-hidden rounded-xl border border-ink/10">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={URL.createObjectURL(f)} alt="" className="h-full w-full object-cover" />
                <button
                  type="button"
                  onClick={() => removePhoto(i)}
                  aria-label="remove"
                  className="absolute right-0.5 top-0.5 flex h-5 w-5 items-center justify-center rounded-full bg-black/60 text-xs text-white"
                >
                  ✕
                </button>
              </div>
            ))}
            {photos.length < 10 && (
              <label className="flex h-20 w-20 cursor-pointer items-center justify-center rounded-xl border-2 border-dashed border-ink/20 text-2xl text-ink-muted transition hover:border-owner hover:text-owner">
                +
                <input type="file" accept="image/*" multiple onChange={addPhotos} className="hidden" />
              </label>
            )}
          </div>
          <p className="mt-1 text-xs text-ink-muted">{t("posts_photos_hint")}</p>
        </div>

        <button
          disabled={busy}
          className="w-full rounded-full bg-owner py-3 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark disabled:opacity-60"
        >
          {busy ? t("posts_publishing") : invite ? t("posts_guest_cta") : t("posts_submit")}
        </button>
        {invite && (
          <p className="text-center text-xs text-ink-muted">{t("posts_guest_note")}</p>
        )}
        {err && <p className="text-center text-sm text-owner-dark">{err}</p>}
        <p className="text-center text-xs text-ink-muted">{t("posts_no_contact_info")}</p>
      </form>
    </div>
  );
}
