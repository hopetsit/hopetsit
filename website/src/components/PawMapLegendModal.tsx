"use client";

// 24/09/2026 — LOT B : le bouton « ? » de la carte ouvre CETTE légende en
// images (9 langues). Les dessins sont ceux des épingles réelles
// (lib/pawmapLegend.ts) : ce ne sont pas des copies qui pourraient diverger.
// Mémo : rond = personne · goutte = lieu · carré = groupe de lieux ·
// noir et or = PawSpot · rose = ami.
// 25/09 (587, point 10) — plus explicative : sections Se repérer · Voir qui est
// autour · Être visible / en direct · Agir · Réglages ; pour chaque bouton, à
// quoi il sert, pourquoi, le geste exact (clés h587_*, lib/i18n/help587.ts,
// mêmes textes que l'app) ; un exemple par section ; une FAQ.

import { useEffect, type ReactNode } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  memberPinHtml,
  photoPinHtml,
  memberClusterHtml,
  placePinHtml,
  placeClusterHtml,
  spotPinHtml,
  spotClusterHtml,
  reportPinHtml,
  requestBubbleHtml,
  PAWMAP_KEYFRAMES,
  ROLE_COLOR,
  PAWBOOST_TURQUOISE,
  PAWFOLLOW_VIOLET,
  PREMIUM_GOLD,
  FRIEND_PINK,
} from "@/lib/pawmapLegend";
import { AppIcon, type AppIconName } from "@/components/AppIcon";

// 25/09 (586) — dessins des nouveaux contrôles de la carte (poignée, Publier,
// Direct, œil), mêmes couleurs que sur /map.
const PAW_PATH = "M12 13.2c-2.6 0-4.8 2.5-4.8 4.5 0 1.3 1 2.1 2.3 2.1 1 0 1.7-.5 2.5-.5s1.5.5 2.5.5c1.3 0 2.3-.8 2.3-2.1 0-2-2.2-4.5-4.8-4.5zM6.2 12.4a2 2.4 0 1 0 0-4.8 2 2.4 0 0 0 0 4.8zM17.8 12.4a2 2.4 0 1 0 0-4.8 2 2.4 0 0 0 0 4.8zM9.6 8.6a2.1 2.6 0 1 0 0-5.2 2.1 2.6 0 0 0 0 5.2zM14.4 8.6a2.1 2.6 0 1 0 0-5.2 2.1 2.6 0 0 0 0 5.2z";
function handleHtml(color: string) {
  return `<span style="display:inline-flex;align-items:center;gap:4px;height:26px;padding:0 9px;border-radius:999px;background:linear-gradient(180deg,#FFFCF8,#FFF3EA);border:1px solid #fff;box-shadow:0 6px 14px -6px ${color}"><svg viewBox="0 0 24 24" width="14" height="14" fill="${color}"><path d="${PAW_PATH}"/></svg><svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="${color}" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6 15l6-6 6 6"/></svg></span>`;
}
function roundHtml(bg: string, inner: string, shadow: string, size = 40) {
  return `<span style="display:grid;place-items:center;width:${size}px;height:${size}px;border-radius:999px;background:${bg};border:1.5px solid #fff;box-shadow:0 6px 14px -6px ${shadow}">${inner}</span>`;
}
const MEGAPHONE = '<svg viewBox="0 0 24 24" width="19" height="19" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 10v4h3l7 4V6l-7 4zM17 9a4 4 0 0 1 0 6M19.5 7a7.5 7.5 0 0 1 0 10"/></svg>';
const LIVE = '<svg viewBox="0 0 24 24" width="19" height="19" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round"><circle cx="12" cy="12" r="2.6" fill="#fff" stroke="none"/><path d="M8.2 8.2a5.4 5.4 0 0 0 0 7.6M15.8 8.2a5.4 5.4 0 0 1 0 7.6M5.3 5.3a9.5 9.5 0 0 0 0 13.4M18.7 5.3a9.5 9.5 0 0 1 0 13.4"/></svg>';
function eyesHtml() {
  const eye = '<path d="M2.4 12C3.4 9.4 7 5.2 12 5.2s8.6 4.2 9.6 6.8c-1 2.6-4.6 6.8-9.6 6.8S3.4 14.6 2.4 12z"/><circle cx="12" cy="12" r="3"/>';
  const svg = (inner: string) => `<svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="#17141F" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${inner}</svg>`;
  return `<span style="display:flex;flex-direction:column;align-items:center;gap:3px">${svg(eye)}${svg(eye + '<path d="M18.2 14.6c-.9-.9-2.4-.3-2.4.9 0 1.5 2.4 3 2.4 3s2.4-1.5 2.4-3c0-1.2-1.5-1.8-2.4-.9z" fill="#F06AA0" stroke="#fff" stroke-width="1.2"/>')}${svg('<path d="M3 3l18 18M10.6 5.3c.5-.1.9-.1 1.4-.1 5 0 8.6 4.2 9.6 6.8-.4 1-1.2 2.3-2.4 3.5M6.6 6.6C4.3 8.1 2.9 10.4 2.4 12c1 2.6 4.6 6.8 9.6 6.8 1.7 0 3.2-.4 4.5-1.1M9.9 9.9a3 3 0 0 0 4.2 4.2"/>')}</span>`;
}

