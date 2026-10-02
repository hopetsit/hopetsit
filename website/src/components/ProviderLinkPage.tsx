"use client";

// 02/10/2026 (607, LEO) — PAGE PUBLIQUE /s/<slug> (décision de Daniel :
// « ramène tes clients »). Le lien qu'un gardien / promeneur envoie à ses
// voisins ou imprime sur son affiche (QR). Contenu = liste blanche de NEO
// (CONTRAT_607_lien_perso.md) : prénom + initiale, photo, ville, tarifs avec
// unité, note et avis, services, animaux, bio, badge « Pionnier ». Bouton
// principal = parcours de réservation existant (/book…) ; sans compte, la
// demande sans compte (askHref) comme sur /p ; l'app en second.
// Page claire comme /p (le site garde ses pages de contenu claires, même en mode sombre).
// Tous les hooks EN HAUT (piège du 22/09 : hook après un retour = page plantée).

import Link from "next/link";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { useAuth } from "@/lib/useAuth";
import { AppIcon } from "@/components/AppIcon";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { askHref, askLabel, askNote } from "@/lib/i18n/demander2809";
import { providerCurrency, providerFrom, providerRateLines, formatMoney } from "@/lib/providerRates";
import { type PublicProvider607, PUBLIC_API_BASE, rateSourceOf, serviceKeys, petKeys, fill } from "@/lib/publicProvider607";

const ROLE = {
  sitter: { c: "#2563EB", g1: "#2563EB", g2: "#1E4FB0", light: "#EAF1FE", ink: "#173E8C", icon: "home" as const },
  walker: { c: "#16A34A", g1: "#15803D", g2: "#166534", light: "#E8F8EE", ink: "#0F5C2B", icon: "walker" as const },
};

