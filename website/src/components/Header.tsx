"use client";

import Link from "@/components/SiteLink";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { LogoWithText } from "./Logo";
import { LangSwitcher } from "./LangSwitcher";
import { useT } from "@/lib/i18n/LanguageProvider";
import { useAuth } from "@/lib/useAuth";
import { clearAuth } from "@/lib/api";

// 31/10 (LEO, décision BOB) — chemin propriétaire à un clic : la page d'arrivée avec le formulaire 1 étape
// (Paris en français, New York en anglais) ; « Devenir gardien » = inscription classique.
const PUBLISH: Partial<Record<string, { label: string; short: string; become: string; href: string }>> = {
  fr: { label: "Publier ma demande", short: "Publier", become: "Devenir gardien", href: "/garde-animaux/paris" },
  en: { label: "Post my request", short: "Post", become: "Become a sitter", href: "/pet-sitting/new-york" },
};

// 31/10 soir (LEO, passe 14 — Daniel : « faire ça plus joli, qu'on comprenne bien ») — en-tête bureau sur UNE ligne :
// logo · 4 liens au centre (+ « Plus » : PawPoints, Contact) · langue · Se connecter · Devenir gardien (contour) ·
// Publier ma demande (seul bouton plein). Sous 1240 px : logo · langue · bouton principal · menu (rien ne se coupe).
const MORE: Record<string, string> = { fr: "Plus", en: "More", es: "Más", de: "Mehr", it: "Altro", pt: "Mais", ko: "더보기", ja: "その他", pl: "Więcej" };
// 1011 (ZOE point 8) — sur la page d'arrivée de la pub (/demande, /request), « Publier » faisait QUITTER la page
// vers /garde-animaux/paris alors que le formulaire est sous les yeux. Il ramène maintenant au formulaire.
export const AD_PAGES_1011 = ["/demande", "/request"];
export function stayOnForm1011(e: { preventDefault: () => void }) {
  e.preventDefault();
  try {
    const el = document.getElementById("publier") || document.querySelector("[data-testid^='demande-']");
    if (el) (el as HTMLElement).scrollIntoView({ behavior: "smooth", block: "start" });
    else window.scrollTo({ top: 0, behavior: "smooth" });
  } catch { /* rien */ }
}
function UserIcon({ size = 18 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4.5 20.5c0-3.6 3.4-6 7.5-6s7.5 2.4 7.5 6" />
    </svg>
  );
}
const NAV_TXT = "text-[#6E4F48]"; // brun chaud plein (contraste 7,5:1 sur blanc) — jamais une encre à opacité réduite (= gris)

