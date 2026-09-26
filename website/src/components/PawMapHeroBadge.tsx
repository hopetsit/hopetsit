"use client";

import { PawMapLogo } from "@/components/PawMapLogo";

/**
 * Héro de /pawmap (build 571, demande de Daniel : « l'icône de la PawMap plus
 * grande et avec l'animation orange »).
 *
 * Reprend la scène de l'écran d'ouverture de l'app
 * (`docs/design_handoff_pawmap_tab_bar/Splash Screen.dc.html`) : tuile au
 * dégradé orange 165° #F26A46 → #C92A12 → #C7311F, la patte-pin qui surgit
 * (pinIn), ses 4 doigts qui sortent en cascade, puis un flottement lent. Deux
 * ondes blanches partent de l'épingle, comme un radar. Tout est coupé si le
 * visiteur demande moins d'animations.
 */
export function PawMapHeroBadge({ className = "" }: { className?: string }) {
  const css = `
@keyframes pmh-in { 0% { transform: scale(.5); opacity: 0 } 100% { transform: scale(1); opacity: 1 } }
@keyframes pmh-float { 0%,100% { transform: translateY(0) } 50% { transform: translateY(-8px) } }
@keyframes pmh-ring { 0% { transform: scale(.55); opacity: .55 } 100% { transform: scale(1.25); opacity: 0 } }
@keyframes pmh-glow { 0%,100% { box-shadow: 0 24px 60px rgba(221,68,48,.35) } 50% { box-shadow: 0 30px 80px rgba(221,68,48,.55) } }
.pmh-tile { background: linear-gradient(165deg,#F26A46 0%,#C92A12 45%,#C7311F 100%); box-shadow: 0 24px 60px rgba(221,68,48,.35); }
.pmh-ring { opacity: 0; }
@media (prefers-reduced-motion: no-preference) {
  .pmh-tile { animation: pmh-glow 3.2s ease-in-out 1.6s infinite; }
  .pmh-in { animation: pmh-in .7s cubic-bezier(.3,1.5,.4,1) both; }
  .pmh-float { animation: pmh-float 3.2s ease-in-out 1.6s infinite; }
  .pmh-ring { animation: pmh-ring 2.8s cubic-bezier(.2,.7,.3,1) 1.2s infinite; }
  .pmh-ring-2 { animation-delay: 2.6s; }
}`;
  return (
    <div
      className={`pmh-tile relative mx-auto flex h-44 w-44 items-center justify-center overflow-hidden rounded-[44px] md:h-56 md:w-56 md:rounded-[56px] ${className}`}
    >
      <style>{css}</style>
      <span aria-hidden className="pmh-ring absolute h-full w-full rounded-full border-2 border-white/70" />
      <span aria-hidden className="pmh-ring pmh-ring-2 absolute h-full w-full rounded-full border-2 border-white/70" />
      <div className="pmh-in relative">
        <div className="pmh-float">
          <PawMapLogo size={132} animated className="md:hidden" />
          <PawMapLogo size={168} animated className="hidden md:block" />
        </div>
      </div>
    </div>
  );
}

export default PawMapHeroBadge;
