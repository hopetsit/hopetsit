"use client";

// v23.1 part 146 — Page chat : liste conversations + détail.
// MVP : 2 panneaux côte à côte sur desktop (liste à gauche, conversation
// active à droite), stack vertical sur mobile (clic ouvre la conversation).
// Temps réel via socket.io : nouveaux messages arrivent live.

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError,
  AuthRole,
  ChatMessage,
  Conversation,
  deleteConversation,
  FriendItem,
  getConversations,
  getMessages,
  getMyFriends,
  getStoredUser,
  requestFollowByConversation,
  respondPawfollowRequest,
  sendMessage,
  sendMessageWithAttachments,
  startFriendConversation,
} from "@/lib/api";
import { useSocket, useSocketEvent } from "@/lib/useSocket";
import { getSocket } from "@/lib/socket";

export default function ChatPage() {
  const { t } = useT();
  const router = useRouter();
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMessages, setLoadingMessages] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  // v23.1 part 248b — Modal "Nouvelle conversation" : Daniel veut
  // choisir un ami pour ouvrir un chat direct avec lui (au lieu d'etre
  // redirige sur /friends/live). On lazy-load les amis a l'ouverture
  // du modal pour eviter une requete inutile sur les visites /chat
  // qui ne touchent pas au bouton.
  const [showNewConvModal, setShowNewConvModal] = useState(false);
  const [friends, setFriends] = useState<FriendItem[]>([]);
  const [loadingFriends, setLoadingFriends] = useState(false);
  const [startingChatWith, setStartingChatWith] = useState<string | null>(null);

  // v23.1 part 146 — assure que le socket est créé même si l'user arrive
  // directement sur /chat sans passer par /dashboard.
  useSocket();

  const user = getStoredUser();

  useEffect(() => {
    if (!user) {
      router.replace("/login");
      return;
    }
    refresh();
  }, [router]);

  async function refresh() {
    setLoading(true);
    setError(null);
    try {
      const list = await getConversations();
      // Tri par date du dernier message DESC.
      list.sort((a, b) => {
        const da = new Date(a.lastMessageAt || 0).getTime();
        const db = new Date(b.lastMessageAt || 0).getTime();
        return db - da;
      });
      setConversations(list);
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
        return;
      }
      setError(e instanceof Error ? e.message : "Failed to load conversations");
    } finally {
      setLoading(false);
    }
  }

  // v402 — deep-link depuis une annonce : /chat?c=<conversationId> ouvre
  // directement la conversation dès que la liste est chargée (le bouton
  // "Contacter" d'une annonce y redirige). window.location évite d'avoir à
  // envelopper la page dans un <Suspense> (useSearchParams).
  const openedDeepLink = useRef(false);
  useEffect(() => {
    if (openedDeepLink.current || loading || conversations.length === 0) return;
    try {
      const cid = new URLSearchParams(window.location.search).get("c");
      if (cid && conversations.some((c) => c.id === cid)) {
        openedDeepLink.current = true;
        openConversation(cid);
      }
    } catch { /* ignore */ }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loading, conversations]);

  async function openConversation(id: string) {
    setActiveId(id);
    setLoadingMessages(true);
    setMessages([]);
    try {
      const msgs = await getMessages(id);
      setMessages(msgs);
      // Rejoindre la room socket pour recevoir les nouveaux messages.
      const sock = getSocket();
      if (sock && user) {
        sock.emit("conversation:join", {
          conversationId: id,
          role: user.role,
          userId: user.id,
        });
        sock.emit("conversation:read", {
          conversationId: id,
          role: user.role,
          userId: user.id,
        });
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load messages");
    } finally {
      setLoadingMessages(false);
    }
  }

  // Cleanup : quitter la room quand on change de conversation.
  useEffect(() => {
    return () => {
      const sock = getSocket();
      if (sock && activeId) {
        sock.emit("conversation:leave", { conversationId: activeId });
      }
    };
  }, [activeId]);

  // Auto-scroll vers le bas quand de nouveaux messages arrivent.
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  // v23.1 part 146 — listener socket pour les nouveaux messages temps réel.
  // v23.1.276 — Daniel : "conversations pas synchronisées + message supprimé".
  // Le backend émet { conversationId, triggeredBy, message, sentMessage } : le
  // vrai message (id, body…) est NICHÉ sous `message` (chat booking) ou
  // `sentMessage` (chat ami/famille). Avant on lisait payload.body / payload.id
  // au top-level → undefined → désync + bulles vides. On DÉBALLE l'enveloppe.
  useSocketEvent<Record<string, unknown>>(
    "message:new",
    (payload) => {
      const inner = (payload.message ??
        payload.sentMessage ??
        payload) as ChatMessage & { conversationId?: string };
      const conversationId =
        (payload.conversationId as string) || inner?.conversationId || "";
      const msg: ChatMessage & { conversationId: string } = {
        ...inner,
        conversationId,
      };
      // Si le message arrive pour la conversation actuellement ouverte, on
      // l'append à la liste. Sinon on bump l'unreadCount dans la liste des
      // conversations (et on refresh pour mettre à jour le lastMessage).
      if (msg.conversationId === activeId) {
        setMessages((prev) => {
          if (prev.some((m) => m.id === msg.id)) return prev; // dédup
          return [...prev, msg];
        });
      } else {
        // Bump unread sur la conv concernée, et hoist en haut.
        setConversations((prev) => {
          const idx = prev.findIndex((c) => c.id === msg.conversationId);
          if (idx < 0) return prev;
          const next = [...prev];
          const target = {
            ...next[idx],
            lastMessage: msg.body,
            lastMessageAt: msg.createdAt,
            unreadCount: (next[idx].unreadCount || 0) + 1,
          };
          next.splice(idx, 1);
          return [target, ...next];
        });
      }
    },
  );

  useSocketEvent<{ conversationId: string; messageId: string }>(
    "message:deleted",
    (data) => {
      if (data.conversationId === activeId) {
        setMessages((prev) => prev.filter((m) => m.id !== data.messageId));
      }
    },
  );

  async function handleSend(e: React.FormEvent) {
    e.preventDefault();
    if (!activeId || !draft.trim() || !user) return;
    const body = draft.trim();
    setDraft("");
    setSending(true);
    try {
      const saved = await sendMessage(activeId, body);
      // L'event socket message:new va arriver mais on append tout de suite
      // pour la latence perçue. Le dédup ID-based dans le listener évite
      // d'avoir le message en double.
      setMessages((prev) => {
        if (prev.some((m) => m.id === saved.id)) return prev;
        return [...prev, saved];
      });
    } catch (e) {
      alert(e instanceof Error ? e.message : "Failed to send");
      setDraft(body); // restore le draft si erreur
    } finally {
      setSending(false);
    }
  }

  // v413 — Daniel : suivi animal dans le chat web. Demande de suivi en direct
  // (POST /conversations/:id/follow-request) → crée une carte pawfollow_request
  // que l'autre peut accepter/refuser. On recharge les messages après.
  const [followBusy, setFollowBusy] = useState(false);
  async function handleRequestFollow() {
    if (!activeId || followBusy) return;
    setFollowBusy(true);
    try {
      await requestFollowByConversation(activeId);
      const list = await getMessages(activeId);
      setMessages(list);
    } catch (e) {
      alert(e instanceof Error ? e.message : "Erreur");
    } finally {
      setFollowBusy(false);
    }
  }

  // v413 — envoi de photo(s) dans le chat web (max 5).
  const photoInputRef = useRef<HTMLInputElement>(null);
  async function handlePhotoSelected(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files || []);
    e.target.value = "";
    if (!activeId || files.length === 0 || !user) return;
    setSending(true);
    try {
      const saved = await sendMessageWithAttachments(activeId, files, draft.trim());
      setDraft("");
      setMessages((prev) =>
        prev.some((m) => m.id === saved.id) ? prev : [...prev, saved],
      );
    } catch (err) {
      alert(err instanceof Error ? err.message : "Erreur");
    } finally {
      setSending(false);
    }
  }

  async function handleRespondFollow(messageId: string, action: "accept" | "refuse") {
    if (followBusy) return;
    setFollowBusy(true);
    try {
      await respondPawfollowRequest(messageId, action);
      if (activeId) {
        const list = await getMessages(activeId);
        setMessages(list);
      }
    } catch (e) {
      alert(e instanceof Error ? e.message : "Erreur");
    } finally {
      setFollowBusy(false);
    }
  }

  // v23.1 part 248b — Daniel : "le bouton ... il faut quil ouvre un chat
  // avec un amis qui choisis". Ouvre la modale + charge la friend list.
  async function handleOpenNewConvModal() {
    setShowNewConvModal(true);
    if (friends.length === 0) {
      setLoadingFriends(true);
      try {
        const list = await getMyFriends();
        // Filtre : seuls les amis acceptes non supprimes, et qu'on n'a
        // pas DEJA en conversation (sinon doublon, l'user devrait juste
        // cliquer sur la conv existante).
        const accepted = list.filter(
          (f) => f.status === "accepted" && !f.other?.deleted && f.other?.id,
        );
        setFriends(accepted);
      } catch (e) {
        alert(e instanceof Error ? e.message : "Failed to load friends");
      } finally {
        setLoadingFriends(false);
      }
    }
  }

  async function handlePickFriend(friend: FriendItem) {
    if (!friend.other?.id || startingChatWith) return;
    setStartingChatWith(friend.other.id);
    try {
      const role = (friend.other.model || "Owner").toLowerCase() as AuthRole;
      const { conversationId } = await startFriendConversation({
        targetUserId: friend.other.id,
        targetUserRole: role,
      });
      if (!conversationId) {
        alert("Failed to start chat.");
        return;
      }
      // Refresh la liste pour que la nouvelle conv apparaisse en haut.
      const updated = await getConversations();
      updated.sort((a, b) => {
        const da = new Date(a.lastMessageAt || 0).getTime();
        const db = new Date(b.lastMessageAt || 0).getTime();
        return db - da;
      });
      setConversations(updated);
      setShowNewConvModal(false);
      // Ouvre la nouvelle conv directement (idempotent serveur-side :
      // si la conv existait deja, on retombe simplement sur la meme).
      openConversation(conversationId);
    } catch (e) {
      alert(e instanceof Error ? e.message : "Failed to start chat");
    } finally {
      setStartingChatWith(null);
    }
  }

  // v23.1 part 248 — Daniel : "dans messag il manque le bouton pour effacer
  // la conversation et nouvelle conversation". On wire les 2 actions.
  async function handleDeleteConversation(id: string) {
    if (typeof window !== "undefined") {
      const confirmed = window.confirm(t("chat_delete_confirm"));
      if (!confirmed) return;
    }
    try {
      await deleteConversation(id);
      setConversations((prev) => prev.filter((c) => c.id !== id));
      if (activeId === id) {
        setActiveId(null);
        setMessages([]);
      }
    } catch (e) {
      alert(e instanceof Error ? e.message : "Failed to delete");
    }
  }

  if (loading) {
    return (
      <div className="mx-auto max-w-5xl px-4 py-24 text-center text-ink-muted">
        {t("common_loading")}
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-5xl px-4 py-12 md:py-16">
      <div className="mb-6">
        <Link href="/dashboard" className="text-sm text-ink-muted hover:text-ink">
          ← {t("nav_dashboard")}
        </Link>
      </div>

      {/* v248 — Header avec titre + bouton "Nouvelle conversation" qui
          renvoie vers /friends/live ou l'user peut piquer un ami pour
          lancer une conv (parite mobile FAB v244c). */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="font-display text-3xl font-extrabold md:text-4xl">
            {t("chat_page_title")}
          </h1>
          <p className="mt-2 text-ink-muted">{t("chat_page_subtitle")}</p>
        </div>
        <button
          type="button"
          onClick={handleOpenNewConvModal}
          className="inline-flex items-center gap-2 rounded-full bg-walker px-4 py-2 text-sm font-semibold text-white shadow-cta hover:bg-walker-dark"
        >
          <span aria-hidden="true">💬</span>
          <span>{t("chat_new_conversation_btn")}</span>
        </button>
      </div>

      {error && (
        <div className="mt-6 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      <div className="mt-8 grid gap-4 md:grid-cols-[280px_1fr] md:gap-6">
        {/* Liste conversations */}
        <div
          className={`${
            activeId ? "hidden md:block" : "block"
          } space-y-2 md:max-h-[600px] md:overflow-y-auto`}
        >
          {conversations.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-ink/15 px-4 py-12 text-center text-sm text-ink-muted">
              {t("chat_empty_state")}
            </div>
          ) : (
            conversations.map((c) => (
              <div
                key={c.id}
                className={`group relative w-full rounded-xl border px-4 py-3 transition ${
                  activeId === c.id
                    ? "border-walker bg-walker/5"
                    : "border-ink/5 bg-white hover:border-ink/15"
                }`}
              >
                <button
                  type="button"
                  onClick={() => openConversation(c.id)}
                  className="w-full text-left"
                >
                  <div className="flex items-center justify-between gap-2 pr-8">
                    {/* v23.1 part 243 round 3 — fallback otherParty pour les
                        friendChats (backend v23.1.200) afin que les
                        conversations entre amis apparaissent avec le bon nom
                        sur le web aussi (parite Android/iOS). */}
                    <span className="truncate text-sm font-semibold text-ink">
                      {c.participantName ||
                        c.otherParty?.name ||
                        "Conversation"}
                    </span>
                    {(c.unreadCount ?? 0) > 0 && (
                      <span className="rounded-full bg-walker px-2 py-0.5 text-xs font-bold text-white">
                        {c.unreadCount}
                      </span>
                    )}
                  </div>
                  {c.lastMessage && (
                    <div className="mt-1 truncate text-xs text-ink-muted">
                      {c.lastMessage}
                    </div>
                  )}
                </button>
                {/* v248 — bouton effacer conversation (icone poubelle) :
                    visible au hover sur desktop, toujours visible sur mobile. */}
                <button
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation();
                    handleDeleteConversation(c.id);
                  }}
                  aria-label={t("chat_delete_btn")}
                  title={t("chat_delete_btn")}
                  className="absolute right-2 top-2 inline-flex h-7 w-7 items-center justify-center rounded-full text-ink-muted opacity-60 transition hover:bg-red-50 hover:text-red-600 hover:opacity-100 md:opacity-0 md:group-hover:opacity-60"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    className="h-4 w-4"
                  >
                    <polyline points="3 6 5 6 21 6" />
                    <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" />
                    <path d="M10 11v6" />
                    <path d="M14 11v6" />
                    <path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
                  </svg>
                </button>
              </div>
            ))
          )}
        </div>

        {/* Détail conversation */}
        <div
          className={`${
            activeId ? "block" : "hidden md:flex md:items-center md:justify-center"
          } flex min-h-[400px] flex-col rounded-2xl border border-ink/5 bg-white shadow-card md:min-h-[600px]`}
        >
          {!activeId ? (
            <div className="p-12 text-center text-sm text-ink-muted">
              Sélectionne une conversation
            </div>
          ) : (
            <>
              <div className="flex items-center justify-between gap-2 border-b border-ink/5 p-3">
                <button
                  type="button"
                  onClick={() => setActiveId(null)}
                  className="text-sm text-ink-muted hover:text-ink md:hidden"
                >
                  ← Conversations
                </button>
                <span className="hidden md:block" />
                {/* v413 — Demander à suivre l'animal en direct (PawFollow). */}
                <button
                  type="button"
                  onClick={handleRequestFollow}
                  disabled={followBusy}
                  className="inline-flex items-center gap-1.5 rounded-full border border-owner/40 px-3 py-1.5 text-xs font-semibold text-owner transition hover:bg-owner-light/40 disabled:opacity-60"
                >
                  📍 {t("chat_request_follow")}
                </button>
              </div>
              <div className="flex-1 space-y-2 overflow-y-auto p-4">
                {loadingMessages ? (
                  <div className="text-center text-sm text-ink-muted">{t("common_loading")}</div>
                ) : messages.length === 0 ? (
                  <div className="text-center text-sm text-ink-muted">
                    Aucun message pour l&apos;instant.
                  </div>
                ) : (
                  messages.map((m) => {
                    const mine = m.senderId === user?.id;
                    // v413 — carte « Demande de suivi en direct » (pawfollow).
                    if (m.type === "pawfollow_request") {
                      const status = (m.metadata?.status as string) || "pending";
                      const bookingId = m.metadata?.bookingId as string | undefined;
                      const canRespond = status === "pending" && !mine;
                      const statusLabel =
                        status === "accepted"
                          ? t("chat_follow_accepted")
                          : status === "refused"
                            ? t("chat_follow_refused")
                            : t("chat_follow_pending");
                      return (
                        <div key={m.id} className="flex justify-center">
                          <div className="w-full max-w-[88%] rounded-2xl border border-owner/30 bg-owner-light/30 p-3">
                            <div className="flex items-center gap-2 text-sm font-bold text-owner">
                              <span>📍</span>
                              {t("chat_follow_card_title")}
                            </div>
                            <div className="mt-1 text-xs text-ink-muted">{statusLabel}</div>
                            {canRespond && (
                              <div className="mt-2 flex gap-2">
                                <button
                                  type="button"
                                  disabled={followBusy}
                                  onClick={() => handleRespondFollow(m.id, "accept")}
                                  className="rounded-full bg-[#16A34A] px-4 py-1.5 text-xs font-semibold text-white disabled:opacity-60"
                                >
                                  {t("chat_follow_accept")}
                                </button>
                                <button
                                  type="button"
                                  disabled={followBusy}
                                  onClick={() => handleRespondFollow(m.id, "refuse")}
                                  className="rounded-full border border-ink/15 px-4 py-1.5 text-xs font-semibold text-ink-muted disabled:opacity-60"
                                >
                                  {t("chat_follow_refuse")}
                                </button>
                              </div>
                            )}
                            {status === "accepted" && (
                              <a
                                href={
                                  bookingId
                                    ? `/walk/${bookingId}`
                                    : "/friends/live"
                                }
                                className="mt-2 inline-flex items-center gap-1.5 rounded-full bg-owner px-4 py-1.5 text-xs font-semibold text-white"
                              >
                                🗺️ {t("chat_follow_view_map")}
                              </a>
                            )}
                          </div>
                        </div>
                      );
                    }
                    return (
                      <div
                        key={m.id}
                        className={`flex ${mine ? "justify-end" : "justify-start"}`}
                      >
                        <div
                          className={`max-w-[75%] rounded-2xl px-4 py-2 text-sm ${
                            mine
                              ? "bg-walker text-white"
                              : "bg-ink/5 text-ink"
                          }`}
                        >
                          {m.body}
                          {/* v413 — photos jointes. */}
                          {Array.isArray(m.attachments) &&
                            m.attachments.filter((a) => a?.url).length > 0 && (
                              <div className="mt-1 flex flex-col gap-1">
                                {m.attachments
                                  .filter((a) => a?.url)
                                  .map((a, i) => (
                                    // eslint-disable-next-line @next/next/no-img-element
                                    <a
                                      key={i}
                                      href={a.url}
                                      target="_blank"
                                      rel="noopener noreferrer"
                                    >
                                      <img
                                        src={a.url}
                                        alt=""
                                        className="max-h-48 w-full rounded-lg object-cover"
                                      />
                                    </a>
                                  ))}
                              </div>
                            )}
                          <div
                            className={`mt-0.5 text-[10px] ${
                              mine ? "text-white/70" : "text-ink-muted"
                            }`}
                          >
                            {new Date(m.createdAt).toLocaleTimeString("fr-FR", {
                              hour: "2-digit",
                              minute: "2-digit",
                            })}
                          </div>
                        </div>
                      </div>
                    );
                  })
                )}
                <div ref={messagesEndRef} />
              </div>
              <form
                onSubmit={handleSend}
                className="flex items-center gap-2 border-t border-ink/5 p-3"
              >
                {/* v413 — envoi de photo dans le chat web. */}
                <input
                  ref={photoInputRef}
                  type="file"
                  accept="image/*"
                  multiple
                  className="hidden"
                  onChange={handlePhotoSelected}
                />
                <button
                  type="button"
                  onClick={() => photoInputRef.current?.click()}
                  disabled={sending}
                  aria-label="Photo"
                  className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full border border-ink/15 text-lg hover:bg-bg-soft disabled:opacity-60"
                >
                  📷
                </button>
                <input
                  type="text"
                  value={draft}
                  onChange={(e) => setDraft(e.target.value)}
                  placeholder="Écris un message…"
                  className="flex-1 rounded-full border border-ink/15 px-4 py-2 text-sm focus:border-walker focus:outline-none focus:ring-2 focus:ring-walker/20"
                />
                <button
                  type="submit"
                  disabled={sending || !draft.trim()}
                  className="rounded-full bg-walker px-5 py-2 text-sm font-semibold text-white disabled:opacity-60"
                >
                  Envoyer
                </button>
              </form>
            </>
          )}
        </div>
      </div>

      {/* v23.1 part 248b — Modal sélection ami pour nouvelle conv */}
      {showNewConvModal && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
          onClick={() => setShowNewConvModal(false)}
        >
          <div
            className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mb-4 flex items-center justify-between">
              <h2 className="font-display text-lg font-extrabold">
                {t("chat_new_conv_modal_title")}
              </h2>
              <button
                type="button"
                onClick={() => setShowNewConvModal(false)}
                aria-label={t("chat_new_conv_modal_close")}
                className="rounded-full p-1 text-ink-muted hover:bg-bg-soft hover:text-ink"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  className="h-5 w-5"
                >
                  <line x1="18" y1="6" x2="6" y2="18" />
                  <line x1="6" y1="6" x2="18" y2="18" />
                </svg>
              </button>
            </div>

            <div className="max-h-[60vh] space-y-2 overflow-y-auto">
              {loadingFriends ? (
                <div className="py-8 text-center text-sm text-ink-muted">
                  {t("common_loading")}
                </div>
              ) : friends.length === 0 ? (
                <div className="rounded-xl bg-bg-soft px-4 py-8 text-center text-sm text-ink-muted">
                  {t("chat_new_conv_modal_empty")}
                </div>
              ) : (
                friends.map((f) => {
                  const other = f.other;
                  if (!other?.id) return null;
                  const role = (other.model || "").toLowerCase();
                  const isPicking = startingChatWith === other.id;
                  const roleColor =
                    role === "walker"
                      ? "#16A34A"
                      : role === "sitter"
                        ? "#2563EB"
                        : "#EF4324";
                  return (
                    <button
                      key={f.id}
                      type="button"
                      disabled={!!startingChatWith}
                      onClick={() => handlePickFriend(f)}
                      className="flex w-full items-center gap-3 rounded-xl border border-ink/5 bg-white px-3 py-2.5 text-left transition hover:border-walker hover:bg-walker/5 disabled:opacity-50"
                    >
                      <div
                        className="grid h-10 w-10 flex-shrink-0 place-items-center overflow-hidden rounded-full"
                        style={{ backgroundColor: roleColor }}
                      >
                        {other.avatar ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img
                            src={other.avatar}
                            alt=""
                            className="h-full w-full object-cover"
                          />
                        ) : (
                          <span className="text-sm font-bold text-white">
                            {(other.name || "?")
                              .split(/\s+/)
                              .map((w) => w[0] || "")
                              .slice(0, 2)
                              .join("")
                              .toUpperCase()}
                          </span>
                        )}
                      </div>
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-semibold text-ink">
                          {other.name || "Friend"}
                        </p>
                        <p className="text-xs capitalize text-ink-muted">
                          {t(`role_${role || "owner"}`)}
                        </p>
                      </div>
                      {isPicking && (
                        <span className="text-xs text-ink-muted">…</span>
                      )}
                    </button>
                  );
                })
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
