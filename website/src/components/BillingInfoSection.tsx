"use client";

// v566 — « Informations de facturation » (Daniel, 18/09) : propriétaires ET
// prestataires saisissent leur identifiant fiscal (NIF, NIE, CIF, SIRET,
// n° de TVA, EIN, passeport, numéro d'entreprise…) pour déclarer leurs
// factures. GET/PATCH /users/me/billing-info — le serveur écrit sur les 3
// profils de la personne et copie un instantané sur chaque facture.
// Tout est facultatif. La liste des types d'identifiant suit le pays choisi.

import { useEffect, useMemo, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError,
  BillingIdType,
  BillingInfo,
  BillingSnapshot,
  getMyBillingInfo,
  updateMyBillingInfo,
} from "@/lib/api";

const ALL_ID_TYPES: BillingIdType[] = [
  "nif", "nie", "cif", "siret", "vat", "ein", "passport", "company_number", "other",
];

// Types proposés selon le pays (ISO-2). Pays absent → liste complète.
const ID_TYPES_BY_COUNTRY: Record<string, BillingIdType[]> = {
  ES: ["nif", "nie", "cif", "vat", "passport", "other"],
  PT: ["nif", "vat", "passport", "other"],
  FR: ["siret", "vat", "company_number", "passport", "other"],
  US: ["ein", "passport", "other"],
  GB: ["company_number", "vat", "passport", "other"],
  IE: ["company_number", "vat", "passport", "other"],
  HK: ["company_number", "passport", "other"],
};
const EU_DEFAULT: BillingIdType[] = ["vat", "company_number", "passport", "other"];
const EU = new Set([
  "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "DE", "GR", "HU", "IT", "LV",
  "LT", "LU", "MT", "NL", "PL", "RO", "SK", "SI", "SE", "CH", "NO", "MC",
]);

export function billingIdTypesFor(country: string): BillingIdType[] {
  const c = (country || "").toUpperCase();
  if (ID_TYPES_BY_COUNTRY[c]) return ID_TYPES_BY_COUNTRY[c];
  if (EU.has(c)) return EU_DEFAULT;
  return ALL_ID_TYPES;
}

// ISO 3166-1 alpha-2 — noms affichés dans la langue du site via Intl.DisplayNames.
const COUNTRY_CODES = (
  "AD AE AF AG AL AM AO AR AT AU AZ BA BB BD BE BF BG BH BI BJ BN BO BR BS BT BW BY BZ " +
  "CA CD CF CG CH CI CL CM CN CO CR CU CV CY CZ DE DJ DK DM DO DZ EC EE EG ER ES ET FI FJ " +
  "FR GA GB GD GE GH GM GN GQ GR GT GW GY HK HN HR HT HU ID IE IL IN IQ IR IS IT JM JO JP " +
  "KE KG KH KM KR KW KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MG MK ML MM MN MO MR " +
  "MT MU MV MW MX MY MZ NA NE NG NI NL NO NP NZ OM PA PE PG PH PK PL PR PT PY QA RO RS RU " +
  "RW SA SC SD SE SG SI SK SL SM SN SO SR SV SY TD TG TH TJ TN TR TT TW TZ UA UG US UY UZ " +
  "VE VN YE ZA ZM ZW"
).split(" ");

const inputCls =
  "w-full rounded-xl border border-ink/10 bg-white px-4 py-2.5 text-sm text-ink outline-none focus:border-ink/30";

const EMPTY: BillingInfo = {
  type: "individual", legalName: "", idType: "", idNumber: "", vatNumber: "",
  address: "", postalCode: "", city: "", country: "", updatedAt: null,
};

