"use client";

import { useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { sendContactMessage } from "@/lib/api";

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
    <div className="mx-auto max-w-xl px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-4xl font-extrabold tracking-tight md:text-5xl">
        {t("contact_title")}
      </h1>
      <p className="mt-4 text-center text-lg text-ink-muted">{t("contact_sub")}</p>

      <form
        onSubmit={onSubmit}
        className="mt-10 space-y-4 rounded-3xl border border-ink/5 bg-white p-7 shadow-card"
      >
        <Field label={t("contact_name")} value={name} onChange={setName} required />
        <Field label={t("contact_email")} value={email} onChange={setEmail} type="email" required />
        <div>
          <label className="block text-sm font-medium text-ink">{t("contact_msg")}</label>
          <textarea
            required
            rows={5}
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            className="mt-1.5 w-full rounded-xl border border-ink/15 bg-bg-soft px-3.5 py-2.5 text-sm text-ink focus:border-owner focus:outline-none"
          />
        </div>
        <button
          disabled={status === "sending"}
          className="w-full rounded-full bg-owner py-3 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark disabled:opacity-60"
        >
          {status === "sending" ? t("common_loading") : t("contact_send")}
        </button>
        {status === "ok"  && <p className="text-center text-sm text-walker-dark">{t("contact_thanks")}</p>}
        {status === "err" && <p className="text-center text-sm text-owner-dark">{errMsg || t("contact_error")}</p>}
      </form>

      <p className="mt-8 text-center text-sm text-ink-muted">
        {t("contact_or")}{" "}
        <a href="mailto:contact@hopetsit.com" className="font-semibold text-owner">contact@hopetsit.com</a>
      </p>
    </div>
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
      <label className="block text-sm font-medium text-ink">{label}</label>
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        required={required}
        className="mt-1.5 w-full rounded-xl border border-ink/15 bg-bg-soft px-3.5 py-2.5 text-sm text-ink focus:border-owner focus:outline-none"
      />
    </div>
  );
}
