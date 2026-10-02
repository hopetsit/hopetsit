"use client";

// 02/10/2026 (609, LEO — demande de Daniel) : vidéo « attraper une peluche »
// (capture réelle de l'app, PAM) dans un cadre de téléphone, section peluches
// de la page PawPoints publique ET membre.
//  · `preload="none"` : la vidéo n'est demandée qu'à l'approche de la zone
//    visible (IntersectionObserver, 400 px d'avance) ;
//  · poster SEUL si le visiteur demande moins de mouvement
//    (prefers-reduced-motion) ou économise ses données (Save-Data) ;
//  · `autoplay muted loop playsinline` + bouton pause / lecture accessible ;
//  · FR pour le français, EN pour les autres langues.

import { useEffect, useRef, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";

export function plushVideoLang(lang: string): "fr" | "en" {
  return lang === "fr" ? "fr" : "en";
}

export function PlushVideo({ className = "" }: { className?: string }) {
  const { t, lang } = useT();
  const v = plushVideoLang(lang);
  const boxRef = useRef<HTMLDivElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const [load, setLoad] = useState(false);
  const [still, setStill] = useState(false);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    let reduce = false;
    try {
      reduce = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false;
      const conn = (navigator as Navigator & { connection?: { saveData?: boolean } }).connection;
      if (conn?.saveData) reduce = true;
    } catch { /* */ }
    if (reduce) { setStill(true); return; }
    const el = boxRef.current;
    if (!el || typeof IntersectionObserver === "undefined") { setLoad(true); return; }
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) { setLoad(true); io.disconnect(); }
    }, { rootMargin: "400px 0px" });
    io.observe(el);
    return () => io.disconnect();
  }, []);

  useEffect(() => {
    const vid = videoRef.current;
    if (!vid || !load) return;
    vid.load();
    const p = vid.play();
    if (p && typeof p.catch === "function") p.catch(() => setPaused(true));
  }, [load, v]);

  const toggle = () => {
    const vid = videoRef.current;
    if (!vid) return;
    if (vid.paused) { void vid.play(); setPaused(false); } else { vid.pause(); setPaused(true); }
  };
  const poster = `/video/peluche_${v}_poster.webp`;

  return (
    <figure className={`flex flex-col items-center ${className}`} data-plush-video="">
      <div ref={boxRef} className="relative w-full max-w-[260px] rounded-[36px] bg-[#231715] p-[6px] shadow-[0_30px_60px_-28px_rgba(35,23,21,0.45)]">
        {still ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={poster} alt={t("plv609_alt")} width={720} height={1564} loading="lazy" className="block h-auto w-full rounded-[30px] bg-[#231715]" data-plush-poster="" />
        ) : (
          <video
            ref={videoRef}
            muted
            loop
            playsInline
            autoPlay
            preload="none"
            poster={poster}
            width={720}
            height={1564}
            aria-label={t("plv609_alt")}
            className="block h-auto w-full rounded-[30px] bg-[#231715]"
          >
            {/* MP4 (H.264) d'abord : lu partout, Safari iOS compris, et plus léger ici ; WebM en secours. */}
            {load && <source src={`/video/peluche_${v}.mp4`} type="video/mp4" />}
            {load && <source src={`/video/peluche_${v}.webm`} type="video/webm" />}
          </video>
        )}
        {!still && (
          <button
            type="button"
            onClick={toggle}
            aria-label={paused ? t("plv609_play") : t("plv609_pause")}
            aria-pressed={!paused}
            data-plush-video-toggle=""
            className="absolute bottom-4 right-4 grid h-11 w-11 place-items-center rounded-full bg-white/95 text-[#231715] shadow-lg ring-1 ring-[#F3E6E1]"
          >
            {paused ? (
              <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" aria-hidden="true"><path d="M8 5v14l11-7z" /></svg>
            ) : (
              <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" aria-hidden="true"><path d="M7 5h4v14H7zM13 5h4v14h-4z" /></svg>
            )}
          </button>
        )}
      </div>
      <figcaption className="mt-3 max-w-[300px] text-center text-[13px] font-semibold leading-snug text-[#0F5C2B]">
        <ol className="space-y-0.5">
          <li>{t("plv609_step1")}</li>
          <li>{t("plv609_step2")}</li>
          <li>{t("plv609_step3")}</li>
        </ol>
      </figcaption>
    </figure>
  );
}

export default PlushVideo;
