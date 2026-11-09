"use client";

// 10/11/2026 — LEO, chantier « conclure » (CONTRAT_1011) : case « J'ai un véhicule (je peux venir
// chercher l'animal) » du gardien / promeneur sur le site. Champ serveur `hasVehicle` (booléen ou null
// = pas dit), lu par GET /users/me/profile et écrit par PUT /users/me/profile (même route que les
// tarifs). Enregistrement au clic, pas de bouton en plus. Le propriétaire voit ensuite le badge
// « Véhiculé » sur la candidature. Couleur du rôle, zéro gris. Hooks en tête, aucun retour avant.

import { useEffect, useState } from "react";
import type { Lang } from "@/lib/i18n/langs";
import { k1011 } from "@/lib/i18n/conclure1011";
import { getMyProfile, updateMyProfile } from "@/lib/api";

const TONE = {
  sitter: { dark: "#1E4FB0", mid: "#2563EB", pale: "#E3EFFE" },
  walker: { dark: "#15803D", mid: "#16A34A", pale: "#DEF7E5" },
} as const;

export function VehicleToggle1011({ role, lang, className = "" }: { role: "sitter" | "walker"; lang: Lang; className?: string }) {
  const tone = TONE[role];
  const [value, setValue] = useState(false);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  useEffect(() => {
    let alive = true;
    getMyProfile()
      .then((p) => { if (alive) setValue(p?.hasVehicle === true); })
      .catch(() => { /* profil illisible : la case reste décochée, rien n'est écrit */ });
    return () => { alive = false; };
  }, []);

  async function toggle(next: boolean) {
    const before = value;
    setValue(next);
    setBusy(true);
    setMsg(null);
    try {
      await updateMyProfile({ hasVehicle: next });
      setMsg({ ok: true, text: k1011(lang, "vehicle_saved") });
    } catch {
      setValue(before);
      setMsg({ ok: false, text: k1011(lang, "vehicle_error") });
    } finally {
      setBusy(false);
    }
  }

  return (
    <div data-testid="vehicle-1011" className={`rounded-2xl bg-white p-3 ${className}`} style={{ boxShadow: `inset 0 0 0 1.5px ${value ? tone.mid : "rgba(35,23,21,0.10)"}` }}>
      <label className="flex cursor-pointer items-start gap-3 max-lg:min-h-[44px]">
        <input
          type="checkbox"
          checked={value}
          disabled={busy}
          onChange={(e) => void toggle(e.target.checked)}
          data-testid="vehicle-1011-input"
          className="mt-1 h-5 w-5 shrink-0"
          style={{ accentColor: tone.mid }}
        />
        <span className="min-w-0">
          <span className="block text-[15px] font-bold leading-tight" style={{ color: "#231715" }}><span aria-hidden className="mr-1.5">🚗</span>{k1011(lang, "vehicle_label")}</span>
          <span className="mt-0.5 block text-xs leading-snug" style={{ color: "#6E4F48" }}>{k1011(lang, "vehicle_sub")}</span>
        </span>
      </label>
      {msg && (
        <p role="status" data-testid="vehicle-1011-msg" className="mt-2 pl-8 text-xs font-bold" style={{ color: msg.ok ? tone.dark : "#9E1F0B" }}>{msg.text}</p>
      )}
    </div>
  );
}