export function BillingInfoSection({
  className = "",
  defaultCountry = "",
}: {
  className?: string;
  /** Pays du compte : pré-sélectionné tant que rien n'est enregistré. */
  defaultCountry?: string;
}) {
  const { t, lang } = useT();
  const [info, setInfo] = useState<BillingInfo>(EMPTY);
  const [loaded, setLoaded] = useState(false);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  useEffect(() => {
    let cancelled = false;
    getMyBillingInfo()
      .then((b) => {
        if (cancelled) return;
        setInfo({ ...EMPTY, ...b, country: b.country || defaultCountry.toUpperCase().slice(0, 2) });
      })
      .catch(() => {
        /* section facultative : on laisse le formulaire vide */
      })
      .finally(() => {
        if (!cancelled) setLoaded(true);
      });
    return () => {
      cancelled = true;
    };
  }, [defaultCountry]);

  // Lien « /profile#billing » (page des factures) : la section n'existe qu'après
  // le chargement du profil → on défile nous-mêmes une fois prête.
  useEffect(() => {
    if (!loaded || typeof window === "undefined" || window.location.hash !== "#billing") return;
    document.getElementById("billing")?.scrollIntoView({ behavior: "smooth", block: "start" });
  }, [loaded]);

  const countries = useMemo(() => {
    let names: Intl.DisplayNames | null = null;
    try {
      names = new Intl.DisplayNames([lang], { type: "region" });
    } catch {
      names = null;
    }
    return COUNTRY_CODES.map((code) => ({ code, name: names?.of(code) || code })).sort((a, b) =>
      a.name.localeCompare(b.name, lang),
    );
  }, [lang]);

  const idTypes = useMemo(() => {
    const list = billingIdTypesFor(info.country);
    // Un type déjà enregistré reste sélectionnable même si le pays a changé.
    return info.idType && !list.includes(info.idType) ? [info.idType, ...list] : list;
  }, [info.country, info.idType]);

  const set = <K extends keyof BillingInfo>(k: K, v: BillingInfo[K]) => {
    setInfo((cur) => ({ ...cur, [k]: v }));
    setMsg(null);
  };

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (busy) return;
    setBusy(true);
    setMsg(null);
    try {
      const saved = await updateMyBillingInfo({
        type: info.type,
        legalName: info.legalName,
        // Comme l'app : un numéro saisi sans type part en « other ».
        idType: info.idType || (info.idNumber.trim() ? "other" : ""),
        idNumber: info.idNumber,
        vatNumber: info.vatNumber,
        address: info.address,
        postalCode: info.postalCode,
        city: info.city,
        country: info.country,
      });
      setInfo({ ...EMPTY, ...saved });
      setMsg({ ok: true, text: t("billing_saved") });
    } catch (err) {
      setMsg({
        ok: false,
        text: err instanceof ApiError && err.status === 400 && err.message ? err.message : t("billing_error"),
      });
    } finally {
      setBusy(false);
    }
  }

  return (
    <section id="billing" className={`rounded-[24px] bg-[#FAF1EC] p-5 md:p-6 ${className}`}>
      <div className="flex items-center gap-2">
        <span aria-hidden="true" className="text-lg">🧾</span>
        <h2 className="text-base font-semibold text-[#231715]">{t("billing_title")}</h2>
      </div>
      <p className="mt-1 text-xs text-[#6E4F48]">{t("billing_sub")}</p>

      <form onSubmit={save} className="mt-4 space-y-4" aria-busy={!loaded || busy}>
        <div className="inline-flex rounded-full bg-white p-1">
          {(["individual", "business"] as const).map((k) => (
            <button
              key={k}
              type="button"
              onClick={() => set("type", k)}
              aria-pressed={info.type === k}
              className={`rounded-full px-4 py-1.5 text-sm font-semibold transition ${
                info.type === k ? "bg-owner-light text-owner-dark" : "text-[#6E4F48] hover:text-[#231715]"
              }`}
            >
              {t(k === "individual" ? "billing_type_individual" : "billing_type_business")}
            </button>
          ))}
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <BField label={t("billing_legal_name")} full>
            <input
              type="text" maxLength={120} value={info.legalName} autoComplete="organization"
              placeholder={t("billing_legal_name_ph")}
              onChange={(e) => set("legalName", e.target.value)} className={inputCls}
            />
          </BField>

          <BField label={t("billing_country")}>
            <select value={info.country} onChange={(e) => set("country", e.target.value)} className={inputCls}>
              <option value="">{t("billing_select")}</option>
              {countries.map((c) => (
                <option key={c.code} value={c.code}>{c.name}</option>
              ))}
            </select>
          </BField>

          <BField label={t("billing_id_type")}>
            <select
              value={info.idType}
              onChange={(e) => set("idType", e.target.value as BillingInfo["idType"])}
              className={inputCls}
            >
              <option value="">{t("billing_select")}</option>
              {idTypes.map((k) => (
                <option key={k} value={k}>{t(`billing_id_${k}`)}</option>
              ))}
            </select>
          </BField>

          <BField label={t("billing_id_number")}>
            <input
              type="text" maxLength={120} value={info.idNumber} autoCapitalize="characters" spellCheck={false}
              onChange={(e) => set("idNumber", e.target.value.toUpperCase())} className={`${inputCls} font-mono`}
            />
          </BField>

          <BField label={t("billing_vat_number")}>
            <input
              type="text" maxLength={120} value={info.vatNumber} autoCapitalize="characters" spellCheck={false}
              onChange={(e) => set("vatNumber", e.target.value.toUpperCase())} className={`${inputCls} font-mono`}
            />
          </BField>

          <BField label={t("billing_address")} full>
            <input
              type="text" maxLength={120} value={info.address} autoComplete="street-address"
              onChange={(e) => set("address", e.target.value)} className={inputCls}
            />
          </BField>

          <BField label={t("billing_postal_code")}>
            <input
              type="text" maxLength={120} value={info.postalCode} autoComplete="postal-code"
              onChange={(e) => set("postalCode", e.target.value)} className={inputCls}
            />
          </BField>

          <BField label={t("billing_city")}>
            <input
              type="text" maxLength={120} value={info.city} autoComplete="address-level2"
              onChange={(e) => set("city", e.target.value)} className={inputCls}
            />
          </BField>
        </div>

        <p className="text-xs text-[#6E4F48]">{t("billing_frozen_note")}</p>

        {msg && (
          <div
            role={msg.ok ? "status" : "alert"}
            className={`rounded-xl px-4 py-3 text-sm ${msg.ok ? "bg-green-50 text-green-700" : "bg-red-50 text-red-700"}`}
          >
            {msg.ok ? "✓ " : ""}{msg.text}
          </div>
        )}

        <button
          type="submit"
          disabled={busy || !loaded}
          className="rounded-full bg-[#231715] px-6 py-2.5 text-sm font-semibold text-white transition hover:bg-black disabled:cursor-not-allowed disabled:opacity-60"
        >
          {busy ? t("billing_saving") : t("billing_save")}
        </button>
      </form>
    </section>
  );
}

