"use client";

// 19/10/2026 — LEO : build 618 sur le site (PROCHAIN_BUILD_618.md).
//   • PinChips1910 — les pins d'une personne (classement, ma ligne, profil, fiche, carte).
//   • PawNews1910 — collection du mois · pins · ×2 Premium (pages /pawmap et /pawpoints-guide).
//   • PodiumPublic1910 — le podium du moment (GET /pawpoints/pins), caché tant que la route n'existe pas.
//   • MonthlyCollection1910 — ma progression dans la collection du mois (/pawpoints).
// Tout est caché quand le serveur n'envoie pas encore le champ : jamais de faux pin.
// Rangs et pins sont honorifiques : aucune promesse d'argent.

import { useEffect, useState } from "react";
import Link from "@/components/SiteLink";
import { useT } from "@/lib/i18n/LanguageProvider";
import { getPublicPins1910 } from "@/lib/api";
import {
  FIRST_PACK_STYLE,
  PIN_STYLE,
  monthLabel1910,
  parsePublicPins1910,
  pinDiscHtml,
  type Monthly1910,
  type Pins1910,
  type PublicPins1910,
} from "@/lib/pins1910";

const INK = "#231715";
const SOFT = "#6E4F48";
const PLUSH = ["teddy", "bunny", "kitty", "puppy", "fox"];
/** Couleur de la collection du mois quand le serveur n'en donne pas : l'orange d'automne de novembre. */
const MONTH_FALLBACK = "#C2410C";

function Disc({ kind, size }: { kind: 1 | 2 | 3 | "first"; size: number }) {
  return <span className="inline-flex shrink-0" aria-hidden="true" dangerouslySetInnerHTML={{ __html: pinDiscHtml(kind, size) }} />;
}

/** Pins d'une personne. `compact` = disques seuls (titre au survol, libellé pour les lecteurs d'écran). */
export function PinChips1910({ pins, compact = false, className = "" }: { pins: Pins1910 | null | undefined; compact?: boolean; className?: string }) {
  const { t } = useT();
  if (!pins) return null;
  const items: { kind: 1 | 2 | 3 | "first"; label: string; color: string }[] = [];
  if (pins.podium) items.push({ kind: pins.podium, label: t(PIN_STYLE[pins.podium].key), color: PIN_STYLE[pins.podium].ink });
  if (pins.firstPackLeader) items.push({ kind: "first", label: t(FIRST_PACK_STYLE.key), color: "#4E2381" });
  if (items.length === 0) return null;
  if (compact) {
    return (
      <span className={`inline-flex items-center gap-1 ${className}`} data-pins="">
        {items.map((it) => (
          <span key={String(it.kind)} title={it.label} aria-label={it.label} role="img" className="inline-flex">
            <Disc kind={it.kind} size={18} />
          </span>
        ))}
      </span>
    );
  }
  return (
    <span className={`inline-flex flex-wrap items-center gap-1.5 ${className}`} data-pins="">
      {items.map((it) => (
        <span key={String(it.kind)} className="inline-flex min-w-0 items-center gap-1.5 rounded-full bg-white py-0.5 pl-0.5 pr-2.5 text-[12px] font-extrabold leading-tight ring-1 ring-[#F1D9A6]" style={{ color: it.color }}>
          <Disc kind={it.kind} size={20} />
          <span className="min-w-0 break-words">{it.label}</span>
        </span>
      ))}
    </span>
  );
}

