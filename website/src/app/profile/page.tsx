"use client";

// v23.1 part 146 — Page profil : voir + éditer mes infos.
// Miroir simplifié de l'écran "Mon profil" de l'app Flutter.

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError,
  getMyProfile,
  getStoredUser,
  getSubscriptionStatus,
  updateMyProfile,
  uploadMyAvatar,
  UserProfile,
} from "@/lib/api";

// v402 — Daniel : "le badge avec le nombre de jours restants des abonnements
// doit apparaître sur les 3 profils". Chip par abo actif (Premium / PawFollow /
// PawFamily / PawSpot) avec les jours restants.
type SubChip = { label: string; cls: string };

export default function ProfilePage() {
  const { t } = useT();
  const router = useRouter();
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [savedAt, setSavedAt] = useState<number | null>(null);

  // Form fields (controlled)
  const [name, setName] = useState("");
  const [mobile, setMobile] = useState("");
  const [countryCode, setCountryCode] = useState("");
  const [address, setAddress] = useState("");
  const [bio, setBio] = useState("");
  // v413 — parité app : préférences + 2FA (synchro app↔web).
  const [prefs, setPrefs] = useState({
    notifications: true,
    quickReplies: true,
    sendPhotosVideos: true,
    pawMapInsurance: true,
    flexibleCancellation: true,
  });
  const [twoFactor, setTwoFactor] = useState(false);

  // v23.1 part 146 — upload avatar.
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);

  // v402 — chips d'abonnement (jours restants).
  const [subChips, setSubChips] = useState<SubChip[]>([]);

  async function handleAvatarChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadingAvatar(true);
    setError(null);
    try {
      const updated = await uploadMyAvatar(file);
      setProfile(updated);
      setSavedAt(Date.now());
      setTimeout(() => setSavedAt(null), 3000);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to upload");
    } finally {
      setUploadingAvatar(false);
      // Reset le input pour pouvoir re-uploader la même image plus tard.
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  }

  useEffect(() => {
    if (!getStoredUser()) {
      router.replace("/login");
      return;
    }
    (async () => {
      try {
        const p = await getMyProfile();
        setProfile(p);
        setName(p.name || "");
        setMobile(p.mobile || "");
        setCountryCode(p.countryCode || "");
        setAddress(p.address || "");
        setBio(p.bio || "");
        // v413 — préférences (synchro avec l'app). Défauts = activé.
        const pr = p.preferences || {};
        setPrefs({
          notifications: pr.notifications !== false,
          quickReplies: pr.quickReplies !== false,
          sendPhotosVideos: pr.sendPhotosVideos !== false,
          pawMapInsurance: pr.pawMapInsurance !== false,
          flexibleCancellation: pr.flexibleCancellation !== false,
        });
        setTwoFactor(p.twoFactorEnabled === true);
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }
        setError(e instanceof Error ? e.message : "Failed to load profile");
      } finally {
        setLoading(false);
      }
    })();
  }, [router]);

  // v402 — charge le statut d'abonnement et construit les chips jours-restants.
  useEffect(() => {
    (async () => {
      try {
        const st = await getSubscriptionStatus();
        const now = Date.now();
        const dleft = (d?: string | null) =>
          d ? Math.ceil((new Date(d).getTime() - now) / 86400000) : 0;
        const staff = st.currentPeriodEnd
          ? new Date(st.currentPeriodEnd).getFullYear() >= 2090
          : false;
        const gold = "border border-amber-400 bg-gradient-to-r from-[#221C12] to-[#15120D] text-yellow-400";
        const violet = "bg-violet-100 text-violet-800";
        const fuchsia = "bg-fuchsia-100 text-fuchsia-800";
        const amber = "bg-amber-100 text-amber-800";
        const chips: SubChip[] = [];
        const pd = dleft(st.premiumExpiry);
        if (pd > 0) chips.push({ label: `👑 PawPremium · ${pd} j`, cls: gold });
        else if (staff) chips.push({ label: "👑 PawPremium · ∞", cls: gold });
        if ((st.plan === "monthly" || st.plan === "yearly") && dleft(st.currentPeriodEnd) > 0)
          chips.push({ label: `📍 PawFollow · ${dleft(st.currentPeriodEnd)} j`, cls: violet });
        const fd = dleft(st.familyExpiry);
        if (fd > 0) chips.push({ label: `👨‍👩‍👧 PawFamily · ${fd} j`, cls: fuchsia });
        const sd = dleft(st.pawspotExpiry);
        if (sd > 0) chips.push({ label: `🐾 PawSpot · ${sd} j`, cls: amber });
        setSubChips(chips);
      } catch { /* pas connecté / pas d'abo → aucune chip */ }
    })();
  }, []);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!profile) return;
    setSaving(true);
    setError(null);
    try {
      const updated = await updateMyProfile({
        name: name.trim(),
        mobile: mobile.trim() || undefined,
        countryCode: countryCode.trim() || undefined,
        address: address.trim() || undefined,
        bio: bio.trim() || undefined,
        preferences: prefs,
        twoFactorEnabled: twoFactor,
      });
      setProfile(updated);
      setSavedAt(Date.now());
      setTimeout(() => setSavedAt(null), 3000);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to save");
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-24 text-center text-ink-muted">
        {t("common_loading")}
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-24">
        <p className="text-center text-ink-muted">{error || "No profile found"}</p>
      </div>
    );
  }

  const roleColor =
    profile.role === "owner" ? "owner" : profile.role === "walker" ? "walker" : "sitter";

  return (
    <div className="mx-auto max-w-2xl px-4 py-12 md:py-16">
      <div className="mb-6 flex items-center justify-between">
        <Link href="/dashboard" className="text-sm text-ink-muted hover:text-ink">
          ← Dashboard
        </Link>
        <span className={`rounded-full bg-${roleColor} px-3 py-1 text-xs font-semibold uppercase tracking-wider text-white`}>
          {profile.role}
        </span>
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        Mon profil
      </h1>
      <p className="mt-2 text-ink-muted">
        Modifie tes infos. Elles sont synchronisées entre le site et l&apos;app.
      </p>

      {/* v23.1 part 146 — Avatar avec upload click-to-change. */}
      <div className="mt-8 flex items-center gap-4">
        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          disabled={uploadingAvatar}
          className="group relative h-20 w-20 shrink-0 overflow-hidden rounded-full bg-ink/10 transition hover:opacity-90"
          aria-label="Changer la photo de profil"
        >
          {profile.avatar?.url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={profile.avatar.url} alt="" className="h-full w-full object-cover" />
          ) : (
            <span className="flex h-full w-full items-center justify-center text-2xl font-bold text-ink-muted">
              {profile.name?.charAt(0).toUpperCase() || "?"}
            </span>
          )}
          {/* Overlay hover */}
          <span
            className={`absolute inset-0 flex items-center justify-center bg-black/40 text-xs font-semibold text-white transition ${
              uploadingAvatar ? "opacity-100" : "opacity-0 group-hover:opacity-100"
            }`}
          >
            {uploadingAvatar ? "Upload…" : "Modifier"}
          </span>
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          onChange={handleAvatarChange}
          className="hidden"
        />
        <div>
          <div className="text-sm font-semibold text-ink">{profile.name}</div>
          <div className="text-xs text-ink-muted">{profile.email}</div>
          {profile.verified && (
            <div className="mt-1 text-xs font-medium text-green-600">✓ Email vérifié</div>
          )}
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            className="mt-1.5 text-xs text-walker hover:underline"
          >
            Changer la photo
          </button>
        </div>
      </div>

      {/* v402 — Badges abonnements (jours restants) sur le profil, 3 rôles. */}
      {subChips.length > 0 && (
        <div className="mt-6">
          <p className="text-xs font-semibold uppercase tracking-wider text-ink-muted">
            {t("profile_subs_title")}
          </p>
          <div className="mt-2 flex flex-wrap gap-2">
            {subChips.map((c) => (
              <span
                key={c.label}
                className={`rounded-full px-3 py-1.5 text-xs font-bold shadow-sm ${c.cls}`}
              >
                {c.label}
              </span>
            ))}
          </div>
        </div>
      )}

      <form onSubmit={handleSubmit} className="mt-8 space-y-5">
        <Field label="Nom complet">
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
            className="w-full rounded-xl border border-ink/15 px-4 py-2.5 text-sm focus:border-walker focus:outline-none focus:ring-2 focus:ring-walker/20"
          />
        </Field>

        <Field label="Email (non modifiable)">
          <input
            type="email"
            value={profile.email}
            disabled
            className="w-full rounded-xl border border-ink/10 bg-ink/5 px-4 py-2.5 text-sm text-ink-muted"
          />
        </Field>

        <div className="grid gap-4 md:grid-cols-[1fr_2fr]">
          <Field label="Indicatif">
            <input
              type="text"
              value={countryCode}
              onChange={(e) => setCountryCode(e.target.value)}
              placeholder="+33"
              className="w-full rounded-xl border border-ink/15 px-4 py-2.5 text-sm focus:border-walker focus:outline-none focus:ring-2 focus:ring-walker/20"
            />
          </Field>
          <Field label="Téléphone">
            <input
              type="tel"
              value={mobile}
              onChange={(e) => setMobile(e.target.value)}
              placeholder="612345678"
              className="w-full rounded-xl border border-ink/15 px-4 py-2.5 text-sm focus:border-walker focus:outline-none focus:ring-2 focus:ring-walker/20"
            />
          </Field>
        </div>

        <Field label="Adresse">
          <input
            type="text"
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            placeholder="123 rue de Paris, 75001 Paris"
            className="w-full rounded-xl border border-ink/15 px-4 py-2.5 text-sm focus:border-walker focus:outline-none focus:ring-2 focus:ring-walker/20"
          />
        </Field>

        <Field label="Bio">
          <textarea
            value={bio}
            onChange={(e) => setBio(e.target.value)}
            rows={4}
            placeholder="Quelques mots sur toi…"
            className="w-full resize-none rounded-xl border border-ink/15 px-4 py-2.5 text-sm focus:border-walker focus:outline-none focus:ring-2 focus:ring-walker/20"
          />
        </Field>

        {/* v413 — Préférences (synchro app↔web). */}
        <div className="space-y-3 rounded-2xl border border-ink/10 bg-ink/[0.02] p-4">
          <h3 className="text-sm font-semibold text-ink">Préférences</h3>
          {[
            { key: "notifications" as const, label: "Notifications", hint: "Push, e-mail et badges" },
            { key: "sendPhotosVideos" as const, label: "Envoyer photos & vidéos", hint: "Pendant les gardes/promenades" },
            { key: "quickReplies" as const, label: "Réponses rapides", hint: "Suggestions dans la messagerie" },
            { key: "flexibleCancellation" as const, label: "Annulation flexible", hint: "Conditions d'annulation souples" },
            { key: "pawMapInsurance" as const, label: "Assurance PawMap", hint: "Couverture sur les trajets" },
          ].map((row) => (
            <label
              key={row.key}
              className="flex cursor-pointer items-center justify-between gap-3 rounded-xl bg-white px-3 py-2.5"
            >
              <span className="min-w-0">
                <span className="block text-sm font-medium text-ink">{row.label}</span>
                <span className="block text-xs text-ink/50">{row.hint}</span>
              </span>
              <input
                type="checkbox"
                checked={prefs[row.key]}
                onChange={(e) => setPrefs((p) => ({ ...p, [row.key]: e.target.checked }))}
                className="h-5 w-5 shrink-0 accent-walker"
              />
            </label>
          ))}
        </div>

        {/* v413 — Sécurité : double authentification. */}
        <div className="space-y-3 rounded-2xl border border-ink/10 bg-ink/[0.02] p-4">
          <h3 className="text-sm font-semibold text-ink">Sécurité</h3>
          <label className="flex cursor-pointer items-center justify-between gap-3 rounded-xl bg-white px-3 py-2.5">
            <span className="min-w-0">
              <span className="block text-sm font-medium text-ink">Authentification à deux facteurs</span>
              <span className="block text-xs text-ink/50">Code de vérification à la connexion</span>
            </span>
            <input
              type="checkbox"
              checked={twoFactor}
              onChange={(e) => setTwoFactor(e.target.checked)}
              className="h-5 w-5 shrink-0 accent-walker"
            />
          </label>
        </div>

        {error && (
          <div className="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700" role="alert">
            {error}
          </div>
        )}
        {savedAt && (
          <div className="rounded-xl bg-green-50 px-4 py-3 text-sm text-green-700">
            ✓ Profil mis à jour
          </div>
        )}

        <div className="flex items-center gap-3">
          <button
            type="submit"
            disabled={saving}
            className={`rounded-full bg-${roleColor} px-6 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60`}
          >
            {saving ? "Enregistrement…" : "Enregistrer"}
          </button>
          <Link
            href="/dashboard"
            className="text-sm text-ink-muted hover:text-ink"
          >
            Annuler
          </Link>
        </div>
      </form>
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
