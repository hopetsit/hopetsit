"use client";

// 24/10/2026 (620, LEO — CONTRAT_620_dates_visites.md §B.1, ordre de Daniel) :
// « Quand ? » en 3 cartes (Dates précises / Période approximative / Dates à
// prévoir), « Visites par jour » (1 | 2) pour la visite à domicile, et la ligne
// d'ESTIMATION (« environ 108 € pour 5 visites », « tarif affiché par visite,
// total après tes dates »). Même calcul que l'app : POST /pricing/estimate
// quand on est connecté ; sinon (invité, serveur ancien) quantité locale +
// tarif du prestataire ciblé s'il est connu — jamais un chiffre inventé.
// Zéro gris : encres brunes de la charte, orange propriétaire #C92A12.
// Tous les hooks en tête, aucun retour conditionnel avant.

import { useEffect, useMemo, useState } from "react";
import { AppIcon } from "@/components/AppIcon";
import type { Lang } from "@/lib/i18n/langs";
import { d620, qtyLabel620, unitLong620 } from "@/lib/i18n/dates620";
import { estimatePricing620 } from "@/lib/api";
import {
  estimateLocal620,
  quantityFor620,
  rateForService620,
  type DateMode620,
  type Estimate620,
  type ProviderRates620,
  type ServiceDef620,
} from "@/lib/services620";

const ORANGE = "#C92A12";
const ORANGE_DARK = "#9E1F0B";
const ORANGE_PALE = "#FBE9E5";
const INK = "#231715";
const INK_SOFT = "#6E4F48";

export const DATE_MODES_620: DateMode620[] = ["exact", "approx", "tbd"];

/** Les 3 cartes du mode de dates. */
export function DateModeCards620({ lang, value, onChange }: { lang: Lang; value: DateMode620; onChange: (m: DateMode620) => void }) {
  const icon = (m: DateMode620) => (m === "exact" ? "calendar" : m === "approx" ? "clock" : "question");
  return (
    <div data-testid="date-mode-620">
      <p className="block text-sm font-medium" style={{ color: INK }}>{d620(lang, "when_title")}</p>
      <div className="mt-2 grid grid-cols-1 gap-2 sm:grid-cols-3" role="radiogroup" aria-label={d620(lang, "when_title")}>
        {DATE_MODES_620.map((m) => {
          const on = value === m;
          return (
            <button
              key={m}
              type="button"
              role="radio"
              aria-checked={on}
              data-mode={m}
              onClick={() => onChange(m)}
              className="flex min-h-[56px] items-center gap-3 rounded-2xl border px-3 py-2.5 text-left transition sm:flex-col sm:items-start sm:gap-1.5 sm:px-3.5 sm:py-3"
              style={on ? { borderColor: ORANGE, background: ORANGE_PALE } : { borderColor: "rgba(35,23,21,0.15)", background: "#fff" }}
            >
              <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full" style={{ background: on ? ORANGE : ORANGE_PALE }}>
                <AppIcon name={icon(m)} size={16} color={on ? "#fff" : ORANGE_DARK} />
              </span>
              <span className="min-w-0">
                <span className="block text-sm font-bold leading-tight" style={{ color: on ? ORANGE_DARK : INK }}>{d620(lang, `mode_${m}`)}</span>
                <span className="block text-xs leading-snug" style={{ color: INK_SOFT }}>{d620(lang, `mode_${m}_sub`)}</span>
              </span>
            </button>
          );
        })}
      </div>
      {value === "tbd" && (
        <p data-testid="tbd-hint-620" className="mt-2 text-xs leading-snug" style={{ color: INK_SOFT }}>{d620(lang, "tbd_hint")}</p>
      )}
    </div>
  );
}