/** Les 3 nouveautés du 618, expliquées (mêmes chiffres que le serveur). */
export function PawNews1910({ className = "", withLink = false }: { className?: string; withLink?: boolean }) {
  const { t } = useT();
  const cards = [
    {
      id: "month",
      title: t("p1910_month_t"),
      body: t("p1910_month_b"),
      chip: t("p1910_month_soon"),
      bg: "linear-gradient(160deg,#FFF1E6,#FFFFFF 75%)",
      ring: "#F6C9A8",
      titleColor: "#9A3412",
      visual: (
        <span className="flex -space-x-3" aria-hidden="true">
          {PLUSH.map((ty) => (
            // eslint-disable-next-line @next/next/no-img-element
            <img key={ty} src={`/plush/${ty}.png`} alt="" width={44} height={44} className="h-11 w-11 rounded-full bg-white object-contain p-0.5" style={{ boxShadow: `0 0 0 2px ${MONTH_FALLBACK}` }} />
          ))}
        </span>
      ),
    },
    {
      id: "pins",
      title: t("p1910_pins_t"),
      body: t("p1910_pins_b"),
      chip: null,
      bg: "linear-gradient(160deg,#FFF6DB,#FFFFFF 75%)",
      ring: "#F1D9A6",
      titleColor: "#8A5A00",
      visual: (
        <span className="flex items-center gap-1.5" aria-hidden="true">
          <Disc kind={1} size={34} />
          <Disc kind={2} size={34} />
          <Disc kind={3} size={34} />
          <Disc kind="first" size={34} />
        </span>
      ),
    },
    {
      id: "premium",
      title: t("p1910_premium_t"),
      body: t("p1910_premium_b"),
      chip: null,
      bg: "linear-gradient(160deg,#2A2219,#15120D)",
      ring: "#4A3A22",
      titleColor: "#FFD34D",
      visual: (
        <span className="inline-flex items-center gap-2" aria-hidden="true">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/pawpremium_logo.svg" alt="" width={40} height={40} className="h-10 w-10" />
          <span className="font-display text-3xl font-extrabold text-[#FFD34D]">×2</span>
        </span>
      ),
    },
  ];
  return (
    <section className={className} data-news1910="">
      <h2 className="text-balance text-center font-display text-2xl font-bold tracking-[-0.02em] md:text-4xl" style={{ color: INK }}>{t("p1910_new_t")}</h2>
      <div className="mt-8 grid gap-4 md:grid-cols-3">
        {cards.map((c) => (
          <article key={c.id} className="flex min-w-0 flex-col rounded-[24px] p-5 md:p-6" style={{ background: c.bg, boxShadow: `inset 0 0 0 1px ${c.ring}` }} data-news-card={c.id}>
            <div className="flex min-h-[48px] items-center">{c.visual}</div>
            <h3 className="mt-4 text-balance font-display text-xl font-extrabold tracking-[-0.01em]" style={{ color: c.titleColor }}>{c.title}</h3>
            {c.chip && <span className="mt-2 inline-flex w-fit rounded-full px-3 py-1 text-[12px] font-extrabold text-white" style={{ background: MONTH_FALLBACK }}>{c.chip}</span>}
            <p className="mt-2 text-[14px] leading-relaxed" style={{ color: c.id === "premium" ? "#FDF8F7" : INK }}>{c.body}</p>
          </article>
        ))}
      </div>
      <p className="mx-auto mt-4 max-w-2xl text-center text-[13px] font-semibold" style={{ color: SOFT }}>{t("rank611_no_money")}</p>
      {withLink && (
        <div className="mt-5 text-center">
          <Link href="/pawpoints-guide" className="inline-flex min-h-[44px] items-center rounded-full px-6 text-sm font-bold text-white" style={{ background: "linear-gradient(165deg,#F4C04A,#D99A0B 55%,#B07800)" }}>{t("ppg_link")} →</Link>
        </div>
      )}
    </section>
  );
}