/** 587 (point 3) — languette des barres repliables (verre chaud + chevron). */
function barTabHtml(side: "left" | "right") {
  const d = side === "left" ? "M14 7l-5 5 5 5" : "M10 7l5 5-5 5";
  return `<span style="display:grid;place-items:center;width:22px;height:38px;border-radius:12px;background:linear-gradient(180deg,#FFFBF7,#FFF2E8);border:1px solid #fff;box-shadow:0 6px 14px -8px rgba(146,64,14,.55)"><svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#3B2A26" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="${d}"/></svg></span>`;
}

function seeChipsHtml() {
  const dot = (bg: string, ring = "#fff") => `<span style="width:14px;height:14px;border-radius:5px;background:${bg};border:1.5px solid ${ring}"></span>`;
  return `<span style="display:grid;grid-template-columns:repeat(4,14px);gap:3px">${["#F06AA0", "#C92A12", "#2563EB", "#16A34A", "#0E7490", "#17141F", "#D32F2F", "#C92A12"].map((c, i) => dot(c, i === 5 ? "#F4C04A" : "#fff")).join("")}</span>`;
}


// 25/09 (587, point 10) — icônes du rail, copie des `RAIL_SVG` de /map (eux-mêmes
// identiques à l'app) : la légende montre EXACTEMENT les boutons de la carte.
const RAIL_ICON = {
  around: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 22s-7.5-6.5-7.5-12A7.5 7.5 0 0 1 19.5 10c0 5.5-7.5 12-7.5 12z"/><g fill="rgba(0,0,0,.34)"><circle cx="10.2" cy="7.2" r="1.1"/><circle cx="13.8" cy="7.2" r="1.1"/><circle cx="8.4" cy="9.4" r="1"/><circle cx="15.6" cy="9.4" r="1"/><path d="M12 9.3c-1.7 0-3.3 1.6-3.3 3.1 0 .9.8 1.7 1.7 1.7.6 0 1.1-.3 1.6-.3s1 .3 1.6.3c.9 0 1.7-.8 1.7-1.7 0-1.5-1.6-3.1-3.3-3.1z"/></g></svg>',
  route: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 18c0-5 3-6 6-6s6-1 6-6" stroke-dasharray="3 2.6"/><circle cx="6" cy="18" r="2.6" fill="#FFFFFF" stroke="none"/><path d="M18 2.5c-1.8 0-3.2 1.4-3.2 3.2 0 2.2 3.2 5.3 3.2 5.3s3.2-3.1 3.2-5.3c0-1.8-1.4-3.2-3.2-3.2z" fill="#FFFFFF" stroke="none"/></svg>',
  chat: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 3C6.9 3 3 6.3 3 10.4c0 2 1 3.9 2.6 5.2L4.8 20l4.6-1.9c.8.2 1.7.3 2.6.3 5.1 0 9-3.3 9-7.4S17.1 3 12 3z"/><g fill="rgba(0,0,0,.34)"><circle cx="8.6" cy="10.6" r="1.1"/><circle cx="12" cy="10.6" r="1.1"/><circle cx="15.4" cy="10.6" r="1.1"/></g></svg>',
  photo: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M9 4h6l1.4 2.2H20a1.6 1.6 0 0 1 1.6 1.6V18A1.6 1.6 0 0 1 20 19.6H4A1.6 1.6 0 0 1 2.4 18V7.8A1.6 1.6 0 0 1 4 6.2h3.6z"/><circle cx="12" cy="12.8" r="3.6" fill="rgba(0,0,0,.34)"/></svg>',
  spot: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 22s-7.5-6.5-7.5-12A7.5 7.5 0 0 1 19.5 10c0 5.5-7.5 12-7.5 12z"/><path d="M12 5.4l1.4 2.9 3.1.4-2.3 2.2.6 3.1L12 12.5 9.2 14l.6-3.1-2.3-2.2 3.1-.4z" fill="rgba(0,0,0,.34)"/></svg>',
  add: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 22s-7.5-6.5-7.5-12A7.5 7.5 0 0 1 19.5 10c0 5.5-7.5 12-7.5 12z"/><path d="M10.9 6h2.2v2.9H16v2.2h-2.9V14h-2.2v-2.9H8V8.9h2.9z" fill="rgba(0,0,0,.34)"/></svg>',
  report: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 2.8 22.6 21H1.4z"/><path d="M10.9 9h2.2v6h-2.2zM10.9 16.5h2.2v2.2h-2.2z" fill="rgba(0,0,0,.4)"/></svg>',
  feed: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M5 2.5h2.2V21.5H5z"/><path d="M7.2 3.5h11.3l-2.4 4.5 2.4 4.5H7.2z"/><circle cx="18.5" cy="5" r="3.6" fill="#E24834" stroke="#fff" stroke-width="1.4"/></svg>',
} as const;
function railHtml(k: keyof typeof RAIL_ICON, g1: string, g2: string) {
  return `<span style="display:grid;place-items:center;width:40px;height:40px;border-radius:999px;background:linear-gradient(165deg,${g1},${g2});border:1.5px solid #fff;box-shadow:0 6px 14px -6px ${g2}"><span style="display:block;width:20px;height:20px">${RAIL_ICON[k].replace("<svg ", '<svg width="20" height="20" ')}</span></span>`;
}

