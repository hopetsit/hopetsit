// 607b (LEO, 01/10/2026) — parité avec l'app : `frontend/lib/utils/booking_date_format.dart`.
// `timeSlot` est un texte libre côté serveur : heures (« 10:00 », « 9:30 AM », ISO)
// ou créneaux NOMMÉS (« allday » par défaut, « All Day » écrit par le site et l'app,
// « morning »…). Avant, le site les affichait bruts (« morning » en anglais partout).
// Libellés STRICTEMENT identiques à ceux de l'app, 9 langues.

const NAMED_SLOTS: Record<string, Record<string, string>> = {
  morning: {
    en: "Morning", fr: "Matin", es: "Mañana", de: "Vormittags",
    it: "Mattina", pt: "Manhã", ko: "오전", ja: "午前", pl: "Rano",
  },
  afternoon: {
    en: "Afternoon", fr: "Après-midi", es: "Tarde", de: "Nachmittags",
    it: "Pomeriggio", pt: "Tarde", ko: "오후", ja: "午後", pl: "Po południu",
  },
  evening: {
    en: "Evening", fr: "Soir", es: "Tarde-noche", de: "Abends",
    it: "Sera", pt: "Fim de tarde", ko: "저녁", ja: "夕方", pl: "Wieczorem",
  },
  night: {
    en: "Night", fr: "Nuit", es: "Noche", de: "Nachts",
    it: "Notte", pt: "Noite", ko: "밤", ja: "夜間", pl: "W nocy",
  },
  allday: {
    en: "All day", fr: "Toute la journée", es: "Todo el día", de: "Ganztägig",
    it: "Tutto il giorno", pt: "Dia inteiro", ko: "하루 종일", ja: "終日", pl: "Cały dzień",
  },
  anytime: {
    en: "Any time", fr: "À tout moment", es: "A cualquier hora", de: "Jederzeit",
    it: "A qualsiasi ora", pt: "A qualquer hora", ko: "언제든지", ja: "いつでも", pl: "O dowolnej porze",
  },
  flexible: {
    en: "Flexible", fr: "Horaire flexible", es: "Horario flexible", de: "Flexibel",
    it: "Orario flessibile", pt: "Horário flexível", ko: "시간 협의 가능", ja: "時間応相談", pl: "Elastyczna pora",
  },
};

const SLOT_ALIASES: Record<string, string> = {
  fullday: "allday",
  wholeday: "allday",
  anytimeofday: "anytime",
};

/** Traduction d'un créneau nommé, ou `null` si `raw` n'en est pas un. */
export function namedSlot(raw: string, lang: string): string | null {
  let key = raw.trim().toLowerCase().replace(/[\s_\-]+/g, "");
  key = SLOT_ALIASES[key] ?? key;
  const tr = NAMED_SLOTS[key];
  if (!tr) return null;
  return tr[lang] ?? tr.en;
}

function fmtClock(h: number, m: number, lang: string): string {
  if (lang === "en") {
    const h12 = h % 12 === 0 ? 12 : h % 12;
    return `${h12}:${String(m).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
  }
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
}

/**
 * Créneau d'une réservation dans la langue du site (même logique que
 * `BookingDateFormat.localizedTime` de l'app) : créneau nommé traduit, heure
 * en 12 h pour l'anglais et 24 h pour les autres langues, sinon texte brut.
 */
export function localizedTimeSlot(raw: string | null | undefined, lang: string): string {
  if (!raw) return "";
  const named = namedSlot(raw, lang);
  if (named) return named;
  if (raw.includes("T")) {
    const dt = new Date(raw);
    if (!Number.isNaN(dt.getTime())) return fmtClock(dt.getHours(), dt.getMinutes(), lang);
  }
  const m = /^(\d{1,2}):(\d{2})\s*(AM|PM)?$/i.exec(raw.trim());
  if (m) {
    let h = parseInt(m[1], 10);
    const mm = parseInt(m[2], 10);
    const ampm = m[3]?.toUpperCase();
    if (ampm === "PM" && h < 12) h += 12;
    if (ampm === "AM" && h === 12) h = 0;
    if (h < 24 && mm < 60) return fmtClock(h, mm, lang);
  }
  return raw;
}
