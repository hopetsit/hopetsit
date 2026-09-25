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
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { useAuth } from "@/lib/useAuth";
import { API_BASE, startProviderConversation } from "@/lib/api";
import { AppIcon } from "@/components/AppIcon";
import { ensureOwnerProfile, isMyProfile, needsOwnerSwitch } from "@/lib/bookAsOwner";
import { providerCurrency, providerFrom, providerRateLines, formatMoney, type ProviderRateSource } from "@/lib/providerRates";

// 25/09/2026 (PawMap 584, point 8) — fiche refaite : bouton principal PLEIN
// « Réserver · dès 20 €/j » (dégradé du rôle, texte blanc, devise du
// prestataire) en premier, « Message » en second plus petit, puis la carte
// « Tarifs » complète (lignes vides masquées). Connecté : Réserver ouvre
// directement le parcours de réservation (/book/<rôle>/<id>) ; sans compte,
// l'inscription propriétaire puis retour à la réservation.

type Fiche = ProviderRateSource & {
  id?: string;
  name?: string;
  firstName?: string;
  city?: string;
  coverageCity?: string;
  bio?: string;
  avatar?: { url?: string } | string | null;
  rating?: number;
  averageRating?: number;
  reviewsCount?: number;
  isTopSitter?: boolean;
  isTopWalker?: boolean;
  identityVerified?: boolean;
  isBoosted?: boolean;
};

const ROLE = {
  sitter: { c: "#2563EB", dark: "#1E4FB0", g1: "#2563EB", g2: "#1E4FB0", light: "#EAF1FE", ink: "#173E8C", icon: "home" as const },
  walker: { c: "#16A34A", dark: "#15803D", g1: "#15803D", g2: "#166534", light: "#E8F8EE", ink: "#0F5C2B", icon: "walker" as const },
};

