"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useT } from "@/lib/i18n/LanguageProvider";
import BackLink from "@/components/BackLink";
import {
  FamilyMember,
  getMyFamily,
  getStoredUser,
  inviteFamilyByEmail,
  removeFamilyMember,
} from "@/lib/api";

/**
 * v413 — Daniel : « PawFamily ajouter 5 personnes » sur le web. Réutilise les
 * endpoints mobiles /friends/family/* (titulaire d'un abo PawFamily ajoute
 * jusqu'à 5 membres). 100% synchronisé avec l'app.
 */
export default function FamilyPage() {
  const { t } = useT();
  const router = useRouter();
  const [members, setMembers] = useState<FamilyMember[]>([]);
  const [remaining, setRemaining] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  async function refresh() {
    try {
      const data = await getMyFamily();
      setMembers(data.members);
      setRemaining(typeof data.remainingSlots === "number" ? data.remainingSlots : null);
    } catch {
      /* silencieux */
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (!getStoredUser()) {
      router.replace("/login");
      return;
    }
    refresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function onAdd(e: React.FormEvent) {
    e.preventDefault();
    const v = email.trim();
    if (!v || busy) return;
    setBusy(true);
    setMsg(null);
    try {
      const res = await inviteFamilyByEmail(v);
      setEmail("");
      setMsg(res.mode === "email_invite" ? t("family_invite_sent") : t("family_added"));
      await refresh();
    } catch (err) {
      setMsg(err instanceof Error ? err.message : "Erreur");
    } finally {
      setBusy(false);
    }
  }

  async function onRemove(id: string) {
    if (busy) return;
    setBusy(true);
    setMembers((prev) => prev.filter((m) => m.id !== id));
    try {
      await removeFamilyMember(id);
      await refresh();
    } catch {
      await refresh();
    } finally {
      setBusy(false);
    }
  }

  const used = members.length;

  return (
    <div className="mx-auto max-w-2xl px-4 py-16 md:py-24">
      <div className="mb-6">
        <BackLink href="/dashboard" label={t("nav_dashboard")} />
      </div>
      <h1 className="font-display text-3xl font-extrabold text-ink">
        👨‍👩‍👧 {t("family_title")}
      </h1>
      <p className="mt-2 text-sm text-ink-muted">{t("family_subtitle")}</p>

      <div className="mt-6 rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
        <div className="mb-3 flex items-center justify-between">
          <span className="font-display text-lg font-extrabold text-ink">
            {t("family_members_title")}
          </span>
          <span className="rounded-full bg-owner-light px-3 py-1 text-sm font-bold text-owner">
            {used}/5
          </span>
        </div>

        {loading ? (
          <div className="py-8 text-center text-sm text-ink-muted">{t("common_loading")}</div>
        ) : members.length === 0 ? (
          <div className="rounded-xl bg-bg-soft px-4 py-8 text-center text-sm text-ink-muted">
            {t("family_empty")}
          </div>
        ) : (
          <ul className="flex flex-col gap-2">
            {members.map((m) => (
              <li
                key={m.id}
                className="flex items-center justify-between rounded-xl border border-ink/5 bg-bg-soft/40 px-4 py-3"
              >
                <div className="min-w-0">
                  <div className="truncate text-sm font-semibold text-ink">
                    {m.name || m.email || m.id}
                  </div>
                  <div className="text-xs text-ink-muted">
                    {m.status === "pending" ? t("family_pending") : t("family_active")}
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => onRemove(m.id)}
                  disabled={busy}
                  className="ml-3 rounded-full border border-ink/15 px-3 py-1 text-xs font-semibold text-ink-muted hover:bg-ink/5 disabled:opacity-60"
                >
                  {t("family_remove")}
                </button>
              </li>
            ))}
          </ul>
        )}

        {(remaining == null || remaining > 0) && (
          <form onSubmit={onAdd} className="mt-4 flex gap-2">
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder={t("family_add_placeholder")}
              className="flex-1 rounded-full border border-ink/15 px-4 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
            <button
              type="submit"
              disabled={busy || !email.trim()}
              className="rounded-full bg-owner px-5 py-2 text-sm font-semibold text-white disabled:opacity-60"
            >
              {t("family_add_button")}
            </button>
          </form>
        )}
        {msg && <p className="mt-2 text-sm text-ink-muted">{msg}</p>}
        <p className="mt-3 text-xs text-ink-muted/80">{t("family_hint")}</p>
      </div>
    </div>
  );
}
