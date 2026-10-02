// 02/10/2026 (609, LEO) — pastille « ✓ Vérifié » (identité vérifiée), partagée par /map,
// la carte sans compte et les listes (fichier séparé : PoiMap charge Leaflet, côté client seulement).
/** 02/10 (609) — pastille « ✓ Vérifié » (identité vérifiée), bleu plein. */
export function VerifiedPill({ label, small = false }: { label: string; small?: boolean }) {
  return (
    <span data-verified-pill="" className={`inline-flex shrink-0 items-center gap-1 rounded-full bg-[#2563EB] font-extrabold text-white ${small ? "px-1.5 py-[1px] text-[10px]" : "px-2 py-0.5 text-[11px]"}`}>
      <svg viewBox="0 0 24 24" width={small ? 9 : 10} height={small ? 9 : 10} fill="none" stroke="#fff" strokeWidth="3.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>
      {label}
    </span>
  );
}

