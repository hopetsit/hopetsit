"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError,
  createPost,
  getStoredUser,
  POST_SERVICE_TYPES,
} from "@/lib/api";

// v402 — Owner publie une annonce depuis le SITE (parité app). Endpoint
// existant POST /posts (owner only). Aucun impact app.
export default function CreatePostPage() {
  const { t } = useT();
  const router = useRouter();

  const [role, setRole] = useState<string | null>(null);
  const [body, setBody] = useState("");
  const [services, setServices] = useState<string[]>([]);
  const [venue, setVenue] = useState<"owners_home" | "sitters_home">("owners_home");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [notes, setNotes] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");

  useEffect(() => {
    const u = getStoredUser();
    if (!u) {
      router.replace("/login");
      return;
    }
    setRole(u.role);
  }, [router]);

  const svcLabel = (s: string) =>
    s === "house_sitting"
      ? t("posts_svc_house_sitting")
      : s === "day_care"
        ? t("posts_svc_day_care")
        : t("posts_svc_dog_walking");

  function toggleService(s: string) {
    setServices((prev) =>
      prev.includes(s) ? prev.filter((x) => x !== s) : [...prev, s],
    );
  }

  const needsVenue = services.includes("house_sitting");

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!body.trim()) {
      setErr(t("posts_error_body"));
      return;
    }
    setBusy(true);
    setErr("");
    try {
      await createPost({
        body: body.trim(),
        serviceTypes: services,
        houseSittingVenue: needsVenue ? venue : undefined,
        startDate: startDate ? new Date(startDate).toISOString() : undefined,
        endDate: endDate ? new Date(endDate).toISOString() : undefined,
        notes: notes.trim() || undefined,
      });
      router.push("/posts");
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
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
                className={`rounded-full border px-4 py-2 text-sm font-semibold transition ${
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
                  className={`flex-1 rounded-xl border px-3 py-2 text-sm font-semibold transition ${
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

        <button
          disabled={busy}
          className="w-full rounded-full bg-owner py-3 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark disabled:opacity-60"
        >
          {busy ? t("posts_publishing") : t("posts_submit")}
        </button>
        {err && <p className="text-center text-sm text-owner-dark">{err}</p>}
        <p className="text-center text-xs text-ink-muted">{t("posts_no_contact_info")}</p>
      </form>
    </div>
  );
}
