"use client";

import { useT } from "@/lib/i18n/LanguageProvider";
import { LegalPage } from "@/components/LegalPage";

export default function PrivacyPage() {
  const { t } = useT();
  return (
    <LegalPage title={t("privacy_title")} lastUpdated="April 25, 2026">
      <p>
        CARDELLI HERMANOS LIMITED (trading as HoPetSit) (&quot;we&quot;, &quot;us&quot;) is the data controller of personal data
        collected through the HoPetSit mobile application and website
        (the &quot;Service&quot;). This page explains what we collect, why, how long we
        keep it, and your rights — in accordance with the EU General Data
        Protection Regulation (GDPR), the UK GDPR and Hong Kong PDPO.
      </p>

      <h2>1. Data we collect</h2>
      <ul>
        <li><strong>Account data:</strong> name, email, phone (optional), city, role, password hash.</li>
        <li><strong>Profile data:</strong> avatar, bio, languages, services offered, rates, availability.</li>
        <li><strong>Booking data:</strong> dates, pets, prices, status, reviews.</li>
        <li><strong>Payment data:</strong> a token from our regulated payment provider — we never see your card number. Last 4 digits and brand are stored to display saved cards.</li>
        <li><strong>Communications:</strong> chat messages, support tickets, contact-form submissions.</li>
        <li><strong>Technical data:</strong> IP address, device type, app version, language, crash reports.</li>
        <li><strong>Location:</strong> only when you explicitly grant location permission to find providers near you or to publish a request.</li>
      </ul>

      <h2>2. Why we process it (legal basis)</h2>
      <ul>
        <li><strong>Contract:</strong> creating and operating your account, processing bookings and payments.</li>
        <li><strong>Legitimate interest:</strong> fraud prevention, content moderation, product analytics.</li>
        <li><strong>Consent:</strong> marketing emails, push notifications, location access.</li>
        <li><strong>Legal obligation:</strong> tax records, anti-money-laundering compliance.</li>
      </ul>

      <h2>3. Sharing</h2>
      <p>We share data with:</p>
      <ul>
        <li>The payment processor (PCI-DSS compliant) for card transactions and IBAN/PayPal payouts.</li>
        <li>Cloud infrastructure (Render, MongoDB, Cloudinary) under strict data-processing agreements.</li>
        <li>Other users only as needed for a booking (e.g. your name and avatar are shown to the sitter you booked).</li>
        <li>Authorities when required by law.</li>
      </ul>
      <p>We do <strong>not</strong> sell your data and do not use it for cross-platform advertising.</p>

      <h2>4. Retention</h2>
      <p>
        Account data is kept while your account is active and 24 months after
        deletion (for fraud prevention). Booking and payment records are kept
        10 years for tax compliance. Chat messages are kept for the lifetime of
        the conversation; soft-deleted messages remain visible to admin
        moderators only.
      </p>

      <h2>5. Your rights</h2>
      <ul>
        <li>Right of access, rectification, erasure, restriction, portability and objection.</li>
        <li>Right to withdraw consent at any time (push notifications, marketing).</li>
        <li>Right to lodge a complaint with your local data-protection authority (e.g. CNIL in France).</li>
      </ul>
      <p>
        Exercise your rights at <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. We answer within 30 days.
      </p>

      <h2>6. International transfers</h2>
      <p>
        Some of our processors are based outside the European Economic Area.
        Transfers are protected by the European Commission&apos;s Standard
        Contractual Clauses (SCCs) and equivalent safeguards under UK and Hong
        Kong law.
      </p>

      <h2>7. Cookies</h2>
      <p>
        The website uses strictly necessary cookies for authentication and
        preferences. We do not use advertising or tracking cookies. The mobile
        app uses local storage and a notification token for push delivery.
      </p>

      <h2>8. Children</h2>
      <p>
        The Service is not directed to children under 16. We do not knowingly
        collect data from minors.
      </p>

      <h2>9. Changes</h2>
      <p>
        Material changes to this policy are notified in-app and by email
        (when you have opted in to product updates) at least 30 days before
        they take effect.
      </p>

      <h2>10. Contact</h2>
      <p>
        Data Protection contact:{" "}
        <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>
      </p>
    </LegalPage>
  );
}
