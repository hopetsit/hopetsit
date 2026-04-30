"use client";

import { useT } from "@/lib/i18n/LanguageProvider";
import { LegalPage } from "@/components/LegalPage";

export default function RefundPage() {
  const { t } = useT();
  return (
    <LegalPage title={t("refund_title")} lastUpdated="April 30, 2026">
      <p>
        This Refund Policy applies to all bookings made through the HoPetSit
        marketplace. It complements the <a href="/terms">Terms of Service</a>{" "}
        and reflects how cancellations and refunds are actually executed by
        our payment processor (Airwallex).
      </p>

      <h2>1. How payments are held</h2>
      <p>
        When an owner pays for a confirmed booking, the funds are captured by
        our regulated payment processor (Airwallex) and held in escrow. They
        are released to the provider&apos;s registered bank account{" "}
        <strong>24 hours after the service ends</strong> — this dispute window
        protects the owner if anything goes wrong during the service.
      </p>

      <h2>2. Cancellation by the owner — 72-hour free window</h2>
      <ul>
        <li>
          <strong>More than 72 hours before the service starts:</strong>{" "}
          You can self-cancel from the app. The booking is cancelled
          immediately and you receive a <strong>100% automatic refund</strong>
          {" "}(no questions asked). Funds typically reach your bank within
          5&ndash;10 business days.
        </li>
        <li>
          <strong>72 hours or less before the service starts:</strong>{" "}
          Self-cancellation is no longer available. You must request a{" "}
          <strong>mutual cancellation</strong> from your provider in the chat,
          or open a formal dispute via{" "}
          <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>.
          Refunds within this window are reviewed case-by-case based on the
          reason and any evidence.
        </li>
      </ul>

      <h2>3. Cancellation by the provider</h2>
      <p>
        If your sitter or walker cancels a confirmed booking — at any time
        before the service starts — you receive a{" "}
        <strong>100% automatic refund</strong>. The provider may incur a
        cancellation fee, visibility downgrade or platform suspension if
        cancellations become repeated, to protect the trust of owners on the
        platform.
      </p>

      <h2>4. Service not delivered (no-show, sitter unreachable)</h2>
      <p>
        If the service was paid for but never delivered, you can open a
        dispute within{" "}
        <strong>24 hours of the scheduled service end</strong> via the chat
        or by emailing{" "}
        <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. After
        verification (chat history, photos, GPS check-ins, ratings), we issue
        a full refund within 5 business days.
      </p>

      <h2>5. Service materially different from what was agreed</h2>
      <p>
        Partial refunds may be granted at our discretion when the service was
        materially different from what was agreed (significantly shorter
        duration, conditions clearly violated, etc.). Both parties have the
        opportunity to share evidence in the dispute.
      </p>

      <h2>6. Force majeure</h2>
      <p>
        Documented force majeure events affecting either party (severe
        illness with medical proof, natural disaster, government-imposed
        travel ban, death of the pet, etc.) are reviewed case-by-case
        regardless of the standard timeline. Refunds may be granted on
        presentation of appropriate evidence.
      </p>

      <h2>7. How refunds are issued</h2>
      <p>
        Refunds are issued back to the original payment method (the card
        used at checkout, via Airwallex). Funds typically arrive within{" "}
        <strong>5 to 10 business days</strong> depending on your bank.
      </p>

      <h2>8. Chargebacks</h2>
      <p>
        We strongly encourage owners to use HoPetSit&apos;s internal dispute
        mechanism before initiating a chargeback with their card issuer.
        Owners initiating chargebacks without first contacting us, or while
        a dispute is already active, may forfeit our internal resolution
        process and may be permanently removed from the platform. We
        cooperate fully with Airwallex on legitimate chargeback
        investigations.
      </p>

      <h2>9. Contact</h2>
      <p>
        Refund requests, disputes and questions:{" "}
        <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> · we
        aim to reply within 48 hours.
      </p>
    </LegalPage>
  );
}
