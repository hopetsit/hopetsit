"use client";

// 24/10/2026 (LEO, complément de BOB 23 h 10, serveur de ZOE `POST /pricing/estimate/public`) :
// « Combien ça coûte à Paris ? » sur les pages villes propriétaires (/garde-animaux/<ville>,
// /pet-sitting/<city>…) — « à partir de X €/jour · d'après N gardiens à Paris », même ligne pour la
// promenade, puis « Vos dates ? » → « estimation ~Y € · 5 jours ». Mêmes chiffres que l'app et que
// /posts/create (même moteur serveur, même lecture `parseEstimate620`).
//
// Règles tenues (comme CitySupplyProof) :
//   - rendu côté client seulement : le HTML servi à Google ne change pas ;
//   - rien quand basedOn vaut 0 (aucun « 0 gardien », aucun chiffre inventé) ; serveur muet → rien ;
//   - 2 appels au chargement (garde + promenade), puis UN appel 600 ms après la dernière date saisie ;
//   - aucune donnée personnelle : ville, code postal (arrondissement), pays, langue, dates ;
//   - zéro gris : encres brunes de la charte, orange propriétaire ; tous les hooks avant tout retour.

import { useEffect, useMemo, useState } from "react";
import { AppIcon } from "@/components/AppIcon";
import { trackSiteEvent, withCampaign } from "@/components/SiteAnalytics";
import { estimatePublic2410 } from "@/lib/api";
import type { Lang } from "@/lib/i18n/langs";
import { d620, qtyLabel620, unitShort620 } from "@/lib/i18n/dates620";
import {
  PUBLIC_ESTIMATE_DEBOUNCE_MS,
  cityQueryName2410,
  countryOfRecruitCity2410,
  createPostHref2410,
  parisPostal2410,
  publicEstimateBody2410,
  publicEstimateKey2410,
} from "@/lib/publicEstimate2410";
import type { Estimate620 } from "@/lib/services620";

const ORANGE = "#C92A12";
const ORANGE_DARK = "#9E1F0B";
const ORANGE_PALE = "#FBE9E5";
const INK = "#231715";
const INK_SOFT = "#6E4F48";
const DRAFT_KEY = "hopetsit_post_draft_v1";

type Props = {
  /** Nom affiché de la ville (« Paris 11e », « Dallas »). */
  name: string;
  slug: string;
  region: string;
  lang: Lang;
};

function money(v: number, currency: string, lang: string): string {
  try {
    return new Intl.NumberFormat(lang, { style: "currency", currency, maximumFractionDigits: Number.isInteger(v) ? 0 : 2 }).format(v);
  } catch {
    return `${v} ${currency}`;
  }
}

function fromLine(lang: Lang, est: Estimate620): string {
  return d620(lang, "est_from").replace("{price}", money(est.fromRate as number, est.currency || "EUR", lang)).replace("{unit}", unitShort620(lang, est.unit));
}

function basedLine(lang: Lang, est: Estimate620, walk: boolean, city: string): string {
  const key = est.basedOn === 1 ? (walk ? "est_from_based_city_walk_1" : "est_from_based_city_1") : (walk ? "est_from_based_city_walk_n" : "est_from_based_city_n");
  return d620(lang, key).replace("{n}", String(est.basedOn)).replace("{city}", city);
}

const usable = (e: Estimate620 | null): e is Estimate620 => !!e && !!e.market && e.fromRate != null && !!e.basedOn && e.basedOn > 0;

