"use client";

import { useState } from "react";
import Link from "next/link";
import { useT } from "@/lib/i18n/LanguageProvider";
import { sendContactMessage } from "@/lib/api";
import { PageHero } from "@/components/PageHero";

/**
 * v556 — Contact en version premium (Daniel). En-tête commun ; formulaire
 * en carte à gauche, à droite trois raccourcis (e-mail direct, FAQ,
 * télécharger l'app). Même logique d'envoi qu'avant (sendContactMessage).
 */
export default function ContactPage() {
  const { t } = useT();
  const [name, setName]       = useState("");
  const [email, setEmail]     = useState("");
  const [message, setMessage] = useState("");
  const [status, setStatus]   = useState<"idle"|"sending"|"ok"|"err">("idle");
  const [errMsg, setErrMsg]   = useState("");

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setStatus("sending");
    setErrMsg("");
    try {
      await sendContactMessage({ name, email, message });
      setStatus("ok");
      setName(""); setEmail(""); setMessage("");
    } catch (e) {
      setStatus("err");
      setErrMsg(e instanceof Error ? e.message : t("contact_error"));
    }
  }

  return (
    <>
      <PageHero title={t("contact_title")} subtitle={t("contact_sub")} badge={<>💬 {t("nav_contact")}</>} />

      <section className="bg-white py-16">
        <div className="mx-auto grid max-w-5xl gap-8 px-4 md:grid-cols-[1.2fr_0.8fr]">
          <form
            onSubmit={onSubmit}
            className="space-y-5 rounded-[28px] border border-[#efe7e0] bg-white p-8 shadow-[0_30px_60px_-30px_rgba(23,19,15,0.35)]"
          >
            <Field label={t("contact_name")} value={name} onChange={setName} required />
            <Field label={t("contact_email")} value={email} onChange={setEmail} type="email" required />
            <div>
              <label className="block text-sm font-semibold text-ink">{t("contact_msg")}</label>
              <textarea
                required
                rows={6}
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                className="mt-2 w-full rounded-2xl border border-ink/10 bg-bg-soft px-4 py-3 text-sm text-ink transition focus:border-owner focus:bg-white focus:outline-none focus:ring-4 focus:ring-owner/10"
              />
            </div>
            <button
              disabled={status === "sending"}
              className="inline-flex w-full items-center justify-center gap-2 rounded-full bg-owner py-3.5 text-sm font-bold text-white shadow-cta transition hover:-translate-y-0.5 hover:bg-owner-dark disabled:opacity-60"
            >
              {status === "sending" ? t("common_loading") : t("contact_send")}
              {status !== "sending" && <span aria-hidden>→</span>}
            </button>
            {status === "ok"  && <p className="rounded-xl bg-walker-light px-4 py-3 text-center text-sm font-semibold text-walker-dark">{t("contact_thanks")}</p>}
            {status === "err" && <p className="rounded-xl bg-owner-light px-4 py-3 text-center text-sm font-semibold text-owner-dark">{errMsg || t("contact_error")}</p>}
          </form>

          <aside className="space-y-4">
            <a
              href="mailto:contact@hopetsit.com"
              className="flex items-start gap-4 rounded-[24px] border border-[#efe7e0] bg-white p-6 shadow-card transition hover:-translate-y-1 hover:shadow-xl"
            >
              <span className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-owner-light text-2xl">✉️</span>
              <span>
                <span className="block text-sm font-extrabold text-ink">{t("contact_or")}</span>
                <span className="mt-1 block text-sm font-semibold text-owner">contact@hopetsit.com</span>
              </span>
            </a>
            <Link
              href="/faq"
              className="flex items-start gap-4 rounded-[24px] border border-[#efe7e0] bg-white p-6 shadow-card transition hover:-translate-y-1 hover:shadow-xl"
            >
              <span className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-sitter-light text-2xl">❓</span>
              <span>
                <span className="block text-sm font-extrabold text-ink">{t("faq_title")}</span>
                <span className="mt-1 block text-sm text-ink-muted">{t("footer_help")} →</span>
              </span>
            </Link>
            <Link
              href="/download"
              className="flex items-start gap-4 rounded-[24px] border border-[#efe7e0] bg-white p-6 shadow-card transition hover:-translate-y-1 hover:shadow-xl"
            >
              <span className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-walker-light text-2xl">📱</span>
              <span>
                <span className="block text-sm font-extrabold text-ink">{t("nav_download")}</span>
                <span className="mt-1 block text-sm text-ink-muted">{t("dl_sub")}</span>
              </span>
            </Link>
          </aside>
        </div>
      </section>
    </>
  );
}

function Field({
  label, value, onChange, type = "text", required,
}: {
  label: string; value: string; onChange: (v: string) => void;
  type?: string; required?: boolean;
}) {
  return (
    <div>
      <label className="block text-sm font-semibold text-ink">{label}</label>
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        required={required}
        className="mt-2 w-full rounded-2xl border border-ink/10 bg-bg-soft px-4 py-3 text-sm text-ink transition focus:border-owner focus:bg-white focus:outline-none focus:ring-4 focus:ring-owner/10"
      />
    </div>
  );
}
