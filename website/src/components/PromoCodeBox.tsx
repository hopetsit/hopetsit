"use client";

// v565 (point 27) — champ « code promo » unique pour tout le site.
// Daniel : « très peu utilisé → le rendre visible sans gêner, entrée claire
// dans Profil et au paiement (« J'ai un code »), message de succès lisible ».
//
// Flux : « Appliquer » → POST /promo/check (404 valid:false = code inconnu ou
// épuisé, message lisible) → POST /promo/redeem (consomme le code, active la
// récompense). Le message de succès dit CE QUE le code a donné (abonnement
// offert, remise sur le prochain achat, boost). Sans session : lien de
// connexion au lieu du champ.
//
// `collapsible` = entrée discrète « J'ai un code » qui déplie le champ
// (pages /pay et /pricing) ; sinon la carte est affichée directement
// (profil, boutique). Style Apple : carte #FAF1EC, coins 24 px, texte
// #231715 / #6E4F48, état sélectionné orange pâle.

import Link from "next/link";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError,
  checkPromo,
  getPublicPromo,
  getStoredUser,
  PublicPromo,
  redeemPromo,
} from "@/lib/api";

type PromoState =
  | { kind: "idle" }
  | { kind: "busy" }
  | { kind: "ok"; text: string }
  | { kind: "error"; text: string };

export function PromoCodeBox({
  collapsible = false,
  className = "",
  onApplied,
}: {
  collapsible?: boolean;
  className?: string;
  /** Appelé après un échange réussi (ex. : rafraîchir les abonnements). */
  onApplied?: (reward: { rewardType?: string; discountPercent?: number }) => void;
}) {
  const { t } = useT();
  const [open, setOpen] = useState(!collapsible);
  const [code, setCode] = useState("");
  const [state, setState] = useState<PromoState>({ kind: "idle" });
  const loggedIn = typeof window !== "undefined" && !!getStoredUser();
  // v565 — code « du moment » (admin) pré-rempli, avec son message.
  const [publicPromo, setPublicPromo] = useState<PublicPromo | null>(null);

  useEffect(() => {
    if (!getStoredUser()) return;
    let cancelled = false;
    getPublicPromo().then((p) => {
      if (cancelled || !p) return;
      setPublicPromo(p);
      setCode((c) => (c.trim() ? c : p.code));
    });
    return () => {
      cancelled = true;
    };
  }, []);

  async function apply() {
    const c = code.trim().toUpperCase();
    if (!c || state.kind === "busy") return;
    setState({ kind: "busy" });
    try {
      // 1) Vérification sans consommer : un code faux s'arrête ici avec
      //    le message du serveur (404 { valid:false, error }).
      const check = await checkPromo(c);
      if (!check?.valid) {
        setState({ kind: "error", text: t("promo_invalid") });
        return;
      }
      // 2) Échange réel.
      const res = await redeemPromo(c);
      const type = res.reward?.rewardType ?? check.rewardType;
      const pct = res.reward?.discountPercent ?? check.discountPercent;
      let text = t("promo_ok_generic");
      if (type === "free_subscription") text = t("promo_ok_sub");
      else if (type === "percent_discount")
        text = `${t("promo_ok_discount")}${pct ? ` (−${pct}%)` : ""}`;
      else if (type && /boost/i.test(type)) text = t("promo_ok_boost");
      setState({ kind: "ok", text });
      setCode("");
      onApplied?.({ rewardType: type, discountPercent: pct });
    } catch (e) {
      const msg =
        e instanceof ApiError && e.status === 404
          ? t("promo_invalid")
          : e instanceof Error && e.message
            ? e.message
            : t("promo_invalid");
      setState({ kind: "error", text: msg });
    }
  }

  if (collapsible && !open) {
    return (
      <div className={className}>
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="inline-flex items-center gap-2 rounded-full bg-owner-light px-4 py-2 text-sm font-semibold text-owner-dark transition hover:brightness-95"
        >
          <span aria-hidden="true">🎁</span>
          {t("promo_have_code")}
          {publicPromo && (
            <span className="rounded-full bg-white/80 px-2 py-0.5 font-mono text-xs tracking-wide text-owner-dark">
              {publicPromo.code}
            </span>
          )}
        </button>
      </div>
    );
  }

  return (
    <div className={`rounded-[24px] bg-[#FAF1EC] p-5 ${className}`}>
      <div className="flex items-center gap-2">
        <span aria-hidden="true" className="text-lg">🎁</span>
        <p className="text-sm font-semibold text-[#231715]">{t("promo_title")}</p>
      </div>
      <p className="mt-1 text-xs text-[#6E4F48]">{t("promo_check_hint")}</p>
      {publicPromo?.message && loggedIn && (
        <p className="mt-2 rounded-2xl bg-owner-light px-3 py-2 text-xs font-medium text-owner-dark">
          🎉 {publicPromo.message}{" "}
          <span className="font-mono font-semibold">{publicPromo.code}</span>
        </p>
      )}

      {!loggedIn ? (
        <Link
          href="/login"
          className="mt-3 inline-flex items-center rounded-full bg-[#231715] px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-black"
        >
          {t("promo_login_first")}
        </Link>
      ) : (
        <>
          <div className="mt-3 flex flex-col gap-2 sm:flex-row">
            <input
              type="text"
              value={code}
              autoCapitalize="characters"
              autoComplete="off"
              spellCheck={false}
              onChange={(e) => {
                setCode(e.target.value);
                if (state.kind !== "idle" && state.kind !== "busy") setState({ kind: "idle" });
              }}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  void apply();
                }
              }}
              placeholder={t("promo_placeholder")}
              aria-label={t("promo_title")}
              className="min-w-0 flex-1 rounded-full border-0 bg-white px-4 py-2.5 text-sm uppercase tracking-wide text-[#231715] outline-none ring-1 ring-black/5 focus:ring-2 focus:ring-owner/40"
            />
            <button
              type="button"
              onClick={() => void apply()}
              disabled={state.kind === "busy" || !code.trim()}
              className="shrink-0 rounded-full bg-[#231715] px-6 py-2.5 text-sm font-semibold text-white transition hover:bg-black disabled:opacity-50"
            >
              {state.kind === "busy" ? "…" : t("promo_apply")}
            </button>
          </div>
          {state.kind === "ok" && (
            <div
              role="status"
              className="mt-3 rounded-2xl bg-emerald-50 px-4 py-3 text-sm text-emerald-800"
            >
              <p className="font-semibold">{t("promo_success_title")}</p>
              <p className="mt-0.5">{state.text}</p>
            </div>
          )}
          {state.kind === "error" && (
            <div
              role="alert"
              className="mt-3 rounded-2xl bg-red-50 px-4 py-3 text-sm font-medium text-red-700"
            >
              {state.text}
            </div>
          )}
        </>
      )}
    </div>
  );
}

export default PromoCodeBox;
