"use client";

// 24/10/2026 (620, LEO — §B.3) : GRILLE DE TARIFS PAR SERVICE du gardien /
// promeneur sur le tableau de bord web. Mêmes champs que l'app et le serveur
// (PUT /users/me/profile) : garde = dailyRate (par jour, par nuit chez toi) +
// hourlyRate (garde courte / garderie < 8 h), visite = visitRate (par visite)
// + visitDurationMinutes 30 | 60, garderie = même tarif jour (affiché, pas
// un 2e champ), promenade = walkRates 30 / 60 / 120 (par balade). Un service
// non proposé = tarif 0 (règle du contrat). Couleur du rôle, zéro gris.
// Hooks en tête, aucun retour conditionnel avant.

import { useEffect, useState } from "react";
import { AppIcon, type AppIconName } from "@/components/AppIcon";
import { SignatureButton } from "@/components/SignatureButton";
import type { Lang } from "@/lib/i18n/langs";
import { d620 } from "@/lib/i18n/dates620";
import { ApiError, getMyRates620, saveMyRates620 } from "@/lib/api";
import type { ProviderRates620 } from "@/lib/services620";

const TONE = {
  sitter: { dark: "#1E4FB0", mid: "#2563EB", pale: "#E3EFFE" },
  walker: { dark: "#15803D", mid: "#16A34A", pale: "#DEF7E5" },
} as const;
const INK = "#231715";
const INK_SOFT = "#6E4F48";

const SYM: Record<string, string> = { EUR: "€", USD: "$", GBP: "£", CHF: "CHF", KRW: "₩", JPY: "¥", PLN: "zł" };

function Field({ id, value, onChange, currency, tone, disabled }: { id: string; value: string; onChange: (v: string) => void; currency: string; tone: { dark: string }; disabled?: boolean }) {
  return (
    <div className="relative">
      <input
        id={id}
        type="number"
        inputMode="decimal"
        min="0"
        step="0.5"
        value={value}
        disabled={disabled}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-xl border px-3 py-2.5 pr-12 text-sm font-semibold focus:outline-none disabled:opacity-60"
        style={{ borderColor: "rgba(35,23,21,0.15)", color: INK, background: disabled ? "#F7F2EF" : "#fff" }}
      />
      <span className="pointer-events-none absolute inset-y-0 right-3 flex items-center text-sm font-extrabold" style={{ color: tone.dark }}>{SYM[currency] || currency}</span>
    </div>
  );
}

function Row({ icon, title, hint, offered, onOffer, tone, lang, children }: { icon: AppIconName; title: string; hint: string; offered: boolean; onOffer: (v: boolean) => void; tone: { dark: string; mid: string; pale: string }; lang: Lang; children?: React.ReactNode }) {
  return (
    <li className="rounded-2xl bg-white p-3" style={{ boxShadow: `inset 0 0 0 1.5px ${offered ? tone.mid : "rgba(35,23,21,0.10)"}` }}>
      {/* À 375 px l'interrupteur passe SOUS le titre (sinon le titre se fait écraser). */}
      <div className="flex flex-wrap items-start gap-x-3 gap-y-1">
        <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full" style={{ background: offered ? tone.mid : tone.pale }}>
          <AppIcon name={icon} size={20} color={offered ? "#fff" : tone.dark} />
        </span>
        <div className="min-w-0 flex-1 basis-[180px]">
          <p className="text-[15px] font-bold leading-tight" style={{ color: INK }}>{title}</p>
          <p className="mt-0.5 text-xs leading-snug" style={{ color: INK_SOFT }}>{hint}</p>
        </div>
        <label className="flex basis-full cursor-pointer items-center gap-1.5 pl-[52px] text-xs font-bold max-lg:min-h-[44px] sm:basis-auto sm:pl-0" style={{ color: offered ? tone.dark : INK_SOFT }}>
          <input type="checkbox" checked={offered} onChange={(e) => onOffer(e.target.checked)} className="h-4 w-4" style={{ accentColor: tone.mid }} />
          {offered ? d620(lang, "rates_offer") : d620(lang, "rates_not_offered")}
        </label>
      </div>
      {offered && children && <div className="mt-3 grid gap-2 sm:grid-cols-2">{children}</div>}
    </li>
  );
}