/** « Visites par jour » : 1 | 2 (visite à domicile seulement). */
export function VisitsPerDay620({ lang, value, options, onChange }: { lang: Lang; value: number; options?: number[]; onChange: (n: number) => void }) {
  const opts = (options && options.length ? options : [1, 2]).filter((n) => n === 1 || n === 2);
  return (
    <div data-testid="visits-620">
      <p className="block text-sm font-medium" style={{ color: INK }}>{d620(lang, "visits_title")}</p>
      <div className="mt-2 flex flex-wrap gap-2" role="radiogroup" aria-label={d620(lang, "visits_title")}>
        {opts.map((n) => {
          const on = value === n;
          return (
            <button
              key={n}
              type="button"
              role="radio"
              aria-checked={on}
              data-visits={n}
              onClick={() => onChange(n)}
              className="rounded-full border px-4 py-2 text-sm font-semibold transition max-lg:min-h-[44px]"
              style={on ? { borderColor: ORANGE, background: ORANGE_PALE, color: ORANGE_DARK } : { borderColor: "rgba(35,23,21,0.15)", background: "#fff", color: INK }}
            >
              {d620(lang, `visits_${n}`)}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function money(v: number, currency: string, lang: string): string {
  try {
    return new Intl.NumberFormat(lang, { style: "currency", currency, maximumFractionDigits: Number.isInteger(v) ? 0 : 2 }).format(v);
  } catch {
    return `${v} ${currency}`;
  }
}

export type EstimateLineProps = {
  lang: Lang;
  service: string;
  dateMode: DateMode620;
  startDate: string;
  endDate: string;
  visitsPerDay: number;
  venue?: "owners_home" | "sitters_home" | null;
  services?: ServiceDef620[] | null;
  /** Prestataire ciblé (« Demander à <prénom> ») : son tarif sert à l'estimation. */
  provider?: { role: "sitter" | "walker"; id: string } | null;
  providerRates?: ProviderRates620 | null;
  /** Devise d'affichage quand aucun tarif n'est connu. */
  currency?: string;
};

/** Ligne d'estimation sous les dates. Rien tant que service + dates ne sont pas connus (sauf « à prévoir »). */
export function EstimateLine620(p: EstimateLineProps) {
  const { lang, service, dateMode, startDate, endDate, visitsPerDay, venue, services, provider, providerRates } = p;
  const q = useMemo(
    () => quantityFor620({ service, dateMode, startDate, endDate, visitsPerDay, venue, services }),
    [service, dateMode, startDate, endDate, visitsPerDay, venue, services],
  );
  const local = useMemo(() => {
    const r = providerRates ? rateForService620(providerRates, service) : null;
    return estimateLocal620(q, r?.rate ?? null, providerRates?.currency || p.currency || "EUR");
  }, [q, providerRates, service, p.currency]);
  const [server, setServer] = useState<Estimate620 | null>(null);
  const [serverKey, setServerKey] = useState("");
  const key = `${service}|${dateMode}|${startDate}|${endDate}|${visitsPerDay}|${venue || ""}|${provider ? `${provider.role}:${provider.id}` : ""}`;
  useEffect(() => {
    if (!service) { setServer(null); setServerKey(""); return; }
    const ready = dateMode === "tbd" || q.quantity != null;
    if (!ready) { setServer(null); setServerKey(""); return; }
    let alive = true;
    const h = window.setTimeout(() => {
      const r = providerRates ? rateForService620(providerRates, service) : null;
      void estimatePricing620(
        {
          serviceType: service, dateMode, startDate: dateMode === "tbd" ? null : startDate, endDate: dateMode === "tbd" ? null : endDate,
          visitsPerDay: service === "home_visit" ? visitsPerDay : null, houseSittingVenue: venue || null,
          providerRole: provider?.role, providerId: provider?.id, rate: r?.rate ?? null, unit: r?.unit ?? null, currency: providerRates?.currency || null,
        },
        q,
      ).then((e) => { if (alive) { setServer(e); setServerKey(key); } });
    }, 300);
    return () => { alive = false; window.clearTimeout(h); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, providerRates]);

  if (!service) return null;
  const est = server && serverKey === key ? server : local;
  const unitLong = unitLong620(lang, est.unit || q.unit);
  const cur = est.currency || "EUR";

  if (dateMode === "tbd") {
    return (
      <div data-testid="estimate-620" data-estimate-kind="tbd" className="flex items-start gap-2.5 rounded-2xl px-3.5 py-3" style={{ background: ORANGE_PALE }}>
        <AppIcon name="wallet" size={18} color={ORANGE_DARK} />
        <div className="min-w-0 text-sm leading-snug" style={{ color: INK }}>
          {est.rate != null && (
            <p className="font-extrabold" style={{ color: ORANGE_DARK }} data-estimate-rate={est.rate}>
              {d620(lang, "est_rate").replace("{price}", money(est.rate, cur, lang)).replace("{unit}", unitLong)}
            </p>
          )}
          <p>{d620(lang, "est_tbd").replace("{unit}", unitLong)}</p>
        </div>
      </div>
    );
  }
  if (q.quantity == null) return null;
  const qty = qtyLabel620(lang, est.quantity ?? q.quantity, est.unit || q.unit);
  if (est.ownerTotal != null) {
    return (
      <div data-testid="estimate-620" data-estimate-kind="total" data-estimate-total={est.ownerTotal} data-estimate-source={est.fromServer ? "server" : "local"} className="flex items-start gap-2.5 rounded-2xl px-3.5 py-3" style={{ background: ORANGE_PALE }}>
        <AppIcon name="wallet" size={18} color={ORANGE_DARK} />
        <div className="min-w-0 text-sm leading-snug" style={{ color: INK }}>
          <p className="font-extrabold" style={{ color: ORANGE_DARK }}>
            {d620(lang, "est_about").replace("{total}", money(est.ownerTotal, cur, lang)).replace("{qty}", qty)}
          </p>
          <p className="text-xs" style={{ color: INK_SOFT }}>
            {est.rate != null ? `${d620(lang, "est_rate").replace("{price}", money(est.rate, cur, lang)).replace("{unit}", unitLong)} · ` : ""}{d620(lang, "est_fees")}
          </p>
        </div>
      </div>
    );
  }
  return (
    <div data-testid="estimate-620" data-estimate-kind="qty" className="flex items-start gap-2.5 rounded-2xl px-3.5 py-3" style={{ background: ORANGE_PALE }}>
      <AppIcon name="calendar" size={18} color={ORANGE_DARK} />
      <p className="min-w-0 text-sm leading-snug" style={{ color: INK }}>{d620(lang, "est_qty_only").replace("{qty}", qty)}</p>
    </div>
  );
}
