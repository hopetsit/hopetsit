"use client";

// 25/09/2026 — LOT D : « Une idée ? Un problème ? » (demande de Daniel du
// 25/09) — le MÊME formulaire que dans l'app (Profil › Aide) : un choix idée /
// problème, un texte libre, envoi en un appui, petit merci après envoi —
// jamais de réponse automatique qui promet quelque chose. Passe par le circuit
// de signalement existant (`sendFeedback` → `POST /bug-reports`, étiquette
// `kind`). Tableau de bord connecté uniquement (pas de page publique).

import { useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { sendFeedback, type FeedbackKind } from "@/lib/api";
import { AppIcon } from "@/components/AppIcon";
import { SignatureButton, type SignatureTone } from "@/components/SignatureButton";

export function FeedbackBox({ tone = "owner" }: { tone?: SignatureTone }) {
  const { t } = useT();
  const [kind, setKind] = useState<FeedbackKind>("idea");
  const [text, setText] = useState("");
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const min = kind === "idea" ? 3 : 10;
  const ready = text.trim().length >= min;

  const submit = async () => {
    if (!ready) return;
    setError(null);
    try {
      await sendFeedback({ kind, description: text, title: text.trim().slice(0, 60) });
      setSent(true);
      setText("");
    } catch {
      setError(t("fb_error"));
    }
  };

  const pill = (k: FeedbackKind, icon: "star" | "settings", label: string) => {
    const on = kind === k;
    return (
      <button
        type="button"
        onClick={() => { setKind(k); setSent(false); }}
        aria-pressed={on}
        className={`hps-pill inline-flex min-h-[34px] items-center gap-1.5 rounded-[12px] px-3 text-[13px] font-bold transition ${on ? "text-white" : "text-[#8A1D0C]"}`}
        data-tone={tone}
      >
        <AppIcon name={icon} size={14} color="currentColor" />
        {label}
      </button>
    );
  };

  return (
    <section id="idees" className="mt-4 scroll-mt-24 rounded-[24px] bg-[#FAF1EC] p-5" aria-labelledby="fb-title">
      <h2 id="fb-title" className="flex items-center gap-2 text-sm font-semibold text-[#231715]">
        <AppIcon name="megaphone" size={18} color="#C92A12" /> {t("fb_title")}
      </h2>
      <p className="mt-1 text-[13px] text-[#6E4F48]">{t("fb_sub")}</p>
      {sent ? (
        <p className="mt-3 flex items-center gap-2 rounded-[16px] bg-white px-4 py-3 text-sm font-semibold text-[#0F7C37]" role="status">
          <AppIcon name="check" size={18} color="#0F7C37" /> {t("fb_thanks")}
        </p>
      ) : (
        <>
          <div className="mt-3 flex flex-wrap gap-2">
            {pill("idea", "star", t("fb_kind_idea"))}
            {pill("problem", "settings", t("fb_kind_problem"))}
          </div>
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            rows={3}
            maxLength={4000}
            placeholder={kind === "idea" ? t("fb_placeholder_idea") : t("fb_placeholder_problem")}
            className="mt-3 w-full resize-y rounded-[16px] border border-[#EADFDC] bg-white px-4 py-3 text-sm outline-none focus:border-[#C92A12]"
            aria-label={t("fb_title")}
          />
          <div className="mt-3 sm:max-w-xs">
            <SignatureButton
              label={t("fb_send")}
              icon="rocket"
              tone={tone}
              onClick={submit}
              disabled={!ready}
              disabledReason={kind === "idea" ? t("fb_too_short_idea") : t("fb_too_short_problem")}
            />
          </div>
          {error && <p className="mt-2 text-sm text-[#B42318]" role="alert">{error}</p>}
        </>
      )}
    </section>
  );
}

export default FeedbackBox;
