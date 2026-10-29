"use client";

// 29/10/2026 (LEO, demande de Daniel « vérifie la fluidité des bulles sur la PawMap et le profil »).
// MESURÉ dans Chrome (build de prod, 375 et 768 px) : la fiche publique /p/<rôle>/<id> et « Mon profil »
// affichaient un simple spinner / « Chargement… » de 50 vh, puis le contenu réel (≈ 1 100 px et ≈ 3 300 px) :
// le pied de page SAUTAIT de 300 à 1 700 px à l'arrivée des données (CLS 0,23–0,30 sur la fiche,
// 0,62–0,69 sur Mon profil ; seuil « bon » = 0,10). Ces squelettes ont la forme et la hauteur du contenu
// final : la page ne bouge plus quand les données arrivent. Couleurs : blanc + teinte claire du rôle,
// jamais de gris (règle du site).

const LINE = "rounded-full";

function Line({ w, h = 12, tone }: { w: string; h?: number; tone: string }) {
  return <span aria-hidden className={`block ${LINE}`} style={{ width: w, height: h, background: tone }} />;
}

/** Fiche publique d'un gardien / promeneur : même structure que la fiche chargée. */
export function FicheSkeleton2910({ tone, ring }: { tone: string; ring: string }) {
  return (
    <div className="mx-auto max-w-lg px-4 py-8 md:py-14 motion-safe:animate-pulse" aria-busy="true" aria-live="polite" data-skeleton-2910="fiche">
      <section className="rounded-[28px] bg-white p-6 text-center shadow-[0_18px_50px_-22px_rgba(35,23,21,0.35)] ring-1 ring-[#F3E6E1]">
        <span aria-hidden className="mx-auto block h-24 w-24 rounded-full" style={{ background: tone, boxShadow: `0 0 0 3px #fff, 0 0 0 6px ${ring}` }} />
        <div className="mt-4 flex justify-center"><Line w="42%" h={26} tone={tone} /></div>
        <div className="mt-2 flex justify-center"><Line w="55%" h={14} tone={tone} /></div>
        <div className="mt-3 flex flex-wrap items-center justify-center gap-2">
          <Line w="88px" h={24} tone={tone} /><Line w="64px" h={24} tone={tone} /><Line w="120px" h={24} tone={tone} />
        </div>
        <span aria-hidden className="mt-6 block min-h-[56px] w-full rounded-[18px]" style={{ background: ring, opacity: 0.35 }} />
        <div className="mt-2 flex justify-center"><Line w="70%" h={12} tone={tone} /></div>
        <div className="mt-3 flex items-center justify-center gap-2">
          <span aria-hidden className="block h-11 w-32 rounded-[16px] border-[1.5px] bg-white" style={{ borderColor: ring, opacity: 0.6 }} />
          <span aria-hidden className="block h-11 w-32 rounded-[16px] border-[1.5px] bg-white" style={{ borderColor: ring, opacity: 0.6 }} />
        </div>
        <div className="mt-3 space-y-1.5"><Line w="100%" h={10} tone={tone} /><Line w="80%" h={10} tone={tone} /></div>
      </section>
      <section className="mt-4 rounded-[24px] p-5" style={{ background: tone }}>
        <Line w="45%" h={20} tone="#fff" />
        <div className="mt-3 space-y-3">
          {[0, 1, 2].map((i) => (
            <div key={i} className="flex items-center justify-between gap-3 py-1"><Line w="40%" h={12} tone="#fff" /><Line w="20%" h={16} tone="#fff" /></div>
          ))}
        </div>
      </section>
      <section className="mt-4 rounded-[24px] bg-[#FDF8F7] p-5 ring-1 ring-[#F3E6E1]">
        <div className="space-y-2"><Line w="100%" h={11} tone={tone} /><Line w="95%" h={11} tone={tone} /><Line w="88%" h={11} tone={tone} /><Line w="60%" h={11} tone={tone} /></div>
      </section>
    </div>
  );
}

/** « Mon profil » (tableau de bord) : en-tête, photo, abonnements, code promo, puis le formulaire. */
export function ProfileSkeleton2910({ fields = 9 }: { fields?: number }) {
  const tone = "#FAF1EC";
  return (
    <div className="mx-auto max-w-2xl px-4 py-12 md:py-16 motion-safe:animate-pulse" aria-busy="true" aria-live="polite" data-skeleton-2910="profil">
      <div className="mb-6 flex items-center justify-between"><Line w="140px" h={20} tone={tone} /><Line w="72px" h={24} tone={tone} /></div>
      <Line w="55%" h={36} tone={tone} />
      <div className="mt-3"><Line w="80%" h={14} tone={tone} /></div>
      <div className="mt-8 flex items-center gap-4">
        <span aria-hidden className="block h-20 w-20 shrink-0 rounded-full" style={{ background: tone }} />
        <div className="space-y-2"><Line w="150px" h={14} tone={tone} /><Line w="190px" h={12} tone={tone} /><Line w="90px" h={12} tone={tone} /></div>
      </div>
      <div className="mt-6 rounded-[20px] p-5" style={{ background: tone }}><Line w="40%" h={14} tone="#fff" /><div className="mt-3"><Line w="100%" h={42} tone="#fff" /></div></div>
      <div className="mt-8 space-y-5">
        {Array.from({ length: fields }, (_, i) => (
          <div key={i}><Line w="30%" h={10} tone={tone} /><div className="mt-2"><Line w="100%" h={42} tone={tone} /></div></div>
        ))}
        <Line w="100%" h={48} tone={tone} />
      </div>
    </div>
  );
}
