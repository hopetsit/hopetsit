"use client";

// v23.1 part 146 — Page "Mes factures".
// Backend renvoie du HTML imprimable (pas de PDF natif) — l'user fait
// Ctrl+P pour exporter en PDF depuis le navigateur. Même UX que l'app
// Flutter (qui génère le PDF localement via le package `pdf`).

import Link from "next/link";
import { useRouter } from "next/navigation";
import { Fragment, useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import BackLink from "@/components/BackLink";
import { BillingPartyBlock } from "@/components/BillingInfoSection";
import {
  ApiError,
  getInvoiceHtmlUrl,
  getMyInvoices,
  getStoredUser,
  Invoice,
} from "@/lib/api";

export default function InvoicesPage() {
  const { t, lang } = useT();
  // v566 — facture dépliée : blocs « Émetteur » / « Client ».
  const [openId, setOpenId] = useState<string | null>(null);
  const router = useRouter();
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!getStoredUser()) {
      router.replace("/login");
      return;
    }
    (async () => {
      try {
        const list = await getMyInvoices();
        list.sort((a, b) =>
          new Date(b.issuedAt).getTime() - new Date(a.issuedAt).getTime(),
        );
        setInvoices(list);
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }
        setError(e instanceof Error ? e.message : "Failed to load invoices");
      } finally {
        setLoading(false);
      }
    })();
  }, [router]);

  function openInvoice(invoiceId: string) {
    const base = getInvoiceHtmlUrl(invoiceId);
    // v566 — la facture HTML suit la langue du site (9 langues côté serveur).
    const url = base ? `${base}&lang=${lang}` : null;
    if (!url) {
      // Pas de token -> session expirée : on renvoie au login plutôt que
      // de cliquer dans le vide.
      router.push("/login");
      return;
    }
    // v498 — Daniel : « le bouton télécharger PDF ne marche pas ». L'ancien
    // window.open(url, "_blank", "noopener,noreferrer") était ignoré par
    // certains navigateurs / bloqueurs de popup (3e arg = window features →
    // popup bloquée silencieusement). On ouvre via un <a target=_blank> (le
    // moyen le plus fiable), avec repli navigation même onglet si bloqué.
    try {
      const a = document.createElement("a");
      a.href = url;
      a.target = "_blank";
      a.rel = "noopener";
      document.body.appendChild(a);
      a.click();
      a.remove();
    } catch {
      window.location.href = url;
    }
  }

  if (loading) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-24 text-center text-ink-muted">
        {t("common_loading")}
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl px-4 py-12 md:py-16">
      <div className="mb-6">
        <BackLink href="/dashboard" label={t("nav_dashboard")} />
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        {t("dash_card_invoices_title")}
      </h1>
      <p className="mt-2 text-ink-muted">
        {t("invoices_hint")}
      </p>
      <p className="mt-2 text-sm text-ink-muted">
        {t("invoices_billing_hint")}{" "}
        <Link href="/profile#billing" className="font-semibold text-owner-dark underline-offset-2 hover:underline">
          {t("billing_add_cta")}
        </Link>
      </p>

      {error && (
        <div className="mt-6 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {invoices.length === 0 ? (
        <div className="mt-12 rounded-3xl border border-dashed border-ink/15 px-6 py-16 text-center">
          <p className="text-2xl">🧾</p>
          <p className="mt-3 font-semibold text-ink">{t("invoices_empty_title")}</p>
          <p className="mt-1 text-sm text-ink-muted">
            {t("invoices_empty_sub")}
          </p>
        </div>
      ) : (
        <div className="mt-8 overflow-hidden rounded-2xl border border-ink/5 bg-white shadow-card">
          <table className="w-full text-sm">
            <thead className="bg-bg-soft text-xs uppercase tracking-wider text-ink-muted">
              <tr>
                <th className="px-4 py-3 text-left font-semibold">{t("invoices_col_number")}</th>
                <th className="px-4 py-3 text-left font-semibold">{t("invoices_col_date")}</th>
                <th className="px-4 py-3 text-left font-semibold">{t("invoices_col_description")}</th>
                <th className="px-4 py-3 text-right font-semibold">{t("invoices_col_amount")}</th>
                <th className="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {invoices.map((inv) => (
                <Fragment key={inv.id}>
                <tr className="border-t border-ink/5 hover:bg-bg-soft/50">
                  <td className="px-4 py-3 font-mono text-xs text-ink">
                    {inv.invoiceNumber}
                  </td>
                  <td className="px-4 py-3 text-ink-muted">
                    {new Date(inv.issuedAt).toLocaleDateString(lang, {
                      day: "2-digit",
                      month: "short",
                      year: "numeric",
                    })}
                  </td>
                  <td className="px-4 py-3 text-ink-muted">
                    {(inv.serviceType || "HoPetSit").replace(/_/g, " ")}
                  </td>
                  <td className="px-4 py-3 text-right font-semibold text-ink">
                    {Number(inv.total ?? inv.grossAmount ?? 0).toFixed(2)} {inv.currency}
                  </td>
                  <td className="whitespace-nowrap px-4 py-3 text-right">
                    <button
                      type="button"
                      onClick={() => setOpenId(openId === inv.id ? null : inv.id)}
                      aria-expanded={openId === inv.id}
                      className="mr-2 rounded-full bg-bg-soft px-3 py-1.5 text-xs font-semibold text-ink hover:bg-owner-light hover:text-owner-dark"
                    >
                      {t("invoices_details")}
                    </button>
                    <button
                      type="button"
                      onClick={() => openInvoice(inv.id)}
                      className="rounded-full bg-walker px-3 py-1.5 text-xs font-semibold text-white hover:opacity-90"
                    >
                      {t("invoices_view_pdf")}
                    </button>
                  </td>
                </tr>
                {openId === inv.id && (
                  <tr className="border-t border-ink/5 bg-white">
                    <td colSpan={5} className="px-4 py-4">
                      <div className="grid gap-3 sm:grid-cols-2">
                        <BillingPartyBlock
                          title={t("billing_issuer")}
                          name={inv.providerName}
                          billing={inv.issuerBilling}
                        />
                        <BillingPartyBlock
                          title={t("billing_customer")}
                          name={inv.ownerName}
                          billing={inv.customerBilling}
                        />
                      </div>
                    </td>
                  </tr>
                )}
                </Fragment>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
