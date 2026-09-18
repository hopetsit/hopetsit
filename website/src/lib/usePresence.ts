"use client";

// v565 (contrat §6) — présence « en ligne » temps réel pour le site.
// Le serveur émet `presence:update { userId, online, at }` aux amis et aux
// correspondants de conversation à chaque connexion / déconnexion socket.
// Ce hook tient une table userId → online, à croiser avec la valeur
// `isOnline` lue au chargement (/conversations/list, /friends,
// /friends/members/nearby) : la lecture donne l'état initial, le socket
// les changements. `resolveOnline(id, fallback)` fait cette fusion.

import { useCallback, useState } from "react";
import { useSocketEvent } from "./useSocket";

// Le serveur (build 565) peut porter `userId` (un seul) ou `userIds` (les 3
// identités de la même personne) : on marque tous les ids reçus.
export type PresenceUpdate = { userId?: string; userIds?: string[]; online: boolean; at?: string };

export function usePresence(): {
  presence: Map<string, boolean>;
  /** État en ligne d'un utilisateur : socket si connu, sinon la valeur lue. */
  resolveOnline: (userId?: string | null, fallback?: boolean | null) => boolean;
} {
  const [presence, setPresence] = useState<Map<string, boolean>>(() => new Map());

  useSocketEvent<PresenceUpdate>("presence:update", (data) => {
    const ids = [
      ...(data?.userId ? [String(data.userId)] : []),
      ...(Array.isArray(data?.userIds) ? data.userIds.map(String) : []),
    ].filter(Boolean);
    if (ids.length === 0) return;
    setPresence((prev) => {
      if (ids.every((id) => prev.get(id) === !!data.online)) return prev;
      const next = new Map(prev);
      for (const id of ids) next.set(id, !!data.online);
      return next;
    });
  });

  const resolveOnline = useCallback(
    (userId?: string | null, fallback?: boolean | null) => {
      if (userId && presence.has(String(userId))) return !!presence.get(String(userId));
      return fallback === true;
    },
    [presence],
  );

  return { presence, resolveOnline };
}

/** Petit point vert / gris, commun aux pages (chat, amis). */
export function onlineDotClass(online: boolean): string {
  return online ? "bg-emerald-500" : "bg-[#C7C7CC]";
}
