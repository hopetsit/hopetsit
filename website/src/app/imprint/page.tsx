"use client";

import { useT } from "@/lib/i18n/LanguageProvider";
import { LegalPage } from "@/components/LegalPage";

// Mentions légales — société Hong Kong CARDELLI HERMANOS LIMITED qui
// exploite la marque HoPetSit. Coordonnées officielles fournies par Daniel
// pour soumission Airwallex Payments product.
export default function ImprintPage() {
  const { t } = useT();
  return (
    <LegalPage title={t("imprint_title")} lastUpdated="April 25, 2026">
      <h2>Operating company</h2>
      <p>
        <strong>CARDELLI HERMANOS LIMITED</strong>
        <br />
        Trading as <strong>HoPetSit</strong>
        <br />
        Hong Kong Companies Registry — CR Number: <strong>2671528</strong>
        <br />
        Registered office: Flat/Rm A, 12/F, ZJ 300, 300 Lockhart Road, Wan Chai, Hong Kong
        <br />
        Director: Daniel Cardelli
      </p>

      <h2>Contact</h2>
      <p>
        General contact: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>
        <br />
        Press &amp; partnerships: same address with subject &quot;Press&quot; or &quot;Partnership&quot;.
      </p>

      <h2>Hosting</h2>
      <p>
        <strong>Application backend:</strong> Render Inc., 525 Brannan St, San Francisco,
        CA 94107, United States.
        <br />
        <strong>Website:</strong> Vercel Inc., 440 N Barranca Ave #4133, Covina, CA
        91723, United States.
        <br />
        <strong>Database:</strong> MongoDB Inc., 1633 Broadway, 38th Floor, New York,
        NY 10019, United States.
      </p>

      <h2>Payment processing</h2>
      <p>
        Card payments and payouts are processed by a regulated payment
        institution (currently in transition). Funds are held in segregated
        accounts pursuant to applicable e-money rules.
      </p>

      <h2>Intellectual property</h2>
      <p>
        The HoPetSit name, logo, mobile application, source code and website
        content are protected by copyright. © {new Date().getFullYear()} CARDELLI
        HERMANOS LIMITED. All rights reserved.
      </p>

      <h2>Editor of publication</h2>
      <p>Daniel Cardelli, Director of CARDELLI HERMANOS LIMITED.</p>

      <h2>Dispute resolution</h2>
      <p>
        For consumers in the EU, the European Commission provides an online
        dispute resolution platform at{" "}
        <a href="https://ec.europa.eu/consumers/odr" rel="noopener" target="_blank">
          ec.europa.eu/consumers/odr
        </a>
        . We are however available to resolve disputes directly via{" "}
        <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> within 48 hours.
      </p>
    </LegalPage>
  );
}