function BField({ label, full, children }: { label: string; full?: boolean; children: React.ReactNode }) {
  return (
    <label className={`block ${full ? "sm:col-span-2" : ""}`}>
      <span className="mb-1.5 block text-xs font-semibold uppercase tracking-wider text-[#6E4F48]">{label}</span>
      {children}
    </label>
  );
}

/** Bloc « Émetteur » / « Client » d'une facture (instantané figé). */
export function BillingPartyBlock({
  title,
  name,
  billing,
}: {
  title: string;
  name?: string;
  billing?: BillingSnapshot;
}) {
  const { t } = useT();
  const b = billing;
  const idLabel = b?.idType ? t(`billing_id_${b.idType}`) : t("billing_id_other");
  const cityLine = [b?.postalCode, b?.city].filter(Boolean).join(" ");
  const addr = [b?.address, cityLine, b?.country].filter(Boolean).join(", ");
  const hasData = !!(b && (b.legalName || b.idNumber || b.vatNumber || addr));
  return (
    <div className="rounded-2xl bg-[#FAF1EC] px-4 py-3">
      <p className="text-[11px] font-semibold uppercase tracking-wider text-[#6E4F48]">{title}</p>
      <p className="mt-1 text-sm font-semibold text-[#231715]">{b?.legalName || name || "—"}</p>
      {hasData ? (
        <div className="mt-0.5 space-y-0.5 text-xs text-[#6E4F48]">
          {b?.legalName && name && b.legalName !== name && <p>{name}</p>}
          {b?.idNumber && (
            <p>
              {idLabel} : <span className="font-mono text-[#231715]">{b.idNumber}</span>
            </p>
          )}
          {b?.vatNumber && !(b.idType === "vat" && b.vatNumber === b.idNumber) && (
            <p>
              {t("billing_vat_number")} : <span className="font-mono text-[#231715]">{b.vatNumber}</span>
            </p>
          )}
          {addr && <p>{addr}</p>}
        </div>
      ) : (
        <p className="mt-0.5 text-xs text-[#6E4F48]">{t("billing_missing")}</p>
      )}
    </div>
  );
}