export default function ProviderSharePage() {
  const params = useParams<{ type: string; id: string }>();
  const type: "sitter" | "walker" = params.type === "walker" ? "walker" : "sitter";
  const id = params.id;
  const { t, lang } = useT();
  const { user, ready } = useAuth();
  const router = useRouter();

  const [fiche, setFiche] = useState<Fiche | null>(null);
  const [etat, setEtat] = useState<"chargement" | "ok" | "absent">("chargement");
  const [msgBusy, setMsgBusy] = useState(false);
  // 25/09 (586, point 8) — Réserver TOUJOURS en premier, quel que soit le rôle
  // du visiteur ; un gardien / promeneur réserve avec son profil propriétaire.
  // Seul cas sans Réserver : ma propre fiche.
  const [asOwnerNote, setAsOwnerNote] = useState(false);
  const [mine, setMine] = useState(false);
  const [bookBusy, setBookBusy] = useState(false);
  const [switchErr, setSwitchErr] = useState(false);
  useEffect(() => {
    setAsOwnerNote(needsOwnerSwitch());
    setMine(isMyProfile(id));
  }, [user, id]);

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

  const r = ROLE[type];
  const prenom = (fiche?.firstName || fiche?.name || "").split(" ")[0];
  const photo = typeof fiche?.avatar === "string" ? fiche?.avatar : fiche?.avatar?.url;
  const note = Number(fiche?.averageRating ?? fiche?.rating ?? 0);
  const avis = Number(fiche?.reviewsCount ?? 0);
  const devise = fiche ? providerCurrency(fiche) : "EUR";
  const lignes = fiche ? providerRateLines(type, fiche) : [];
  const des = fiche ? providerFrom(type, fiche) : null;
  const ville = fiche?.city || fiche?.coverageCity || "";
  const connecte = ready && !!user;

  const cible = `/book/${type}/${id}`;
  const lienReserver = connecte
    ? cible
    : `/signup?role=owner${ville ? `&city=${encodeURIComponent(ville)}` : ""}&next=${encodeURIComponent(cible)}`;
  const libelleReserver = des
    ? t("prov_book_from").replace("{price}", `${formatMoney(des.value, devise, lang)}/${t(des.unitKey)}`)
    : t("prov_book");

  async function onBook(e: React.MouseEvent) {
    if (!connecte || !asOwnerNote) return; // lien normal
    e.preventDefault();
    if (bookBusy) return;
    setBookBusy(true);
    setSwitchErr(false);
    if (await ensureOwnerProfile()) router.push(cible);
    else { setSwitchErr(true); setBookBusy(false); }
  }
  async function onMessage() {
    if (!connecte) {
      router.push(`/signup?role=owner&next=${encodeURIComponent(`/p/${type}/${id}`)}`);
      return;
    }
    setMsgBusy(true);
    if (asOwnerNote && !(await ensureOwnerProfile())) { setSwitchErr(true); setMsgBusy(false); return; }
    try {
      const cid = await startProviderConversation(type, id);
      router.push(cid ? `/chat?c=${cid}` : "/chat");
    } catch {
      // Un gardien / promeneur ne peut pas ouvrir ce chat : la réservation
      // reste le chemin (le chat s'ouvre avec elle).
      router.push(cible);
    } finally {
      setMsgBusy(false);
    }
  }

  if (etat === "chargement") {
    return (
      <div className="flex min-h-[50vh] items-center justify-center">
        <span className="h-7 w-7 animate-spin rounded-full border-2 border-t-transparent" style={{ borderColor: r.c, borderTopColor: "transparent" }} />
      </div>
    );
  }
  if (etat === "absent" || !fiche) {
    return (
      <div className="mx-auto max-w-md px-4 py-24 text-center">
        <p className="text-sm text-[#6E4F48]">{t("provider_not_found")}</p>
        <Link href="/" className="mt-6 inline-block rounded-full bg-owner px-6 py-3 text-sm font-semibold text-white">
          HoPetSit
        </Link>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-lg px-4 py-8 md:py-14">
      {/* ── EN-TÊTE ── photo, prénom, ville, badges, puis LES DEUX BOUTONS. */}
      <section className="rounded-[28px] bg-white p-6 text-center shadow-[0_18px_50px_-22px_rgba(35,23,21,0.35)] ring-1 ring-[#F3E6E1]">
        <div className="relative mx-auto h-24 w-24">
          {photo ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={photo} alt="" className="h-24 w-24 rounded-full object-cover" style={{ boxShadow: `0 0 0 3px #fff, 0 0 0 6px ${r.c}` }} />
          ) : (
            <span className="grid h-24 w-24 place-items-center rounded-full text-3xl font-bold text-white" style={{ background: `linear-gradient(160deg, ${r.g1}, ${r.g2})`, boxShadow: `0 0 0 3px #fff, 0 0 0 6px ${r.c}` }}>
              {prenom.charAt(0).toUpperCase() || <AppIcon name={r.icon} size={36} color="#fff" />}
            </span>
          )}
          <span className="absolute -bottom-1 -right-1 grid h-9 w-9 place-items-center rounded-full border-[2.5px] border-white" style={{ background: r.c }}>
            <AppIcon name={r.icon} size={17} color="#fff" />
          </span>
        </div>

        <h1 className="mt-4 font-display text-[1.75rem] font-bold leading-tight tracking-[-0.02em] text-[#231715]">{prenom}</h1>
        <p className="mt-1 text-sm font-semibold" style={{ color: r.dark }}>
          {t(type === "walker" ? "role_walker" : "role_sitter")}{ville ? <span className="font-medium text-[#6E4F48]"> · {ville}</span> : null}
        </p>

        <div className="mt-3 flex flex-wrap items-center justify-center gap-2 text-xs font-semibold">
          {(fiche.isTopSitter || fiche.isTopWalker) && (
            <span className="inline-flex items-center gap-1 rounded-full bg-[#FFF6DB] px-3 py-1 text-[#7A5200]"><AppIcon name="star" size={13} color="#C58A00" />{t("provider_top")}</span>
          )}
          {avis > 0 && (
            <span className="inline-flex items-center gap-1 rounded-full bg-[#FFF6DB] px-3 py-1 text-[#231715]"><AppIcon name="star" size={13} color="#E0A100" />{note.toFixed(1)} · {avis}</span>
          )}
          {fiche.identityVerified && (
            <span className="inline-flex items-center gap-1 rounded-full bg-[#E8F8EE] px-3 py-1 text-[#0F5C2B]"><AppIcon name="shield-check" size={13} color="#16A34A" />{t("trust_id_title")}</span>
          )}
        </div>

        {!mine && (<>
        <Link
          href={lienReserver}
          onClick={onBook}
          aria-busy={bookBusy}
          className="relative mt-6 flex min-h-[56px] w-full items-center justify-center gap-3 overflow-hidden rounded-[18px] px-5 text-[15px] font-bold text-white shadow-[0_12px_28px_-10px_rgba(23,20,31,0.45)] transition active:scale-[0.97]"
          style={{ background: `linear-gradient(90deg, ${r.g1}, ${r.g2})`, color: "#fff" }}
        >
          <span aria-hidden className="pointer-events-none absolute inset-x-0 top-0 h-1/2 bg-white/15" />
          <span className="relative grid h-9 w-9 shrink-0 place-items-center rounded-full bg-white"><AppIcon name="calendar" size={18} color={r.c} /></span>
          <span className="relative text-balance leading-tight">{bookBusy ? t("m586_switching_owner") : libelleReserver}</span>
        </Link>
        {asOwnerNote && (
          <p className="mt-2 inline-flex items-center justify-center gap-1.5 text-[12px] font-bold text-[#9E1F0B]">
            <AppIcon name="paw" size={13} color="#C92A12" />{t("m586_book_as_owner")}
          </p>
        )}
        {switchErr && <p className="mt-1 text-[12px] font-bold text-[#B42318]" role="alert">{t("m586_switch_owner_error")}</p>}
        <button
          type="button"
          onClick={onMessage}
          disabled={msgBusy}
          className="mx-auto mt-3 flex min-h-[44px] items-center justify-center gap-2 rounded-[16px] border-[1.5px] bg-white px-5 text-sm font-bold transition active:scale-[0.97] disabled:opacity-70"
          style={{ borderColor: r.c, color: r.dark }}
        >
          {msgBusy ? <span className="h-4 w-4 animate-spin rounded-full border-2 border-t-transparent" style={{ borderColor: r.c, borderTopColor: "transparent" }} /> : <AppIcon name="chat" size={17} color={r.c} />}
          {t("prov_message")}
        </button>
        </>)}
        <p className="mt-3 text-xs leading-relaxed text-[#6E4F48]">{t("provider_reassure")}</p>
      </section>

      {/* ── TARIFS ── juste sous l'en-tête, lignes vides jamais affichées. */}
      {lignes.length > 0 && (
        <section className="mt-4 rounded-[24px] p-5" style={{ background: r.light }}>
          <h2 className="flex items-center gap-2 font-display text-lg font-bold" style={{ color: r.ink }}>
            <AppIcon name="coins" size={19} color={r.c} />{t("prov_rates_title")}
          </h2>
          <ul className="mt-3 divide-y" style={{ borderColor: `${r.c}22` }}>
            {lignes.map((l) => (
              <li key={l.key} className="flex items-center justify-between gap-3 py-2.5" style={{ borderColor: `${r.c}22` }}>
                <span className="text-sm font-medium text-[#231715]">{t(l.labelKey)}</span>
                <span className="font-display text-base font-bold tabular-nums" style={{ color: r.ink }}>{formatMoney(l.value, devise, lang)}</span>
              </li>
            ))}
          </ul>
        </section>
      )}

      {fiche.bio && (
        <section className="mt-4 rounded-[24px] bg-[#FDF8F7] p-5 ring-1 ring-[#F3E6E1]">
          <p className="whitespace-pre-line text-left text-sm leading-relaxed text-[#3A2A26]">{fiche.bio}</p>
        </section>
      )}

      <p className="mt-6 text-center text-xs text-[#6E4F48]">
        <Link href="/" className="font-semibold text-owner-dark">HoPetSit</Link>
      </p>
    </div>
  );
}
