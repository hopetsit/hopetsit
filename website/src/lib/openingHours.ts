// v559 — Daniel (option A) : horaires « ouvert / fermé » dans la fiche d'un
// lieu, sans lien sortant. Lecture du sous-ensemble courant de la syntaxe
// OpenStreetMap `opening_hours` (« Mo-Fr 09:00-19:00; Sa 09:00-13:00 »,
// « 24/7 », « Tu-Su 10:00-20:00; Mo off »). Tout ce qui n'est pas compris →
// null : la fiche affiche alors les horaires bruts, jamais un statut faux.
// Même logique que frontend/lib/utils/opening_hours.dart — garder alignés.

export type OpeningHoursStatus = {
  isOpen: boolean;
  always?: boolean;
  closesAt?: Date;
  opensAt?: Date;
};

type Range = { start: number; end: number }; // minutes ; end > 1440 = passe minuit

const DAYS = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];
const DAY_SPEC_RE =
  /^((?:(?:Mo|Tu|We|Th|Fr|Sa|Su)(?:-(?:Mo|Tu|We|Th|Fr|Sa|Su))?)(?:\s*,\s*(?:Mo|Tu|We|Th|Fr|Sa|Su)(?:-(?:Mo|Tu|We|Th|Fr|Sa|Su))?)*)\s*(.*)$/;
const TIME_RANGE_RE = /^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$/;
const RULE_SPLIT_RE = /,\s*(?=(?:Mo|Tu|We|Th|Fr|Sa|Su|PH|SH)\b)/;

function expandDays(spec: string): number[] | null {
  const out = new Set<number>();
  for (const item of spec.split(",")) {
    const t = item.trim();
    if (t.includes("-")) {
      const [a0, b0] = t.split("-");
      const a = DAYS.indexOf(a0.trim());
      const b = DAYS.indexOf(b0.trim());
      if (a < 0 || b < 0) return null;
      let i = a;
      for (;;) {
        out.add(i);
        if (i === b) break;
        i = (i + 1) % 7;
      }
    } else {
      const a = DAYS.indexOf(t);
      if (a < 0) return null;
      out.add(a);
    }
  }
  return [...out].sort((x, y) => x - y);
}

export function evaluateOpeningHours(
  raw: string,
  now: Date = new Date(),
): OpeningHoursStatus | null {
  const text = (raw || "").trim();
  if (!text) return null;
  if (text === "24/7") return { isOpen: true, always: true };

  const week: Range[][] = Array.from({ length: 7 }, () => []);
  let anyRule = false;

  for (const part of text.split(";")) {
    const chunk = part.trim();
    if (!chunk) continue;
    // « Mo-Fr 10:00-18:00, Sa 09:00-15:00 » = deux règles ; « Su,Mo off » = UNE
    // règle sur deux jours : un morceau réduit à des jours est recollé au suivant.
    const pieces = chunk.split(RULE_SPLIT_RE).map((p) => p.trim());
    const rules: string[] = [];
    let pending = "";
    for (const p of pieces) {
      if (!p) continue;
      const only = DAY_SPEC_RE.exec(p);
      if (only && !(only[2] || "").trim()) {
        pending = pending ? `${pending},${p}` : p;
        continue;
      }
      rules.push(pending ? `${pending},${p}` : p);
      pending = "";
    }
    if (pending) rules.push(pending);
    for (const ruleRaw of rules) {
      const rule = ruleRaw.trim();
      if (!rule) continue;
      if (rule.startsWith("PH") || rule.startsWith("SH")) continue;

      let days: number[];
      let rest: string;
      const m = DAY_SPEC_RE.exec(rule);
      if (m && m[1]) {
        const d = expandDays(m[1]);
        if (!d || d.length === 0) return null;
        days = d;
        rest = (m[2] || "").trim();
      } else {
        days = [0, 1, 2, 3, 4, 5, 6];
        rest = rule;
      }

      const lower = rest.toLowerCase();
      if (!rest || lower === "24/7" || lower === "open") {
        for (const d of days) week[d] = [{ start: 0, end: 1440 }];
        anyRule = true;
        continue;
      }
      if (lower === "off" || lower === "closed") {
        for (const d of days) week[d] = [];
        anyRule = true;
        continue;
      }
      const ranges: Range[] = [];
      for (const tr of rest.split(",")) {
        const tm = TIME_RANGE_RE.exec(tr.trim());
        if (!tm) return null;
        const s = Number(tm[1]) * 60 + Number(tm[2]);
        let e = Number(tm[3]) * 60 + Number(tm[4]);
        if (s > 1440 || e > 1440 + 720) return null;
        if (e <= s) e += 1440;
        ranges.push({ start: s, end: e });
      }
      for (const d of days) week[d] = ranges.slice();
      anyRule = true;
    }
  }
  if (!anyRule) return null;

  const today = (now.getDay() + 6) % 7; // Mo = 0
  const nowMin = now.getHours() * 60 + now.getMinutes();
  const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const at = (dayOffset: number, minutes: number) =>
    new Date(midnight.getTime() + (dayOffset * 1440 + minutes) * 60_000);

  for (const r of week[today]) {
    if (r.start <= nowMin && nowMin < r.end) {
      return { isOpen: true, closesAt: at(0, r.end) };
    }
  }
  const yesterday = (today + 6) % 7;
  for (const r of week[yesterday]) {
    if (r.end > 1440 && nowMin < r.end - 1440) {
      return { isOpen: true, closesAt: at(0, r.end - 1440) };
    }
  }
  for (let offset = 0; offset < 8; offset++) {
    const d = (today + offset) % 7;
    const starts = week[d].map((r) => r.start).sort((x, y) => x - y);
    for (const s of starts) {
      if (offset === 0 && s <= nowMin) continue;
      return { isOpen: false, opensAt: at(offset, s) };
    }
  }
  return { isOpen: false };
}
