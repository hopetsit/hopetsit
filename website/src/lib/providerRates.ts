// 25/09/2026 (PawMap 584, point 8) — TARIFS d'un prestataire dans SA devise,
// forme pure (même règle que l'app, frontend/lib/views/map/pawmap_rates.dart) :
//   · gardien  : heure / jour / semaine / mois + animal en plus ;
//   · promeneur : 30 min / 1 h / 2 h.
// Une ligne vide (absente, 0 ou négative) n'existe pas : jamais « 0 € ».

export type ProviderRateSource = {
  currency?: string | null;
  hourlyRate?: number | null;
  dailyRate?: number | null;
  weeklyRate?: number | null;
  monthlyRate?: number | null;
  extraPetRate?: number | null;
  walkRates?: { durationMinutes?: number; basePrice?: number; currency?: string; enabled?: boolean }[] | null;
};

export type RateLine = { key: string; labelKey: string; value: number };

const pos = (v: unknown): number | null => {
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? n : null;
};

export function providerCurrency(src: ProviderRateSource): string {
  const w = (src.walkRates || []).find((r) => r?.currency);
  return String(src.currency || w?.currency || "EUR").toUpperCase();
}

export function providerRateLines(role: "sitter" | "walker", src: ProviderRateSource): RateLine[] {
  const out: RateLine[] = [];
  if (role === "walker") {
    const walk = (min: number) => pos((src.walkRates || []).find((r) => r && r.enabled !== false && Number(r.durationMinutes) === min)?.basePrice);
    const w30 = walk(30);
    const w60 = walk(60) ?? pos(src.hourlyRate);
    const w120 = walk(120);
    if (w30) out.push({ key: "30", labelKey: "prov_rate_30", value: w30 });
    if (w60) out.push({ key: "60", labelKey: "prov_rate_60", value: w60 });
    if (w120) out.push({ key: "120", labelKey: "prov_rate_120", value: w120 });
    return out;
  }
  const h = pos(src.hourlyRate), d = pos(src.dailyRate), wk = pos(src.weeklyRate), m = pos(src.monthlyRate), x = pos(src.extraPetRate);
  if (h) out.push({ key: "hour", labelKey: "prov_rate_hour", value: h });
  if (d) out.push({ key: "day", labelKey: "prov_rate_day", value: d });
  if (wk) out.push({ key: "week", labelKey: "prov_rate_week", value: wk });
  if (m) out.push({ key: "month", labelKey: "prov_rate_month", value: m });
  if (x) out.push({ key: "extra", labelKey: "prov_rate_extra_pet", value: x });
  return out;
}

/** Prix d'entrée le plus parlant + son unité (clé i18n) : « 20 €/j », « 12 €/1 h ». */
export function providerFrom(role: "sitter" | "walker", src: ProviderRateSource): { value: number; unitKey: string } | null {
  const lines = providerRateLines(role, src);
  const pick = (k: string) => lines.find((l) => l.key === k);
  const order = role === "walker" ? [["30", "unit_30"], ["60", "unit_60"], ["120", "unit_120"]] : [["day", "unit_day"], ["hour", "unit_hour"], ["week", "unit_week"], ["month", "unit_month"]];
  for (const [k, u] of order) {
    const l = pick(k);
    if (l) return { value: l.value, unitKey: u };
  }
  return null;
}

/** Montant dans la devise du prestataire, format compact (pas de ,00 inutile). */
export function formatMoney(value: number, currency: string, lang: string): string {
  try {
    return new Intl.NumberFormat(lang, { style: "currency", currency, maximumFractionDigits: Number.isInteger(value) ? 0 : 2 }).format(value);
  } catch {
    return `${value} ${currency}`;
  }
}
