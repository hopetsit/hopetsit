"use client";

// 06/11/2026 — LEO (ordre de Daniel « fais tout ce qui est possible », mesure de FLO : 5 propriétaires
// sur 16 arrivés sur « mes candidats → payer » SANS le jeton de l'e-mail → mur « mot de passe » qu'ils
// n'ont pas, compte créé par la pub).
// Encart « Pas de mot de passe ? Reçois ton lien par e-mail » : champ e-mail (pré-rempli si ?e=),
// bouton « M'envoyer mon lien » → POST /auth/owner-link { email, next, lang } → « C'est parti : ouvre
// ton e-mail et appuie sur le bouton ». MÊME écran quel que soit le résultat (compte connu ou pas :
// le serveur ne révèle rien). Le serveur envoie le même lien signé `k=` que nos e-mails candidats.
// Repères : magic_vu (encart affiché), magic_envoye (demande acceptée par le serveur).
// Zéro gris : encres brunes de la charte (#231715, #6E4F48), orange #C92A12. Hooks en tête.

import { useEffect, useRef, useState, type FormEvent } from "react";
import { AppIcon } from "@/components/AppIcon";
import { SignatureButton } from "@/components/SignatureButton";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { API_BASE } from "@/lib/api";
import { c3110 } from "@/lib/i18n/cand3110";
import type { Lang } from "@/lib/i18n/langs";

type State = "idle" | "busy" | "sent" | "again" | "error" | "bad";
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export function MagicLinkBox0611({ next, lang, onHasPassword, defaultEmail = "" }: {
  /** Chemin interne à rouvrir après le clic dans l'e-mail (ex. /application/<id>?choose=1). */
  next: string;
  lang: Lang;
  /** Si fourni : lien discret « J'ai un mot de passe » sous l'encart. */
  onHasPassword?: () => void;
  defaultEmail?: string;
}) {
  const [email, setEmail] = useState(defaultEmail);
  const [state, setState] = useState<State>("idle");
  const seenRef = useRef(false);
  const inputRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    try {
      const e = (new URLSearchParams(window.location.search).get("e") || "").trim();
      if (e && EMAIL_RE.test(e)) setEmail(e);
    } catch { /* adresse exotique */ }
    if (!seenRef.current) { seenRef.current = true; trackSiteEvent("cta_click", { label: "magic_vu" }); }
  }, []);

  async function send(ev?: FormEvent) {
    ev?.preventDefault();
    const clean = email.trim().toLowerCase();
    if (!EMAIL_RE.test(clean)) { setState("bad"); try { inputRef.current?.focus(); } catch { /* sans focus */ } return; }
    setState("busy");
    try {
      const res = await fetch(`${API_BASE}/auth/owner-link`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json", "X-App-Version": "web" },
        body: JSON.stringify({ email: clean, next, lang }),
      });
      if (res.ok) { setState("sent"); trackSiteEvent("cta_click", { label: "magic_envoye" }); }
      else if (res.status === 429) setState("again");
      else setState("error");
    } catch { setState("error"); }
  }

  const t = (k: string) => c3110(lang, k);
  const busy = state === "busy";

  return (
    <div className="rounded-2xl bg-white p-4 md:p-5" style={{ boxShadow: "0 0 0 2px #C92A12, 0 14px 30px -18px rgba(35,23,21,.5)", colorScheme: "light" }} data-magic0611={state}>
      <p className="flex items-start gap-2 text-[18px] font-extrabold leading-tight md:text-[20px]" style={{ color: "#231715" }}>
        <span className="mt-0.5 shrink-0"><AppIcon name="lock" size={20} color="#C92A12" /></span>
        <span>{t("magic_title")}</span>
      </p>
      {state === "sent" ? (
        <div className="mt-3" data-magic0611-sent="">
          <p className="flex items-center gap-2 text-[17px] font-extrabold" style={{ color: "#15803D" }}>
            <AppIcon name="check" size={20} color="#15803D" />{t("magic_sent_title")}
          </p>
          <p className="mt-1 text-[14px] leading-snug" style={{ color: "#231715" }}>{t("magic_sent_sub")}</p>
          <p className="mt-1 text-[13px] font-semibold" style={{ color: "#6E4F48" }}>{email.trim().toLowerCase()}</p>
          <button type="button" className="mt-3 min-h-[40px] text-[13px] font-bold underline-offset-2 hover:underline" style={{ color: "#9E1F0B" }} onClick={() => setState("idle")}>
            {t("magic_resend")}
          </button>
        </div>
      ) : (
        <form onSubmit={send} className="mt-2" noValidate>
          <p className="text-[14px] leading-snug" style={{ color: "#6E4F48" }}>{t("magic_sub")}</p>
          <label className="mt-3 block text-[13px] font-bold" style={{ color: "#231715" }} htmlFor="magic0611-email">{t("magic_email")}</label>
          <input
            id="magic0611-email"
            ref={inputRef}
            type="email"
            inputMode="email"
            autoComplete="email"
            value={email}
            onChange={(e) => { setEmail(e.target.value); if (state === "bad") setState("idle"); }}
            disabled={busy}
            className="mt-1.5 w-full rounded-xl bg-white px-3.5 py-3 text-[16px] focus:outline-none"
            style={{ color: "#231715", boxShadow: state === "bad" ? "0 0 0 2px #C92A12" : "inset 0 0 0 1px #E3B7AC" }}
            placeholder="prenom@exemple.com"
          />
          {state === "bad" && <p className="mt-1.5 text-[13px] font-bold" style={{ color: "#9E1F0B" }} role="alert">{t("magic_bad_email")}</p>}
          {state === "again" && <p className="mt-1.5 text-[13px] font-bold" style={{ color: "#9E1F0B" }} role="alert">{t("magic_again")}</p>}
          {state === "error" && <p className="mt-1.5 text-[13px] font-bold" style={{ color: "#9E1F0B" }} role="alert">{t("error")}</p>}
          <div className="mt-3">
            <SignatureButton tone="owner" icon="arrow-right" type="submit" label={busy ? t("magic_sending") : t("magic_send")} loading={busy} />
          </div>
        </form>
      )}
      {onHasPassword && (
        <p className="mt-3 text-center text-[13px]">
          <button type="button" className="min-h-[40px] font-bold underline-offset-2 hover:underline" style={{ color: "#6E4F48" }} onClick={onHasPassword} data-magic0611-pwd="">
            {t("magic_pwd")}
          </button>
        </p>
      )}
    </div>
  );
}
