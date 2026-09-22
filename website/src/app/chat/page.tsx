"use client";

// v23.1 part 146 — Page chat : liste conversations + détail.
// MVP : 2 panneaux côte à côte sur desktop (liste à gauche, conversation
// active à droite), stack vertical sur mobile (clic ouvre la conversation).
// Temps réel via socket.io : nouveaux messages arrivent live.

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import BackLink from "@/components/BackLink";
import {
  ApiError,
  AuthRole,
  ChatDeliveredEvent,
  ChatFeatures,
  ChatMessage,
  ChatReadEvent,
  chatReceiptStatus,
  ChatReceiptStatus,
  ChatReplyTo,
  Conversation,
  deleteConversation,
  FriendItem,
  getChatFeatures,
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
import { usePresence } from "@/lib/usePresence";

// v565 (point 10) — identité de l'autre personne d'une conversation (chat
// ami : `otherParty`, chat réservation : l'autre rôle que le mien).
function otherUserId(c: Conversation, myRole?: string): string | undefined {
  if (c.otherParty?.id) return c.otherParty.id;
  if (myRole === "owner") return c.sitterId || c.walkerId;
  return c.ownerId;
}

// v565 (point 36/18) — résumé lisible d'un message cité (réponse).
function replyPreview(r: ChatReplyTo, t: (k: string) => string): string {
  if (r.kind === "image") return `📷 ${t("chat_reply_photo")}`;
  if (r.kind === "video") return `🎬 ${t("chat_reply_video")}`;
  if (r.kind === "audio") return `🎤 ${t("chat_reply_voice")}`;
  if (r.kind === "phone_share") return `📞 ${t("chat_reply_phone")}`;
  if (r.kind === "address_share") return `📍 ${t("chat_reply_address")}`;
  return r.body || "…";
}

// Instantané `replyTo` construit localement depuis le message qu'on cite
// (le serveur stocke le sien ; celui-ci sert à l'aperçu dans le composeur).
function toReplySnapshot(m: ChatMessage): ChatReplyTo {
  const a = Array.isArray(m.attachments) ? m.attachments[0] : undefined;
  const rt = String(a?.resourceType || a?.type || "").toLowerCase();
  const kind: ChatReplyTo["kind"] =
    m.type === "voice" || rt === "audio"
      ? "audio"
      : m.type === "phone_share" || m.type === "address_share"
        ? m.type
        : rt === "video"
          ? "video"
          : a?.url
            ? "image"
            : "text";
  return {
    messageId: m.id,
    body: (m.body || "").slice(0, 120),
    senderRole: m.senderRole,
    senderId: m.senderId,
    kind,
  };
}

function isAudioAttachment(a: { resourceType?: string; type?: string; url: string }): boolean {
  const rt = String(a.resourceType || a.type || "").toLowerCase();
  return rt === "audio" || /\.(m4a|aac|mp3|ogg|wav|webm)(\?|$)/i.test(a.url || "");
}

// v566 — coches façon WhatsApp. Sur une bulle colorée, le bleu « lu » est posé
// sur une mini-pastille blanche pour rester lisible.
function ReceiptTicks({
  status,
  label,
  onColor = false,
}: {
  status: ChatReceiptStatus;
  label: string;
  onColor?: boolean;
}) {
  const read = status === "read";
  const glyph = status === "sent" ? "✓" : "✓✓";
  return (
    <span
      title={label}
      aria-label={label}
      className={`shrink-0 text-[11px] font-bold leading-none tracking-[-0.15em] ${
        read
          ? onColor
            ? "rounded-full bg-white/95 px-1 py-px text-[#34B7F1]"
            : "text-[#34B7F1]"
          : onColor
            ? "text-white/70"
            : "text-ink-muted"
      }`}
    >
      {glyph}
    </span>
  );
}

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
  // v565 (point 36/18) — réponse à un message + drapeaux admin du chat.
  const [replyTo, setReplyTo] = useState<ChatMessage | null>(null);
  const [features, setFeatures] = useState<ChatFeatures>({ media: true, voice: true, reply: true });
  const draftInputRef = useRef<HTMLInputElement>(null);
  // v565 (point 10) — présence réelle (`isOnline` de /conversations/list + socket).
  const { resolveOnline } = usePresence();
  // v23.1 part 248b — Modal "Nouvelle conversation" : Daniel veut
  // choisir un ami pour ouvrir un chat direct avec lui (au lieu d'etre
  // redirige sur /friends/live). On lazy-load les amis a l'ouverture
  // du modal pour eviter une requete inutile sur les visites /chat
  // qui ne touchent pas au bouton.
  const [showNewConvModal, setShowNewConvModal] = useState(false);
  const [friends, setFriends] = useState<FriendItem[]>([]);
  const [loadingFriends, setLoadingFriends] = useState(false);
  const [startingChatWith, setStartingChatWith] = useState<string | null>(null);
  // v569 — suppression d'une conversation : confirmation dans une boîte propre
  // (plus de window.confirm), suppression optimiste, et retrait en direct sur
  // mes autres appareils via `conversation:deleted`.
  const [deleteTarget, setDeleteTarget] = useState<Conversation | null>(null);
  const [deleting, setDeleting] = useState(false);

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
    // v565 — drapeaux admin (médias / vocal / réponse) chargés à l'ouverture.
    getChatFeatures().then(setFeatures).catch(() => {});
  }, [router]);

  // v569 — `silent` : rechargement de fond (une conversation masquée qui
  // revient parce que l'autre m'écrit) — surtout pas l'écran « Chargement… »
  // à la place de la page à chaque message.
  async function refresh(silent = false) {
    if (!silent) setLoading(true);
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
      if (!silent) setLoading(false);
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
    setReplyTo(null);
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
      // v566 — accusés façon WhatsApp. Message REÇU dans la conversation
      // ouverte et onglet visible → lu (`conversation:read` pose readAt côté
      // serveur) ; sinon simple accusé de réception (`message:delivered`).
      // Le serveur ne répond qu'à l'EXPÉDITEUR → aucune boucle.
      const fromOther =
        !!msg.id && !!msg.senderId && msg.senderId !== user?.id &&
        String(msg.senderRole) !== "system";
      if (fromOther) {
        const sock = getSocket();
        const visible =
          typeof document === "undefined" || document.visibilityState === "visible";
        if (sock && msg.conversationId === activeId && visible && user) {
          sock.emit("conversation:read", {
            conversationId: msg.conversationId,
            role: user.role,
            userId: user.id,
          });
        } else if (sock && !msg.deliveredAt && !ackedRef.current.has(msg.id)) {
          ackedRef.current.add(msg.id);
          sock.emit("message:delivered", {
            conversationId: msg.conversationId,
            messageId: msg.id,
          });
        }
      }
      if (msg.conversationId === activeId) {
        setMessages((prev) => {
          if (prev.some((m) => m.id === msg.id)) return prev; // dédup
          return [...prev, msg];
        });
        setConversations((prev) =>
          prev.map((c) =>
            c.id === msg.conversationId
              ? {
                  ...c,
                  lastMessage: msg.body || c.lastMessage,
                  lastMessageAt: msg.createdAt,
                  lastMessageMine: !fromOther,
                  lastMessageStatus: "sent" as ChatReceiptStatus,
                }
              : c,
          ),
        );
      } else {
        // v569 — conversation ABSENTE de ma liste : soit elle est nouvelle,
        // soit je l'avais supprimée (masquée) et l'autre vient de m'écrire —
        // le serveur vide alors `clearedFor` et la conversation M'EST rendue,
        // avec son historique. Avant, la liste l'ignorait jusqu'au prochain
        // rechargement de la page (l'app, elle, rechargeait déjà). On
        // rafraîchit donc la liste : même comportement sur les 3 surfaces.
        if (!conversations.some((c) => c.id === msg.conversationId)) {
          void refresh(true);
          return;
        }
        // Bump unread sur la conv concernée, et hoist en haut.
        setConversations((prev) => {
          const idx = prev.findIndex((c) => c.id === msg.conversationId);
          if (idx < 0) return prev;
          const next = [...prev];
          const target = {
            ...next[idx],
            lastMessage: msg.body,
            lastMessageAt: msg.createdAt,
            unreadCount: (next[idx].unreadCount || 0) + (fromOther ? 1 : 0),
            lastMessageMine: !fromOther,
            lastMessageStatus: "sent" as ChatReceiptStatus,
          };
          next.splice(idx, 1);
          return [target, ...next];
        });
      }
    },
  );

  // v566 — `message:read` / `message:delivered` : les coches se mettent à
  // jour sans recharger. « Lu » est un pointeur : tous MES messages envoyés
  // avant `readAt` sont lus.
  const ackedRef = useRef<Set<string>>(new Set());
  function bumpListStatus(conversationId: string, status: ChatReceiptStatus) {
    setConversations((prev) =>
      prev.map((c) => {
        if (c.id !== conversationId || !c.lastMessageMine) return c;
        if (c.lastMessageStatus === "read") return c;
        if (status === "delivered" && c.lastMessageStatus === "delivered") return c;
        return { ...c, lastMessageStatus: status };
      }),
    );
  }
  useSocketEvent<ChatReadEvent>("message:read", (data) => {
    if (!data?.conversationId) return;
    const readAt = data.readAt || new Date().toISOString();
    const ids = new Set(data.messageIds || []);
    const limit = new Date(readAt).getTime();
    if (data.conversationId === activeId) {
      setMessages((prev) =>
        prev.map((m) => {
          if (m.senderId !== user?.id || m.readAt) return m;
          const hit = ids.has(m.id) || new Date(m.createdAt).getTime() <= limit;
          return hit ? { ...m, deliveredAt: m.deliveredAt || readAt, readAt } : m;
        }),
      );
    }
    bumpListStatus(data.conversationId, "read");
  });
  useSocketEvent<ChatDeliveredEvent>("message:delivered", (data) => {
    if (!data?.conversationId) return;
    const deliveredAt = data.deliveredAt || new Date().toISOString();
    const ids = new Set([...(data.messageIds || []), data.messageId].filter(Boolean));
    if (data.conversationId === activeId) {
      setMessages((prev) =>
        prev.map((m) =>
          ids.has(m.id) && m.senderId === user?.id && !m.deliveredAt
            ? { ...m, deliveredAt }
            : m,
        ),
      );
    }
    bumpListStatus(data.conversationId, "delivered");
  });

  // v566 — l'onglet redevient visible avec une conversation ouverte → lu.
  useEffect(() => {
    const onVisible = () => {
      if (document.visibilityState !== "visible" || !activeId || !user) return;
      getSocket()?.emit("conversation:read", {
        conversationId: activeId,
        role: user.role,
        userId: user.id,
      });
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => document.removeEventListener("visibilitychange", onVisible);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeId]);

  useSocketEvent<{ conversationId: string; messageId: string }>(
    "message:deleted",
    (data) => {
      if (data.conversationId === activeId) {
        setMessages((prev) => prev.filter((m) => m.id !== data.messageId));
      }
    },
  );

  // v569 — Daniel : « que tout soit bien synchronisé Android / iOS / web ».
  // Le serveur émet `conversation:deleted { conversationId }` vers MES trois
  // rooms de rôle quand je supprime une conversation (sur n'importe lequel de
  // mes appareils) : l'onglet ouvert ici retire la ligne SANS recharger, et
  // ferme le panneau de droite si c'était la conversation affichée. Rien n'est
  // émis à l'autre personne : elle garde sa copie.
  useSocketEvent<{ conversationId?: string }>("conversation:deleted", (data) => {
    const id = data?.conversationId;
    if (!id) return;
    setConversations((prev) => prev.filter((c) => c.id !== id));
    setDeleteTarget((prev) => (prev && prev.id === id ? null : prev));
    if (activeId === id) {
      setActiveId(null);
      setMessages([]);
    }
  });

  // v566 — « Lu · heure » : sous le DERNIER de mes messages lus.
  let lastReadId = "";
  for (let i = messages.length - 1; i >= 0; i--) {
    const m = messages[i];
    if (m.senderId === user?.id && m.readAt) {
      lastReadId = m.id;
      break;
    }
  }

  async function handleSend(e: React.FormEvent) {
    e.preventDefault();
    if (!activeId || !draft.trim() || !user) return;
    const body = draft.trim();
    const quoted = replyTo;
    setDraft("");
    setReplyTo(null);
    setSending(true);
    try {
      const saved = await sendMessage(
        activeId,
        body,
        quoted && features.reply ? { messageId: quoted.id } : null,
      );
      // L'event socket message:new va arriver mais on append tout de suite
      // pour la latence perçue. Le dédup ID-based dans le listener évite
      // d'avoir le message en double.
      setMessages((prev) => {
        if (prev.some((m) => m.id === saved.id)) return prev;
        return [...prev, saved];
      });
      // v566 — le dernier message est le mien : ✓ devant l'aperçu.
      setConversations((prev) =>
        prev.map((c) =>
          c.id === activeId
            ? {
                ...c,
                lastMessage: body,
                lastMessageAt: saved.createdAt,
                lastMessageMine: true,
                lastMessageStatus: chatReceiptStatus(saved),
              }
            : c,
        ),
      );
    } catch (e) {
      const disabled =
        e instanceof ApiError &&
        e.status === 403 &&
        (e.details as { code?: string } | null)?.code === "FEATURE_DISABLED";
      alert(disabled ? t("chat_feature_disabled") : e instanceof Error ? e.message : "Failed to send");
      setDraft(body); // restore le draft si erreur
      if (quoted) setReplyTo(quoted);
      if (disabled) setFeatures((f) => ({ ...f, reply: false }));
    } finally {
      setSending(false);
    }
  }

  // v565 — « Répondre » sur une bulle → aperçu au-dessus du composeur.
  function startReply(m: ChatMessage) {
    if (!features.reply) return;
    setReplyTo(m);
    draftInputRef.current?.focus();
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
      const disabled =
        err instanceof ApiError &&
        err.status === 403 &&
        (err.details as { code?: string } | null)?.code === "FEATURE_DISABLED";
      alert(disabled ? t("chat_feature_disabled") : err instanceof Error ? err.message : "Erreur");
      if (disabled) setFeatures((f) => ({ ...f, media: false }));
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
  // la conversation et nouvelle conversation".
  // v569 — plus de `window.confirm` : boîte de confirmation dans le style du
  // site (même texte honnête que l'app), puis suppression OPTIMISTE.
  async function confirmDeleteConversation() {
    const target = deleteTarget;
    if (!target || deleting) return;
    const id = target.id;
    // La ligne part tout de suite ; on garde sa place pour pouvoir la remettre.
    const index = conversations.findIndex((c) => c.id === id);
    const wasActive = activeId === id;
    setDeleting(true);
    setConversations((prev) => prev.filter((c) => c.id !== id));
    if (wasActive) {
      setActiveId(null);
      setMessages([]);
    }
    try {
      await deleteConversation(id);
      setDeleteTarget(null);
    } catch (e) {
      // Échec réseau : la conversation REVIENT à sa place, avec un message.
      setConversations((prev) => {
        if (prev.some((c) => c.id === id)) return prev;
        const next = [...prev];
        next.splice(index < 0 ? next.length : index, 0, target);
        return next;
      });
      setError(e instanceof Error ? e.message : t("chatdel569_failed_body"));
      setDeleteTarget(null);
    } finally {
      setDeleting(false);
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
        <BackLink href="/dashboard" label={t("nav_dashboard")} />
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
            conversations.map((c) => {
              const online = resolveOnline(otherUserId(c, user?.role), c.isOnline);
              return (
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
                    <span className="flex min-w-0 items-center gap-2 text-sm font-semibold text-ink">
                      {/* v565 (point 10) — point vert « en ligne » réel. */}
                      <span
                        aria-label={online ? t("chat_online") : t("chat_offline")}
                        title={online ? t("chat_online") : t("chat_offline")}
                        className={`inline-block h-2.5 w-2.5 shrink-0 rounded-full ${
                          online ? "bg-emerald-500" : "bg-[#D6C3BE]"
                        }`}
                      />
                      <span className="truncate">
                        {c.participantName ||
                          c.otherParty?.name ||
                          "Conversation"}
                      </span>
                    </span>
                    {(c.unreadCount ?? 0) > 0 && (
                      <span className="rounded-full bg-walker px-2 py-0.5 text-xs font-bold text-white">
                        {c.unreadCount}
                      </span>
                    )}
                  </div>
                  {c.lastMessage && (
                    <div className="mt-1 flex items-center gap-1 text-xs text-ink-muted">
                      {/* v566 — coches quand le dernier message est le mien. */}
                      {c.lastMessageMine && c.lastMessageStatus && (
                        <ReceiptTicks
                          status={c.lastMessageStatus}
                          label={t(`chat_receipt_${c.lastMessageStatus}`)}
                        />
                      )}
                      <span className="truncate">{c.lastMessage}</span>
                    </div>
                  )}
                </button>
                {/* v248 — bouton effacer conversation (icone poubelle) :
                    visible au hover sur desktop, toujours visible sur mobile. */}
                <button
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation();
                    setDeleteTarget(c);
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
              );
            })
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
              {t("chat_select_conv")}
            </div>
          ) : (
            <>
              <div className="flex items-center justify-between gap-2 border-b border-ink/5 p-3">
                <button
                  type="button"
                  onClick={() => setActiveId(null)}
                  className="text-sm text-ink-muted hover:text-ink md:hidden"
                >
                  ← {t("chat_back")}
                </button>
                {/* v565 (point 10) — nom + état en ligne du correspondant. */}
                {(() => {
                  const c = conversations.find((x) => x.id === activeId);
                  const online = c ? resolveOnline(otherUserId(c, user?.role), c.isOnline) : false;
                  return (
                    <span className="hidden min-w-0 items-center gap-2 md:flex">
                      <span
                        className={`inline-block h-2.5 w-2.5 shrink-0 rounded-full ${
                          online ? "bg-emerald-500" : "bg-[#D6C3BE]"
                        }`}
                      />
                      <span className="truncate text-sm font-semibold text-ink">
                        {c?.participantName || c?.otherParty?.name || ""}
                      </span>
                      <span className={`text-xs ${online ? "text-emerald-600" : "text-ink-muted"}`}>
                        {online ? t("chat_online") : t("chat_offline")}
                      </span>
                    </span>
                  );
                })()}
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
                    {t("chat_no_messages")}
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
                    // v565 (point 36/18) — pièces jointes : vocal (audio) lu
                    // dans un <audio controls>, le reste en image cliquable.
                    const atts = Array.isArray(m.attachments) ? m.attachments.filter((a) => a?.url) : [];
                    const audios = atts.filter(isAudioAttachment);
                    const images = atts.filter((a) => !isAudioAttachment(a));
                    const isVoice = m.type === "voice" || audios.length > 0;
                    const quote = m.replyTo && m.replyTo.messageId ? m.replyTo : null;
                    const quoteMine = quote ? quote.senderId === user?.id : false;
                    return (
                      <div
                        key={m.id}
                        className={`group/msg flex items-end gap-1 ${mine ? "flex-row-reverse" : "flex-row"}`}
                      >
                        <div
                          className={`max-w-[75%] rounded-2xl px-4 py-2 text-sm ${
                            mine
                              ? "bg-walker text-white"
                              : "bg-ink/5 text-ink"
                          }`}
                        >
                          {/* v565 — citation du message auquel on répond. */}
                          {quote && (
                            <div
                              className={`mb-1.5 rounded-lg border-l-4 px-2.5 py-1.5 text-xs ${
                                mine
                                  ? "border-white/70 bg-white/15 text-white/90"
                                  : "border-walker bg-white/70 text-ink/80"
                              }`}
                            >
                              <div className="font-semibold">
                                {quoteMine
                                  ? t("chat_reply_you")
                                  : conversations.find((x) => x.id === activeId)?.participantName ||
                                    conversations.find((x) => x.id === activeId)?.otherParty?.name ||
                                    ""}
                              </div>
                              <div className="line-clamp-2 break-words">{replyPreview(quote, t)}</div>
                            </div>
                          )}
                          {isVoice && (
                            <div className="flex flex-col gap-1">
                              <span className={`text-xs font-semibold ${mine ? "text-white/85" : "text-ink-muted"}`}>
                                🎤 {t("chat_voice_message")}
                                {typeof audios[0]?.duration === "number" && audios[0].duration > 0
                                  ? ` · ${Math.floor(audios[0].duration / 60)}:${String(Math.round(audios[0].duration % 60)).padStart(2, "0")}`
                                  : ""}
                              </span>
                              {audios.map((a, i) => (
                                <audio key={i} controls preload="metadata" src={a.url} className="h-9 w-[220px] max-w-full" />
                              ))}
                            </div>
                          )}
                          {m.body && <div className="whitespace-pre-wrap break-words">{m.body}</div>}
                          {/* v413 — photos jointes. */}
                          {images.length > 0 && (
                              <div className="mt-1 flex flex-col gap-1">
                                {images.map((a, i) => (
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
                            className={`mt-0.5 flex items-center gap-1 text-[10px] ${
                              mine ? "justify-end text-white/70" : "text-ink-muted"
                            }`}
                          >
                            <span>
                              {new Date(m.createdAt).toLocaleTimeString("fr-FR", {
                                hour: "2-digit",
                                minute: "2-digit",
                              })}
                            </span>
                            {/* v566 — ✓ envoyé / ✓✓ remis / ✓✓ bleu lu. */}
                            {mine && (
                              <ReceiptTicks
                                status={chatReceiptStatus(m)}
                                label={t(`chat_receipt_${chatReceiptStatus(m)}`)}
                                onColor
                              />
                            )}
                          </div>
                          {/* v566 — « Lu · heure » sous le DERNIER message lu. */}
                          {mine && m.id === lastReadId && m.readAt && (
                            <div className="mt-0.5 text-right text-[10px] font-semibold text-white/85">
                              {t("chat_read_at").replace(
                                "{time}",
                                new Date(m.readAt).toLocaleTimeString("fr-FR", {
                                  hour: "2-digit",
                                  minute: "2-digit",
                                }),
                              )}
                            </div>
                          )}
                        </div>
                        {/* v565 — « Répondre » (masqué si l'admin a coupé la fonction). */}
                        {features.reply && (
                          <button
                            type="button"
                            onClick={() => startReply(m)}
                            aria-label={t("chat_reply")}
                            title={t("chat_reply")}
                            className="mb-1 shrink-0 rounded-full px-2 py-1 text-[11px] font-semibold text-ink-muted opacity-70 transition hover:bg-owner-light hover:text-owner-dark hover:opacity-100 md:opacity-0 md:group-hover/msg:opacity-100"
                          >
                            ↩ {t("chat_reply")}
                          </button>
                        )}
                      </div>
                    );
                  })
                )}
                <div ref={messagesEndRef} />
              </div>
              {/* v565 — aperçu « Réponse à … » au-dessus du composeur. */}
              {replyTo && (
                <div className="flex items-center gap-3 border-t border-ink/5 bg-owner-light/60 px-4 py-2">
                  <div className="min-w-0 flex-1 border-l-4 border-owner pl-3">
                    <div className="text-xs font-semibold text-owner-dark">
                      {t("chat_replying_to")}{" "}
                      {replyTo.senderId === user?.id
                        ? t("chat_reply_you")
                        : conversations.find((x) => x.id === activeId)?.participantName ||
                          conversations.find((x) => x.id === activeId)?.otherParty?.name ||
                          ""}
                    </div>
                    <div className="truncate text-xs text-ink/80">
                      {replyPreview(toReplySnapshot(replyTo), t)}
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => setReplyTo(null)}
                    aria-label={t("chat_reply_cancel")}
                    title={t("chat_reply_cancel")}
                    className="shrink-0 rounded-full px-2 py-1 text-sm text-ink-muted hover:bg-white hover:text-ink"
                  >
                    ✕
                  </button>
                </div>
              )}
              <form
                onSubmit={handleSend}
                className="flex items-center gap-2 border-t border-ink/5 p-3"
              >
                {/* v413 — envoi de photo dans le chat web ; v565 : masqué si
                    l'admin a coupé les médias (drapeau `media`). */}
                <input
                  ref={photoInputRef}
                  type="file"
                  accept="image/*"
                  multiple
                  className="hidden"
                  onChange={handlePhotoSelected}
                />
                {features.media && (
                  <button
                    type="button"
                    onClick={() => photoInputRef.current?.click()}
                    disabled={sending}
                    aria-label={t("chat_photo")}
                    title={t("chat_photo")}
                    className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full border border-ink/15 text-lg hover:bg-bg-soft disabled:opacity-60"
                  >
                    📷
                  </button>
                )}
                <input
                  ref={draftInputRef}
                  type="text"
                  value={draft}
                  onChange={(e) => setDraft(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Escape" && replyTo) setReplyTo(null);
                  }}
                  placeholder={t("chat_placeholder")}
                  className="flex-1 rounded-full border border-ink/15 px-4 py-2 text-sm focus:border-walker focus:outline-none focus:ring-2 focus:ring-walker/20"
                />
                <button
                  type="submit"
                  disabled={sending || !draft.trim()}
                  className="rounded-full bg-walker px-5 py-2 text-sm font-semibold text-white disabled:opacity-60"
                >
                  {t("chat_send")}
                </button>
              </form>
            </>
          )}
        </div>
      </div>

      {/* v569 — Confirmation de suppression, style du site (plus de
          window.confirm). Le texte dit la VÉRITÉ du serveur : la conversation
          est masquée pour MOI sur tous MES appareils, l'autre garde sa copie,
          et elle revient avec son historique si cette personne m'écrit. */}
      {deleteTarget && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
          onClick={() => {
            if (!deleting) setDeleteTarget(null);
          }}
        >
          <div
            role="dialog"
            aria-modal="true"
            aria-label={t("chatdel569_sheet_title")}
            className="w-full max-w-sm rounded-2xl bg-white p-6 text-center shadow-xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mx-auto mb-3 grid h-16 w-16 place-items-center overflow-hidden rounded-full bg-bg-soft">
              {deleteTarget.otherParty?.avatar || deleteTarget.participantAvatar ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={deleteTarget.otherParty?.avatar || deleteTarget.participantAvatar}
                  alt=""
                  className="h-full w-full object-cover"
                />
              ) : (
                <span className="text-lg font-bold text-ink-muted">
                  {(deleteTarget.participantName || deleteTarget.otherParty?.name || "?")
                    .split(/\s+/)
                    .map((w) => w[0] || "")
                    .slice(0, 2)
                    .join("")
                    .toUpperCase()}
                </span>
              )}
            </div>
            {(deleteTarget.participantName || deleteTarget.otherParty?.name) && (
              <p className="text-sm font-semibold text-ink-muted">
                {deleteTarget.participantName || deleteTarget.otherParty?.name}
              </p>
            )}
            <h2 className="mt-1 font-display text-lg font-extrabold text-ink">
              {t("chatdel569_sheet_title")}
            </h2>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">
              {(() => {
                const name =
                  deleteTarget.participantName || deleteTarget.otherParty?.name || "";
                return name
                  ? t("chatdel569_sheet_body").replace(/\{name\}/g, name)
                  : t("chatdel569_sheet_body_generic");
              })()}
            </p>
            <button
              type="button"
              disabled={deleting}
              onClick={confirmDeleteConversation}
              className="mt-5 w-full rounded-full bg-red-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-red-700 disabled:opacity-60"
            >
              {deleting ? t("common_loading") : t("chatdel569_confirm")}
            </button>
            <button
              type="button"
              disabled={deleting}
              onClick={() => setDeleteTarget(null)}
              className="mt-2 w-full rounded-full px-4 py-2 text-sm font-semibold text-ink-muted transition hover:text-ink disabled:opacity-60"
            >
              {t("common_cancel")}
            </button>
          </div>
        </div>
      )}

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
                        : "#C92A12";
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