export function Header() {
  const { t, lang } = useT();
  const router = useRouter();
  const pathname = usePathname();
  const { user, ready } = useAuth();
  const onAdPage1011 = AD_PAGES_1011.includes((pathname || "").replace(/\/$/, ""));
  const [open, setOpen] = useState(false);

  const links = [
    { href: "/how-it-works", label: t("nav_how") },
    { href: "/pricing",      label: t("nav_pricing") },
    // 25/09 (PawMap 584, point 11) — connecté, « PawMap » = MA PawMap (/map :
    // mes amis, les membres autour de moi, mes demandes, mon rond « Moi »).
    // Sans compte : la carte publique floutée (/pawmap).
    { href: ready && user ? "/map" : "/pawmap", label: t("nav_pawmap"), also: ["/pawmap", "/map"] },
    // 02/10 (607, Daniel) — onglet PawPoints : page publique (la page membre reste /pawpoints).
    { href: "/pawpoints-guide", label: t("nav_pawpoints") },
    { href: "/faq",          label: t("nav_faq") },
    { href: "/contact",      label: t("nav_contact") },
  ];
  const mainLinks = links.filter((l) => l.href !== "/pawpoints-guide" && l.href !== "/contact");
  const moreLinks = links.filter((l) => l.href === "/pawpoints-guide" || l.href === "/contact");
  const isCurrent = (l: { href: string; also?: string[] }) =>
    pathname === l.href || !!pathname?.startsWith(l.href + "/") || !!l.also?.includes(pathname || "");

  // Menu « Plus » (bureau) : fermé au clic extérieur, à Échap et au changement de page.
  const [moreOpen, setMoreOpen] = useState(false);
  const moreRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!moreOpen) return;
    const onDown = (e: PointerEvent) => { if (!moreRef.current?.contains(e.target as Node)) setMoreOpen(false); };
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") setMoreOpen(false); };
    document.addEventListener("pointerdown", onDown);
    document.addEventListener("keydown", onKey);
    return () => { document.removeEventListener("pointerdown", onDown); document.removeEventListener("keydown", onKey); };
  }, [moreOpen]);
  useEffect(() => { setMoreOpen(false); setOpen(false); }, [pathname]);

  function onLogout() {
    clearAuth();
    setOpen(false);
    router.push("/");
  }

  // Avatar fallback: first letter of the name (or "?" if missing).
  const initial = user?.name?.trim()?.charAt(0)?.toUpperCase() || "?";
  // Tailwind class names that match the safelist in tailwind.config.ts so the
  // role color survives the production purge.
  const roleColor =
    user?.role === "walker" ? "bg-walker"
    : user?.role === "sitter" ? "bg-sitter"
    : "bg-owner";

  return (
    <header className="sticky top-0 z-[1600] border-b border-black/[0.06] bg-white/80 backdrop-blur-xl">
      {/* 08/10 (Daniel) — z-40 laissait le menu des langues SOUS la PawMap (contrôles Leaflet z-1000, feuille z-1500) ; les fenêtres modales restent au-dessus (z-2000+). */}
      {/* v577 — TABLETTE (21/09/2026). Le menu du haut passait en version
          « bureau » des 768 px : a cette largeur exacte, « Comment ca marche »
          et « Se connecter » n'avaient plus la place, se cassaient en trois
          lignes et DEBORDAIENT de la barre (hauteur fixe h-14), par-dessus le
          logo. Mesure : nav 359 px + logo 103 px + boutons 274 px = 736 px pour
          736 px utiles. La version compacte (logo + langue + S'inscrire +
          menu) court donc maintenant jusqu'a 1024 px. */}
      <div className="mx-auto flex h-14 max-w-7xl items-center gap-2 px-3 sm:gap-3 sm:px-4 min-[1240px]:h-16 min-[1240px]:gap-8 min-[1240px]:px-5">
        <Link href="/" className="flex min-h-[44px] shrink-0 items-center" aria-label="HoPetSit">
          <LogoWithText />
        </Link>

        {/* Bureau (≥ 1240 px) : 4 liens au centre + « Plus ». Page courante en orange pâle (v562). */}
        <nav className="hidden min-w-0 flex-1 items-center justify-center gap-1 min-[1240px]:flex" data-entete-3110="nav">
          {mainLinks.map((l) => {
            const current = isCurrent(l);
            return (
              <Link
                key={l.href}
                href={l.href}
                aria-current={current ? "page" : undefined}
                className={`whitespace-nowrap rounded-full px-3 py-2 text-[14px] font-semibold transition ${
                  current ? "bg-owner-light text-owner-dark" : `${NAV_TXT} hover:bg-[#FAF1EC] hover:text-ink`
                }`}
              >
                {l.label}
              </Link>
            );
          })}
          <div ref={moreRef} className="relative">
            <button
              type="button"
              aria-haspopup="menu"
              aria-expanded={moreOpen}
              onClick={() => setMoreOpen((v) => !v)}
              className={`inline-flex items-center gap-1 whitespace-nowrap rounded-full px-3 py-2 text-[14px] font-semibold transition ${
                moreOpen || moreLinks.some(isCurrent) ? "bg-owner-light text-owner-dark" : `${NAV_TXT} hover:bg-[#FAF1EC] hover:text-ink`
              }`}
            >
              {MORE[lang] || MORE.en}
              <svg width="12" height="12" viewBox="0 0 12 12" aria-hidden="true" className={`transition-transform ${moreOpen ? "rotate-180" : ""}`}>
                <path d="M2.5 4.5 6 8l3.5-3.5" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </button>
            {moreOpen && (
              <div role="menu" className="absolute left-1/2 top-full z-50 mt-2 w-52 -translate-x-1/2 overflow-hidden rounded-2xl border border-[#F1DED6] bg-white p-1.5 shadow-card">
                {moreLinks.map((l) => (
                  <Link
                    key={l.href}
                    href={l.href}
                    role="menuitem"
                    onClick={() => setMoreOpen(false)}
                    className={`block whitespace-nowrap rounded-xl px-3 py-2.5 text-[14px] font-semibold ${isCurrent(l) ? "bg-owner-light text-owner-dark" : "text-ink hover:bg-[#FAF1EC]"}`}
                  >
                    {l.label}
                  </Link>
                ))}
              </div>
            )}
          </div>
        </nav>

        <div className="ml-auto flex shrink-0 items-center gap-1.5 sm:gap-2 min-[1240px]:ml-0 min-[1240px]:gap-3" data-entete-3110="actions">
          {/* v458 — Daniel : retirer le bouton « Ouvrir la PawMap » de la
              barre du haut pour l'instant (il reste dans le footer + les pages). */}
          <LangSwitcher />

          {/* 31/10 soir (Daniel via BOB) — « Se connecter » doit se voir et se comprendre : « je me connecte à mon compte ».
              Pilule blanche à contour sombre #1C1917 + icône personne (dès 768 px) ; sur téléphone, l'icône seule,
              toujours visible dans la barre. Connecté : « 👤 <Prénom> » → mon espace. « Devenir gardien » passe en simple lien,
              pour ne jamais avoir deux boutons identiques côte à côte ; « Publier ma demande » reste le seul bouton plein. */}
          {!ready ? (
            <div aria-hidden="true" className="h-10 w-10 min-[1240px]:w-[150px]" />
          ) : user ? (
            <>
              <Link
                href="/dashboard"
                className="hidden items-center gap-2 whitespace-nowrap rounded-full border-[1.5px] border-[#1C1917] bg-white py-[5px] pl-[5px] pr-4 text-[14px] font-bold text-[#1C1917] transition hover:bg-[#FAF1EC] md:inline-flex"
                title={user.email}
                data-entete-3110="compte"
              >
                <span className={`flex h-7 w-7 items-center justify-center rounded-full ${roleColor} text-white`}>
                  <UserIcon size={15} />
                </span>
                <span className="max-w-[140px] truncate">{user.name?.split(" ")[0] || t("nav_dashboard")}</span>
              </Link>
              <button
                type="button"
                onClick={onLogout}
                className={`hidden whitespace-nowrap rounded-full px-2 py-1.5 text-sm font-semibold ${NAV_TXT} hover:text-ink min-[1240px]:inline-block`}
              >
                {t("dash_logout")}
              </button>
              <Link
                href="/dashboard"
                aria-label={user.name?.split(" ")[0] || t("nav_dashboard")}
                className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full ${roleColor} text-white md:hidden`}
                data-entete-3110="compte-icone"
              >
                <UserIcon size={19} />
              </Link>
            </>
          ) : (
            <>
              {/* « Devenir gardien » : simple lien (orange foncé), plus un bouton. */}
              {PUBLISH[lang] && (
                <Link
                  href="/signup"
                  className="hidden whitespace-nowrap px-1.5 py-2 text-[14px] font-semibold text-owner-dark underline-offset-4 transition hover:underline min-[1240px]:inline-block"
                  data-entete-3110="gardien"
                >
                  {PUBLISH[lang]!.become}
                </Link>
              )}
              {/* « Se connecter » : pilule blanche, contour sombre, icône personne. */}
              <Link
                href="/login"
                className="hidden items-center gap-1.5 whitespace-nowrap rounded-full border-[1.5px] border-[#1C1917] bg-white py-[7px] pl-3 pr-4 text-[14px] font-bold text-[#1C1917] transition hover:bg-[#FAF1EC] md:inline-flex"
                data-entete-3110="connexion"
              >
                <UserIcon size={17} />
                {t("nav_login")}
              </Link>
              {/* Téléphone (< 768 px) : l'icône seule, dans la barre (cible 44 px par calque invisible). */}
              <Link
                href="/login"
                aria-label={t("nav_login")}
                title={t("nav_login")}
                className="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-full border-[1.5px] border-[#1C1917] bg-white text-[#1C1917] after:absolute after:-inset-0.5 after:content-[''] md:hidden"
                data-entete-3110="connexion-icone"
              >
                <UserIcon size={19} />
              </Link>
              {/* 31/10 (LEO, décision BOB, étape 3) — bouton principal = « Publier ma demande » (propriétaires d'abord) ;
                  fr/en seulement, les autres langues gardent « S'inscrire ». */}
              <Link
                href={onAdPage1011 ? "#publier" : PUBLISH[lang] ? PUBLISH[lang]!.href : "/signup"}
                onClick={onAdPage1011 ? stayOnForm1011 : undefined}
                /* v585 — pouce : zone de toucher portée à 44 px par un calque invisible. */
                className="relative whitespace-nowrap rounded-full bg-owner px-4 py-1.5 text-[13px] font-semibold text-white shadow-cta transition after:absolute after:inset-x-0 after:-inset-y-1.5 after:content-[''] hover:bg-owner-dark min-[1240px]:px-5 min-[1240px]:py-[9px] min-[1240px]:text-[14px] min-[1240px]:font-bold"
                data-nav-publish-3110={PUBLISH[lang] ? "1" : undefined}
              >
                {PUBLISH[lang] ? (
                  <>
                    <span className="sm:hidden">{PUBLISH[lang]!.short}</span>
                    <span className="hidden sm:inline">{PUBLISH[lang]!.label}</span>
                  </>
                ) : t("nav_signup")}
              </Link>
            </>
          )}

          <button
            type="button"
            /* v583 — pouce : carré de 44 px. Passe 14 : le menu court jusqu'à 1240 px (avant 1024) pour que
               rien ne se coupe entre 1024 et 1240 px. */
            className="flex h-11 w-10 items-center justify-center rounded-xl text-ink min-[1240px]:hidden"
            aria-label="Toggle menu"
            aria-expanded={open}
            onClick={() => setOpen((v) => !v)}
          >
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              {open
                ? <path d="M6 6l12 12M6 18L18 6" />
                : <><path d="M4 6h16" /><path d="M4 12h16" /><path d="M4 18h16" /></>}
            </svg>
          </button>
        </div>
      </div>

      {open && (
        <nav className="border-t border-[#F1DED6] bg-white px-4 py-2 min-[1240px]:hidden">
          {/* v458 — bouton « Ouvrir la PawMap » retiré du menu (barre du haut)
              pour l'instant. */}
          {links.map((l) => {
            const current = isCurrent(l);
            return (
              <Link
                key={l.href}
                href={l.href}
                onClick={() => setOpen(false)}
                className={`block rounded-xl px-3 py-3 text-sm font-medium ${current ? "bg-owner-light text-owner-dark" : "text-ink"}`}
              >
                {l.label}
              </Link>
            );
          })}
          {ready && user ? (
            <>
              <Link
                href="/dashboard"
                onClick={() => setOpen(false)}
                className="flex min-h-[44px] items-center gap-2 px-2 py-2.5 text-sm font-medium text-ink"
              >
                <span
                  className={`flex h-6 w-6 items-center justify-center rounded-full ${roleColor} text-xs font-bold text-white`}
                >
                  {initial}
                </span>
                {user.name?.split(" ")[0] || t("nav_dashboard")}
              </Link>
              <button
                type="button"
                onClick={onLogout}
                className="block w-full px-2 py-3 text-left text-sm font-medium text-ink-muted"
              >
                {t("dash_logout")}
              </button>
            </>
          ) : (
            <>
              {PUBLISH[lang] && (
                <Link href="/signup" onClick={() => setOpen(false)} className="block px-3 py-3 text-sm font-medium text-ink">
                  {PUBLISH[lang]!.become}
                </Link>
              )}
              <Link
                href="/login"
                onClick={() => setOpen(false)}
                className="block px-3 py-3 text-sm font-medium text-ink"
              >
                {t("nav_login")}
              </Link>
            </>
          )}
        </nav>
      )}
    </header>
  );
}
