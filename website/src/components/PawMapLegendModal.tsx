"use client";

// 24/09/2026 — LOT B : le bouton « ? » de la carte ouvre CETTE légende en
// images (9 langues). Les dessins sont ceux des épingles réelles
// (lib/pawmapLegend.ts) : ce ne sont pas des copies qui pourraient diverger.
// Mémo : rond = personne · goutte = lieu · carré = groupe de lieux ·
// noir et or = PawSpot · rose = ami.

import { useEffect } from "react";
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
import { AppIcon } from "@/components/AppIcon";

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

export function PawMapLegendModal({ open, onClose, role = "owner" }: { open: boolean; onClose: () => void; role?: "owner" | "sitter" | "walker" }) {
  const { t } = useT();
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);
  if (!open) return null;

  const rows: { html: string; title: string; body?: string; color?: string }[] = [
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
    // 25/09 (586) — les contrôles de la carte discrète.
    { html: handleHtml(ROLE_COLOR[role]), title: t("m586_leg_handle_t"), body: t("m586_leg_handle_b") },
    { html: roundHtml("linear-gradient(165deg,#E0553F,#C92A12 55%,#A31F0C)", MEGAPHONE, "#C92A12"), title: t("m586_leg_publish_t"), body: t("m586_leg_publish_b"), color: ROLE_COLOR.owner },
    { html: `<span style="display:flex;gap:4px">${roundHtml("linear-gradient(165deg,#2C2533,#17141F)", LIVE, "rgba(23,20,31,0.7)", 30)}${roundHtml("linear-gradient(165deg,#34B857,#16A34A)", LIVE, "#16A34A", 30)}</span>`, title: t("m586_leg_live_t"), body: t("m587_leg_live_b"), color: "#17141F" },
    { html: `<span style="display:flex;gap:4px">${barTabHtml("left")}${barTabHtml("right")}</span>`, title: t("m587_leg_bars_t"), body: t("m587_leg_bars_b"), color: "#17141F" },
    { html: eyesHtml(), title: t("m586_leg_eye_t"), body: t("m586_leg_eye_b"), color: "#17141F" },
    { html: seeChipsHtml(), title: t("m586_leg_see_t"), body: t("m586_leg_see_b") },
  ];

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
        className="max-h-[88vh] w-full max-w-lg overflow-y-auto rounded-t-[28px] bg-white p-5 shadow-2xl sm:rounded-[28px] sm:p-7"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 id="pawmap-legend-title" className="font-display text-xl font-bold tracking-[-0.02em] text-[#231715]">
              {t("legend_title")}
            </h2>
            <p className="mt-1 text-sm text-[#6E4F48]">{t("legend_intro")}</p>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label={t("map_close")}
            className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-[#FAF1EC] text-[#231715] transition hover:bg-[#F0E3DF]"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round"><path d="M6 6l12 12M6 18L18 6" /></svg>
          </button>
        </div>

        <p className="mt-4 rounded-2xl bg-[#FAF1EC] px-4 py-3 text-sm font-semibold text-[#231715]">{t("legend_memo")}</p>

        <ul className="mt-4 space-y-2">
          {rows.map((r) => (
            <li key={r.title} className="flex items-center gap-4 rounded-2xl px-2 py-2">
              <span className="grid h-16 w-16 shrink-0 place-items-center" dangerouslySetInnerHTML={{ __html: r.html }} />
              <span className="min-w-0">
                <span className="block text-sm font-bold" style={{ color: r.color || "#231715" }}>{r.title}</span>
                {r.body && <span className="block text-xs leading-snug text-[#6E4F48]">{r.body}</span>}
              </span>
            </li>
          ))}
        </ul>

        <button
          type="button"
          onClick={onClose}
          className="mt-5 inline-flex min-h-[48px] w-full items-center justify-center gap-2 rounded-[18px] bg-[#231715] px-5 text-sm font-semibold text-white transition hover:bg-black"
        >
          <AppIcon name="check" size={18} />
          {t("legend_close")}
        </button>
      </div>
    </div>
  );
}

export default PawMapLegendModal;