export function FromRateCity2410({ name, slug, region, lang }: Props) {
  const cityQ = cityQueryName2410(name);
  const postal = parisPostal2410(slug);
  const country = countryOfRecruitCity2410(region, lang);
  const [sitting, setSitting] = useState<Estimate620 | null>(null);
  const [walking, setWalking] = useState<Estimate620 | null>(null);
  const [start, setStart] = useState("");
  const [end, setEnd] = useState("");
  const [dated, setDated] = useState<Estimate620 | null>(null);
  const [datedKey, setDatedKey] = useState("");

  // Au chargement : garde + promenade, tarif unitaire (« à prévoir »), un appel chacun.
  useEffect(() => {
    const ctrl = new AbortController();
    let alive = true;
    const bS = publicEstimateBody2410({ serviceType: "house_sitting", city: cityQ, postalCode: postal, country, lang, dateMode: "tbd" });
    const bW = publicEstimateBody2410({ serviceType: "dog_walking", city: cityQ, postalCode: postal, country, lang, dateMode: "tbd" });
    if (bS) void estimatePublic2410(bS, "day", ctrl.signal).then((e) => { if (alive) setSitting(e); });
    if (bW) void estimatePublic2410(bW, "walk", ctrl.signal).then((e) => { if (alive) setWalking(e); });
    return () => { alive = false; ctrl.abort(); };
  }, [cityQ, postal, country, lang]);

  // Dates saisies : UN appel 600 ms après la dernière frappe, et seulement quand les deux dates sont là.
  const datedBody = useMemo(
    () => (start && end ? publicEstimateBody2410({ serviceType: "house_sitting", city: cityQ, postalCode: postal, country, lang, dateMode: "exact", startDate: start, endDate: end }) : null),
    [start, end, cityQ, postal, country, lang],
  );
  const key = publicEstimateKey2410(datedBody);
  useEffect(() => {
    if (!datedBody || !key) { setDated(null); setDatedKey(""); return; }
    if (key === datedKey) return;
    let alive = true;
    const ctrl = new AbortController();
    const h = window.setTimeout(() => {
      void estimatePublic2410(datedBody, "day", ctrl.signal).then((e) => { if (alive) { setDated(e); setDatedKey(key); } });
    }, PUBLIC_ESTIMATE_DEBOUNCE_MS);
    return () => { alive = false; window.clearTimeout(h); ctrl.abort(); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  const okS = usable(sitting);
  const okW = usable(walking);
  if (!okS && !okW) return null;

  const total = dated && datedKey === key && usable(dated) && dated.ownerTotalFrom != null && dated.quantity != null ? dated : null;
  const href = createPostHref2410(cityQ);
  const field = "mt-1 w-full rounded-xl border px-3 py-2.5 text-sm focus:outline-none";

  function onCta() {
    // Le service (garde, sinon promenade) et les dates saisies suivent le visiteur dans le brouillon
    // du formulaire (jamais dans l'URL) ; un brouillon déjà commencé garde ses choix.
    try {
      const cur = JSON.parse(window.localStorage.getItem(DRAFT_KEY) || "{}") as Record<string, unknown>;
      const services = Array.isArray(cur.services) && cur.services.length ? cur.services : [okS ? "house_sitting" : "dog_walking"];
      const dates = start && end ? { startDate: start, endDate: end } : {};
      window.localStorage.setItem(DRAFT_KEY, JSON.stringify({ ...cur, city: cur.city || cityQ, services, ...dates, fromPrix: true }));
    } catch { /* navigation privée */ }
    trackSiteEvent("cta_click", { label: "prix_ville" });
  }

  return (
    <section data-testid="from-rate-city-2410" className="mt-5 rounded-2xl px-4 py-4" style={{ background: ORANGE_PALE }} aria-label={d620(lang, "city_price_title").replace("{city}", name)}>
      <div className="flex items-start gap-2.5">
        <AppIcon name="wallet" size={20} color={ORANGE_DARK} />
        <div className="min-w-0 flex-1">
          <h2 className="font-display text-base font-extrabold leading-tight" style={{ color: ORANGE_DARK }}>
            {d620(lang, "city_price_title").replace("{city}", name)}
          </h2>
          <ul className="mt-2 space-y-1.5 text-sm leading-snug" style={{ color: INK }}>
            {okS && (
              <li data-city-rate="house_sitting">
                <span className="font-semibold">{d620(lang, "svc_house_sitting")} : </span>
                <span className="font-extrabold" style={{ color: ORANGE_DARK }}>{fromLine(lang, sitting)}</span>
                <span style={{ color: INK_SOFT }}> · {basedLine(lang, sitting, false, cityQ)}</span>
              </li>
            )}
            {okW && (
              <li data-city-rate="dog_walking">
                <span className="font-semibold">{d620(lang, "svc_dog_walking")} : </span>
                <span className="font-extrabold" style={{ color: ORANGE_DARK }}>{fromLine(lang, walking)}</span>
                <span style={{ color: INK_SOFT }}> · {basedLine(lang, walking, true, cityQ)}</span>
              </li>
            )}
          </ul>

          {okS && (
            <div className="mt-3">
              <p className="text-xs font-semibold" style={{ color: INK }}>{d620(lang, "city_price_dates")}</p>
              <div className="mt-1 grid grid-cols-2 gap-2">
                <label className="block text-xs font-semibold" style={{ color: INK_SOFT }}>
                  {d620(lang, "city_price_from")}
                  <input type="date" value={start} min={new Date().toISOString().slice(0, 10)} onChange={(e) => setStart(e.target.value)} data-testid="city-date-start" className={field} style={{ borderColor: "rgba(201,42,18,0.3)", background: "#fff", color: INK }} />
                </label>
                <label className="block text-xs font-semibold" style={{ color: INK_SOFT }}>
                  {d620(lang, "city_price_to")}
                  <input type="date" value={end} min={start || new Date().toISOString().slice(0, 10)} onChange={(e) => setEnd(e.target.value)} data-testid="city-date-end" className={field} style={{ borderColor: "rgba(201,42,18,0.3)", background: "#fff", color: INK }} />
                </label>
              </div>
              {total && (
                <p data-testid="city-estimate-2410" className="mt-2 text-sm font-extrabold leading-snug" style={{ color: ORANGE_DARK }}>
                  {fromLine(lang, total)} · {d620(lang, "est_from_total").replace("{total}", money(total.ownerTotalFrom as number, total.currency || "EUR", lang))}
                  <span className="font-semibold" style={{ color: INK_SOFT }}> · {qtyLabel620(lang, total.quantity as number, total.unit)} · {d620(lang, "est_fees")}</span>
                </p>
              )}
            </div>
          )}

          <a
            href={withCampaign(href)}
            onClick={onCta}
            data-testid="city-price-cta"
            className="mt-3 block w-full rounded-full px-5 py-3 text-center text-sm font-extrabold text-white shadow-cta md:w-auto md:min-w-[16rem]"
            style={{ background: ORANGE }}
          >
            {d620(lang, "city_price_cta")}
          </a>
          <p className="mt-2 text-xs leading-snug" style={{ color: INK_SOFT }}>{d620(lang, "city_price_note")}</p>
        </div>
      </div>
    </section>
  );
}

export default FromRateCity2410;
