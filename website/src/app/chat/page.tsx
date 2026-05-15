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
  ChatMessage,
  Conversation,
  getConversations,
  getMessages,
  getStoredUser,
  sendMessage,
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
  useSocketEvent<ChatMessage & { conversationId: string }>(
    "message:new",
    (msg) => {
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
          ← Dashboard
        </Link>
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">Messages</h1>
      <p className="mt-2 text-ink-muted">
        Synchro temps réel avec l&apos;app.
      </p>

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
              Aucune conversation
            </div>
          ) : (
            conversations.map((c) => (
              <button
                key={c.id}
                type="button"
                onClick={() => openConversation(c.id)}
                className={`w-full rounded-xl border px-4 py-3 text-left transition ${
                  activeId === c.id
                    ? "border-walker bg-walker/5"
                    : "border-ink/5 bg-white hover:border-ink/15"
                }`}
              >
                <div className="flex items-center justify-between gap-2">
                  <span className="truncate text-sm font-semibold text-ink">
                    {c.participantName || "Conversation"}
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
              <div className="border-b border-ink/5 p-4 md:hidden">
                <button
                  type="button"
                  onClick={() => setActiveId(null)}
                  className="text-sm text-ink-muted hover:text-ink"
                >
                  ← Conversations
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
                className="flex gap-2 border-t border-ink/5 p-3"
              >
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
    </div>
  );
}
