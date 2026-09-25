"use client";

// v587 (point 8 de Daniel) — choix du LIEU du service, identique à l'app :
//   garde : Chez moi / Chez le gardien · promenade : Récupérer chez moi /
//   Point de rendez-vous (+ adresse) · visites : chez moi, fixé.
// Utilisé par /posts/create et /book. Icônes maison (AppIcon), encre chaude,
// sélection à la couleur du service (jamais de gris).
import { AppIcon, type AppIconName } from "@/components/AppIcon";
import type { Lang } from "@/lib/i18n/translations";
import {
  OPTION_KEYS,
  locationFamily,
  locationOptions,
  locationTitleKey,
  p587,
  type ServiceLocation,
} from "@/lib/i18n/publish587";

const ICONS: Record<ServiceLocation, AppIconName> = {
  at_owner: "home",
  at_sitter: "paw",
  both: "check",
  pickup: "route",
  meeting_point: "pin",
};

export default function ServiceLocationPicker587({
  lang,
  service,
  value,
  meetingPoint,
  onChange,
  onMeetingPoint,
  accent,
  dark,
  pale,
}: {
  lang: Lang;
  service: string | null | undefined;
  value: string;
  meetingPoint: string;
  onChange: (v: ServiceLocation) => void;
  onMeetingPoint: (v: string) => void;
  accent: string;
  dark: string;
  pale: string;
}) {
  const family = locationFamily(service);
  if (!family) return null;
  const options = locationOptions(service, value);
  const t = (k: string) => p587(lang, k);

  const tile = (o: ServiceLocation, fixed = false) => {
    const selected = fixed || value === o;
    const label = fixed ? t("svc587_visit_fixed") : t(OPTION_KEYS[o].label);
    const sub = fixed || !OPTION_KEYS[o].sub ? "" : t(OPTION_KEYS[o].sub);
    return (
      <button
        key={o}
        type="button"
        disabled={fixed}
        aria-pressed={selected}
        data-testid={`svc587-opt-${o}`}
        onClick={() => !fixed && onChange(o)}
        className="flex w-full items-center gap-3 rounded-[14px] border-[1.5px] px-3 py-2.5 text-left transition max-lg:min-h-[52px] disabled:cursor-default"
        style={selected ? { background: pale, borderColor: accent } : { background: "#FFFDFB", borderColor: "#EAD6CB" }}
      >
        <span
          className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[11px]"
          style={{ background: selected ? accent : pale }}
        >
          <AppIcon name={ICONS[o]} size={19} color={selected ? "#FFFFFF" : dark} />
        </span>
        <span className="min-w-0 flex-1">
          <span className="block text-sm font-bold" style={{ color: selected ? dark : "#231715" }}>{label}</span>
          {sub && <span className="block text-xs text-[#6E4F48]">{sub}</span>}
        </span>
        {selected && !fixed && (
          <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full" style={{ background: accent }}>
            <AppIcon name="check" size={13} color="#FFFFFF" />
          </span>
        )}
      </button>
    );
  };

  return (
    <div data-testid="svc587-picker">
      <p className="block text-sm font-medium text-ink">{t(locationTitleKey(service))} *</p>
      <div className="mt-2 grid gap-2 sm:grid-cols-2">
        {family === "visit" ? tile("at_owner", true) : options.map((o) => tile(o))}
      </div>
      {family === "walk" && value === "meeting_point" && (
        <div className="relative mt-2">
          <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2">
            <AppIcon name="pin" size={17} color={dark} />
          </span>
          <input
            data-testid="svc587-meeting"
            value={meetingPoint}
            onChange={(e) => onMeetingPoint(e.target.value)}
            maxLength={200}
            placeholder={t("svc587_meeting_hint")}
            className="w-full rounded-xl border bg-bg-soft py-2.5 pl-9 pr-3.5 text-sm text-ink focus:outline-none"
            style={{ borderColor: meetingPoint.trim() ? "#EAD6CB" : accent }}
          />
        </div>
      )}
    </div>
  );
}
