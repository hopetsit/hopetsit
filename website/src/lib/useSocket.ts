"use client";

// v23.1 part 146 — Hooks React au-dessus du singleton socket.
// Deux hooks :
//   - useSocket() : connecte le socket, expose son état (connected boolean).
//     À appeler dans le composant racine (ex layout du dashboard) pour
//     déclencher la connexion dès que l'user est logué.
//   - useSocketEvent<T>(event, handler) : abonne un handler à un event
//     socket et le nettoie automatiquement au unmount du composant.

import { useEffect, useRef, useState } from "react";
import { disconnectSocket, getSocket, onSocketConnected } from "./socket";

/**
 * Crée/maintient la connexion socket. Renvoie `connected: boolean`.
 *
 * Le hook réagit aux changements d'auth (login/logout) en réagissant à
 * l'event custom `hopetsit:auth-changed` que `api.ts` dispatche.
 */
export function useSocket(): { connected: boolean } {
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    const socket = getSocket();
    if (!socket) {
      setConnected(false);
      return;
    }
    setConnected(socket.connected);

    const onConnect = () => setConnected(true);
    const onDisconnect = () => setConnected(false);
    socket.on("connect", onConnect);
    socket.on("disconnect", onDisconnect);

    // Si l'utilisateur se logout (clearAuth() dans api.ts), on coupe le socket.
    const onAuthChange = () => {
      const fresh = getSocket();
      if (!fresh) {
        // user a logout
        setConnected(false);
        disconnectSocket();
      }
    };
    window.addEventListener("hopetsit:auth-changed", onAuthChange);

    return () => {
      socket.off("connect", onConnect);
      socket.off("disconnect", onDisconnect);
      window.removeEventListener("hopetsit:auth-changed", onAuthChange);
    };
  }, []);

  return { connected };
}

/**
 * Abonne un handler à un event socket. Le handler est cleaned up au unmount
 * et re-attaché sur reconnect (utile pour les rooms qu'on doit re-join).
 *
 * Exemple :
 *   useSocketEvent<{ bookingId: string }>("booking:paid", (data) => {
 *     toast(`Paiement reçu pour booking ${data.bookingId}`);
 *   });
 */
export function useSocketEvent<T = unknown>(
  event: string,
  handler: (data: T) => void,
): void {
  // useRef pour ne pas ré-attacher si le handler change de référence à chaque
  // render (callback inline).
  const handlerRef = useRef(handler);
  handlerRef.current = handler;

  useEffect(() => {
    const socket = getSocket();
    if (!socket) return;

    const wrapped = (data: T) => {
      try {
        handlerRef.current(data);
      } catch (e) {
        console.error(`[socket] handler ${event} threw`, e);
      }
    };

    socket.on(event, wrapped);

    // Si le socket se reconnecte, le listener est encore attaché à l'instance
    // (qui survit aux reconnect). Donc rien à faire de spécial. Mais on
    // s'abonne quand même au connect pour les cas où le socket est créé
    // après le mount (race condition).
    const unsubscribeConnect = onSocketConnected(() => {
      // Re-attacher au cas où le socket aurait été disconnect+reconnect manuellement.
      const sock = getSocket();
      if (sock && !sock.listeners(event).includes(wrapped)) {
        sock.on(event, wrapped);
      }
    });

    return () => {
      socket.off(event, wrapped);
      unsubscribeConnect();
    };
  }, [event]);
}
