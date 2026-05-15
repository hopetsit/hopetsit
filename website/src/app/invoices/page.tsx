"use client";

// v23.1 part 146 — Page "Mes factures".
// Backend renvoie du HTML imprimable (pas de PDF natif) — l'user fait
// Ctrl+P pour exporter en PDF depuis le navigateur. Même UX que l'app
// Flutter (qui génère le PDF localement via le package `pdf`).

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError,
  getInvoiceHtmlUrl,
  getMyInvoices,
  getStoredUser,
  Invoice,
} from "@/lib/api";

export default function InvoicesPage() {
  const { t } = useT();
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
    const url = getInvoiceHtmlUrl(invoiceId);
    if (!url) return;
    window.open(url, "_blank", "noopener,noreferrer");
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
        <Link href="/dashboard" className="text-sm text-ink-muted hover:text-ink">
          ← Dashboard
        </Link>
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        Mes factures
      </h1>
      <p className="mt-2 text-ink-muted">
        Clique sur une facture pour l&apos;ouvrir, puis utilise Ctrl+P pour
        l&apos;enregistrer en PDF.
      </p>

      {error && (
        <div className="mt-6 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {invoices.length === 0 ? (
        <div className="mt-12 rounded-3xl border border-dashed border-ink/15 px-6 py-16 text-center">
          <p className="text-2xl">🧾</p>
          <p className="mt-3 font-semibold text-ink">Aucune facture</p>
          <p className="mt-1 text-sm text-ink-muted">
            Les factures sont générées automatiquement après chaque paiement
            d&apos;une réservation.
          </p>
        </div>
      ) : (
        <div className="mt-8 overflow-hidden rounded-2xl border border-ink/5 bg-white shadow-card">
          <table className="w-full text-sm">
            <thead className="bg-bg-soft text-xs uppercase tracking-wider text-ink-muted">
              <tr>
                <th className="px-4 py-3 text-left font-semibold">Numéro</th>
                <th className="px-4 py-3 text-left font-semibold">Date</th>
                <th className="px-4 py-3 text-left font-semibold">Description</th>
                <th className="px-4 py-3 text-right font-semibold">Montant</th>
                <th className="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {invoices.map((inv) => (
                <tr
                  key={inv.id}
                  className="border-t border-ink/5 hover:bg-bg-soft/50"
                >
                  <td className="px-4 py-3 font-mono text-xs text-ink">
                    {inv.invoiceNumber}
                  </td>
                  <td className="px-4 py-3 text-ink-muted">
                    {new Date(inv.issuedAt).toLocaleDateString("fr-FR", {
                      day: "2-digit",
                      month: "short",
                      year: "numeric",
                    })}
                  </td>
                  <td className="px-4 py-3 text-ink-muted">
                    {inv.serviceType || "Service HoPetSit"}
                  </td>
                  <td className="px-4 py-3 text-right font-semibold text-ink">
                    {inv.total} {inv.currency}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button
                      type="button"
                      onClick={() => openInvoice(inv.id)}
                      className="rounded-full bg-walker px-3 py-1.5 text-xs font-semibold text-white hover:opacity-90"
                    >
                      Voir / PDF
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
