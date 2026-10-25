"use client";

// 25/10/2026 (LEO, 622 — ordre de Daniel via BOB : « il n'y a pas beaucoup les prix »).
// « à partir de » des demandes SANS budget, partagé par /map (PoiMap) et la carte publique
// (PublicPawMap, accueil + /pawmap) :
//   - bulle : « dès 10 €/jour », UN appel POST /pricing/estimate/public par service / devise / zone
//     d'~50 km, au plus BUBBLE_ESTIMATE_MAX_622 par carte (route limitée à 30 appels/min/IP) ;
//   - fiche : « à partir de 10 €/jour · estimation ~180 € » (dates de la demande quand elle en a).
// Rien quand basedOn vaut 0 ou que le serveur ne répond pas : jamais de prix inventé.
// Tous les hooks avant le moindre retour.

import { useEffect, useMemo, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { estimatePublic2410 } from "@/lib/api";
import { d620, unitShort620 } from "@/lib/i18n/dates620";
import { formatPriceUnit, priceUnitLabels } from "@/lib/priceUnit";
import type { Estimate620 } from "@/lib/services620";
import {
  BUBBLE_ESTIMATE_MAX_622,
  requestBubbleKey622,
  requestEstimateBody622,
  requestFicheKey622,
  usableEstimate622,
  type MapRequestPricing622,
  type RequestEstimateBody622,
} from "@/lib/mapPrice622";

const bubbleCache = new Map<string, Promise<Estimate620 | null>>();
const ficheCache = new Map<string, Promise<Estimate620 | null>>();

function unitOf(serviceType: string): "walk" | "visit" | "day" {
  return serviceType.includes("walk") ? "walk" : serviceType.includes("visit") ? "visit" : "day";
}
function ask(cache: Map<string, Promise<Estimate620 | null>>, key: string, body: RequestEstimateBody622): Promise<Estimate620 | null> {
  let p = cache.get(key);
  if (!p) {
    p = estimatePublic2410(body as never, unitOf(body.serviceType)).then((e) => (usableEstimate622(e) ? e : null)).catch(() => null);
    cache.set(key, p);
  }
  return p;
}

/** « dès 10 €/jour » (japonais : « 10 €/日～ »). */
export function useFromText622(): (txt: string) => string {
  const { t, lang } = useT();
  return (txt: string) => (lang === "ja" ? `${txt}～` : `${t("map_member_price_from")} ${txt}`);
}

/**
 * Libellés « dès X » des bulles de demande. `items` = la `pricing` de chaque demande sans budget
 * (null = demande avec budget, à moi, ou sans position). Renvoie `labelOf(pricing)`.
 */
export function useRequestFromLabels622(items: (MapRequestPricing622 | null | undefined)[]): (p: MapRequestPricing622 | null | undefined) => string | null {
  const { t, lang } = useT();
  const fromText = useFromText622();
  const [labels, setLabels] = useState<Record<string, string>>({});
  const wanted = useMemo(() => {
    const keys = new Map<string, RequestEstimateBody622>();
    for (const p of items) {
      if (!p) continue;
      const body = requestEstimateBody622(p, false);
      const k = requestBubbleKey622(body);
      if (body && k && !keys.has(k)) keys.set(k, body);
    }
    return [...keys.entries()].slice(0, BUBBLE_ESTIMATE_MAX_622);
  }, [items]);
  const sig = wanted.map(([k]) => k).join(";");
  useEffect(() => {
    let alive = true;
    const units = priceUnitLabels(t, lang);
    void Promise.all(wanted.map(async ([k, body]) => [k, await ask(bubbleCache, k, body)] as const)).then((pairs) => {
      if (!alive) return;
      const next: Record<string, string> = {};
      for (const [k, e] of pairs) {
        if (!e || e.fromRate == null) continue;
        const txt = formatPriceUnit(e.fromRate, e.currency || "EUR", null, units, e.unit);
        if (txt) next[k] = fromText(txt);
      }
      setLabels((p) => (JSON.stringify(p) === JSON.stringify(next) ? p : next));
    });
    return () => { alive = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sig, lang]);
  return (p) => (p ? labels[requestBubbleKey622(requestEstimateBody622(p, false))] ?? null : null);
}

/** Ligne de la fiche d'une demande sans budget. */
export function RequestFromLine622({ pricing, color = "#C92A12" }: { pricing: MapRequestPricing622; color?: string }) {
  const { lang } = useT();
  const body = requestEstimateBody622(pricing, true);
  const key = requestFicheKey622(body);
  const [est, setEst] = useState<Estimate620 | null>(null);
  useEffect(() => {
    if (!body || !key) { setEst(null); return; }
    let alive = true;
    void ask(ficheCache, key, body).then((e) => { if (alive) setEst(e); });
    return () => { alive = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  if (!est || est.fromRate == null) return null;
  const cur = est.currency || pricing.currency || "EUR";
  const money = (v: number) => {
    try { return new Intl.NumberFormat(lang, { style: "currency", currency: cur, maximumFractionDigits: Number.isInteger(v) ? 0 : 2 }).format(v); } catch { return `${v} ${cur}`; }
  };
  const from = d620(lang, "est_from").replace("{price}", money(est.fromRate)).replace("{unit}", unitShort620(lang, est.unit));
  const total = est.ownerTotalFrom != null && est.ownerTotalFrom > 0 ? d620(lang, "est_from_total").replace("{total}", money(est.ownerTotalFrom)) : null;
  return (
    <div data-request-from-622="" className="mt-0.5 text-xs font-bold" style={{ color }}>
      {total ? `${from} · ${total}` : from}
    </div>
  );
}
