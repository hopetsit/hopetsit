"use client";

import type { ReactNode } from "react";

/**
 * v556 — en-tête commun aux pages secondaires.
 * v562 — refonte minimaliste façon Apple (Daniel, 13/09) : fond blanc, titre
 * XXL centré, sous-titre gris, aucun halo ni trame. Une seule source de
 * vérité pour que les pages se ressemblent.
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
    <section className="bg-white">
      <div className={"mx-auto max-w-4xl px-4 pb-14 pt-20 md:pb-20 md:pt-28 " + (centered ? "text-center" : "text-left")}>
        {badge && (
          <div className={"mb-6 flex " + (centered ? "justify-center" : "justify-start")}>
            <span className="inline-flex items-center gap-2 rounded-full bg-[#F5F5F7] px-3.5 py-1.5 text-xs font-semibold text-[#6E6E73]">
              {badge}
            </span>
          </div>
        )}
        <h1 className="font-display text-[2.75rem] font-bold leading-[1.05] tracking-[-0.03em] text-[#1D1D1F] md:text-6xl">
          {title}
        </h1>
        {subtitle && (
          <p className={"mt-5 max-w-2xl text-lg leading-relaxed text-[#6E6E73] md:text-xl " + (centered ? "mx-auto" : "")}>
            {subtitle}
          </p>
        )}
        {children && <div className={"mt-8 " + (centered ? "flex justify-center" : "")}>{children}</div>}
      </div>
    </section>
  );
}

/** Titre de section secondaire (même style que l'accueil). */
export function SectionTitle({ children, sub }: { children: ReactNode; sub?: string }) {
  return (
    <div className="text-center">
      <h2 className="font-display text-3xl font-bold tracking-[-0.02em] text-[#1D1D1F] md:text-5xl">{children}</h2>
      {sub && <p className="mx-auto mt-4 max-w-2xl text-lg text-[#6E6E73]">{sub}</p>}
    </div>
  );
}

export default PageHero;
