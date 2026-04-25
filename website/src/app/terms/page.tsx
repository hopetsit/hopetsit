"use client";

import { useT } from "@/lib/i18n/LanguageProvider";
import { LegalPage } from "@/components/LegalPage";

export default function TermsPage() {
  const { t } = useT();
  return (
    <LegalPage title={t("terms_title")} lastUpdated="April 25, 2026">
      <p>
        These Terms of Service (the &quot;Terms&quot;) govern your use of the HoPetSit
        marketplace (the &quot;Service&quot;), operated by CARDELLI HERMANOS LIMITED (trading as HoPetSit), a company
        incorporated in Hong Kong (the &quot;Company&quot;, &quot;we&quot;, &quot;us&quot;).
      </p>

      <h2>1. The Service</h2>
      <p>
        HoPetSit is a marketplace connecting pet owners with independent pet
        sitters and dog walkers across the European Union, United Kingdom,
        Switzerland, Norway and adjacent territories. We are <strong>not</strong> a
        provider of pet-care services ourselves. We facilitate matching, secure
        chat, payment processing and dispute resolution between users.
      </p>

      <h2>2. Eligibility</h2>
      <ul>
        <li>You must be at least 18 years old to register as a sitter or walker.</li>
        <li>Pet owners must be at least 18 years old or use the platform under the supervision of a legal guardian.</li>
        <li>You must provide accurate, current and complete information at registration.</li>
      </ul>

      <h2>3. Account &amp; security</h2>
      <p>
        You are responsible for the activity on your account and for keeping your
        credentials confidential. Notify us at <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> as soon
        as you suspect unauthorised access.
      </p>

      <h2>4. Bookings &amp; payments</h2>
      <p>
        Owners pay the service price plus a 20% platform commission (15% for
        Top Sitter / Top Walker badges). Payments are processed by a regulated
        payment provider. Funds are held until the service is delivered, then
        released to the provider&apos;s registered IBAN or PayPal.
      </p>
      <p>
        Providers receive 100% of the rate they advertise. The platform fee is
        added on top, paid by the owner at checkout.
      </p>

      <h2>5. Cancellations &amp; refunds</h2>
      <p>
        Owners may cancel a booking before the service is delivered for a full
        refund. Once the service has started, refunds are subject to the
        Refund Policy and dispute review by our team.
      </p>

      <h2>6. Conduct</h2>
      <ul>
        <li>No harassment, hate speech, or harmful behaviour toward other users or animals.</li>
        <li>No solicitation of contact details to bypass the platform&apos;s payment system.</li>
        <li>No fraudulent reviews, fake bookings, or chargeback abuse.</li>
        <li>Sitters and walkers must respect local animal welfare laws.</li>
      </ul>

      <h2>7. Reviews &amp; reputation</h2>
      <p>
        Both parties may leave a review after a completed booking. Reviews must
        reflect a real experience. We may remove reviews that violate these
        Terms or applicable law.
      </p>

      <h2>8. Intellectual property</h2>
      <p>
        The HoPetSit name, logo, application, website, and content are owned by
        CARDELLI HERMANOS LIMITED (trading as HoPetSit). You may not copy, reproduce, or distribute them
        without our prior written consent.
      </p>

      <h2>9. Liability</h2>
      <p>
        To the fullest extent permitted by law, CARDELLI HERMANOS LIMITED (trading as HoPetSit) is not liable
        for indirect or consequential damages arising from a booking. Our
        aggregate liability for any claim is limited to the platform fees we
        have collected from the affected booking.
      </p>

      <h2>10. Termination</h2>
      <p>
        We may suspend or terminate accounts that breach these Terms. You may
        delete your account at any time from the mobile app or by contacting us.
      </p>

      <h2>11. Governing law</h2>
      <p>
        These Terms are governed by the laws of Hong Kong SAR. Disputes shall
        be resolved by the competent courts of Hong Kong, without prejudice to
        mandatory consumer-protection rights in your country of residence.
      </p>

      <h2>12. Contact</h2>
      <p>
        Questions: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>
      </p>
    </LegalPage>
  );
}
