"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useT } from "@/lib/i18n/LanguageProvider";
import BackLink from "@/components/BackLink";
import {
  FamilyMember,
  FriendItem,
  FriendRequests,
  UserSearchResult,
  acceptFriendRequest,
  declineFriendRequest,
  getFriendRequests,
  getMyFamily,
  getMyFriends,
  getStoredUser,
  searchUsers,
  sendFriendRequest,
} from "@/lib/api";

/**
 * v509 — Daniel : « sur le site web à côté de mon profil (dans mon espace)
 * rajoute les demandes et acceptation et liste des amis famille sans rebuild
 * l'app et que tout soit synchronisé ». Mêmes routes que l'app
 * (/friends, /friends/requests, /friends/search…) → synchro automatique :
 * une demande acceptée ici apparaît instantanément dans l'app (et
 * inversement), le backend envoie déjà cloche + push.
 */

function roleKey(model?: string): string {
  const m = String(model || "").toLowerCase();
  if (m === "sitter") return "friends_role_sitter";
  if (m === "walker") return "friends_role_walker";
  return "friends_role_owner";
}

function Avatar({ url, name }: { url?: string; name?: string }) {
  if (url) {
    // eslint-disable-next-line @next/next/no-img-element
    return (
      <img
        src={url}
        alt={name || ""}
        className="h-10 w-10 shrink-0 rounded-full border border-ink/10 object-cover"
      />
    );
  }
  return (
    <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-bg-soft text-lg">
      🐶
    </span>
  );
}