/** Pastille ronde d'icône (même dessin que la capsule de /map). */
function RoundIcon({ name, color, filled = false }: { name: AppIconName; color: string; filled?: boolean }) {
  return (
    <span
      className="grid h-10 w-10 place-items-center rounded-full"
      style={filled
        ? { background: `linear-gradient(165deg,${color},${color})`, border: "1.5px solid #fff", boxShadow: `0 6px 14px -6px ${color}` }
        : { background: `${color}24`, border: `1px solid ${color}73` }}
    >
      <AppIcon name={name} size={20} color={filled ? "#fff" : color} />
    </span>
  );
}

type Row = { html?: string; node?: ReactNode; title: string; body?: string; color?: string };
type Section = { id: string; title: string; rows: Row[]; example?: string };

/**
 * `role` absent = la petite carte publique (accueil, /pawmap) : seulement les
 * épingles et la FAQ, ses autres boutons n'existent pas là. Avec `role` (la
 * vraie /map) : tous les boutons, par section, SEULEMENT ceux du rôle (Direct =
 * gardien / promeneur, Publier = propriétaire), comme sur la carte.
 */
export function PawMapLegendModal({ open, onClose, role }: { open: boolean; onClose: () => void; role?: "owner" | "sitter" | "walker" }) {
  const { t } = useT();
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);
  if (!open) return null;

  const full = role !== undefined;
  const roleK = role ?? "owner";
  const provider = roleK === "sitter" || roleK === "walker";
  const visExplained = [
    `${t("v587_all_t")} — ${t("v587_all_d")}`,
    `${t("v587_friends_t")} — ${t("v587_friends_d")}`,
    `${t("v587_hidden_t")} — ${t("v587_hidden_d")}`,
    t("v587_live"),
    t("v587_where"),
  ].join("\n");

  const pins: Row[] = [
    { html: photoPinHtml({ role: "owner", name: "Moi", me: true, meLabel: t("legend_me_label") }), title: t("legend_me"), body: t("legend_me_body"), color: ROLE_COLOR.owner },
    { html: photoPinHtml({ role: "sitter", name: "Léa Martin", online: true }), title: t("legend_friend"), body: t("legend_friend_body"), color: FRIEND_PINK },
    { html: memberPinHtml({ role: "owner" }), title: t("legend_member_owner"), body: t("legend_member_owner_body"), color: ROLE_COLOR.owner },
    { html: memberPinHtml({ role: "sitter" }), title: t("legend_member_sitter"), body: t("legend_member_sitter_body"), color: ROLE_COLOR.sitter },
    { html: memberPinHtml({ role: "walker" }), title: t("legend_member_walker"), body: t("legend_member_walker_body"), color: ROLE_COLOR.walker },
    { html: memberPinHtml({ role: "sitter", premium: true }), title: t("legend_premium"), body: t("legend_premium_body"), color: PREMIUM_GOLD },
    { html: memberPinHtml({ role: "walker", boosted: true }), title: t("legend_boost"), body: t("legend_boost_body"), color: PAWBOOST_TURQUOISE },
    { html: memberPinHtml({ role: "walker", pawFollow: true }), title: t("legend_follow"), body: t("legend_follow_body"), color: PAWFOLLOW_VIOLET },
    { html: memberClusterHtml(4, "sitter"), title: t("legend_member_group"), body: t("legend_member_group_body"), color: ROLE_COLOR.sitter },
    { html: memberClusterHtml(3, "walker", true), title: t("legend_member_group_friend"), body: t("legend_member_group_friend_body"), color: FRIEND_PINK },
    { html: requestBubbleHtml({ service: "sitting", priceLabel: "25 €" }), title: t("legend_request"), body: t("legend_request_body"), color: ROLE_COLOR.owner },
    { html: placePinHtml("vet"), title: t("legend_place"), body: t("legend_place_body") },
    { html: placeClusterHtml(6, "park"), title: t("legend_place_group"), body: t("legend_place_group_body") },
    { html: spotPinHtml("path_walk", false), title: t("legend_spot"), body: t("legend_spot_body") },
    { html: spotPinHtml("path_walk", true), title: t("legend_spot_gold"), body: t("legend_spot_gold_body"), color: PREMIUM_GOLD },
    { html: spotClusterHtml(3), title: t("legend_spot_group") },
    { html: reportPinHtml(), title: t("legend_report"), body: t("legend_report_body") },
  ];
  const roleColor = ROLE_COLOR[roleK];

  const sections: Section[] = full
    ? [
        {
          id: "find", title: t("h587_sec_find"), example: t("h587_ex_find"),
          rows: [
            { node: <RoundIcon name="pin" color="#C92A12" />, title: t("h587_t_pins"), body: t("h587_b_pins") },
            ...pins,
            { node: <RoundIcon name="locate" color={roleColor} filled />, title: t("map_locate_btn"), body: t("h587_b_locate"), color: roleColor },
            { node: <span className="grid h-10 w-10 place-items-center rounded-full border border-[#17141F]/40 bg-[#17141F]/10 text-base font-extrabold leading-none text-[#17141F] dark:text-[#FBEFE6]">±</span>, title: t("h587_t_zoom"), body: t("h587_b_zoom") },
            { node: <RoundIcon name="globe" color="#C92A12" />, title: t("h587_t_sat"), body: t("h587_b_sat") },
            { node: <RoundIcon name="search" color="#2563EB" />, title: t("h587_t_search"), body: t("h587_b_search") },
            { html: railHtml("around", "#A076FF", "#7040D6"), title: t("map_around_title"), body: t("h587_b_around") },
            { html: railHtml("route", "#3DBF6C", "#188A42"), title: t("map_directions_btn"), body: t("h587_b_directions") },
            { node: <RoundIcon name="map" color="#2563EB" />, title: t("h587_t_fade"), body: t("h587_b_fade") },
          ],
        },
        {
          id: "see", title: t("h587_sec_see"), example: t("h587_ex_see"),
          rows: [
            { html: seeChipsHtml(), title: t("m586_see_title"), body: t("h587_b_see") },
            { node: <RoundIcon name="friends" color={FRIEND_PINK} />, title: t("map_live_friends"), body: t("h587_b_live_friends"), color: FRIEND_PINK },
            { node: <RoundIcon name="people" color="#17141F" />, title: t("map_members_show"), body: t("h587_b_members") },
            { node: <RoundIcon name="friends" color={FRIEND_PINK} filled />, title: t("map_friends_btn"), body: t("h587_b_friends"), color: FRIEND_PINK },
            { html: railHtml("spot", "#FAC346", "#E2981A"), title: t("map_panel_spots_title"), body: t("h587_b_spots") },
            { html: railHtml("feed", "#6B5A50", "#2E231D"), title: t("map_panel_reports_title"), body: t("h587_b_feed") },
          ],
        },
        {
          id: "live", title: t("h587_sec_live"), example: provider ? t("h587_ex_live_walker") : t("h587_ex_live_owner"),
          rows: [
            { html: eyesHtml(), title: t("m586_leg_eye_t"), body: t("h587_b_eye"), color: "#17141F" },
            // 587 — Daniel : les 3 réglages en clair, mêmes phrases que le réglage (vis587).
            { html: eyesHtml(), title: t("v587_title"), body: visExplained, color: "#17141F" },
            ...(provider
              ? [{ html: `<span style="display:flex;gap:4px">${roundHtml("linear-gradient(165deg,#2C2533,#17141F)", LIVE, "rgba(23,20,31,0.7)", 30)}${roundHtml("linear-gradient(165deg,#34B857,#16A34A)", LIVE, "#16A34A", 30)}</span>`, title: t("m586_live"), body: t("h587_b_direct"), color: "#17141F" }]
              : []),
          ],
        },
        {
          id: "act", title: t("h587_sec_act"), example: t("h587_ex_act"),
          rows: [
            ...(!provider
              ? [{ html: roundHtml("linear-gradient(165deg,#E0553F,#C92A12 55%,#A31F0C)", MEGAPHONE, "#C92A12"), title: t("m586_publish"), body: t("h587_b_publish"), color: ROLE_COLOR.owner }]
              : []),
            { html: railHtml("chat", "#5B9DFF", "#2358D6"), title: t("dash_card_messages_title"), body: t("h587_b_chat") },
            { html: railHtml("photo", "#FFB067", "#E07A12"), title: t("map_spot_photo_label"), body: t("h587_b_photo") },
            { html: railHtml("add", "#48C8BA", "#18968A"), title: t("map_tag_spot_cta"), body: t("h587_b_tag") },
            { html: railHtml("report", "#FF6E5C", "#D63A28"), title: t("map_report_cta"), body: t("h587_b_report") },
          ],
        },
        {
          id: "set", title: t("h587_sec_set"), example: t("h587_ex_set"),
          rows: [
            { html: handleHtml(roleColor), title: t("m586_leg_handle_t"), body: t("h587_b_handle") },
            { html: `<span style="display:flex;gap:4px">${barTabHtml("left")}${barTabHtml("right")}</span>`, title: t("m587_leg_bars_t"), body: t("m587_leg_bars_b"), color: "#17141F" },
            { node: <RoundIcon name="moon" color="#17141F" />, title: t("map_dark_mode"), body: t("h587_b_night") },
            { node: <RoundIcon name="crown" color="#7C3AED" />, title: t("map_subs_title"), body: t("h587_b_subs"), color: "#7C3AED" },
          ],
        },
      ]
    : [{ id: "find", title: t("h587_sec_find"), rows: [{ node: <RoundIcon name="pin" color="#C92A12" />, title: t("h587_t_pins"), body: t("h587_b_pins") }, ...pins] }];

  // 587 — « Qui voit ma position ? » = les phrases du réglage, mot pour mot.
  const faq = [1, 2, 3, 4].map((n) => ({ q: t(`h587_q${n}`), a: n === 2 ? visExplained : t(`h587_a${n}`) }));

  return (
    <div
      className="fixed inset-0 z-[3000] flex items-end justify-center bg-[#231715]/55 p-0 sm:items-center sm:p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="pawmap-legend-title"
      onClick={onClose}
    >
      <style dangerouslySetInnerHTML={{ __html: PAWMAP_KEYFRAMES }} />
      <div
        className="max-h-[88vh] w-full max-w-lg overflow-y-auto rounded-t-[28px] bg-white p-4 shadow-2xl sm:rounded-[28px] sm:p-7 dark:bg-[#241916]"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <h2 id="pawmap-legend-title" className="font-display text-xl font-bold tracking-[-0.02em] text-[#231715] dark:text-[#FBEFE6]">
              {t("legend_title")}
            </h2>
            <p className="mt-1 text-sm text-[#3B2A26] dark:text-[#EBDDD6]">{full ? t("h587_intro") : t("legend_intro")}</p>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label={t("map_close")}
            className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-[#FAF1EC] text-[#231715] transition hover:bg-[#F0E3DF] dark:bg-[#3A2A25] dark:text-[#FBEFE6]"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round"><path d="M6 6l12 12M6 18L18 6" /></svg>
          </button>
        </div>

        <p className="mt-4 rounded-2xl bg-[#17141F] px-4 py-3 text-sm font-semibold text-[#F4C04A]">{t("legend_memo")}</p>

        {sections.map((sec) => (
          <section key={sec.id} aria-labelledby={`legend-sec-${sec.id}`} className="mt-6">
            <h3 id={`legend-sec-${sec.id}`} className="flex items-center gap-2 font-display text-lg font-bold text-[#231715] dark:text-[#FBEFE6]">
              <span aria-hidden="true" className="block h-5 w-1 shrink-0 rounded-full bg-[#C92A12]" />
              <span className="min-w-0">{sec.title}</span>
            </h3>
            <ul className="mt-2 space-y-1.5">
              {sec.rows.map((r, i) => (
                <li key={`${sec.id}-${i}`} className="flex items-start gap-3 rounded-2xl px-1 py-2 sm:gap-4 sm:px-2">
                  {r.node
                    ? <span className="grid h-14 w-14 shrink-0 place-items-center">{r.node}</span>
                    : <span className="grid h-14 w-14 shrink-0 place-items-center sm:h-16 sm:w-16" dangerouslySetInnerHTML={{ __html: r.html || "" }} />}
                  <span className="min-w-0 flex-1 pt-1">
                    <span className="block break-words text-sm font-bold dark:!text-[#FBEFE6]" style={{ color: r.color || "#231715" }}>{r.title}</span>
                    {r.body && <span className="mt-0.5 block whitespace-pre-line break-words text-[13px] leading-snug text-[#3B2A26] dark:text-[#EBDDD6]">{r.body}</span>}
                  </span>
                </li>
              ))}
            </ul>
            {sec.example && (
              <p className="mt-2 flex items-start gap-2.5 rounded-2xl border border-[#E8920A]/45 bg-[#FCEDE4] px-3.5 py-3 text-[13px] leading-snug text-[#3B2A26] dark:bg-[#2E201C] dark:text-[#EBDDD6]">
                <span aria-hidden="true" className="shrink-0 text-base leading-none">💡</span>
                <span className="min-w-0 break-words"><strong className="font-extrabold text-[#C92A12] dark:text-[#FF9A85]">{t("h587_ex_label")} · </strong>{sec.example}</span>
              </p>
            )}
          </section>
        ))}

        <section aria-labelledby="legend-faq" className="mt-6">
          <h3 id="legend-faq" className="flex items-center gap-2 font-display text-lg font-bold text-[#231715] dark:text-[#FBEFE6]">
            <span aria-hidden="true" className="block h-5 w-1 shrink-0 rounded-full bg-[#C92A12]" />
            <span className="min-w-0">{t("h587_faq_title")}</span>
          </h3>
          <div className="mt-2 space-y-2">
            {faq.map((f) => (
              <details key={f.q} className="group rounded-2xl border border-[#C92A12]/25 bg-white px-3.5 py-3 dark:bg-[#2E201C]" open={full}>
                <summary className="cursor-pointer list-none break-words text-sm font-extrabold text-[#231715] dark:text-[#FBEFE6]">{f.q}</summary>
                <p className="mt-1.5 whitespace-pre-line break-words text-[13px] leading-snug text-[#3B2A26] dark:text-[#EBDDD6]">{f.a}</p>
              </details>
            ))}
          </div>
        </section>

        <button
          type="button"
          onClick={onClose}
          className="mt-5 inline-flex min-h-[48px] w-full items-center justify-center gap-2 rounded-[18px] bg-[#231715] px-5 text-sm font-semibold text-white transition hover:bg-black dark:bg-[#C92A12]"
        >
          <AppIcon name="check" size={18} />
          {t("legend_close")}
        </button>
      </div>
    </div>
  );
}

export default PawMapLegendModal;
