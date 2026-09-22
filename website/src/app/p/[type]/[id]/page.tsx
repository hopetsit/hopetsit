"use client";

// 22/09/2026 — LE LIEN QU'UN PRESTATAIRE PEUT ENVOYER À SON VOISIN.
//
// Constat du jour : 65 prestataires réels pour 15 propriétaires, et aucune
// demande publiée depuis toujours. Les prestataires arrivent seuls et
// gratuitement ; les propriétaires, jamais. Or chaque gardien connaît des
// propriétaires — et l'e-mail « ton premier client est déjà dans ton
// téléphone » leur dit déjà de partager leur profil… en pointant vers
// /profile, une page PRIVÉE : le voisin tombait sur un mur de connexion.
//
// Cette page est ce lien : publique, lisible sans compte, et elle mène à la
// réservation. C'est le chemin le plus court vers une première transaction,
// parce que la confiance existe déjà hors de l'application.
//
// Volontairement `noindex` (cf. middleware) : c'est un lien que la personne
// partage elle-même, pas un annuaire public de prestataires.

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { API_BASE } from "@/lib/api";

type Fiche = {
  id?: string;
  name?: string;
  firstName?: string;
  city?: string;
  bio?: string;
  avatar?: { url?: string } | string | null;
  rating?: number;
  averageRating?: number;
  reviewsCount?: number;
  completedServicesCount?: number;
  hourlyRate?: number;
  dailyRate?: number;
  currency?: string;
  walkRates?: { durationMinutes?: number; basePrice?: number; currency?: string; enabled?: boolean }[];
  isTopSitter?: boolean;
  isTopWalker?: boolean;
};

const DEVISE: Record<string, string> = { EUR: "€", USD: "$", GBP: "£" };

export default function ProviderSharePage() {
  const params = useParams<{ type: string; id: string }>();
  const type = params.type === "walker" ? "walker" : "sitter";
  const id = params.id;
  const { t } = useT();

  const [fiche, setFiche] = useState<Fiche | null>(null);
  const [etat, setEtat] = useState<"chargement" | "ok" | "absent">("chargement");

  useEffect(() => {
    let vivant = true;
    fetch(`${API_BASE}/${type}s/${id}`)
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => {
        if (!vivant) return;
        const f = (d && (d.sitter || d.walker)) as Fiche | undefined;
        if (f && (f.name || f.firstName)) {
          setFiche(f);
          setEtat("ok");
        } else setEtat("absent");
      })
      .catch(() => vivant && setEtat("absent"));
    return () => { vivant = false; };
  }, [type, id]);

  const prenom = (fiche?.firstName || fiche?.name || "").split(" ")[0];
  const photo = typeof fiche?.avatar === "string" ? fiche?.avatar : fiche?.avatar?.url;
  const note = Number(fiche?.averageRating ?? fiche?.rating ?? 0);
  const avis = Number(fiche?.reviewsCount ?? 0);
  const sym = DEVISE[fiche?.currency || "EUR"] || "";
  const tarifs = (fiche?.walkRates || []).filter((w) => w.basePrice && w.enabled !== false);
  const prix = type === "walker"
    ? (tarifs.length ? Math.min(...tarifs.map((w) => Number(w.basePrice))) : 0)
    : Number(fiche?.dailyRate || fiche?.hourlyRate || 0);

  // Réserver : la personne connectée va droit au but ; sinon on crée le compte
  // propriétaire et on revient exactement ici.
  const cible = `/book/${type}/${id}`;
  const lienReserver = `/signup?role=owner${fiche?.city ? `&city=${encodeURIComponent(fiche.city)}` : ""}`
    + `&next=${encodeURIComponent(cible)}`;

  if (etat === "chargement") {
    return <div className="mx-auto max-w-md px-4 py-24 text-center text-sm text-ink-muted">…</div>;
  }
  if (etat === "absent" || !fiche) {
    return (
      <div className="mx-auto max-w-md px-4 py-24 text-center">
        <p className="text-sm text-ink-muted">{t("provider_not_found")}</p>
        <Link href="/" className="mt-6 inline-block rounded-full bg-owner px-6 py-3 text-sm font-semibold text-white">
          HoPetSit
        </Link>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-md px-4 py-10 md:py-16">
      <div className="rounded-3xl border border-ink/5 bg-white p-6 text-center shadow-card">
        {photo ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={photo} alt="" className="mx-auto h-24 w-24 rounded-full object-cover" />
        ) : (
          <div className="mx-auto flex h-24 w-24 items-center justify-center rounded-full bg-bg-soft text-3xl font-bold text-ink-muted">
            {prenom.charAt(0).toUpperCase()}
          </div>
        )}

        <h1 className="mt-4 font-display text-2xl font-extrabold tracking-tight text-ink">{prenom}</h1>
        {fiche.city && <p className="mt-1 text-sm text-ink-muted">{fiche.city}</p>}

        <div className="mt-3 flex flex-wrap items-center justify-center gap-2 text-xs font-semibold">
          {(fiche.isTopSitter || fiche.isTopWalker) && (
            <span className="rounded-full bg-owner-light px-3 py-1 text-owner-dark">★ {t("provider_top")}</span>
          )}
          {avis > 0 && (
            <span className="rounded-full bg-bg-soft px-3 py-1 text-ink">
              {note.toFixed(1)} ★ · {avis}
            </span>
          )}
          {prix > 0 && (
            <span className="rounded-full bg-bg-soft px-3 py-1 text-ink">
              {t("provider_from")} {prix}{sym}
            </span>
          )}
        </div>

        {fiche.bio && (
          <p className="mt-5 whitespace-pre-line text-left text-sm leading-relaxed text-ink-muted">{fiche.bio}</p>
        )}

        <Link
          href={lienReserver}
          className="mt-7 block w-full rounded-full bg-owner py-3.5 text-sm font-bold text-white shadow-cta hover:bg-owner-dark"
        >
          {t("provider_book_cta")} {prenom}
        </Link>
        <p className="mt-2 text-xs text-ink-muted">{t("provider_reassure")}</p>
      </div>

      <p className="mt-6 text-center text-xs text-ink-muted">
        <Link href="/" className="font-semibold text-owner-dark">HoPetSit</Link>
      </p>
    </div>
  );
}