export function ProviderLinkPage({ p }: { p: PublicProvider607 }) {
  const { t, lang } = useT();
  const { user, ready } = useAuth();
  const [copied, setCopied] = useState(false);
  const [canShare, setCanShare] = useState(false);
  useEffect(() => { setCanShare(typeof navigator !== "undefined" && (typeof navigator.share === "function" || !!navigator.clipboard)); }, []);

  const r = ROLE[p.role];
  const src = rateSourceOf(p);
  const devise = providerCurrency(src);
  const lignes = providerRateLines(p.role, src);
  const des = providerFrom(p.role, src);
  const connecte = ready && !!user;
  const prenom = p.firstName || p.name.split(" ")[0] || "";
  const roleLabel = t(p.role === "walker" ? "role_walker" : "role_sitter");
  const cible = `/book/${p.role}/${p.id}`;
  const libelleReserver = des ? t("prov_book_from").replace("{price}", `${formatMoney(des.value, devise, lang)}/${t(des.unitKey)}`) : t("prov_book");
  const services = serviceKeys(p.services);
  const pets = petKeys(p.acceptedPetTypes);
  const posterLang = ["fr", "en", "es", "de", "it", "pt", "pl"].includes(lang) ? lang : "en";

  async function onShare() {
    trackSiteEvent("cta_click", { label: "partager_lien_perso" });
    try {
      if (typeof navigator.share === "function") { await navigator.share({ title: p.name, url: p.url }); return; }
      await navigator.clipboard.writeText(p.url);
      setCopied(true);
      setTimeout(() => setCopied(false), 2200);
    } catch { /* partage annulé */ }
  }

  return (
    <div className="mx-auto max-w-5xl px-4 py-8 md:py-14">
      <div className="grid gap-4 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] md:items-start md:gap-6">
        {/* ── EN-TÊTE : photo, nom, rôle · ville, badges, bouton principal. */}
        <section className="rounded-[28px] bg-white p-6 text-center shadow-[0_18px_50px_-22px_rgba(35,23,21,0.35)] ring-1 ring-[#F3E6E1] md:sticky md:top-24">
          <div className="relative mx-auto h-28 w-28">
            {p.photo ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={p.photo} alt={p.name} width={112} height={112} className="h-28 w-28 rounded-full object-cover" style={{ boxShadow: `0 0 0 3px #fff, 0 0 0 6px ${r.c}` }} />
            ) : (
              <span className="grid h-28 w-28 place-items-center rounded-full text-4xl font-bold text-white" style={{ background: `linear-gradient(160deg, ${r.g1}, ${r.g2})`, boxShadow: `0 0 0 3px #fff, 0 0 0 6px ${r.c}` }}>
                {prenom.charAt(0).toUpperCase() || <AppIcon name={r.icon} size={40} color="#fff" />}
              </span>
            )}
            <span className="absolute -bottom-1 -right-1 grid h-10 w-10 place-items-center rounded-full border-[2.5px] border-white" style={{ background: r.c }}>
              <AppIcon name={r.icon} size={18} color="#fff" />
            </span>
          </div>

          <h1 className="mt-4 text-balance font-display text-[1.85rem] font-bold leading-tight tracking-[-0.02em] text-[#231715]">{p.name}</h1>
          <p className="mt-1 text-sm font-semibold" style={{ color: r.c }}>
            {roleLabel}{p.city ? <span className="font-medium text-[#6E4F48]"> · {p.city}</span> : null}
          </p>

          <div className="mt-3 flex flex-wrap items-center justify-center gap-2 text-xs font-semibold">
            {p.isPioneer && (
              <span data-pioneer="" className="inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-white" style={{ background: "linear-gradient(165deg,#E0553F,#C92A12 55%,#A31F0C)", boxShadow: "0 6px 14px -8px #C92A12" }}>
                <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="#fff" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M5 21V4" /><path d="M5 4h11l-2 4 2 4H5" /></svg>
                {p.city ? fill(t("s607_pioneer_at"), { city: p.city }) : t("s607_pioneer")}
              </span>
            )}
            {p.reviewsCount > 0 && p.rating > 0 && (
              <span className="inline-flex items-center gap-1 rounded-full bg-[#FFF6DB] px-3 py-1 text-[#231715]"><AppIcon name="star" size={13} color="#E0A100" />{p.rating.toFixed(1)} · {p.reviewsCount}</span>
            )}
            {p.verified && (
              <span className="inline-flex items-center gap-1 rounded-full bg-[#E8F8EE] px-3 py-1 text-[#0F5C2B]"><AppIcon name="shield-check" size={13} color="#16A34A" />{t("trust_id_title")}</span>
            )}
          </div>

          {ready && (
            <Link
              href={connecte ? cible : askHref(p.city, p.role, p.id)}
              onClick={() => trackSiteEvent("cta_click", { label: connecte ? "reserver_lien_perso" : "demander_lien_perso" })}
              className="relative mt-6 flex min-h-[56px] w-full items-center justify-center gap-3 overflow-hidden rounded-[18px] px-5 text-[15px] font-bold text-white shadow-[0_12px_28px_-10px_rgba(23,20,31,0.45)] transition active:scale-[0.97]"
              style={{ background: `linear-gradient(90deg, ${r.g1}, ${r.g2})`, color: "#fff" }}
            >
              <span aria-hidden className="pointer-events-none absolute inset-x-0 top-0 h-1/2 bg-white/15" />
              <span className="relative grid h-9 w-9 shrink-0 place-items-center rounded-full bg-white"><AppIcon name={connecte ? "calendar" : "megaphone"} size={18} color={r.c} /></span>
              <span className="relative text-balance leading-tight">
                {connecte ? libelleReserver : askLabel(lang, prenom)}
                {!connecte && des && <span className="block text-[12px] font-semibold opacity-90">{t("map_member_price_from")} {formatMoney(des.value, devise, lang)}/{t(des.unitKey)}</span>}
              </span>
            </Link>
          )}
          {ready && !connecte && <p className="mt-2 text-[12px] leading-snug text-[#6E4F48]">{askNote(lang, p.city, prenom)}</p>}

          <div className="mt-3 flex flex-wrap items-center justify-center gap-2">
            <Link
              href="/download"
              onClick={() => trackSiteEvent("cta_click", { label: "app_lien_perso" })}
              className="flex min-h-[44px] items-center justify-center gap-2 rounded-[16px] border-[1.5px] bg-white px-4 text-sm font-bold transition active:scale-[0.97]"
              style={{ borderColor: r.c, color: r.ink }}
            >
              <AppIcon name="download" size={16} color={r.c} />{t("s607_app")}
            </Link>
            {canShare && (
              <button
                type="button"
                onClick={() => void onShare()}
                className="flex min-h-[44px] items-center justify-center gap-2 rounded-[16px] border-[1.5px] bg-white px-4 text-sm font-bold transition active:scale-[0.97]"
                style={{ borderColor: r.c, color: r.ink }}
              >
                <AppIcon name={copied ? "check" : "arrow-right"} size={16} color={r.c} />{copied ? t("s607_copied") : t("s607_share")}
              </button>
            )}
          </div>
          <p className="mt-3 text-xs leading-relaxed text-[#6E4F48]">{t("provider_reassure")}</p>
        </section>

        <div className="space-y-4">
          {/* ── TARIFS (lignes vides jamais affichées, devise du prestataire). */}
          {lignes.length > 0 && (
            <section className="rounded-[24px] p-5" style={{ background: r.light }}>
              <h2 className="flex items-center gap-2 font-display text-lg font-bold" style={{ color: r.ink }}>
                <AppIcon name="coins" size={19} color={r.c} />{t("prov_rates_title")}
              </h2>
              <ul className="mt-3">
                {lignes.map((l) => (
                  <li key={l.key} className="flex items-center justify-between gap-3 border-b py-2.5 last:border-b-0" style={{ borderColor: `${r.c}33` }}>
                    <span className="text-sm font-medium text-[#231715]">{t(l.labelKey)}</span>
                    <span className="font-display text-base font-bold tabular-nums" style={{ color: r.ink }}>{formatMoney(l.value, devise, lang)}</span>
                  </li>
                ))}
              </ul>
            </section>
          )}

          {(services.length > 0 || pets.length > 0) && (
            <section className="rounded-[24px] bg-white p-5 ring-1 ring-[#F3E6E1]">
              {services.length > 0 && (
                <>
                  <h2 className="font-display text-lg font-bold text-[#231715]">{t("s607_services")}</h2>
                  <ul className="mt-2 flex flex-wrap gap-2">
                    {services.map((k) => <li key={k} className="rounded-full px-3 py-1.5 text-[13px] font-semibold" style={{ background: r.light, color: r.ink }}>{t(k)}</li>)}
                  </ul>
                </>
              )}
              {pets.length > 0 && (
                <>
                  <h2 className={`font-display text-lg font-bold text-[#231715] ${services.length ? "mt-4" : ""}`}>{t("s607_pets")}</h2>
                  <ul className="mt-2 flex flex-wrap gap-2">
                    {pets.map((k) => <li key={k} className="rounded-full bg-[#FFF1E8] px-3 py-1.5 text-[13px] font-semibold text-[#7A2A12]">{t(k)}</li>)}
                  </ul>
                </>
              )}
            </section>
          )}

          {p.bio && (
            <section className="rounded-[24px] bg-[#FDF8F7] p-5 ring-1 ring-[#F3E6E1]">
              <p className="whitespace-pre-line break-words text-left text-sm leading-relaxed text-[#3A2A26]">{p.bio}</p>
            </section>
          )}

          <section className="rounded-[24px] bg-white p-5 ring-1 ring-[#F3E6E1]">
            <h2 className="flex items-center gap-2 font-display text-lg font-bold text-[#231715]">
              <AppIcon name="star" size={19} color="#E0A100" />{t("s607_reviews")}
            </h2>
            {p.reviews.length === 0 ? (
              <p className="mt-2 text-sm text-[#6E4F48]">{t("s607_no_reviews")}</p>
            ) : (
              <ul className="mt-2 space-y-3">
                {p.reviews.map((rv, i) => (
                  <li key={i} className="rounded-2xl bg-[#FFF8E6] p-3">
                    <div className="flex items-center justify-between gap-2 text-[13px] font-bold text-[#231715]">
                      <span className="min-w-0 truncate">{rv.reviewerName}</span>
                      <span className="inline-flex shrink-0 items-center gap-0.5" aria-label={`${rv.rating}/5`}>
                        {[1, 2, 3, 4, 5].map((n) => <AppIcon key={n} name="star" size={13} color={n <= Math.round(rv.rating) ? "#E0A100" : "#F1D9CC"} />)}
                      </span>
                    </div>
                    {rv.comment && <p className="mt-1 whitespace-pre-line break-words text-[13px] leading-snug text-[#3A2A26]">{rv.comment}</p>}
                  </li>
                ))}
              </ul>
            )}
          </section>

          <p className="text-center text-xs">
            <a href={`${PUBLIC_API_BASE}/public/providers/${p.slug}/poster.pdf?lang=${posterLang}`} target="_blank" rel="noopener" className="inline-flex min-h-[44px] items-center gap-1.5 font-semibold text-[#9E1F0B] hover:underline">
              <AppIcon name="download" size={14} color="#C92A12" />{t("s607_poster")}
            </a>
          </p>
        </div>
      </div>
    </div>
  );
}

export default ProviderLinkPage;
