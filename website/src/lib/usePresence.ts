"use client";

// v565 (contrat §6) — présence « en ligne » temps réel pour le site.
// Le serveur émet `presence:update { userId, online, at }` aux amis et aux
// correspondants de conversation à chaque connexion / déconnexion socket.
// Ce hook tient une table userId → online, à croiser avec la valeur
// `isOnline` lue au chargement (/conversations/list, /friends,
// /friends/members/nearby) : la lecture donne l'état initial, le socket
// les changements. `resolveOnline(id, fallback)` fait cette fusion.

import { useCallback, useEffect, useRef, useState } from "react";
import { useSocketEvent } from "./useSocket";
import { getMembersPresence } from "./api";

// Le serveur (build 565) peut porter `userId` (un seul) ou `userIds` (les 3
// identités de la même personne) : on marque tous les ids reçus.
export type PresenceUpdate = { userId?: string; userIds?: string[]; online: boolean; at?: string };

export function usePresence(): {
  presence: Map<string, boolean>;
  /** 616 — ids des membres affichés, relus toutes les 30 s. */
  watch: (ids: string[]) => void;
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

  // 616 (15/10) — relecture périodique (30 s, onglet visible) de l'état des
  // ids passés à `watch(ids)` : GET /friends/members/presence. Même fusion que
  // le socket : le résultat remplit la table. Rien n'est envoyé sans ids.
  const watchedRef = useRef<string[]>([]);
  const watch = useCallback((ids: string[]) => {
    const next = [...new Set(ids.map(String).filter(Boolean))].sort();
    if (next.join(",") !== watchedRef.current.join(",")) watchedRef.current = next;
  }, []);
  useEffect(() => {
    let stop = false;
    const tick = async () => {
      if (stop || typeof document !== "undefined" && document.visibilityState === "hidden") return;
      const ids = watchedRef.current;
      if (ids.length === 0) return;
      try {
        const online = await getMembersPresence(ids);
        if (stop) return;
        setPresence((prev) => {
          let changed = false;
          const next = new Map(prev);
          for (const [id, v] of Object.entries(online)) {
            if (next.get(id) !== !!v) { next.set(id, !!v); changed = true; }
          }
          return changed ? next : prev;
        });
      } catch { /* réseau : on garde l'état connu */ }
    };
    const t0 = window.setTimeout(tick, 1500);
    const iv = window.setInterval(tick, 30_000);
    return () => { stop = true; window.clearTimeout(t0); window.clearInterval(iv); };
  }, []);

  const resolveOnline = useCallback(
    (userId?: string | null, fallback?: boolean | null) => {
      if (userId && presence.has(String(userId))) return !!presence.get(String(userId));
      return fallback === true;
    },
    [presence],
  );

  return { presence, resolveOnline, watch };
}

/** Petit point vert / gris, commun aux pages (chat, amis). */
export function onlineDotClass(online: boolean): string {
  return online ? "bg-emerald-500" : "bg-[#D6C3BE]";
}
