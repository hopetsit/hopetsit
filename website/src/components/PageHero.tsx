"use client";

import type { ReactNode } from "react";

/**
 * v556 — En-tête « premium » commun aux pages secondaires (Comment ça marche,
 * Tarifs, PawMap, FAQ, Contact) : même langage que l'accueil — fond crème,
 * halos de couleur très doux, trame fine, badge optionnel, titre en grande
 * échelle, filet dégradé, sous-titre. Une seule source de vérité pour que les
 * pages se ressemblent.
 */
export function PageHero({
  title,
  subtitle,
  badge,
  children,
  align = "center",
}: {
  title: string;
  subtitle?: string;
  badge?: ReactNode;
  children?: ReactNode;
  align?: "center" | "left";
}) {
  const centered = align === "center";
  return (
    <section className="relative overflow-hidden bg-[#FAF7F2]">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            "radial-gradient(55% 60% at 10% 20%, rgba(201,42,18,0.10) 0%, rgba(201,42,18,0) 60%)," +
            "radial-gradient(45% 50% at 90% 25%, rgba(37,99,235,0.09) 0%, rgba(37,99,235,0) 60%)," +
            "radial-gradient(40% 45% at 60% 100%, rgba(22,163,74,0.07) 0%, rgba(22,163,74,0) 60%)",
        }}
      />
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 opacity-[0.35]"
        style={{
          backgroundImage:
            "linear-gradient(rgba(23,19,15,0.045) 1px, transparent 1px), linear-gradient(90deg, rgba(23,19,15,0.045) 1px, transparent 1px)",
          backgroundSize: "44px 44px",
          maskImage: "radial-gradient(70% 70% at 50% 40%, #000 30%, transparent 100%)",
          WebkitMaskImage: "radial-gradient(70% 70% at 50% 40%, #000 30%, transparent 100%)",
        }}
      />
      <div
        className={
          "relative mx-auto max-w-6xl px-4 pb-14 pt-16 md:pb-20 md:pt-24 " +
          (centered ? "text-center" : "text-left")
        }
      >
        {badge && (
          <div className={"mb-5 flex " + (centered ? "justify-center" : "justify-start")}>
            <span className="inline-flex items-center gap-2 rounded-full border border-owner/20 bg-white/80 px-3.5 py-1.5 text-xs font-bold text-owner shadow-sm backdrop-blur">
              {badge}
            </span>
          </div>
        )}
        <h1 className="font-display text-4xl font-extrabold leading-[1.05] tracking-[-0.02em] text-ink md:text-6xl">
          {title}
        </h1>
        <span
          aria-hidden
          className={
            "mt-5 block h-1 w-14 rounded-full bg-gradient-to-r from-owner to-amber-400 " +
            (centered ? "mx-auto" : "")
          }
        />
        {subtitle && (
          <p
            className={
              "mt-5 max-w-2xl text-lg leading-relaxed text-ink-muted " +
              (centered ? "mx-auto" : "")
            }
          >
            {subtitle}
          </p>
        )}
        {children && <div className={"mt-8 " + (centered ? "flex justify-center" : "")}>{children}</div>}
      </div>
    </section>
  );
}

/** Titre de section secondaire avec le filet dégradé (même style que l'accueil). */
export function SectionTitle({ children, sub }: { children: ReactNode; sub?: string }) {
  return (
    <div className="text-center">
      <h2 className="font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">{children}</h2>
      <span aria-hidden className="mx-auto mt-4 block h-1 w-14 rounded-full bg-gradient-to-r from-owner to-amber-400" />
      {sub && <p className="mx-auto mt-4 max-w-2xl text-ink-muted">{sub}</p>}
    </div>
  );
}

export default PageHero;
