// v23.1 part 146 — Client socket.io pour le site, miroir du `socket_service.dart`
// de l'app Flutter. Permet au site de recevoir en temps réel les mêmes events
// que l'app : `message:new`, `booking:paid`, `application:new`,
// `map:friend-position`, etc.
//
// Architecture identique à l'app :
//   - Connexion vers le ROOT du backend Render (pas /api/v1, pas de namespace).
//   - Auth via `socket.auth.token = <JWT>` lu par le middleware `io.use` côté
//     backend (chatSocket.js → io.use((socket, next) => jwt.verify(...))).
//   - Après `connect`, on émet `user:identify { role, userId }` pour rejoindre
//     la `user:<role>:<userId>` room et recevoir les notifications ciblées.
//   - Reconnect auto avec backoff, re-identify à chaque reconnect.

import { io, Socket } from "socket.io-client";
import { getStoredToken, getStoredUser } from "./api";

// L'URL du socket = root du backend (sans /api/v1). On dérive depuis la même
// var d'env que api.ts pour rester cohérent.
const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE ??
  "https://hopetsit-backend.onrender.com/api/v1";
const SOCKET_URL = API_BASE.replace(/\/api\/v\d+\/?$/, "");

let _socket: Socket | null = null;
const _connectListeners: Array<() => void> = [];

/**
 * Retourne le singleton socket (le crée à la première demande).
 *
 * Le socket est créé EN DEHORS de tout composant React pour survivre aux
 * remounts. Il est nettoyé via `disconnectSocket()` quand l'user se logout.
 *
 * @returns Le socket connecté (ou en cours de connexion), ou null si l'user
 *          n'est pas logué (pas de JWT en localStorage).
 */
export function getSocket(): Socket | null {
  if (typeof window === "undefined") return null;

  const token = getStoredToken();
  if (!token) {
    // Pas logué → pas de socket. On nettoie l'ancien au cas où.
    if (_socket) {
      _socket.disconnect();
      _socket = null;
    }
    return null;
  }

  if (_socket && _socket.connected) {
    return _socket;
  }

  if (_socket) {
    // Existe mais pas connecté → on tente une reconnexion.
    _socket.auth = { token };
    if (!_socket.connected && !_socket.active) {
      _socket.connect();
    }
    return _socket;
  }

  // Première création.
  _socket = io(SOCKET_URL, {
    auth: { token },
    // Mêmes settings que l'app Flutter : websocket only, auto-reconnect.
    transports: ["websocket"],
    reconnection: true,
    reconnectionAttempts: 5,
    reconnectionDelay: 1000,
    reconnectionDelayMax: 5000,
    // Cookie/credentials pas nécessaires (JWT en auth).
    withCredentials: false,
  });

  _socket.on("connect", () => {
    // 1) Re-attacher le token au cas où il a changé (logout → re-login).
    const fresh = getStoredToken();
    if (fresh && _socket) _socket.auth = { token: fresh };

    // 2) Émettre `user:identify` pour rejoindre la user-room (sine qua non
    //    pour recevoir les events ciblés type booking:paid).
    const user = getStoredUser();
    if (user && _socket) {
      _socket.emit("user:identify", { role: user.role, userId: user.id });
    }

    // 3) Fire les listeners externes (hooks React).
    for (const cb of _connectListeners) {
      try {
        cb();
      } catch (e) {
        console.error("[socket] connect listener threw", e);
      }
    }
  });

  _socket.on("connect_error", (err) => {
    // Volontairement silencieux en prod (le hook useSocket expose `connected`).
    if (process.env.NODE_ENV === "development") {
      console.warn("[socket] connect_error:", err.message);
    }
  });

  _socket.on("disconnect", (reason) => {
    if (process.env.NODE_ENV === "development") {
      console.log("[socket] disconnected:", reason);
    }
  });

  return _socket;
}

/**
 * Enregistre un callback fired CHAQUE fois que le socket se (re)connecte.
 * Utile pour les hooks qui doivent re-join des rooms après un reconnect.
 *
 * Retourne une fonction unsubscribe.
 */
export function onSocketConnected(cb: () => void): () => void {
  _connectListeners.push(cb);
  // Si déjà connecté, fire immédiatement.
  if (_socket?.connected) {
    try {
      cb();
    } catch (e) {
      console.error("[socket] immediate connect cb threw", e);
    }
  }
  return () => {
    const idx = _connectListeners.indexOf(cb);
    if (idx >= 0) _connectListeners.splice(idx, 1);
  };
}

/**
 * Force la fermeture du socket. À appeler au logout pour ne pas continuer
 * à recevoir des events après que l'user soit déconnecté.
 */
export function disconnectSocket(): void {
  if (_socket) {
    _socket.removeAllListeners();
    _socket.disconnect();
    _socket = null;
  }
  _connectListeners.length = 0;
}