/** Podium du moment + « 1er Chef de meute ». Rien tant que la route n'existe pas. */
export function PodiumPublic1910({ className = "" }: { className?: string }) {
  const { t, lang } = useT();
  const [data, setData] = useState<PublicPins1910 | null>(null);
  useEffect(() => {
    let alive = true;
    void getPublicPins1910().then((raw) => { if (alive) setData(parsePublicPins1910(raw)); });
    return () => { alive = false; };
  }, []);
  if (!data || (data.podium.length === 0 && !data.firstPackLeader)) return null;
  let fmt = (n: number) => String(n);
  try { const nf = new Intl.NumberFormat(lang); fmt = (n: number) => nf.format(n); } catch { /* */ }
  return (
    <section className={className} data-podium1910="">
      <h2 className="text-balance font-display text-2xl font-extrabold tracking-[-0.02em] md:text-[28px]" style={{ color: INK }}>{t("p1910_podium_t")}</h2>
      <ul className="mt-4 divide-y divide-[#F3E6E1] rounded-[20px] bg-white ring-1 ring-[#F3E6E1]">
        {data.podium.map((p, i) => {
          const place = (i + 1) as 1 | 2 | 3;
          return (
            <li key={`${p.userId}-${i}`} className="flex items-center gap-3 px-4 py-3" data-podium-row={place}>
              <span title={t(PIN_STYLE[place].key)} aria-label={t(PIN_STYLE[place].key)} role="img" className="inline-flex"><Disc kind={place} size={28} /></span>
              <span className="min-w-0 flex-1 break-words text-sm font-bold" style={{ color: INK }}>{p.name}</span>
              <span className="shrink-0 text-sm font-extrabold tabular-nums" style={{ color: "#8A5A00" }}>{t("p1910_points").replace("{n}", fmt(p.points))}</span>
            </li>
          );
        })}
        <li className="flex items-center gap-3 px-4 py-3" data-podium-first="">
          <span className="inline-flex"><Disc kind="first" size={28} /></span>
          {data.firstPackLeader ? (
            <span className="min-w-0 flex-1 break-words text-sm font-bold" style={{ color: INK }}>
              {data.firstPackLeader.name} <span className="font-extrabold" style={{ color: "#4E2381" }}>· {t("p1910_pin_first")}</span>
            </span>
          ) : (
            <span className="min-w-0 flex-1 break-words text-sm font-semibold" style={{ color: "#4E2381" }}>{t("p1910_first_none")}</span>
          )}
        </li>
      </ul>
    </section>
  );
}

/** Ma collection du mois (dès le 01/11/2026). Avant le début : bandeau « À partir du … ». */
export function MonthlyCollection1910({ monthly, className = "" }: { monthly: Monthly1910 | null; className?: string }) {
  const { t, lang } = useT();
  if (!monthly) return null;
  const color = monthly.color || MONTH_FALLBACK;
  const notStarted = monthly.startsAt ? Date.parse(monthly.startsAt) > Date.now() : false;
  const caught = new Set(monthly.caughtTypes);
  const month = monthLabel1910(monthly.key, lang);
  return (
    <div className={`rounded-[22px] bg-white p-4 md:p-5 ${className}`} style={{ boxShadow: `inset 0 0 0 2px ${color}` }} data-monthly1910="">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h3 className="min-w-0 break-words font-display text-lg font-extrabold" style={{ color }}>
          {t("p1910_month_t")}{monthly.label ? ` · ${monthly.label}` : ""}
        </h3>
        {notStarted ? (
          <span className="rounded-full px-3 py-1 text-[12px] font-extrabold text-white" style={{ background: color }}>{t("p1910_month_soon")}</span>
        ) : monthly.complete ? (
          <span className="rounded-full px-3 py-1 text-[12px] font-extrabold text-white" style={{ background: color }}>🏅 {t("p1910_month_badge").replace("{month}", month)}</span>
        ) : (
          <span className="rounded-full bg-white px-3 py-1 text-[12px] font-extrabold tabular-nums" style={{ color, boxShadow: `inset 0 0 0 2px ${color}` }}>{t("p1910_month_progress").replace("{n}", String(caught.size))}</span>
        )}
      </div>
      <ul className="mt-3 flex flex-wrap gap-2">
        {PLUSH.map((ty, i) => {
          const ok = !notStarted && caught.has(ty);
          return (
            <li key={ty} className="relative" title={t(`help607_plush_names_${i + 1}`)}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={`/plush/${ty}.png`} alt={t(`help607_plush_names_${i + 1}`)} width={52} height={52} className="h-[52px] w-[52px] rounded-full bg-white object-contain p-1" style={{ border: `2.5px ${ok ? "solid" : "dashed"} ${color}` }} />
              {ok && <span className="absolute -bottom-0.5 -right-0.5 grid h-5 w-5 place-items-center rounded-full border-2 border-white text-[11px] font-black text-white" style={{ background: "#16A34A" }} aria-hidden="true">✓</span>}
            </li>
          );
        })}
      </ul>
      {monthly.complete && <p className="mt-3 text-sm font-bold" style={{ color }}>{t("p1910_month_done")}</p>}
      <p className="mt-3 text-[13px] leading-relaxed" style={{ color: INK }}>{t("p1910_month_b")}</p>
    </div>
  );
}