export function RatesGrid620({ role, lang }: { role: "sitter" | "walker"; lang: Lang }) {
  const tone = TONE[role];
  const [loaded, setLoaded] = useState<ProviderRates620 | null>(null);
  const [currency, setCurrency] = useState("EUR");
  const [daily, setDaily] = useState("");
  const [hourly, setHourly] = useState("");
  const [visit, setVisit] = useState("");
  const [visitDur, setVisitDur] = useState<30 | 60>(30);
  const [w30, setW30] = useState("");
  const [w60, setW60] = useState("");
  const [w120, setW120] = useState("");
  const [offSitting, setOffSitting] = useState(false);
  const [offVisit, setOffVisit] = useState(false);
  const [offWalk, setOffWalk] = useState(false);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  useEffect(() => {
    let alive = true;
    getMyRates620()
      .then(({ rates }) => {
        if (!alive) return;
        setLoaded(rates);
        setCurrency(rates.currency);
        setDaily(rates.dailyRate ? String(rates.dailyRate) : "");
        setHourly(rates.hourlyRate ? String(rates.hourlyRate) : "");
        setVisit(rates.visitRate ? String(rates.visitRate) : "");
        setVisitDur(rates.visitDurationMinutes === 60 ? 60 : 30);
        const w = (m: number) => rates.walkRates.find((x) => x.durationMinutes === m)?.basePrice;
        setW30(w(30) ? String(w(30)) : "");
        setW60(w(60) ? String(w(60)) : "");
        setW120(w(120) ? String(w(120)) : "");
        setOffSitting(!!(rates.dailyRate || rates.hourlyRate));
        setOffVisit(!!rates.visitRate);
        setOffWalk(rates.walkRates.length > 0);
      })
      .catch(() => { if (alive) setLoaded({ currency: "EUR", hourlyRate: null, dailyRate: null, weeklyRate: null, monthlyRate: null, visitRate: null, visitDurationMinutes: null, walkRates: [] }); });
    return () => { alive = false; };
  }, []);

  const num = (v: string) => { const n = Number(String(v).replace(",", ".")); return Number.isFinite(n) && n > 0 ? Math.round(n * 100) / 100 : 0; };

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    try {
      if (role === "walker") {
        const list = [[30, w30], [60, w60], [120, w120]] as const;
        await saveMyRates620({
          walkRates: offWalk
            ? list.filter(([, v]) => num(v) > 0).map(([m, v]) => ({ durationMinutes: m, basePrice: num(v), currency, enabled: true }))
            : [],
        });
      } else {
        await saveMyRates620({
          dailyRate: offSitting ? num(daily) : 0,
          hourlyRate: offSitting ? num(hourly) : 0,
          visitRate: offVisit ? num(visit) : 0,
          visitDurationMinutes: visitDur,
        });
      }
      setMsg({ ok: true, text: d620(lang, "rates_saved") });
    } catch (ex) {
      setMsg({ ok: false, text: ex instanceof ApiError && ex.message ? ex.message : d620(lang, "rates_error") });
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={save} id="rates-620" data-testid="rates-grid-620" className="mt-10 rounded-[24px] p-5" style={{ background: "#FAF1EC" }}>
      <h2 className="flex items-center gap-2 font-display text-2xl font-bold tracking-[-0.02em]" style={{ color: INK }}>
        <AppIcon name="wallet" size={24} color={tone.mid} />
        {d620(lang, "rates_title")}
      </h2>
      <p className="mt-1 text-[15px]" style={{ color: INK_SOFT }}>{d620(lang, "rates_sub")}</p>
      {!loaded ? (
        <p className="mt-4 text-sm font-semibold" style={{ color: tone.dark }}>{d620(lang, "rates_loading")}</p>
      ) : (
        <ul className="mt-4 space-y-2">
          {role === "sitter" ? (
            <>
              <Row icon="home" title={d620(lang, "rates_sitting")} hint={d620(lang, "rates_sitting_hint")} offered={offSitting} onOffer={setOffSitting} tone={tone} lang={lang}>
                <label className="block">
                  <span className="block text-xs font-semibold" style={{ color: INK_SOFT }}>{d620(lang, "rates_sitting")} · {d620(lang, "unit_long_day")}</span>
                  <div className="mt-1"><Field id="rate-daily-620" value={daily} onChange={setDaily} currency={currency} tone={tone} /></div>
                </label>
                <label className="block">
                  <span className="block text-xs font-semibold" style={{ color: INK_SOFT }}>{d620(lang, "rates_hour")} · {d620(lang, "rates_hour_hint")}</span>
                  <div className="mt-1"><Field id="rate-hourly-620" value={hourly} onChange={setHourly} currency={currency} tone={tone} /></div>
                </label>
              </Row>
              <Row icon="clock" title={d620(lang, "rates_visit")} hint={d620(lang, "rates_visit_hint")} offered={offVisit} onOffer={setOffVisit} tone={tone} lang={lang}>
                <label className="block">
                  <span className="block text-xs font-semibold" style={{ color: INK_SOFT }}>{d620(lang, "unit_long_visit")}</span>
                  <div className="mt-1"><Field id="rate-visit-620" value={visit} onChange={setVisit} currency={currency} tone={tone} /></div>
                </label>
                <div>
                  <span className="block text-xs font-semibold" style={{ color: INK_SOFT }}>{d620(lang, "rates_visit_duration")}</span>
                  <div className="mt-1 flex gap-2" role="radiogroup">
                    {([30, 60] as const).map((m) => {
                      const on = visitDur === m;
                      return (
                        <button key={m} type="button" role="radio" aria-checked={on} data-visit-duration={m} onClick={() => setVisitDur(m)}
                          className="min-h-[42px] flex-1 rounded-xl border text-sm font-semibold"
                          style={on ? { borderColor: tone.mid, background: tone.pale, color: tone.dark } : { borderColor: "rgba(35,23,21,0.15)", background: "#fff", color: INK }}>
                          {d620(lang, `rates_${m}`)}
                        </button>
                      );
                    })}
                  </div>
                </div>
              </Row>
              <li className="flex items-center gap-3 rounded-2xl bg-white p-3" style={{ boxShadow: "inset 0 0 0 1.5px rgba(35,23,21,0.10)" }} data-testid="rates-daycare-620">
                <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full" style={{ background: tone.pale }}><AppIcon name="sun" size={20} color={tone.dark} /></span>
                <div className="min-w-0 flex-1">
                  <p className="text-[15px] font-bold leading-tight" style={{ color: INK }}>{d620(lang, "rates_daycare")}</p>
                  <p className="mt-0.5 text-xs leading-snug" style={{ color: INK_SOFT }}>{d620(lang, "rates_daycare_hint")}</p>
                </div>
                {offSitting && num(daily) > 0 && <span className="shrink-0 text-sm font-extrabold" style={{ color: tone.dark }}>{num(daily)} {SYM[currency] || currency}</span>}
              </li>
            </>
          ) : (
            <Row icon="walker" title={d620(lang, "rates_walk")} hint={d620(lang, "rates_walk_hint")} offered={offWalk} onOffer={setOffWalk} tone={tone} lang={lang}>
              {([["30", w30, setW30], ["60", w60, setW60], ["120", w120, setW120]] as const).map(([m, v, set]) => (
                <label key={m} className="block">
                  <span className="block text-xs font-semibold" style={{ color: INK_SOFT }}>{d620(lang, `rates_${m}`)} · {d620(lang, "unit_long_walk")}</span>
                  <div className="mt-1"><Field id={`rate-walk-${m}-620`} value={v} onChange={set} currency={currency} tone={tone} /></div>
                </label>
              ))}
            </Row>
          )}
        </ul>
      )}
      {msg && (
        <p role={msg.ok ? "status" : "alert"} className="mt-3 rounded-xl px-3 py-2 text-[13px] font-bold" style={msg.ok ? { background: tone.pale, color: tone.dark } : { background: "#FBE9E5", color: "#9E1F0B" }}>
          {msg.text}
        </p>
      )}
      {loaded && (
        <div className="mt-4 sm:max-w-xs">
          <SignatureButton tone={role} icon="check" type="submit" label={d620(lang, "rates_save")} loading={busy} disabled={busy} />
        </div>
      )}
    </form>
  );
}

export default RatesGrid620;
