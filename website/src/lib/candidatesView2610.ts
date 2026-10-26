// 26/10/2026 (ADA, décision de Daniel — proposition C de SAM) — repère « le
// propriétaire a OUVERT la page de ses candidats », à brancher par LEO dans la
// page des candidats (PostCandidates1610.tsx et /application/<id>).
//
//   useEffect(() => { markCandidatesViewed({ postId }); }, [postId]);
//   // ou, sur /application/<id> : markCandidatesViewed({ applicationId: id });
//
// - Sans cookie, sans dépendance, jamais bloquant (erreurs avalées). Appel à l’OUVERTURE de la page, pas à la fermeture.
// - Le serveur décide seul du canal (site/app) et écarte nos scripts ; il ne
//   crée un repère que si la personne connectée est bien le propriétaire, et
//   fusionne deux ouvertures à moins de 2 min.
// - `source` est déduit de l'adresse : ?utm_medium=email ou ?from=email → "email",
//   ?from=push → "push", ?from=notification → "notification", sinon "direct".
//   On peut le forcer en le passant.
import { API_BASE, getStoredToken } from "@/lib/api";

type Source = "email" | "push" | "notification" | "direct" | "link";

function sourceFromUrl(): Source {
  try {
    const q = new URLSearchParams(window.location.search);
    const from = (q.get("from") || "").toLowerCase();
    if (from === "email" || (q.get("utm_medium") || "").toLowerCase() === "email") return "email";
    if (from === "push") return "push";
    if (from === "notification") return "notification";
  } catch {
    /* rien */
  }
  return "direct";
}

export function markCandidatesViewed(p: { postId?: string; applicationId?: string; source?: Source }): void {
  try {
    if (typeof window === "undefined") return;
    const token = getStoredToken();
    if (!token || (!p.postId && !p.applicationId)) return;
    const body = JSON.stringify({
      ...(p.postId ? { postId: p.postId } : {}),
      ...(p.applicationId ? { applicationId: p.applicationId } : {}),
      source: p.source || sourceFromUrl(),
    });
    void fetch(`${API_BASE}/owner-signals/candidates-view`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}`, "X-App-Version": "web" },
      body,
    }).catch(() => {});
  } catch {
    /* jamais bloquant */
  }
}
