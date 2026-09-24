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

export function PawMapLegendModal({ open, onClose }: { open: boolean; onClose: () => void }) {
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
    { html: memberClusterHtml(4), title: t("legend_member_group"), body: t("legend_member_group_body") },
    { html: requestBubbleHtml({ service: "sitting", priceLabel: "25 €" }), title: t("legend_request"), body: t("legend_request_body"), color: ROLE_COLOR.owner },
    { html: placePinHtml("vet"), title: t("legend_place"), body: t("legend_place_body") },
    { html: placeClusterHtml(6, "park"), title: t("legend_place_group"), body: t("legend_place_group_body") },
    { html: spotPinHtml("path_walk", false), title: t("legend_spot"), body: t("legend_spot_body") },
    { html: spotPinHtml("path_walk", true), title: t("legend_spot_gold"), body: t("legend_spot_gold_body"), color: PREMIUM_GOLD },
    { html: spotClusterHtml(3), title: t("legend_spot_group") },
    { html: reportPinHtml(), title: t("legend_report"), body: t("legend_report_body") },
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
