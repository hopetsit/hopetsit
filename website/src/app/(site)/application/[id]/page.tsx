"use client";

// 16/10/2026 — LEO. Cible du lien de l'e-mail « candidature reçue » envoyé au
// PROPRIÉTAIRE (`emailLinkBuilder` : /application/:id). Avant : aucune page →
// repli « Ouvre dans l'app ». Maintenant : connecté → ses demandes avec la
// candidature mise en avant (Choisir → Payer) ; sinon connexion puis retour ici.
// Page privée (noindex via middleware). Hooks en tête, aucun retour anticipé avant.

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useT } from "@/lib/i18n/LanguageProvider";
import { getStoredUser } from "@/lib/api";

export default function ApplicationRoutePage({ params }: { params: { id: string } }) {
  const { t } = useT();
  const router = useRouter();
  const id = String(params?.id || "").replace(/[^a-fA-F0-9]/g, "").slice(0, 24);

  useEffect(() => {
    // 26/10 (ADA/LEO) — la provenance (?from=email, utm_medium=email…) suit jusqu'à la page des
    // candidats, où elle est mesurée (markCandidatesViewed).
    let extra = "";
    try {
      const q = new URLSearchParams(window.location.search);
      const keep = new URLSearchParams();
      for (const k of ["from", "utm_medium", "utm_source", "utm_campaign"]) { const v = q.get(k); if (v) keep.set(k, v.slice(0, 40)); }
      extra = keep.toString() ? `&${keep.toString()}` : "";
    } catch { /* URL exotique */ }
    const target = id ? `/posts?application=${encodeURIComponent(id)}${extra}` : "/posts";
    const u = getStoredUser();
    if (!u) {
      router.replace(`/login?redirect=${encodeURIComponent(target)}`);
      return;
    }
    router.replace(u.role === "owner" ? target : "/posts");
  }, [id, router]);

  return (
    <div className="mx-auto max-w-md px-4 py-24 text-center">
      <p className="text-base font-bold" style={{ color: "#231715" }}>{t("c1610_opening")}</p>
    </div>
  );
}
