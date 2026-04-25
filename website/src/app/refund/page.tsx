"use client";

import { useT } from "@/lib/i18n/LanguageProvider";
import { LegalPage } from "@/components/LegalPage";

export default function RefundPage() {
  const { t } = useT();
  return (
    <LegalPage title={t("refund_title")} lastUpdated="April 25, 2026">
      <p>
        This Refund Policy applies to all bookings made through the HoPetSit
        marketplace. It complements the <a href="/terms">Terms of Service</a>.
      </p>

      <h2>1. Cancellation by the owner before the service starts</h2>
      <ul>
        <li><strong>More than 48 h before:</strong> full refund (100% of the amount paid).</li>
        <li><strong>Between 24 h and 48 h before:</strong> 50% refund.</li>
        <li><strong>Less than 24 h before:</strong> no refund — the provider has reserved the slot.</li>
      </ul>

      <h2>2. Cancellation by the provider</h2>
      <p>
        If a sitter or walker cancels a confirmed booking before the service
        starts, the owner is automatically refunded in full. We may
        additionally take action against repeat offenders (visibility
        downgrade, badge loss, account suspension).
      </p>

      <h2>3. Service not delivered</h2>
      <p>
        If the service was paid for but not delivered (no-show by the
        provider, dog not picked up, sitter unreachable), the owner can open
        a dispute within <strong>7 days</strong> from the scheduled date. We refund
        100% of the amount within 5 business days after verification.
      </p>

      <h2>4. Service not as described</h2>
      <p>
        Partial refunds are possible at our discretion when the service was
        materially different from what was agreed (e.g. duration much shorter
        than booked, conditions clearly violated). Both parties have a chance
        to share evidence.
      </p>

      <h2>5. How refunds are issued</h2>
      <p>
        Refunds are issued to the original payment method used at checkout
        (the card via the regulated payment processor). Funds typically arrive
        within 5–10 business days depending on your bank.
      </p>

      <h2>6. Chargebacks</h2>
      <p>
        Initiating a chargeback before raising a dispute through the platform
        violates these Terms and may result in account suspension. Please
        contact us first — we resolve most cases within 48 hours.
      </p>

      <h2>7. Contact</h2>
      <p>
        Refund requests and disputes:{" "}
        <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>
      </p>
    </LegalPage>
  );
}