export default function FriendsPage() {
  const { t } = useT();
  const router = useRouter();

  const [loading, setLoading] = useState(true);
  const [friends, setFriends] = useState<FriendItem[]>([]);
  const [requests, setRequests] = useState<FriendRequests>({ incoming: [], outgoing: [] });
  const [family, setFamily] = useState<FamilyMember[]>([]);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);

  // Recherche
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<UserSearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [sentIds, setSentIds] = useState<Set<string>>(new Set());

  async function refresh() {
    try {
      const [fr, req, fam] = await Promise.all([
        getMyFriends(),
        getFriendRequests(),
        getMyFamily().catch(() => ({ members: [] as FamilyMember[] })),
      ]);
      setFriends(fr.filter((f) => f.status === "accepted"));
      setRequests(req);
      setFamily(Array.isArray(fam.members) ? fam.members : []);
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

  // Recherche avec petit debounce (min. 2 caractères, comme le backend).
  useEffect(() => {
    const q = query.trim();
    if (q.length < 2) {
      setResults([]);
      return;
    }
    const timer = setTimeout(async () => {
      setSearching(true);
      try {
        setResults(await searchUsers(q));
      } catch {
        setResults([]);
      } finally {
        setSearching(false);
      }
    }, 350);
    return () => clearTimeout(timer);
  }, [query]);

  // Ids déjà liés (ami ou demande en cours) → pas de bouton « Ajouter ».
  const linkedIds = useMemo(() => {
    const s = new Set<string>();
    for (const f of friends) s.add(f.other?.id);
    for (const r of requests.incoming) s.add(r.other?.id);
    for (const r of requests.outgoing) s.add(r.other?.id);
    const me = getStoredUser();
    if (me?.id) s.add(me.id);
    return s;
  }, [friends, requests]);

  async function onAccept(id: string) {
    if (busyId) return;
    setBusyId(id);
    setMsg(null);
    try {
      await acceptFriendRequest(id);
      await refresh();
    } catch {
      setMsg(t("friends_error"));
    } finally {
      setBusyId(null);
    }
  }

  async function onDecline(id: string) {
    if (busyId) return;
    setBusyId(id);
    setMsg(null);
    try {
      await declineFriendRequest(id);
      await refresh();
    } catch {
      setMsg(t("friends_error"));
    } finally {
      setBusyId(null);
    }
  }

  async function onAdd(u: UserSearchResult) {
    if (busyId) return;
    setBusyId(u.id);
    setMsg(null);
    try {
      await sendFriendRequest(u.id, u.role);
      setSentIds((prev) => new Set(prev).add(u.id));
      await refresh();
    } catch {
      setMsg(t("friends_error"));
    } finally {
      setBusyId(null);
    }
  }

  const sectionCls = "mt-6 rounded-2xl border border-ink/5 bg-white p-5 shadow-card";
  const rowCls =
    "flex items-center justify-between gap-3 rounded-xl border border-ink/5 bg-bg-soft/40 px-4 py-3";
  const emptyCls = "rounded-xl bg-bg-soft px-4 py-6 text-center text-sm text-ink-muted";

  return (
    <div className="mx-auto max-w-2xl px-4 py-16 md:py-24">
      <div className="mb-6">
        <BackLink href="/dashboard" label={t("nav_dashboard")} />
      </div>
      <h1 className="font-display text-3xl font-extrabold text-ink">
        👥 {t("friends_title")}
      </h1>
      <p className="mt-2 text-sm text-ink-muted">{t("friends_subtitle")}</p>
      {msg && (
        <p className="mt-3 rounded-xl bg-red-50 px-4 py-2 text-sm font-semibold text-red-600">
          {msg}
        </p>
      )}

      {loading ? (
        <div className="py-16 text-center text-sm text-ink-muted">{t("common_loading")}</div>
      ) : (
        <>
          {/* ── Demandes reçues ─────────────────────────────────────────── */}
          <div className={sectionCls}>
            <div className="mb-3 flex items-center justify-between">
              <span className="font-display text-lg font-extrabold text-ink">
                📥 {t("friends_req_in_title")}
              </span>
              {requests.incoming.length > 0 && (
                <span className="rounded-full bg-owner-light px-3 py-1 text-sm font-bold text-owner">
                  {requests.incoming.length}
                </span>
              )}
            </div>
            {requests.incoming.length === 0 ? (
              <div className={emptyCls}>{t("friends_req_empty")}</div>
            ) : (
              <ul className="flex flex-col gap-2">
                {requests.incoming.map((r) => (
                  <li key={r.id} className={rowCls}>
                    <Avatar url={r.other?.avatar} name={r.other?.name} />
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-sm font-semibold text-ink">
                        {r.other?.name || r.other?.email || "—"}
                        {r.other?.isPremium ? " 👑" : ""}
                      </div>
                      <div className="text-xs text-ink-muted">
                        {t(roleKey(r.other?.model))}
                        {r.other?.city ? ` · ${r.other.city}` : ""}
                      </div>
                    </div>
                    <div className="flex shrink-0 gap-2">
                      <button
                        type="button"
                        onClick={() => onAccept(r.id)}
                        disabled={busyId !== null}
                        className="rounded-full bg-owner px-4 py-1.5 text-xs font-semibold text-white disabled:opacity-60"
                      >
                        {t("friends_accept")}
                      </button>
                      <button
                        type="button"
                        onClick={() => onDecline(r.id)}
                        disabled={busyId !== null}
                        className="rounded-full border border-ink/15 px-4 py-1.5 text-xs font-semibold text-ink-muted hover:bg-ink/5 disabled:opacity-60"
                      >
                        {t("friends_decline")}
                      </button>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </div>

          {/* ── Demandes envoyées ───────────────────────────────────────── */}
          {requests.outgoing.length > 0 && (
            <div className={sectionCls}>
              <div className="mb-3 font-display text-lg font-extrabold text-ink">
                📤 {t("friends_req_out_title")}
              </div>
              <ul className="flex flex-col gap-2">
                {requests.outgoing.map((r) => (
                  <li key={r.id} className={rowCls}>
                    <Avatar url={r.other?.avatar} name={r.other?.name} />
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-sm font-semibold text-ink">
                        {r.other?.name || r.other?.email || "—"}
                      </div>
                      <div className="text-xs text-ink-muted">
                        {t(roleKey(r.other?.model))} · {t("friends_pending_out")}
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => onDecline(r.id)}
                      disabled={busyId !== null}
                      className="shrink-0 rounded-full border border-ink/15 px-4 py-1.5 text-xs font-semibold text-ink-muted hover:bg-ink/5 disabled:opacity-60"
                    >
                      {t("friends_cancel_req")}
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* ── Liste d'amis ────────────────────────────────────────────── */}
          <div className={sectionCls}>
            <div className="mb-3 flex items-center justify-between">
              <span className="font-display text-lg font-extrabold text-ink">
                💚 {t("friends_list_title")}
              </span>
              <span className="rounded-full bg-owner-light px-3 py-1 text-sm font-bold text-owner">
                {friends.length}
              </span>
            </div>
            {friends.length === 0 ? (
              <div className={emptyCls}>{t("friends_empty")}</div>
            ) : (
              <ul className="flex flex-col gap-2">
                {friends.map((f) => (
                  <li key={f.id} className={rowCls}>
                    <Avatar url={f.other?.avatar} name={f.other?.name} />
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-sm font-semibold text-ink">
                        {f.other?.name || f.other?.email || "—"}
                        {f.other?.isPremium ? " 👑" : ""}
                      </div>
                      <div className="text-xs text-ink-muted">
                        {t(roleKey(f.other?.model))}
                        {f.other?.city ? ` · ${f.other.city}` : ""}
                      </div>
                    </div>
                    {f.theirSharePosition && (
                      <Link
                        href="/friends/live"
                        className="shrink-0 rounded-full bg-[#7C3AED]/10 px-4 py-1.5 text-xs font-semibold text-[#7C3AED] hover:bg-[#7C3AED]/20"
                      >
                        📍 {t("friends_live_link")}
                      </Link>
                    )}
                  </li>
                ))}
              </ul>
            )}
            {friends.some((f) => f.theirSharePosition) && (
              <p className="mt-3 text-xs text-ink-muted/80">{t("friends_live_hint")}</p>
            )}
          </div>

          {/* ── Famille (PawFamily) ─────────────────────────────────────── */}
          <div className={sectionCls}>
            <div className="mb-3 flex items-center justify-between">
              <span className="font-display text-lg font-extrabold text-ink">
                👨‍👩‍👧 {t("family_title")}
              </span>
              <Link
                href="/family"
                className="rounded-full border border-ink/15 px-4 py-1.5 text-xs font-semibold text-ink hover:bg-ink/5"
              >
                {t("friends_family_manage")}
              </Link>
            </div>
            {family.length === 0 ? (
              <div className={emptyCls}>{t("family_empty")}</div>
            ) : (
              <ul className="flex flex-col gap-2">
                {family.map((m) => (
                  <li key={m.id} className={rowCls}>
                    <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-pink-50 text-lg">
                      💗
                    </span>
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-sm font-semibold text-ink">
                        {m.name || m.email || m.id}
                      </div>
                      <div className="text-xs text-ink-muted">
                        {m.status === "pending" ? t("family_pending") : t("family_active")}
                      </div>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </div>

          {/* ── Recherche / ajout ───────────────────────────────────────── */}
          <div className={sectionCls}>
            <div className="mb-3 font-display text-lg font-extrabold text-ink">
              🔍 {t("friends_search_title")}
            </div>
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={t("friends_search_placeholder")}
              className="w-full rounded-full border border-ink/15 px-4 py-2 text-sm focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
            />
            {searching && (
              <div className="mt-3 text-center text-sm text-ink-muted">{t("common_loading")}</div>
            )}
            {!searching && query.trim().length >= 2 && results.length === 0 && (
              <div className={`${emptyCls} mt-3`}>{t("friends_search_empty")}</div>
            )}
            {results.length > 0 && (
              <ul className="mt-3 flex flex-col gap-2">
                {results.map((u) => {
                  const linked = linkedIds.has(u.id);
                  const sent = sentIds.has(u.id);
                  return (
                    <li key={`${u.id}-${u.role}`} className={rowCls}>
                      <Avatar url={u.avatar} name={u.name} />
                      <div className="min-w-0 flex-1">
                        <div className="truncate text-sm font-semibold text-ink">
                          {u.name || "—"}
                        </div>
                        <div className="text-xs text-ink-muted">{t(roleKey(u.role))}</div>
                      </div>
                      {sent ? (
                        <span className="shrink-0 text-xs font-semibold text-emerald-600">
                          {t("friends_request_sent")}
                        </span>
                      ) : linked ? (
                        <span className="shrink-0 text-xs font-semibold text-ink-muted">
                          {t("friends_already")}
                        </span>
                      ) : (
                        <button
                          type="button"
                          onClick={() => onAdd(u)}
                          disabled={busyId !== null}
                          className="shrink-0 rounded-full bg-owner px-4 py-1.5 text-xs font-semibold text-white disabled:opacity-60"
                        >
                          {t("friends_add")}
                        </button>
                      )}
                    </li>
                  );
                })}
              </ul>
            )}
            <p className="mt-3 text-xs text-ink-muted/80">{t("friends_search_hint")}</p>
          </div>
        </>
      )}
    </div>
  );
}
