/**
 * v23.1.147 — Contenus structurés des 4 docs légaux dans les 6 langues.
 *
 * Pourquoi ce fichier ?
 *   Avant : chaque doc avait 2 routes (genre /terms en EN + /cgu en FR) et le
 *   contenu était hardcodé en JSX. ES/DE/IT/PT n'existaient pas → un user
 *   espagnol voyait /terms en anglais.
 *
 *   Maintenant : 4 routes principales (/terms, /privacy, /refund, /imprint)
 *   qui détectent la langue active via useLang() et affichent le contenu
 *   approprié depuis ce fichier.
 *
 * Format :
 *   - Chaque doc = Record<Lang, { lastUpdated: string; sections: Section[] }>
 *   - Une Section est { type: 'h2' | 'p' | 'ul'; html: string | string[] }
 *   - html peut contenir des balises inline (<strong>, <a>, etc.) qu'on
 *     render via dangerouslySetInnerHTML côté composant.
 *
 * Traductions ES/DE/IT/PT générées par `translate_legal.py` à partir d'EN.
 * À re-générer si le contenu EN/FR change.
 */

import type { Lang } from "./i18n/translations";

export type LegalSection =
  | { type: "h2"; html: string }
  | { type: "p"; html: string }
  | { type: "ul"; html: string[] };

export type LegalDoc = {
  lastUpdated: string;
  sections: LegalSection[];
};

export type LegalDocByLang = Record<Lang, LegalDoc>;

// ──────────────────────────────────────────────────────────────────────────
// TERMS OF SERVICE
// ──────────────────────────────────────────────────────────────────────────

const TERMS_EN_SECTIONS: LegalSection[] = [
  { type: "p", html: `These Terms of Service (the "Terms") govern your use of the HoPetSit marketplace (the "Service"), operated by CARDELLI HERMANOS LIMITED (trading as HoPetSit), a company incorporated in Hong Kong (the "Company", "we", "us").` },
  { type: "h2", html: `1. The Service` },
  { type: "p", html: `HoPetSit is a marketplace connecting pet owners with independent pet sitters and dog walkers worldwide (177 countries, including the European Union, United Kingdom, Switzerland, Norway and the United States). We are <strong>not</strong> a provider of pet-care services ourselves. We facilitate matching, secure chat, payment processing and dispute resolution between users.` },
  { type: "h2", html: `2. Eligibility` },
  { type: "ul", html: [
    `You must be at least 18 years old to register as a sitter or walker.`,
    `Pet owners must be at least 18 years old or use the platform under the supervision of a legal guardian.`,
    `You must provide accurate, current and complete information at registration.`,
  ]},
  { type: "h2", html: `3. Account &amp; security` },
  { type: "p", html: `You are responsible for the activity on your account and for keeping your credentials confidential. Notify us at <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> as soon as you suspect unauthorised access.` },
  { type: "h2", html: `4. Bookings &amp; payments` },
  { type: "p", html: `Owners pay the gross booking amount via our regulated payment processor (Airwallex). HoPetSit retains a <strong>20% platform commission</strong>; the remaining <strong>80%</strong> is paid out to the provider's registered IBAN <strong>24 hours after the service ends</strong>, allowing a dispute window for the owner. Funds are held in escrow during this entire period and HoPetSit does not access them.` },
  { type: "h2", html: `5. Cancellations &amp; refunds` },
  { type: "p", html: `Owners can self-cancel for free up to <strong>72 hours before the service starts</strong> — the booking is cancelled immediately and a 100% automatic refund is issued. Within the 72-hour window, cancellations require a mutual agreement with the provider or a formal dispute. Provider-initiated cancellations always result in a full owner refund. See the full <a href="/refund">Refund Policy</a> for the complete process, deadlines and dispute procedure.` },
  { type: "h2", html: `6. Conduct` },
  { type: "ul", html: [
    `No harassment, hate speech, or harmful behaviour toward other users or animals.`,
    `No solicitation of contact details to bypass the platform's payment system.`,
    `No fraudulent reviews, fake bookings, or chargeback abuse.`,
    `Sitters and walkers must respect local animal welfare laws.`,
  ]},
  { type: "h2", html: `7. Reviews &amp; reputation` },
  { type: "p", html: `Both parties may leave a review after a completed booking. Reviews must reflect a real experience. We may remove reviews that violate these Terms or applicable law.` },
  { type: "h2", html: `8. Intellectual property` },
  { type: "p", html: `The HoPetSit name, logo, application, website, and content are owned by CARDELLI HERMANOS LIMITED (trading as HoPetSit). You may not copy, reproduce, or distribute them without our prior written consent.` },
  { type: "h2", html: `9. Liability` },
  { type: "p", html: `To the fullest extent permitted by law, CARDELLI HERMANOS LIMITED (trading as HoPetSit) is not liable for indirect or consequential damages arising from a booking. Our aggregate liability for any claim is limited to the platform fees we have collected from the affected booking.` },
  { type: "h2", html: `10. Termination` },
  { type: "p", html: `We may suspend or terminate accounts that breach these Terms. You may delete your account at any time from the mobile app or by contacting us.` },
  { type: "h2", html: `11. Governing law` },
  { type: "p", html: `These Terms are governed by the laws of Hong Kong SAR. Disputes shall be resolved by the competent courts of Hong Kong, without prejudice to mandatory consumer-protection rights in your country of residence.` },
  { type: "h2", html: `12. Contact` },
  { type: "p", html: `Questions: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
];

// PRIVACY POLICY
const PRIVACY_EN_SECTIONS: LegalSection[] = [
  { type: "p", html: `CARDELLI HERMANOS LIMITED (trading as HoPetSit) ("we", "us") is the data controller of personal data collected through the HoPetSit mobile application and website (the "Service"). This page explains what we collect, why, how long we keep it, and your rights — in accordance with the EU General Data Protection Regulation (GDPR), the UK GDPR and Hong Kong PDPO.` },
  { type: "h2", html: `1. Data we collect` },
  { type: "ul", html: [
    `<strong>Account data:</strong> name, email, phone (optional), city, role, password hash.`,
    `<strong>Profile data:</strong> avatar, bio, languages, services offered, rates, availability.`,
    `<strong>Booking data:</strong> dates, pets, prices, status, reviews.`,
    `<strong>Payment data:</strong> a token from our regulated payment provider — we never see your card number. Last 4 digits and brand are stored to display saved cards.`,
    `<strong>Communications:</strong> chat messages, support tickets, contact-form submissions.`,
    `<strong>Technical data:</strong> IP address, device type, app version, language, crash reports.`,
    `<strong>Location:</strong> only when you explicitly grant location permission to find providers near you or to publish a request.`,
  ]},
  { type: "h2", html: `2. Why we process it (legal basis)` },
  { type: "ul", html: [
    `<strong>Contract:</strong> creating and operating your account, processing bookings and payments.`,
    `<strong>Legitimate interest:</strong> fraud prevention, content moderation, product analytics.`,
    `<strong>Consent:</strong> marketing emails, push notifications, location access.`,
    `<strong>Legal obligation:</strong> tax records, anti-money-laundering compliance.`,
  ]},
  { type: "h2", html: `3. Sharing` },
  { type: "p", html: `We share data with:` },
  { type: "ul", html: [
    `The payment processor (PCI-DSS compliant) for card transactions and IBAN payouts.`,
    `Cloud infrastructure (Render, MongoDB, Cloudinary) under strict data-processing agreements.`,
    `Other users only as needed for a booking (e.g. your name and avatar are shown to the sitter you booked).`,
    `Authorities when required by law.`,
  ]},
  { type: "p", html: `We do <strong>not</strong> sell your data and do not use it for cross-platform advertising.` },
  { type: "h2", html: `4. Retention` },
  { type: "p", html: `Account data is kept while your account is active and 24 months after deletion (for fraud prevention). Booking and payment records are kept 10 years for tax compliance. Chat messages are kept for the lifetime of the conversation; soft-deleted messages remain visible to admin moderators only.` },
  { type: "h2", html: `5. Your rights` },
  { type: "ul", html: [
    `Right of access, rectification, erasure, restriction, portability and objection.`,
    `Right to withdraw consent at any time (push notifications, marketing).`,
    `Right to lodge a complaint with your local data-protection authority (e.g. CNIL in France).`,
  ]},
  { type: "p", html: `Exercise your rights at <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. We answer within 30 days.` },
  { type: "h2", html: `6. International transfers` },
  { type: "p", html: `Some of our processors are based outside the European Economic Area. Transfers are protected by the European Commission's Standard Contractual Clauses (SCCs) and equivalent safeguards under UK and Hong Kong law.` },
  { type: "h2", html: `7. Cookies` },
  { type: "p", html: `The website uses strictly necessary cookies for authentication and preferences. We do not use advertising or tracking cookies. The mobile app uses local storage and a notification token for push delivery.` },
  { type: "h2", html: `8. Children` },
  { type: "p", html: `The Service is not directed to children under 16. We do not knowingly collect data from minors.` },
  { type: "h2", html: `9. Changes` },
  { type: "p", html: `Material changes to this policy are notified in-app and by email (when you have opted in to product updates) at least 30 days before they take effect.` },
  { type: "h2", html: `10. Contact` },
  { type: "p", html: `Data Protection contact: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
];

// REFUND POLICY
const REFUND_EN_SECTIONS: LegalSection[] = [
  { type: "p", html: `This Refund Policy applies to all bookings made through the HoPetSit marketplace. It complements the <a href="/terms">Terms of Service</a> and reflects how cancellations and refunds are actually executed by our payment processor (Airwallex).` },
  { type: "h2", html: `1. How payments are held` },
  { type: "p", html: `When an owner pays for a confirmed booking, the funds are captured by our regulated payment processor (Airwallex) and held in escrow. They are released to the provider's registered bank account <strong>24 hours after the service ends</strong> — this dispute window protects the owner if anything goes wrong during the service.` },
  { type: "h2", html: `2. Cancellation by the owner — 72-hour free window` },
  { type: "ul", html: [
    `<strong>More than 72 hours before the service starts:</strong> You can self-cancel from the app. The booking is cancelled immediately and you receive a <strong>100% automatic refund</strong> (no questions asked). Funds typically reach your bank within 5–10 business days.`,
    `<strong>72 hours or less before the service starts:</strong> Self-cancellation is no longer available. You must request a <strong>mutual cancellation</strong> from your provider in the chat, or open a formal dispute via <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. Refunds within this window are reviewed case-by-case based on the reason and any evidence.`,
  ]},
  { type: "h2", html: `3. Cancellation by the provider` },
  { type: "p", html: `If your sitter or walker cancels a confirmed booking — at any time before the service starts — you receive a <strong>100% automatic refund</strong>. The provider may incur a cancellation fee, visibility downgrade or platform suspension if cancellations become repeated, to protect the trust of owners on the platform.` },
  { type: "h2", html: `4. Service not delivered (no-show, sitter unreachable)` },
  { type: "p", html: `If the service was paid for but never delivered, you can open a dispute within <strong>24 hours of the scheduled service end</strong> via the chat or by emailing <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. After verification (chat history, photos, GPS check-ins, ratings), we issue a full refund within 5 business days.` },
  { type: "h2", html: `5. Service materially different from what was agreed` },
  { type: "p", html: `Partial refunds may be granted at our discretion when the service was materially different from what was agreed (significantly shorter duration, conditions clearly violated, etc.). Both parties have the opportunity to share evidence in the dispute.` },
  { type: "h2", html: `6. Force majeure` },
  { type: "p", html: `Documented force majeure events affecting either party (severe illness with medical proof, natural disaster, government-imposed travel ban, death of the pet, etc.) are reviewed case-by-case regardless of the standard timeline. Refunds may be granted on presentation of appropriate evidence.` },
  { type: "h2", html: `7. How refunds are issued` },
  { type: "p", html: `Refunds are issued back to the original payment method (the card used at checkout, via Airwallex). Funds typically arrive within <strong>5 to 10 business days</strong> depending on your bank.` },
  { type: "h2", html: `8. Chargebacks` },
  { type: "p", html: `We strongly encourage owners to use HoPetSit's internal dispute mechanism before initiating a chargeback with their card issuer. Owners initiating chargebacks without first contacting us, or while a dispute is already active, may forfeit our internal resolution process and may be permanently removed from the platform. We cooperate fully with Airwallex on legitimate chargeback investigations.` },
  { type: "h2", html: `9. Contact` },
  { type: "p", html: `Refund requests, disputes and questions: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> · we aim to reply within 48 hours.` },
];

// IMPRINT / LEGAL NOTICE
const IMPRINT_EN_SECTIONS: LegalSection[] = [
  { type: "h2", html: `Operating company` },
  { type: "p", html: `<strong>CARDELLI HERMANOS LIMITED</strong><br/>Trading as <strong>HoPetSit</strong><br/>Hong Kong Companies Registry — CR Number: <strong>2671528</strong><br/>Registered office: Flat/Rm A, 12/F, ZJ 300, 300 Lockhart Road, Wan Chai, Hong Kong<br/>Director: Daniel Cardelli` },
  { type: "h2", html: `Contact` },
  { type: "p", html: `General contact: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a><br/>Press &amp; partnerships: same address with subject "Press" or "Partnership".` },
  { type: "h2", html: `Hosting` },
  { type: "p", html: `<strong>Application backend:</strong> Render Inc., 525 Brannan St, San Francisco, CA 94107, United States.<br/><strong>Website:</strong> Vercel Inc., 440 N Barranca Ave #4133, Covina, CA 91723, United States.<br/><strong>Database:</strong> MongoDB Inc., 1633 Broadway, 38th Floor, New York, NY 10019, United States.` },
  { type: "h2", html: `Payment processing` },
  { type: "p", html: `Card payments and payouts are processed by a regulated payment institution (currently in transition). Funds are held in segregated accounts pursuant to applicable e-money rules.` },
  { type: "h2", html: `Intellectual property` },
  { type: "p", html: `The HoPetSit name, logo, mobile application, source code and website content are protected by copyright. © CARDELLI HERMANOS LIMITED. All rights reserved.` },
  { type: "h2", html: `Editor of publication` },
  { type: "p", html: `Daniel Cardelli, Director of CARDELLI HERMANOS LIMITED.` },
  { type: "h2", html: `Dispute resolution` },
  { type: "p", html: `For consumers in the EU, the European Commission provides an online dispute resolution platform at <a href="https://ec.europa.eu/consumers/odr" rel="noopener" target="_blank">ec.europa.eu/consumers/odr</a>. We are however available to resolve disputes directly via <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> within 48 hours.` },
];

// ──────────────────────────────────────────────────────────────────────────
// EXPORTED MAPS — populated by translate_legal.py
// Note : pour l'instant FR/ES/DE/IT/PT pointent sur EN (fallback) en
// attendant que translate_legal.py génère les vraies traductions. Le script
// écrira directement ce fichier en remplaçant les pointeurs par les sections
// traduites.
// ──────────────────────────────────────────────────────────────────────────

const placeholder = (sections: LegalSection[]): LegalDoc => ({
  lastUpdated: "April 25, 2026",
  sections,
});

export const TERMS: LegalDocByLang = {
  en: {
    lastUpdated: "April 25, 2026",
    sections: [
    { type: "p", html: `These Terms of Service (the "Terms") govern your use of the HoPetSit marketplace (the "Service"), operated by CARDELLI HERMANOS LIMITED (trading as HoPetSit), a company incorporated in Hong Kong (the "Company", "we", "us").` },
    { type: "h2", html: `1. The Service` },
    { type: "p", html: `HoPetSit is a marketplace connecting pet owners with independent pet sitters and dog walkers worldwide (177 countries, including the European Union, United Kingdom, Switzerland, Norway and the United States). We are <strong>not</strong> a provider of pet-care services ourselves. We facilitate matching, secure chat, payment processing and dispute resolution between users.` },
    { type: "h2", html: `2. Eligibility` },
    { type: "ul", html: [
      `You must be at least 18 years old to register as a sitter or walker.`,
      `Pet owners must be at least 18 years old or use the platform under the supervision of a legal guardian.`,
      `You must provide accurate, current and complete information at registration.`
    ]},
    { type: "h2", html: `3. Account &amp; security` },
    { type: "p", html: `You are responsible for the activity on your account and for keeping your credentials confidential. Notify us at <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> as soon as you suspect unauthorised access.` },
    { type: "h2", html: `4. Bookings &amp; payments` },
    { type: "p", html: `Owners pay the gross booking amount via our regulated payment processor (Airwallex). HoPetSit retains a <strong>20% platform commission</strong>; the remaining <strong>80%</strong> is paid out to the provider's registered IBAN <strong>24 hours after the service ends</strong>, allowing a dispute window for the owner. Funds are held in escrow during this entire period and HoPetSit does not access them.` },
    { type: "h2", html: `5. Cancellations &amp; refunds` },
    { type: "p", html: `Owners can self-cancel for free up to <strong>72 hours before the service starts</strong> — the booking is cancelled immediately and a 100% automatic refund is issued. Within the 72-hour window, cancellations require a mutual agreement with the provider or a formal dispute. Provider-initiated cancellations always result in a full owner refund. See the full <a href="/refund">Refund Policy</a> for the complete process, deadlines and dispute procedure.` },
    { type: "h2", html: `6. Conduct` },
    { type: "ul", html: [
      `No harassment, hate speech, or harmful behaviour toward other users or animals.`,
      `No solicitation of contact details to bypass the platform's payment system.`,
      `No fraudulent reviews, fake bookings, or chargeback abuse.`,
      `Sitters and walkers must respect local animal welfare laws.`
    ]},
    { type: "h2", html: `7. Reviews &amp; reputation` },
    { type: "p", html: `Both parties may leave a review after a completed booking. Reviews must reflect a real experience. We may remove reviews that violate these Terms or applicable law.` },
    { type: "h2", html: `8. Intellectual property` },
    { type: "p", html: `The HoPetSit name, logo, application, website, and content are owned by CARDELLI HERMANOS LIMITED (trading as HoPetSit). You may not copy, reproduce, or distribute them without our prior written consent.` },
    { type: "h2", html: `9. Liability` },
    { type: "p", html: `To the fullest extent permitted by law, CARDELLI HERMANOS LIMITED (trading as HoPetSit) is not liable for indirect or consequential damages arising from a booking. Our aggregate liability for any claim is limited to the platform fees we have collected from the affected booking.` },
    { type: "h2", html: `10. Termination` },
    { type: "p", html: `We may suspend or terminate accounts that breach these Terms. You may delete your account at any time from the mobile app or by contacting us.` },
    { type: "h2", html: `11. Governing law` },
    { type: "p", html: `These Terms are governed by the laws of Hong Kong SAR. Disputes shall be resolved by the competent courts of Hong Kong, without prejudice to mandatory consumer-protection rights in your country of residence.` },
    { type: "h2", html: `12. Contact` },
    { type: "p", html: `Questions: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  fr: {
    lastUpdated: "25 avril 2026",
    sections: [
    { type: "p", html: `Les présentes conditions d'utilisation (les « Conditions ») régissent votre utilisation du marché HoPetSit (le « Service »), exploité par CARDELLI HERMANOS LIMITED (exerçant ses activités sous le nom de HoPetSit), une société constituée à Hong Kong (la « Société », « nous », « notre »).` },
    { type: "h2", html: `1. Le service` },
    { type: "p", html: `HoPetSit est une place de marché mettant en relation les propriétaires d'animaux avec des gardiens d'animaux indépendants et des promeneurs de chiens partout dans le monde (177 pays, dont l'Union européenne, le Royaume-Uni, la Suisse, la Norvège et les États-Unis). Nous sommes nous-mêmes <strong>not</strong> un fournisseur de services de soins pour animaux de compagnie. Nous facilitons la mise en relation, le chat sécurisé, le traitement des paiements et la résolution des litiges entre utilisateurs.` },
    { type: "h2", html: `2. Éligibilité` },
    { type: "ul", html: [
      `Vous devez avoir au moins 18 ans pour vous inscrire en tant que gardien ou marcheur.`,
      `Les propriétaires d'animaux doivent être âgés d'au moins 18 ans ou utiliser la plateforme sous la surveillance d'un tuteur légal.`,
      `Vous devez fournir des informations exactes, à jour et complètes lors de l’inscription.`
    ]},
    { type: "h2", html: `3. Compte et compte sécurité` },
    { type: "p", html: `Vous êtes responsable de l’activité sur votre compte et de la confidentialité de vos informations d’identification. Informez-nous à <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> dès que vous soupçonnez un accès non autorisé.` },
    { type: "h2", html: `4. Réservations et réservations paiements` },
    { type: "p", html: `Les propriétaires paient le montant brut de la réservation via notre processeur de paiement réglementé (Airwallex). HoPetSit conserve une commission de plateforme <strong>20%</strong> ; le <strong>80%</strong> restant est versé sur l'IBAN <strong>24 enregistré par le fournisseur 24 heures après la fin du service</strong>, permettant ainsi une fenêtre de litige pour le propriétaire. Les fonds sont bloqués pendant toute cette période et HoPetSit n'y a pas accès.` },
    { type: "h2", html: `5. Annulations et réservations remboursements` },
    { type: "p", html: `Les propriétaires peuvent s'annuler eux-mêmes gratuitement jusqu'à <strong>72 heures avant le début du service</strong> — la réservation est annulée immédiatement et un remboursement automatique à 100 % est émis. Dans le délai de 72 heures, les annulations nécessitent un accord mutuel avec le prestataire ou une contestation formelle. Les annulations initiées par le fournisseur entraînent toujours un remboursement intégral du propriétaire. Consultez la politique de remboursement complète <a href="/refund"></a> pour connaître le processus complet, les délais et la procédure de litige.` },
    { type: "h2", html: `6. Conduite` },
    { type: "ul", html: [
      `Pas de harcèlement, discours de haine ou comportement préjudiciable envers les autres utilisateurs ou animaux.`,
      `Pas de sollicitation de coordonnées pour contourner le système de paiement de la plateforme.`,
      `Pas d'avis frauduleux, de fausses réservations ou d'abus de rétrofacturation.`,
      `Les gardiens et les promeneurs doivent respecter les lois locales sur le bien-être des animaux.`
    ]},
    { type: "h2", html: `7. Avis et avis réputation` },
    { type: "p", html: `Les deux parties peuvent laisser un avis une fois la réservation terminée. Les avis doivent refléter une expérience réelle. Nous pouvons supprimer les avis qui enfreignent les présentes Conditions ou la loi applicable.` },
    { type: "h2", html: `8. Propriété intellectuelle` },
    { type: "p", html: `Le nom, le logo, l'application, le site Web et le contenu HoPetSit sont la propriété de CARDELLI HERMANOS LIMITED (sous le nom de HoPetSit). Vous ne pouvez pas les copier, les reproduire ou les distribuer sans notre consentement écrit préalable.` },
    { type: "h2", html: `9. Responsabilité` },
    { type: "p", html: `Dans toute la mesure permise par la loi, CARDELLI HERMANOS LIMITED (sous le nom de HoPetSit) n'est pas responsable des dommages indirects ou consécutifs découlant d'une réservation. Notre responsabilité globale pour toute réclamation est limitée aux frais de plateforme que nous avons perçus pour la réservation concernée.` },
    { type: "h2", html: `10. Résiliation` },
    { type: "p", html: `Nous pouvons suspendre ou résilier les comptes qui enfreignent ces Conditions. Vous pouvez supprimer votre compte à tout moment depuis l'application mobile ou en nous contactant.` },
    { type: "h2", html: `11. Loi applicable` },
    { type: "p", html: `Les présentes Conditions sont régies par les lois de la RAS de Hong Kong. Les litiges seront résolus par les tribunaux compétents de Hong Kong, sans préjudice des droits obligatoires de protection des consommateurs dans votre pays de résidence.` },
    { type: "h2", html: `12. Contacter` },
    { type: "p", html: `Questions : <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  es: {
    lastUpdated: "25 de abril de 2026",
    sections: [
    { type: "p", html: `Estos Términos de servicio (los "Términos") rigen su uso del mercado HoPetSit (el "Servicio"), operado por CARDELLI HERMANOS LIMITED (que opera como HoPetSit), una empresa constituida en Hong Kong (la "Compañía", "nosotros", "nos").` },
    { type: "h2", html: `1. El Servicio` },
    { type: "p", html: `HoPetSit es un mercado que conecta a los dueños de mascotas con cuidadores de mascotas y paseadores de perros independientes en todo el mundo (177 países, incluidos la Unión Europea, el Reino Unido, Suiza, Noruega y los Estados Unidos). Somos <strong>not</strong> un proveedor de servicios de cuidado de mascotas. Facilitamos la coincidencia, el chat seguro, el procesamiento de pagos y la resolución de disputas entre usuarios.` },
    { type: "h2", html: `2. Elegibilidad` },
    { type: "ul", html: [
      `Debes tener al menos 18 años para registrarte como cuidador o paseador.`,
      `Los dueños de mascotas deben tener al menos 18 años o utilizar la plataforma bajo la supervisión de un tutor legal.`,
      `Debe proporcionar información precisa, actual y completa en el momento del registro.`
    ]},
    { type: "h2", html: `3. Cuenta y cuenta seguridad` },
    { type: "p", html: `Usted es responsable de la actividad de su cuenta y de mantener la confidencialidad de sus credenciales. Notifíquenos a <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> tan pronto como sospeche de un acceso no autorizado.` },
    { type: "h2", html: `4. Reservas y pagos` },
    { type: "p", html: `Los propietarios pagan el importe bruto de la reserva a través de nuestro procesador de pagos regulado (Airwallex). HoPetSit retiene una comisión de plataforma <strong>20%</strong>; el <strong>80%</strong> restante se paga al IBAN registrado del proveedor <strong>24 horas después de que finalice el servicio</strong>, lo que permite una ventana de disputa para el propietario. Los fondos se mantienen en custodia durante todo este período y HoPetSit no accede a ellos.` },
    { type: "h2", html: `5. Cancelaciones y reembolsos` },
    { type: "p", html: `Los propietarios pueden cancelar su reserva de forma gratuita hasta <strong>72 horas antes de que comience el servicio</strong>: la reserva se cancela inmediatamente y se emite un reembolso 100% automático. Dentro del plazo de 72 horas, las cancelaciones requieren un acuerdo mutuo con el proveedor o una disputa formal. Las cancelaciones iniciadas por el proveedor siempre resultan en un reembolso completo al propietario. Consulte la Política de reembolso <a href="/refund"></a> completa para conocer el proceso completo, los plazos y el procedimiento de disputa.` },
    { type: "h2", html: `6. Conducta` },
    { type: "ul", html: [
      `No se permiten acosos, discursos de odio o comportamientos dañinos hacia otros usuarios o animales.`,
      `No se solicitan datos de contacto para eludir el sistema de pago de la plataforma.`,
      `Sin reseñas fraudulentas, reservas falsas ni abuso de contracargos.`,
      `Los cuidadores y paseadores deben respetar las leyes locales de bienestar animal.`
    ]},
    { type: "h2", html: `7. Reseñas y comentarios reputación` },
    { type: "p", html: `Ambas partes pueden dejar una reseña después de completar la reserva. Las reseñas deben reflejar una experiencia real. Podemos eliminar reseñas que violen estos Términos o la ley aplicable.` },
    { type: "h2", html: `8. Propiedad intelectual` },
    { type: "p", html: `El nombre, el logotipo, la aplicación, el sitio web y el contenido de HoPetSit son propiedad de CARDELLI HERMANOS LIMITED (que opera como HoPetSit). No puede copiarlos, reproducirlos ni distribuirlos sin nuestro consentimiento previo por escrito.` },
    { type: "h2", html: `9. Responsabilidad` },
    { type: "p", html: `En la máxima medida permitida por la ley, CARDELLI HERMANOS LIMITED (que opera como HoPetSit) no es responsable de los daños indirectos o consecuentes que surjan de una reserva. Nuestra responsabilidad total por cualquier reclamación se limita a las tarifas de plataforma que hayamos cobrado de la reserva afectada.` },
    { type: "h2", html: `10. Terminación` },
    { type: "p", html: `Podemos suspender o cancelar cuentas que infrinjan estos Términos. Puede eliminar su cuenta en cualquier momento desde la aplicación móvil o contactándonos.` },
    { type: "h2", html: `11. Ley aplicable` },
    { type: "p", html: `Estos Términos se rigen por las leyes de la RAE de Hong Kong. Las disputas serán resueltas por los tribunales competentes de Hong Kong, sin perjuicio de los derechos obligatorios de protección del consumidor en su país de residencia.` },
    { type: "h2", html: `12. Contacto` },
    { type: "p", html: `Preguntas: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  de: {
    lastUpdated: "25. April 2026",
    sections: [
    { type: "p", html: `Diese Nutzungsbedingungen (die „Bedingungen“) regeln Ihre Nutzung des HoPetSit-Marktplatzes (der „Dienst“), der von CARDELLI HERMANOS LIMITED (firmierend als HoPetSit), einem in Hongkong eingetragenen Unternehmen (das „Unternehmen“, „wir“, „uns“), betrieben wird.` },
    { type: "h2", html: `1. Der Dienst` },
    { type: "p", html: `HoPetSit ist ein Marktplatz, der Tierbesitzer mit unabhängigen Tiersittern und Hundeführern weltweit (177 Länder, einschließlich der Europäischen Union, des Vereinigten Königreichs, der Schweiz, Norwegens und der USA) verbindet. Wir sind selbst <strong>nicht</strong> ein Anbieter von Haustierbetreuungsdiensten. Wir ermöglichen Matching, sicheren Chat, Zahlungsabwicklung und Streitbeilegung zwischen Benutzern.` },
    { type: "h2", html: `2. Teilnahmeberechtigung` },
    { type: "ul", html: [
      `Um sich als Sitter oder Walker anzumelden, müssen Sie mindestens 18 Jahre alt sein.`,
      `Tierhalter müssen mindestens 18 Jahre alt sein oder die Plattform unter Aufsicht eines Erziehungsberechtigten nutzen.`,
      `Bei der Registrierung müssen Sie genaue, aktuelle und vollständige Angaben machen.`
    ]},
    { type: "h2", html: `3. Konto &amp; Sicherheit` },
    { type: "p", html: `Sie sind für die Aktivitäten auf Ihrem Konto und für die Geheimhaltung Ihrer Zugangsdaten verantwortlich. Benachrichtigen Sie uns unter <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>, sobald Sie den Verdacht eines unbefugten Zugriffs haben.` },
    { type: "h2", html: `4. Buchungen &amp; Zahlungen` },
    { type: "p", html: `Eigentümer zahlen den Bruttobuchungsbetrag über unseren regulierten Zahlungsabwickler (Airwallex). HoPetSit behält eine Plattformprovision von <strong>20 %</strong>; Die verbleibenden <strong>80%</strong> werden 24 Stunden nach Ende des Dienstes an die beim Anbieter registrierte IBAN <strong> ausgezahlt</strong>, sodass dem Eigentümer ein Streitzeitfenster zur Verfügung steht. Die Gelder werden während dieses gesamten Zeitraums treuhänderisch verwaltet und HoPetSit hat keinen Zugriff darauf.` },
    { type: "h2", html: `5. Stornierungen &amp; Rückerstattungen` },
    { type: "p", html: `Eigentümer können bis zu <strong>72 Stunden vor Beginn des Dienstes kostenlos selbst stornieren. Die Buchung wird sofort storniert und eine 100-prozentige automatische Rückerstattung erfolgt. Innerhalb des 72-Stunden-Fensters erfordern Stornierungen eine gegenseitige Vereinbarung mit dem Anbieter oder eine formelle Streitigkeit. Vom Anbieter veranlasste Stornierungen führen immer zu einer vollständigen Rückerstattung des Mietpreises durch den Eigentümer. Den vollständigen Prozess, die Fristen und das Streitbeilegungsverfahren finden Sie in der vollständigen <a href="/refund">Rückerstattungsrichtlinie</a>.` },
    { type: "h2", html: `6. Verhalten` },
    { type: "ul", html: [
      `Keine Belästigung, Hassrede oder schädliches Verhalten gegenüber anderen Benutzern oder Tieren.`,
      `Keine Abfrage von Kontaktdaten zur Umgehung des Zahlungssystems der Plattform.`,
      `Keine betrügerischen Bewertungen, gefälschten Buchungen oder Missbrauch von Rückbuchungen.`,
      `Sitter und Spaziergänger müssen die örtlichen Tierschutzgesetze respektieren.`
    ]},
    { type: "h2", html: `7. Bewertungen &amp; Ruf` },
    { type: "p", html: `Beide Parteien können nach einer abgeschlossenen Buchung eine Bewertung abgeben. Bewertungen müssen ein echtes Erlebnis widerspiegeln. Wir können Bewertungen entfernen, die gegen diese Bedingungen oder geltendes Recht verstoßen.` },
    { type: "h2", html: `8. Geistiges Eigentum` },
    { type: "p", html: `Der Name, das Logo, die Anwendung, die Website und der Inhalt von HoPetSit sind Eigentum von CARDELLI HERMANOS LIMITED (firmierend als HoPetSit). Sie dürfen sie ohne unsere vorherige schriftliche Zustimmung nicht kopieren, reproduzieren oder verbreiten.` },
    { type: "h2", html: `9. Haftung` },
    { type: "p", html: `Soweit gesetzlich zulässig, haftet CARDELLI HERMANOS LIMITED (firmierend als HoPetSit) nicht für indirekte Schäden oder Folgeschäden, die sich aus einer Buchung ergeben. Unsere Gesamthaftung für etwaige Ansprüche ist auf die Plattformgebühren beschränkt, die wir für die betroffene Buchung erhoben haben.` },
    { type: "h2", html: `10. Kündigung` },
    { type: "p", html: `Wir können Konten sperren oder kündigen, die gegen diese Bedingungen verstoßen. Sie können Ihr Konto jederzeit über die mobile App oder durch Kontaktaufnahme mit uns löschen.` },
    { type: "h2", html: `11. Anwendbares Recht` },
    { type: "p", html: `Diese Bedingungen unterliegen den Gesetzen der Sonderverwaltungszone Hongkong. Streitigkeiten werden von den zuständigen Gerichten in Hongkong beigelegt, unbeschadet der zwingenden Verbraucherschutzrechte in Ihrem Wohnsitzland.` },
    { type: "h2", html: `12. Kontakt` },
    { type: "p", html: `Fragen: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  it: {
    lastUpdated: "25 aprile 2026",
    sections: [
    { type: "p", html: `I presenti Termini di servizio (i "Termini") regolano l'utilizzo del mercato HoPetSit (il "Servizio"), gestito da CARDELLI HERMANOS LIMITED (operante come HoPetSit), una società costituita a Hong Kong (la "Società", "noi", "ci").` },
    { type: "h2", html: `1. Il Servizio` },
    { type: "p", html: `HoPetSit è un mercato che mette in contatto i proprietari di animali domestici con pet sitter e dog sitter indipendenti in tutto il mondo (177 paesi, inclusi Unione Europea, Regno Unito, Svizzera, Norvegia e Stati Uniti). Siamo <strong>not</strong> un fornitore di servizi per la cura degli animali domestici. Facilitiamo l'abbinamento, la chat sicura, l'elaborazione dei pagamenti e la risoluzione delle controversie tra gli utenti.` },
    { type: "h2", html: `2. Idoneità` },
    { type: "ul", html: [
      `Devi avere almeno 18 anni per registrarti come sitter o walker.`,
      `I proprietari di animali domestici devono avere almeno 18 anni o utilizzare la piattaforma sotto la supervisione di un tutore legale.`,
      `È necessario fornire informazioni accurate, aggiornate e complete al momento della registrazione.`
    ]},
    { type: "h2", html: `3. Conto e sicurezza` },
    { type: "p", html: `Sei responsabile dell'attività del tuo account e della riservatezza delle tue credenziali. Avvisateci a <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> non appena sospetti un accesso non autorizzato.` },
    { type: "h2", html: `4. Prenotazioni e servizi pagamenti` },
    { type: "p", html: `I proprietari pagano l'importo lordo della prenotazione tramite il nostro sistema di pagamento regolamentato (Airwallex). HoPetSit trattiene una commissione sulla piattaforma <strong>20%</strong>; il restante <strong>80%</strong> viene pagato all'IBAN registrato <strong> del fornitore 24 ore dopo la fine del servizio</strong>, consentendo una finestra di controversia per il proprietario. I fondi vengono tenuti in garanzia durante l'intero periodo e HoPetSit non vi accede.` },
    { type: "h2", html: `5. Cancellazioni e rinunce rimborsi` },
    { type: "p", html: `I proprietari possono annullare autonomamente la prenotazione gratuitamente fino a <strong>72 ore prima dell'inizio del servizio</strong>: la prenotazione viene annullata immediatamente e viene emesso un rimborso automatico al 100%. Entro la finestra di 72 ore, le cancellazioni richiedono un accordo reciproco con il fornitore o una controversia formale. Le cancellazioni avviate dal fornitore comportano sempre un rimborso completo al proprietario. Consulta la <a href="/refund">Politica di rimborso</a> per il processo completo, le scadenze e la procedura di controversia.` },
    { type: "h2", html: `6. Condotta` },
    { type: "ul", html: [
      `Nessuna molestia, incitamento all'odio o comportamento dannoso nei confronti di altri utenti o animali.`,
      `Nessuna richiesta di dettagli di contatto per aggirare il sistema di pagamento della piattaforma.`,
      `Nessuna recensione fraudolenta, prenotazione falsa o abuso di chargeback.`,
      `I sitter e i camminatori devono rispettare le leggi locali sul benessere degli animali.`
    ]},
    { type: "h2", html: `7. Recensioni e informazioni reputazione` },
    { type: "p", html: `Entrambe le parti possono lasciare una recensione dopo una prenotazione completata. Le recensioni devono riflettere un'esperienza reale. Potremmo rimuovere le recensioni che violano i presenti Termini o la legge applicabile.` },
    { type: "h2", html: `8. Proprietà intellettuale` },
    { type: "p", html: `Il nome, il logo, l'applicazione, il sito Web e i contenuti di HoPetSit sono di proprietà di CARDELLI HERMANOS LIMITED (operante come HoPetSit). Non è possibile copiarli, riprodurli o distribuirli senza il nostro previo consenso scritto.` },
    { type: "h2", html: `9. Responsabilità` },
    { type: "p", html: `Nella misura massima consentita dalla legge, CARDELLI HERMANOS LIMITED (operante come HoPetSit) non è responsabile per danni indiretti o consequenziali derivanti da una prenotazione. La nostra responsabilità complessiva per qualsiasi reclamo è limitata alle tariffe della piattaforma che abbiamo riscosso dalla prenotazione interessata.` },
    { type: "h2", html: `10. Risoluzione` },
    { type: "p", html: `Potremo sospendere o chiudere gli account che violano i presenti Termini. Puoi eliminare il tuo account in qualsiasi momento dall'app mobile o contattandoci.` },
    { type: "h2", html: `11. Legge applicabile` },
    { type: "p", html: `I presenti Termini sono regolati dalle leggi della Regione Amministrativa Speciale di Hong Kong. Le controversie saranno risolte dai tribunali competenti di Hong Kong, fatti salvi i diritti obbligatori di protezione dei consumatori nel tuo paese di residenza.` },
    { type: "h2", html: `12. Contatto` },
    { type: "p", html: `Domande: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  pt: {
    lastUpdated: "25 de abril de 2026",
    sections: [
    { type: "p", html: `Estes Termos de Serviço (os "Termos") regem o uso do mercado HoPetSit (o "Serviço"), operado pela CARDELLI HERMANOS LIMITED (negociando como HoPetSit), uma empresa constituída em Hong Kong (a "Empresa", "nós", "nos").` },
    { type: "h2", html: `1. O serviço` },
    { type: "p", html: `HoPetSit é um mercado que conecta proprietários de animais de estimação a babás e passeadores de cães independentes em todo o mundo (177 países, incluindo União Europeia, Reino Unido, Suíça, Noruega e Estados Unidos). Somos <strong>not</strong>, fornecedores de serviços de cuidados com animais de estimação. Facilitamos a correspondência, bate-papo seguro, processamento de pagamentos e resolução de disputas entre usuários.` },
    { type: "h2", html: `2. Elegibilidade` },
    { type: "ul", html: [
      `Você deve ter pelo menos 18 anos para se registrar como babá ou andador.`,
      `Os donos de animais de estimação devem ter pelo menos 18 anos ou utilizar a plataforma sob supervisão de um responsável legal.`,
      `Você deve fornecer informações precisas, atuais e completas no momento do registro.`
    ]},
    { type: "h2", html: `3. Conta e conta segurança` },
    { type: "p", html: `Você é responsável pela atividade em sua conta e por manter a confidencialidade de suas credenciais. Notifique-nos em <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> assim que suspeitar de acesso não autorizado.` },
    { type: "h2", html: `4. Reservas e visitas pagamentos` },
    { type: "p", html: `Os proprietários pagam o valor bruto da reserva através do nosso processador de pagamentos regulamentado (Airwallex). HoPetSit retém uma comissão de plataforma <strong>20%</strong>; o restante <strong>80%</strong> é pago ao IBAN registrado do provedor <strong>24 horas após o término do serviço</strong>, permitindo uma janela de disputa para o proprietário. Os fundos são mantidos em custódia durante todo esse período e o HoPetSit não tem acesso a eles.` },
    { type: "h2", html: `5. Cancelamentos e cancelamentos reembolsos` },
    { type: "p", html: `Os proprietários podem cancelar gratuitamente até <strong>72 horas antes do início do serviço</strong> — a reserva é cancelada imediatamente e um reembolso 100% automático é emitido. Dentro do período de 72 horas, os cancelamentos exigem um acordo mútuo com o fornecedor ou uma disputa formal. Os cancelamentos iniciados pelo provedor sempre resultam em um reembolso total ao proprietário. Consulte a Política de Reembolso <a href="/refund"> completa</a> para o processo completo, prazos e procedimento de disputa.` },
    { type: "h2", html: `6. Conduta` },
    { type: "ul", html: [
      `Nenhum assédio, discurso de ódio ou comportamento prejudicial a outros usuários ou animais.`,
      `Nenhuma solicitação de dados de contato para contornar o sistema de pagamento da plataforma.`,
      `Sem avaliações fraudulentas, reservas falsas ou abuso de estorno.`,
      `Os acompanhantes e acompanhantes devem respeitar as leis locais de bem-estar animal.`
    ]},
    { type: "h2", html: `7. Críticas e avaliações reputação` },
    { type: "p", html: `Ambas as partes podem deixar um comentário após a conclusão da reserva. As avaliações devem refletir uma experiência real. Poderemos remover comentários que violem estes Termos ou a lei aplicável.` },
    { type: "h2", html: `8. Propriedade intelectual` },
    { type: "p", html: `O nome, logotipo, aplicativo, site e conteúdo do HoPetSit são propriedade da CARDELLI HERMANOS LIMITED (negociada como HoPetSit). Você não pode copiá-los, reproduzi-los ou distribuí-los sem nosso consentimento prévio por escrito.` },
    { type: "h2", html: `9. Responsabilidade` },
    { type: "p", html: `Em toda a extensão permitida por lei, CARDELLI HERMANOS LIMITED (negociando como HoPetSit) não é responsável por danos indiretos ou consequenciais decorrentes de uma reserva. A nossa responsabilidade agregada por qualquer reclamação está limitada às taxas de plataforma que cobramos da reserva afetada.` },
    { type: "h2", html: `10. Rescisão` },
    { type: "p", html: `Poderemos suspender ou encerrar contas que violem estes Termos. Você pode excluir sua conta a qualquer momento pelo aplicativo móvel ou entrando em contato conosco.` },
    { type: "h2", html: `11. Lei aplicável` },
    { type: "p", html: `Estes Termos são regidos pelas leis da RAE de Hong Kong. Os litígios serão resolvidos pelos tribunais competentes de Hong Kong, sem prejuízo dos direitos obrigatórios de proteção do consumidor no seu país de residência.` },
    { type: "h2", html: `12. Contato` },
    { type: "p", html: `Perguntas: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  ko: {
    lastUpdated: "2026년 4월 25일",
    sections: [
    { type: "p", html: `본 서비스 이용약관(이하 "약관")은 홍콩에서 설립된 회사인 CARDELLI HERMANOS LIMITED(HoPetSit이라는 상호로 영업, 이하 "회사", "당사")가 운영하는 HoPetSit 마켓플레이스(이하 "서비스")의 이용에 적용됩니다.` },
    { type: "h2", html: `1. 서비스` },
    { type: "p", html: `HoPetSit은 반려동물 소유자와 독립적인 펫시터 및 도그워커를 전 세계(유럽연합, 영국, 스위스, 노르웨이, 미국을 포함한 177개국)에서 연결하는 마켓플레이스입니다. 당사는 반려동물 돌봄 서비스를 직접 제공하지 <strong>않습니다</strong>. 당사는 이용자 간의 매칭, 안전한 채팅, 결제 처리 및 분쟁 해결을 지원합니다.` },
    { type: "h2", html: `2. 이용 자격` },
    { type: "ul", html: [
      `펫시터 또는 도그워커로 등록하려면 만 18세 이상이어야 합니다.`,
      `반려동물 소유자는 만 18세 이상이거나 법정대리인의 감독하에 플랫폼을 이용해야 합니다.`,
      `등록 시 정확하고 최신이며 완전한 정보를 제공해야 합니다.`
    ]},
    { type: "h2", html: `3. 계정 및 보안` },
    { type: "p", html: `귀하는 귀하의 계정에서 이루어지는 활동과 계정 정보의 기밀 유지에 대한 책임이 있습니다. 무단 접근이 의심되는 즉시 <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>으로 알려 주십시오.` },
    { type: "h2", html: `4. 예약 및 결제` },
    { type: "p", html: `소유자는 규제 대상 결제 처리업체(Airwallex)를 통해 예약 총액을 결제합니다. HoPetSit은 <strong>20% 플랫폼 수수료</strong>를 보유하며, 나머지 <strong>80%</strong>는 <strong>서비스 종료 24시간 후</strong> 제공자가 등록한 IBAN으로 지급되어 소유자에게 분쟁 제기 기간이 보장됩니다. 이 기간 전체에 걸쳐 자금은 에스크로에 보관되며 HoPetSit은 이에 접근하지 않습니다.` },
    { type: "h2", html: `5. 취소 및 환불` },
    { type: "p", html: `소유자는 <strong>서비스 시작 72시간 전</strong>까지 무료로 직접 취소할 수 있으며, 이 경우 예약은 즉시 취소되고 100% 자동 환불이 이루어집니다. 72시간 이내에는 취소를 위해 제공자와의 상호 합의 또는 공식 분쟁 절차가 필요합니다. 제공자가 취소한 경우에는 언제나 소유자에게 전액 환불됩니다. 전체 절차, 기한 및 분쟁 절차는 <a href="/refund">환불 정책</a> 전문을 참조하십시오.` },
    { type: "h2", html: `6. 행동 규범` },
    { type: "ul", html: [
      `다른 이용자 또는 동물에 대한 괴롭힘, 혐오 표현 또는 유해한 행위를 금지합니다.`,
      `플랫폼의 결제 시스템을 우회하기 위한 연락처 요구를 금지합니다.`,
      `허위 후기, 허위 예약 또는 지급 거절(차지백) 남용을 금지합니다.`,
      `펫시터와 도그워커는 현지 동물 복지 법령을 준수해야 합니다.`
    ]},
    { type: "h2", html: `7. 후기 및 평판` },
    { type: "p", html: `양 당사자는 완료된 예약에 대해 후기를 남길 수 있습니다. 후기는 실제 경험을 반영해야 합니다. 당사는 본 약관 또는 관련 법령을 위반하는 후기를 삭제할 수 있습니다.` },
    { type: "h2", html: `8. 지식재산권` },
    { type: "p", html: `HoPetSit의 명칭, 로고, 애플리케이션, 웹사이트 및 콘텐츠는 CARDELLI HERMANOS LIMITED(HoPetSit이라는 상호로 영업)의 소유입니다. 당사의 사전 서면 동의 없이 이를 복제, 재생산 또는 배포할 수 없습니다.` },
    { type: "h2", html: `9. 책임` },
    { type: "p", html: `법이 허용하는 최대 범위에서, CARDELLI HERMANOS LIMITED(HoPetSit이라는 상호로 영업)는 예약으로 인해 발생하는 간접적 손해 또는 결과적 손해에 대해 책임을 지지 않습니다. 모든 청구에 대한 당사의 총 책임은 해당 예약에서 당사가 수취한 플랫폼 수수료로 제한됩니다.` },
    { type: "h2", html: `10. 해지` },
    { type: "p", html: `당사는 본 약관을 위반하는 계정을 정지하거나 해지할 수 있습니다. 귀하는 모바일 앱에서 또는 당사에 연락하여 언제든지 계정을 삭제할 수 있습니다.` },
    { type: "h2", html: `11. 준거법` },
    { type: "p", html: `본 약관은 홍콩 특별행정구의 법률에 따릅니다. 분쟁은 홍콩의 관할 법원에서 해결되며, 귀하의 거주 국가에서 강행적으로 적용되는 소비자 보호 권리에는 영향을 미치지 않습니다.` },
    { type: "h2", html: `12. 문의` },
    { type: "p", html: `문의 사항: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  ja: {
    lastUpdated: "2026年4月25日",
    sections: [
    { type: "p", html: `本利用規約（以下「本規約」）は、香港で設立された会社であるCARDELLI HERMANOS LIMITED（HoPetSitとして事業を行う。以下「当社」）が運営するHoPetSitマーケットプレイス（以下「本サービス」）のご利用に適用されます。` },
    { type: "h2", html: `1. 本サービス` },
    { type: "p", html: `HoPetSitは、ペットの飼い主と独立したペットシッターおよびドッグウォーカーを世界中（欧州連合、英国、スイス、ノルウェー、米国を含む177か国）で結び付けるマーケットプレイスです。当社自身はペットケアサービスの提供者では<strong>ありません</strong>。当社は、利用者間のマッチング、安全なチャット、決済処理および紛争解決を仲介します。` },
    { type: "h2", html: `2. 利用資格` },
    { type: "ul", html: [
      `シッターまたはウォーカーとして登録するには、18歳以上である必要があります。`,
      `ペットの飼い主は、18歳以上であるか、法定後見人の監督の下で本プラットフォームを利用する必要があります。`,
      `登録時には、正確かつ最新で完全な情報を提供する必要があります。`
    ]},
    { type: "h2", html: `3. アカウントとセキュリティ` },
    { type: "p", html: `お客様は、ご自身のアカウント上での活動および認証情報の機密保持について責任を負います。不正アクセスの疑いが生じた場合は、直ちに<a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>までご連絡ください。` },
    { type: "h2", html: `4. 予約と支払い` },
    { type: "p", html: `飼い主は、規制を受けた決済処理業者（Airwallex）を通じて予約総額をお支払いいただきます。HoPetSitは<strong>20%のプラットフォーム手数料</strong>を留保し、残りの<strong>80%</strong>は<strong>サービス終了の24時間後</strong>に提供者が登録したIBANへ支払われ、飼い主には異議申立ての期間が確保されます。この期間中、資金はエスクローに保管され、HoPetSitがこれにアクセスすることはありません。` },
    { type: "h2", html: `5. キャンセルと返金` },
    { type: "p", html: `飼い主は<strong>サービス開始の72時間前</strong>まで無料でご自身によるキャンセルが可能で、この場合、予約は直ちにキャンセルされ、100%の自動返金が行われます。72時間を切ってからのキャンセルには、提供者との相互合意または正式な異議申立てが必要です。提供者によるキャンセルの場合は、常に飼い主へ全額返金されます。手続きの全体、期限および紛争処理手順については、<a href="/refund">返金ポリシー</a>の全文をご覧ください。` },
    { type: "h2", html: `6. 行動規範` },
    { type: "ul", html: [
      `他の利用者または動物に対する嫌がらせ、ヘイトスピーチ、有害な行為を禁止します。`,
      `プラットフォームの決済システムを回避するための連絡先の要求を禁止します。`,
      `不正なレビュー、虚偽の予約、チャージバックの濫用を禁止します。`,
      `シッターおよびウォーカーは、現地の動物福祉に関する法令を遵守しなければなりません。`
    ]},
    { type: "h2", html: `7. レビューと評価` },
    { type: "p", html: `予約完了後、双方の当事者がレビューを投稿できます。レビューは実際の体験を反映したものでなければなりません。当社は、本規約または適用法令に違反するレビューを削除する場合があります。` },
    { type: "h2", html: `8. 知的財産` },
    { type: "p", html: `HoPetSitの名称、ロゴ、アプリケーション、ウェブサイトおよびコンテンツは、CARDELLI HERMANOS LIMITED（HoPetSitとして事業を行う）に帰属します。当社の事前の書面による同意なく、これらを複製、複写または配布することはできません。` },
    { type: "h2", html: `9. 責任` },
    { type: "p", html: `法律で認められる最大限の範囲において、CARDELLI HERMANOS LIMITED（HoPetSitとして事業を行う）は、予約に起因する間接的損害または結果的損害について責任を負いません。いかなる請求についても、当社の責任の総額は、当該予約に関して当社が受領したプラットフォーム手数料を上限とします。` },
    { type: "h2", html: `10. 契約の終了` },
    { type: "p", html: `当社は、本規約に違反するアカウントを停止または解除する場合があります。お客様は、モバイルアプリからいつでも、または当社にご連絡いただくことでアカウントを削除できます。` },
    { type: "h2", html: `11. 準拠法` },
    { type: "p", html: `本規約は香港特別行政区の法律に準拠します。紛争は香港の管轄裁判所において解決されるものとし、お客様の居住国における強行的な消費者保護の権利を妨げるものではありません。` },
    { type: "h2", html: `12. お問い合わせ` },
    { type: "p", html: `ご質問: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  // v546 — polonais : version ANGLAISE reprise telle quelle (un texte
  // juridique ne se traduit pas automatiquement ; à faire relire par un
  // traducteur juridique avant une version polonaise).
  pl: {
    lastUpdated: "April 25, 2026",
    sections: [
    { type: "p", html: `These Terms of Service (the "Terms") govern your use of the HoPetSit marketplace (the "Service"), operated by CARDELLI HERMANOS LIMITED (trading as HoPetSit), a company incorporated in Hong Kong (the "Company", "we", "us").` },
    { type: "h2", html: `1. The Service` },
    { type: "p", html: `HoPetSit is a marketplace connecting pet owners with independent pet sitters and dog walkers worldwide (177 countries, including the European Union, United Kingdom, Switzerland, Norway and the United States). We are <strong>not</strong> a provider of pet-care services ourselves. We facilitate matching, secure chat, payment processing and dispute resolution between users.` },
    { type: "h2", html: `2. Eligibility` },
    { type: "ul", html: [
      `You must be at least 18 years old to register as a sitter or walker.`,
      `Pet owners must be at least 18 years old or use the platform under the supervision of a legal guardian.`,
      `You must provide accurate, current and complete information at registration.`
    ]},
    { type: "h2", html: `3. Account &amp; security` },
    { type: "p", html: `You are responsible for the activity on your account and for keeping your credentials confidential. Notify us at <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> as soon as you suspect unauthorised access.` },
    { type: "h2", html: `4. Bookings &amp; payments` },
    { type: "p", html: `Owners pay the gross booking amount via our regulated payment processor (Airwallex). HoPetSit retains a <strong>20% platform commission</strong>; the remaining <strong>80%</strong> is paid out to the provider's registered IBAN <strong>24 hours after the service ends</strong>, allowing a dispute window for the owner. Funds are held in escrow during this entire period and HoPetSit does not access them.` },
    { type: "h2", html: `5. Cancellations &amp; refunds` },
    { type: "p", html: `Owners can self-cancel for free up to <strong>72 hours before the service starts</strong> — the booking is cancelled immediately and a 100% automatic refund is issued. Within the 72-hour window, cancellations require a mutual agreement with the provider or a formal dispute. Provider-initiated cancellations always result in a full owner refund. See the full <a href="/refund">Refund Policy</a> for the complete process, deadlines and dispute procedure.` },
    { type: "h2", html: `6. Conduct` },
    { type: "ul", html: [
      `No harassment, hate speech, or harmful behaviour toward other users or animals.`,
      `No solicitation of contact details to bypass the platform's payment system.`,
      `No fraudulent reviews, fake bookings, or chargeback abuse.`,
      `Sitters and walkers must respect local animal welfare laws.`
    ]},
    { type: "h2", html: `7. Reviews &amp; reputation` },
    { type: "p", html: `Both parties may leave a review after a completed booking. Reviews must reflect a real experience. We may remove reviews that violate these Terms or applicable law.` },
    { type: "h2", html: `8. Intellectual property` },
    { type: "p", html: `The HoPetSit name, logo, application, website, and content are owned by CARDELLI HERMANOS LIMITED (trading as HoPetSit). You may not copy, reproduce, or distribute them without our prior written consent.` },
    { type: "h2", html: `9. Liability` },
    { type: "p", html: `To the fullest extent permitted by law, CARDELLI HERMANOS LIMITED (trading as HoPetSit) is not liable for indirect or consequential damages arising from a booking. Our aggregate liability for any claim is limited to the platform fees we have collected from the affected booking.` },
    { type: "h2", html: `10. Termination` },
    { type: "p", html: `We may suspend or terminate accounts that breach these Terms. You may delete your account at any time from the mobile app or by contacting us.` },
    { type: "h2", html: `11. Governing law` },
    { type: "p", html: `These Terms are governed by the laws of Hong Kong SAR. Disputes shall be resolved by the competent courts of Hong Kong, without prejudice to mandatory consumer-protection rights in your country of residence.` },
    { type: "h2", html: `12. Contact` },
    { type: "p", html: `Questions: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
};

export const PRIVACY: LegalDocByLang = {
  en: {
    lastUpdated: "April 25, 2026",
    sections: [
    { type: "p", html: `CARDELLI HERMANOS LIMITED (trading as HoPetSit) ("we", "us") is the data controller of personal data collected through the HoPetSit mobile application and website (the "Service"). This page explains what we collect, why, how long we keep it, and your rights — in accordance with the EU General Data Protection Regulation (GDPR), the UK GDPR and Hong Kong PDPO.` },
    { type: "h2", html: `1. Data we collect` },
    { type: "ul", html: [
      `<strong>Account data:</strong> name, email, phone (optional), city, role, password hash.`,
      `<strong>Profile data:</strong> avatar, bio, languages, services offered, rates, availability.`,
      `<strong>Booking data:</strong> dates, pets, prices, status, reviews.`,
      `<strong>Payment data:</strong> a token from our regulated payment provider — we never see your card number. Last 4 digits and brand are stored to display saved cards.`,
      `<strong>Communications:</strong> chat messages, support tickets, contact-form submissions.`,
      `<strong>Technical data:</strong> IP address, device type, app version, language, crash reports.`,
      `<strong>Location:</strong> only when you explicitly grant location permission to find providers near you or to publish a request.`
    ]},
    { type: "h2", html: `2. Why we process it (legal basis)` },
    { type: "ul", html: [
      `<strong>Contract:</strong> creating and operating your account, processing bookings and payments.`,
      `<strong>Legitimate interest:</strong> fraud prevention, content moderation, product analytics.`,
      `<strong>Consent:</strong> marketing emails, push notifications, location access.`,
      `<strong>Legal obligation:</strong> tax records, anti-money-laundering compliance.`
    ]},
    { type: "h2", html: `3. Sharing` },
    { type: "p", html: `We share data with:` },
    { type: "ul", html: [
      `The payment processor (PCI-DSS compliant) for card transactions and IBAN payouts.`,
      `Cloud infrastructure (Render, MongoDB, Cloudinary) under strict data-processing agreements.`,
      `Other users only as needed for a booking (e.g. your name and avatar are shown to the sitter you booked).`,
      `Authorities when required by law.`
    ]},
    { type: "p", html: `We do <strong>not</strong> sell your data and do not use it for cross-platform advertising.` },
    { type: "h2", html: `4. Retention` },
    { type: "p", html: `Account data is kept while your account is active and 24 months after deletion (for fraud prevention). Booking and payment records are kept 10 years for tax compliance. Chat messages are kept for the lifetime of the conversation; soft-deleted messages remain visible to admin moderators only.` },
    { type: "h2", html: `5. Your rights` },
    { type: "ul", html: [
      `Right of access, rectification, erasure, restriction, portability and objection.`,
      `Right to withdraw consent at any time (push notifications, marketing).`,
      `Right to lodge a complaint with your local data-protection authority (e.g. CNIL in France).`
    ]},
    { type: "p", html: `Exercise your rights at <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. We answer within 30 days.` },
    { type: "h2", html: `6. International transfers` },
    { type: "p", html: `Some of our processors are based outside the European Economic Area. Transfers are protected by the European Commission's Standard Contractual Clauses (SCCs) and equivalent safeguards under UK and Hong Kong law.` },
    { type: "h2", html: `7. Cookies` },
    { type: "p", html: `The website uses strictly necessary cookies for authentication and preferences. We do not use advertising or tracking cookies. The mobile app uses local storage and a notification token for push delivery.` },
    { type: "h2", html: `8. Children` },
    { type: "p", html: `The Service is not directed to children under 16. We do not knowingly collect data from minors.` },
    { type: "h2", html: `9. Changes` },
    { type: "p", html: `Material changes to this policy are notified in-app and by email (when you have opted in to product updates) at least 30 days before they take effect.` },
    { type: "h2", html: `10. Contact` },
    { type: "p", html: `Data Protection contact: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  fr: {
    lastUpdated: "25 avril 2026",
    sections: [
    { type: "p", html: `CARDELLI HERMANOS LIMITED (exerçant ses activités sous le nom de HoPetSit) (« nous », « notre ») est le responsable du traitement des données personnelles collectées via l'application mobile et le site Web HoPetSit (le « Service »). Cette page explique ce que nous collectons, pourquoi, combien de temps nous le conservons et vos droits – conformément au Règlement général sur la protection des données (RGPD) de l'UE, au RGPD du Royaume-Uni et au PDPO de Hong Kong.` },
    { type: "h2", html: `1. Données que nous collectons` },
    { type: "ul", html: [
      `<strong>Données du compte : nom </strong>, e-mail, téléphone (facultatif), ville, rôle, hachage du mot de passe.`,
      `Données de profil <strong> : avatar </strong>, bio, langues, services proposés, tarifs, disponibilités.`,
      `Données de réservation <strong> : dates </strong>, animaux, prix, statut, avis.`,
      `<strong>Données de paiement :</strong> un jeton de notre fournisseur de paiement réglementé — nous ne voyons jamais votre numéro de carte. Les 4 derniers chiffres et la marque sont stockés pour afficher les cartes enregistrées.`,
      `<strong>Communications : messages de discussion </strong>, tickets d'assistance, soumissions par formulaire de contact.`,
      `<strong>Données techniques : adresse IP </strong>, type d'appareil, version de l'application, langue, rapports d'erreur.`,
      `<strong>Location : </strong> uniquement lorsque vous accordez explicitement l'autorisation de localisation pour rechercher des fournisseurs proches de chez vous ou pour publier une demande.`
    ]},
    { type: "h2", html: `2. Pourquoi nous les traitons (base juridique)` },
    { type: "ul", html: [
      `<strong>Contract : </strong> créant et gérant votre compte, traitant les réservations et les paiements.`,
      `<strong>Lintérêt légitime : prévention de la fraude </strong>, modération du contenu, analyse des produits.`,
      `<strong>Consent : e-mails marketing </strong>, notifications push, accès à la localisation.`,
      `<strong>Lobligation légale : dossiers fiscaux </strong>, conformité anti-blanchiment.`
    ]},
    { type: "h2", html: `3. Partage` },
    { type: "p", html: `Nous partageons des données avec :` },
    { type: "ul", html: [
      `Le processeur de paiement (conforme PCI-DSS) pour les transactions par carte et les paiements IBAN.`,
      `Infrastructure cloud (Render, MongoDB, Cloudinary) sous accords stricts en matière de traitement des données.`,
      `Autres utilisateurs uniquement si nécessaire pour une réservation (par exemple, votre nom et votre avatar sont montrés au gardien que vous avez réservé).`,
      `Autorités lorsque la loi l’exige.`
    ]},
    { type: "p", html: `Nous <strong>not</strong> vendons vos données et ne les utilisons pas à des fins de publicité multiplateforme.` },
    { type: "h2", html: `4. Rétention` },
    { type: "p", html: `Les données du compte sont conservées pendant que votre compte est actif et 24 mois après sa suppression (à des fins de prévention de la fraude). Les enregistrements de réservation et de paiement sont conservés 10 ans pour des raisons de conformité fiscale. Les messages de chat sont conservés pendant toute la durée de la conversation ; Les messages supprimés de manière logicielle restent visibles uniquement par les modérateurs administrateurs.` },
    { type: "h2", html: `5. Vos droits` },
    { type: "ul", html: [
      `Droit d'accès, de rectification, d'effacement, de restriction, de portabilité et d'opposition.`,
      `Droit de retirer son consentement à tout moment (notifications push, marketing).`,
      `Droit de déposer une réclamation auprès de votre autorité locale de protection des données (par exemple la CNIL en France).`
    ]},
    { type: "p", html: `Exercez vos droits à <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. Nous répondons sous 30 jours.` },
    { type: "h2", html: `6. Virements internationaux` },
    { type: "p", html: `Certains de nos processeurs sont basés en dehors de l’Espace économique européen. Les transferts sont protégés par les clauses contractuelles types (CCS) de la Commission européenne et par des garanties équivalentes en vertu des lois du Royaume-Uni et de Hong Kong.` },
    { type: "h2", html: `7. Cookies` },
    { type: "p", html: `Le site utilise des cookies strictement nécessaires à l'authentification et aux préférences. Nous n'utilisons pas de cookies publicitaires ou de suivi. L'application mobile utilise le stockage local et un jeton de notification pour la livraison push.` },
    { type: "h2", html: `8. Enfants` },
    { type: "p", html: `Le Service n'est pas destiné aux enfants de moins de 16 ans. Nous ne collectons pas sciemment de données auprès de mineurs.` },
    { type: "h2", html: `9. Modifications` },
    { type: "p", html: `Les modifications importantes apportées à cette politique sont notifiées dans l'application et par e-mail (lorsque vous avez accepté les mises à jour du produit) au moins 30 jours avant leur entrée en vigueur.` },
    { type: "h2", html: `10. Contacter` },
    { type: "p", html: `Contact pour la protection des données : <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  es: {
    lastUpdated: "25 de abril de 2026",
    sections: [
    { type: "p", html: `CARDELLI HERMANOS LIMITED (que opera como HoPetSit) ("nosotros", "nos") es el controlador de datos personales recopilados a través de la aplicación móvil y el sitio web de HoPetSit (el "Servicio"). Esta página explica qué recopilamos, por qué, durante cuánto tiempo lo conservamos y sus derechos, de acuerdo con el Reglamento General de Protección de Datos de la UE (GDPR), el RGPD del Reino Unido y la PDPO de Hong Kong.` },
    { type: "h2", html: `1. Datos que recopilamos` },
    { type: "ul", html: [
      `<strong>Datos de cuenta:</strong> nombre, correo electrónico, teléfono (opcional), ciudad, rol, hash de contraseña.`,
      `<strong>Datos de perfil:</strong> avatar, bio, idiomas, servicios ofrecidos, tarifas, disponibilidad.`,
      `<strong>Datos de reserva:</strong> fechas, mascotas, precios, estado, opiniones.`,
      `<strong>Datos de pago:</strong> un token de nuestro proveedor de pagos regulado; nunca vemos su número de tarjeta. Los últimos 4 dígitos y la marca se almacenan para mostrar las tarjetas guardadas.`,
      `Comunicaciones <strong>: mensajes de chat </strong>, tickets de soporte, envíos de formularios de contacto.`,
      `<strong>Datos técnicos: dirección IP </strong>, tipo de dispositivo, versión de la aplicación, idioma, informes de fallos.`,
      `<strong>Lubicación:</strong> solo cuando otorga explícitamente permiso de ubicación para encontrar proveedores cerca de usted o publicar una solicitud.`
    ]},
    { type: "h2", html: `2. Por qué lo procesamos (base legal)` },
    { type: "ul", html: [
      `<strong>Contract:</strong> creando y operando su cuenta, procesando reservas y pagos.`,
      `<strong>Linterés legítimo:</strong> prevención de fraude, moderación de contenidos, análisis de productos.`,
      `<strong>Consentimiento: correos electrónicos de marketing </strong>, notificaciones automáticas, acceso a la ubicación.`,
      `<strong>Obligación legal:</strong> registros fiscales, cumplimiento de medidas contra el blanqueo de capitales.`
    ]},
    { type: "h2", html: `3. Compartir` },
    { type: "p", html: `Compartimos datos con:` },
    { type: "ul", html: [
      `El procesador de pagos (compatible con PCI-DSS) para transacciones con tarjeta y pagos IBAN.`,
      `Infraestructura en la nube (Render, MongoDB, Cloudinary) bajo estrictos acuerdos de procesamiento de datos.`,
      `Otros usuarios solo según sea necesario para una reserva (por ejemplo, su nombre y avatar se muestran a la niñera que contrató).`,
      `Autoridades cuando así lo requiera la ley.`
    ]},
    { type: "p", html: `Nosotros <strong>not</strong> vendemos sus datos y no los utilizamos para publicidad multiplataforma.` },
    { type: "h2", html: `4. Retención` },
    { type: "p", html: `Los datos de la cuenta se conservan mientras su cuenta esté activa y 24 meses después de su eliminación (para prevención de fraude). Los registros de reservas y pagos se conservan durante 10 años para el cumplimiento tributario. Los mensajes de chat se conservan mientras dure la conversación; Los mensajes eliminados temporalmente permanecen visibles solo para los moderadores administradores.` },
    { type: "h2", html: `5. Tus derechos` },
    { type: "ul", html: [
      `Derecho de acceso, rectificación, supresión, limitación, portabilidad y oposición.`,
      `Derecho a retirar el consentimiento en cualquier momento (notificaciones push, marketing).`,
      `Derecho a presentar una queja ante la autoridad local de protección de datos (por ejemplo, CNIL en Francia).`
    ]},
    { type: "p", html: `Ejerza sus derechos en <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. Respondemos en un plazo de 30 días.` },
    { type: "h2", html: `6. Transferencias internacionales` },
    { type: "p", html: `Algunos de nuestros procesadores tienen su sede fuera del Espacio Económico Europeo. Las transferencias están protegidas por las Cláusulas Contractuales Estándar (SCC) de la Comisión Europea y salvaguardias equivalentes según las leyes del Reino Unido y Hong Kong.` },
    { type: "h2", html: `7. Galletas` },
    { type: "p", html: `El sitio web utiliza cookies estrictamente necesarias para la autenticación y las preferencias. No utilizamos cookies publicitarias ni de seguimiento. La aplicación móvil utiliza almacenamiento local y un token de notificación para la entrega automática.` },
    { type: "h2", html: `8. Niños` },
    { type: "p", html: `El Servicio no está dirigido a niños menores de 16 años. No recopilamos datos de menores de forma consciente.` },
    { type: "h2", html: `9. Cambios` },
    { type: "p", html: `Los cambios materiales a esta política se notifican en la aplicación y por correo electrónico (cuando haya optado por recibir actualizaciones de productos) al menos 30 días antes de que entren en vigencia.` },
    { type: "h2", html: `10. Contacto` },
    { type: "p", html: `Contacto de Protección de Datos: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  de: {
    lastUpdated: "25. April 2026",
    sections: [
    { type: "p", html: `CARDELLI HERMANOS LIMITED (firmierend als HoPetSit) („wir“, „uns“) ist der Datenverantwortliche für personenbezogene Daten, die über die mobile Anwendung und Website von HoPetSit (der „Dienst“) erfasst werden. Auf dieser Seite wird erklärt, was wir sammeln, warum, wie lange wir es aufbewahren und welche Rechte Sie haben – gemäß der EU-Datenschutz-Grundverordnung (DSGVO), der britischen DSGVO und dem Hongkonger PDPO.` },
    { type: "h2", html: `1. Von uns erfasste Daten` },
    { type: "ul", html: [
      `<strong>Kontodaten:</strong> Name, E-Mail, Telefonnummer (optional), Stadt, Rolle, Passwort-Hash.`,
      `<strong>Profildaten:</strong> Avatar, Biografie, Sprachen, angebotene Dienste, Preise, Verfügbarkeit.`,
      `<strong>Buchungsdaten:</strong> Termine, Haustiere, Preise, Status, Bewertungen.`,
      `<strong>Zahlungsdaten:</strong> ein Token von unserem regulierten Zahlungsanbieter – wir sehen Ihre Kartennummer nie. Die letzten 4 Ziffern und die Marke werden gespeichert, um gespeicherte Karten anzuzeigen.`,
      `<strong>Communications:</strong> Chat-Nachrichten, Support-Tickets, Kontaktformular-Übermittlungen.`,
      `<strong>Technische Daten:</strong> IP-Adresse, Gerätetyp, App-Version, Sprache, Absturzberichte.`,
      `<strong>Location:</strong> nur, wenn Sie explizit die Standortberechtigung erteilen, um Anbieter in Ihrer Nähe zu finden oder eine Anfrage zu veröffentlichen.`
    ]},
    { type: "h2", html: `2. Warum wir sie verarbeiten (Rechtsgrundlage)` },
    { type: "ul", html: [
      `<strong>Vertrag:</strong> Erstellen und Betreiben Ihres Kontos, Bearbeiten von Buchungen und Zahlungen.`,
      `<strong>Lerechtiges Interesse:</strong> Betrugsprävention, Inhaltsmoderation, Produktanalyse.`,
      `<strong>Zustimmung:</strong> Marketing-E-Mails, Push-Benachrichtigungen, Standortzugriff.`,
      `<strong>Rechtliche Verpflichtung:</strong> Steuerunterlagen, Einhaltung der Geldwäschebekämpfung.`
    ]},
    { type: "h2", html: `3. Teilen` },
    { type: "p", html: `Wir teilen Daten mit:` },
    { type: "ul", html: [
      `Der Zahlungsabwickler (PCI-DSS-konform) für Kartentransaktionen und IBAN-Auszahlungen.`,
      `Cloud-Infrastruktur (Render, MongoDB, Cloudinary) unter strengen Datenverarbeitungsvereinbarungen.`,
      `Andere Benutzer nur, wenn dies für eine Buchung erforderlich ist (z. B. werden Ihr Name und Ihr Avatar dem von Ihnen gebuchten Sitter angezeigt).`,
      `Behörden, sofern gesetzlich vorgeschrieben.`
    ]},
    { type: "p", html: `Wir verkaufen Ihre Daten nicht und nutzen sie nicht für plattformübergreifende Werbung.` },
    { type: "h2", html: `4. Aufbewahrung` },
    { type: "p", html: `Kontodaten werden aufbewahrt, solange Ihr Konto aktiv ist und 24 Monate nach der Löschung (zur Betrugsprävention). Buchungs- und Zahlungsunterlagen werden aus steuerrechtlichen Gründen 10 Jahre lang aufbewahrt. Chatnachrichten werden für die gesamte Dauer der Konversation aufbewahrt; Vorläufig gelöschte Nachrichten bleiben nur für Admin-Moderatoren sichtbar.` },
    { type: "h2", html: `5. Ihre Rechte` },
    { type: "ul", html: [
      `Recht auf Auskunft, Berichtigung, Löschung, Einschränkung, Übertragbarkeit und Widerspruch.`,
      `Recht auf jederzeitigen Widerruf der Einwilligung (Push-Benachrichtigungen, Marketing).`,
      `Recht, eine Beschwerde bei Ihrer örtlichen Datenschutzbehörde einzureichen (z. B. CNIL in Frankreich).`
    ]},
    { type: "p", html: `Machen Sie von Ihren Rechten Gebrauch unter <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. Wir antworten innerhalb von 30 Tagen.` },
    { type: "h2", html: `6. Internationale Überweisungen` },
    { type: "p", html: `Einige unserer Auftragsverarbeiter haben ihren Sitz außerhalb des Europäischen Wirtschaftsraums. Übertragungen sind durch die Standardvertragsklauseln (SCCs) der Europäischen Kommission und gleichwertige Schutzmaßnahmen nach britischem und Hongkonger Recht geschützt.` },
    { type: "h2", html: `7. Cookies` },
    { type: "p", html: `Die Website verwendet unbedingt notwendige Cookies zur Authentifizierung und Präferenzen. Wir verwenden keine Werbe- oder Tracking-Cookies. Die mobile App nutzt lokalen Speicher und ein Benachrichtigungstoken für die Push-Zustellung.` },
    { type: "h2", html: `8. Kinder` },
    { type: "p", html: `Der Dienst richtet sich nicht an Kinder unter 16 Jahren. Wir erfassen wissentlich keine Daten von Minderjährigen.` },
    { type: "h2", html: `9. Änderungen` },
    { type: "p", html: `Wesentliche Änderungen dieser Richtlinie werden in der App und per E-Mail (wenn Sie sich für Produktaktualisierungen entschieden haben) mindestens 30 Tage vor ihrem Inkrafttreten mitgeteilt.` },
    { type: "h2", html: `10. Kontakt` },
    { type: "p", html: `Datenschutzkontakt: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  it: {
    lastUpdated: "25 aprile 2026",
    sections: [
    { type: "p", html: `CARDELLI HERMANOS LIMITED (operante come HoPetSit) ("noi") è il titolare del trattamento dei dati personali raccolti tramite l'applicazione mobile e il sito web HoPetSit (il "Servizio"). Questa pagina spiega cosa raccogliamo, perché, per quanto tempo li conserviamo e i tuoi diritti, in conformità con il Regolamento generale sulla protezione dei dati (GDPR) dell'UE, il GDPR del Regno Unito e il PDPO di Hong Kong.` },
    { type: "h2", html: `1. Dati che raccogliamo` },
    { type: "ul", html: [
      `<strong>Dati dell'account:</strong> nome, email, telefono (opzionale), città, ruolo, hash della password.`,
      `<strong>Dati profilo:</strong> avatar, bio, lingue, servizi offerti, tariffe, disponibilità.`,
      `<strong>Dati prenotazione:</strong> date, animali domestici, prezzi, stato, recensioni.`,
      `<strong>Dati di pagamento:</strong> un token del nostro fornitore di servizi di pagamento regolamentato: non vediamo mai il numero della tua carta. Le ultime 4 cifre e il marchio vengono memorizzati per visualizzare le carte salvate.`,
      `<strong>Communications: messaggi di chat </strong>, ticket di supporto, invii di moduli di contatto.`,
      `<strong>Dati tecnici:</strong> Indirizzo IP, tipo di dispositivo, versione dell'app, lingua, rapporti sugli arresti anomali.`,
      `<strong>Location:</strong> solo quando concedi esplicitamente l'autorizzazione alla posizione per trovare fornitori vicino a te o per pubblicare una richiesta.`
    ]},
    { type: "h2", html: `2. Perché li trattiamo (base giuridica)` },
    { type: "ul", html: [
      `<strong>Contract:</strong> crea e gestisce il tuo account, elabora prenotazioni e pagamenti.`,
      `<strong>Ligittimo interesse:</strong> prevenzione delle frodi, moderazione dei contenuti, analisi dei prodotti.`,
      `<strong>Consent: e-mail di marketing </strong>, notifiche push, accesso alla posizione.`,
      `<strong>Lobbligo legale:</strong> documentazione fiscale, adempimenti antiriciclaggio.`
    ]},
    { type: "h2", html: `3. Condivisione` },
    { type: "p", html: `Condividiamo i dati con:` },
    { type: "ul", html: [
      `Il processore di pagamento (conforme PCI-DSS) per transazioni con carta e pagamenti IBAN.`,
      `Infrastruttura cloud (Render, MongoDB, Cloudinary) soggetta a rigidi accordi sul trattamento dei dati.`,
      `Altri utenti solo se necessario per una prenotazione (ad esempio il tuo nome e avatar vengono mostrati al sitter che hai prenotato).`,
      `Autorità quando richiesto dalla legge.`
    ]},
    { type: "p", html: `<strong>not</strong> vendiamo i tuoi dati e non li utilizziamo per la pubblicità multipiattaforma.` },
    { type: "h2", html: `4. Conservazione` },
    { type: "p", html: `I dati dell'account vengono conservati mentre il tuo account è attivo e 24 mesi dopo la cancellazione (per la prevenzione delle frodi). I registri delle prenotazioni e dei pagamenti vengono conservati per 10 anni ai fini degli adempimenti fiscali. I messaggi di chat vengono conservati per tutta la durata della conversazione; i messaggi eliminati temporaneamente rimangono visibili solo ai moderatori amministratori.` },
    { type: "h2", html: `5. I tuoi diritti` },
    { type: "ul", html: [
      `Diritto di accesso, rettifica, cancellazione, limitazione, portabilità e opposizione.`,
      `Diritto di revocare il consenso in qualsiasi momento (notifiche push, marketing).`,
      `Diritto di presentare un reclamo all'autorità locale per la protezione dei dati (ad esempio CNIL in Francia).`
    ]},
    { type: "p", html: `Esercita i tuoi diritti all'indirizzo <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. Rispondiamo entro 30 giorni.` },
    { type: "h2", html: `6. Trasferimenti internazionali` },
    { type: "p", html: `Alcuni dei nostri responsabili del trattamento hanno sede al di fuori dello Spazio Economico Europeo. I trasferimenti sono protetti dalle clausole contrattuali standard (SCC) della Commissione Europea e da garanzie equivalenti ai sensi della legge del Regno Unito e di Hong Kong.` },
    { type: "h2", html: `7. Cookie` },
    { type: "p", html: `Il sito utilizza cookie strettamente necessari per l'autenticazione e le preferenze. Non utilizziamo cookie pubblicitari o di tracciamento. L'app mobile utilizza l'archiviazione locale e un token di notifica per la consegna push.` },
    { type: "h2", html: `8. Bambini` },
    { type: "p", html: `Il Servizio non è rivolto a minori di 16 anni. Non raccogliamo consapevolmente dati di minori.` },
    { type: "h2", html: `9. Modifiche` },
    { type: "p", html: `Le modifiche sostanziali a questa politica vengono notificate nell'app e via e-mail (se hai aderito agli aggiornamenti del prodotto) almeno 30 giorni prima che entrino in vigore.` },
    { type: "h2", html: `10. Contatto` },
    { type: "p", html: `Contatto per la protezione dei dati: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  pt: {
    lastUpdated: "25 de abril de 2026",
    sections: [
    { type: "p", html: `CARDELLI HERMANOS LIMITED (negociado como HoPetSit) ("nós", "nos") é o controlador de dados pessoais coletados por meio do aplicativo móvel e site HoPetSit (o "Serviço"). Esta página explica o que coletamos, por que, por quanto tempo os mantemos e seus direitos — de acordo com o Regulamento Geral de Proteção de Dados (GDPR) da UE, o GDPR do Reino Unido e o PDPO de Hong Kong.` },
    { type: "h2", html: `1. Dados que coletamos` },
    { type: "ul", html: [
      `<strong>Dados da conta: nome </strong>, e-mail, telefone (opcional), cidade, função, hash de senha.`,
      `Dados do perfil <strong>: avatar </strong>, biografia, idiomas, serviços oferecidos, tarifas, disponibilidade.`,
      `Dados <strong>Booking: datas </strong>, animais de estimação, preços, status, comentários.`,
      `<strong>Dados de pagamento:</strong> um token do nosso provedor de pagamento regulamentado — nunca vemos o número do seu cartão. Os últimos 4 dígitos e a marca são armazenados para exibir os cartões salvos.`,
      `<strong>Comunicações: mensagens de bate-papo </strong>, tickets de suporte, envios de formulários de contato.`,
      `<strong>Dados técnicos:Endereço IP </strong>, tipo de dispositivo, versão do aplicativo, idioma, relatórios de falhas.`,
      `<strong>Location:</strong> somente quando você concede explicitamente permissão de localização para encontrar provedores perto de você ou para publicar uma solicitação.`
    ]},
    { type: "h2", html: `2. Por que processamos (base legal)` },
    { type: "ul", html: [
      `<strong>Contract:</strong> criando e operando sua conta, processando reservas e pagamentos.`,
      `<strong>Linteresse legítimo: prevenção de fraudes </strong>, moderação de conteúdo, análise de produtos.`,
      `<strong>Consent:E-mails de marketing </strong>, notificações push, acesso à localização.`,
      `<strong>Obrigação legal:Registros fiscais </strong>, conformidade contra lavagem de dinheiro.`
    ]},
    { type: "h2", html: `3. Compartilhamento` },
    { type: "p", html: `Compartilhamos dados com:` },
    { type: "ul", html: [
      `O processador de pagamentos (compatível com PCI-DSS) para transações com cartão e pagamentos IBAN.`,
      `Infraestrutura em nuvem (Render, MongoDB, Cloudinary) sob rígidos acordos de processamento de dados.`,
      `Outros usuários apenas quando necessário para uma reserva (por exemplo, seu nome e avatar são mostrados ao babá que você reservou).`,
      `Autoridades quando exigido por lei.`
    ]},
    { type: "p", html: `Nós vendemos seus dados e não os usamos para publicidade em várias plataformas.` },
    { type: "h2", html: `4. Retenção` },
    { type: "p", html: `Os dados da conta são mantidos enquanto sua conta estiver ativa e 24 meses após a exclusão (para prevenção de fraudes). Os registros de reservas e pagamentos são mantidos por 10 anos para cumprimento fiscal. As mensagens de bate-papo são mantidas durante toda a conversa; mensagens excluídas de forma reversível permanecem visíveis apenas para moderadores administradores.` },
    { type: "h2", html: `5. Seus direitos` },
    { type: "ul", html: [
      `Direito de acesso, retificação, apagamento, restrição, portabilidade e oposição.`,
      `Direito de retirar o consentimento a qualquer momento (notificações push, marketing).`,
      `Direito de apresentar uma reclamação junto da autoridade local de proteção de dados (por exemplo, CNIL em França).`
    ]},
    { type: "p", html: `Exerça seus direitos em <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. Respondemos em até 30 dias.` },
    { type: "h2", html: `6. Transferências internacionais` },
    { type: "p", html: `Alguns dos nossos processadores estão localizados fora do Espaço Económico Europeu. As transferências são protegidas pelas Cláusulas Contratuais Padrão (SCCs) da Comissão Europeia e salvaguardas equivalentes ao abrigo da legislação do Reino Unido e de Hong Kong.` },
    { type: "h2", html: `7. Biscoitos` },
    { type: "p", html: `O site utiliza cookies estritamente necessários para autenticação e preferências. Não utilizamos cookies de publicidade ou rastreamento. O aplicativo móvel usa armazenamento local e um token de notificação para entrega push.` },
    { type: "h2", html: `8. Crianças` },
    { type: "p", html: `O Serviço não é direcionado a menores de 16 anos. Não coletamos intencionalmente dados de menores.` },
    { type: "h2", html: `9. Mudanças` },
    { type: "p", html: `Alterações materiais nesta política são notificadas no aplicativo e por e-mail (quando você tiver optado por receber atualizações do produto) pelo menos 30 dias antes de entrarem em vigor.` },
    { type: "h2", html: `10. Contato` },
    { type: "p", html: `Contato de proteção de dados: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  ko: {
    lastUpdated: "2026년 4월 25일",
    sections: [
    { type: "p", html: `CARDELLI HERMANOS LIMITED(HoPetSit이라는 상호로 영업, 이하 "당사")는 HoPetSit 모바일 애플리케이션 및 웹사이트(이하 "서비스")를 통해 수집되는 개인정보의 관리자입니다. 본 페이지는 당사가 무엇을 수집하는지, 그 이유, 보관 기간 및 귀하의 권리를 EU 일반 개인정보 보호법(GDPR), 영국 GDPR 및 홍콩 PDPO에 따라 설명합니다.` },
    { type: "h2", html: `1. 당사가 수집하는 정보` },
    { type: "ul", html: [
      `<strong>계정 정보:</strong> 이름, 이메일, 전화번호(선택), 도시, 역할, 비밀번호 해시.`,
      `<strong>프로필 정보:</strong> 프로필 사진, 소개, 사용 언어, 제공 서비스, 요금, 예약 가능 일정.`,
      `<strong>예약 정보:</strong> 날짜, 반려동물, 가격, 상태, 후기.`,
      `<strong>결제 정보:</strong> 규제 대상 결제 제공업체가 발급한 토큰 — 당사는 귀하의 카드 번호를 확인하지 않습니다. 저장된 카드를 표시하기 위해 카드 번호 마지막 4자리와 카드 브랜드가 저장됩니다.`,
      `<strong>커뮤니케이션:</strong> 채팅 메시지, 고객 지원 문의, 문의 양식 제출 내용.`,
      `<strong>기술 정보:</strong> IP 주소, 기기 종류, 앱 버전, 언어, 오류 보고서.`,
      `<strong>위치:</strong> 근처의 제공자를 찾거나 요청을 게시하기 위해 귀하가 명시적으로 위치 권한을 허용한 경우에만 해당합니다.`
    ]},
    { type: "h2", html: `2. 처리 목적(법적 근거)` },
    { type: "ul", html: [
      `<strong>계약:</strong> 계정 생성 및 운영, 예약 및 결제 처리.`,
      `<strong>정당한 이익:</strong> 부정행위 방지, 콘텐츠 관리, 제품 분석.`,
      `<strong>동의:</strong> 마케팅 이메일, 푸시 알림, 위치 정보 접근.`,
      `<strong>법적 의무:</strong> 세무 기록, 자금세탁 방지 규정 준수.`
    ]},
    { type: "h2", html: `3. 정보 공유` },
    { type: "p", html: `당사는 다음과 정보를 공유합니다:` },
    { type: "ul", html: [
      `카드 거래 및 IBAN 지급을 위한 결제 처리업체(PCI-DSS 준수).`,
      `엄격한 데이터 처리 계약을 체결한 클라우드 인프라(Render, MongoDB, Cloudinary).`,
      `예약에 필요한 범위에서만 다른 이용자(예: 귀하가 예약한 펫시터에게 귀하의 이름과 프로필 사진이 표시됩니다).`,
      `법률상 요구되는 경우 관계 당국.`
    ]},
    { type: "p", html: `당사는 귀하의 정보를 판매하지 <strong>않으며</strong>, 플랫폼 간 광고에 이용하지 않습니다.` },
    { type: "h2", html: `4. 보관 기간` },
    { type: "p", html: `계정 정보는 계정이 활성 상태인 동안 및 삭제 후 24개월간(부정행위 방지 목적) 보관됩니다. 예약 및 결제 기록은 세무 규정 준수를 위해 10년간 보관됩니다. 채팅 메시지는 해당 대화가 유지되는 기간 동안 보관되며, 소프트 삭제된 메시지는 관리자 모더레이터에게만 계속 표시됩니다.` },
    { type: "h2", html: `5. 귀하의 권리` },
    { type: "ul", html: [
      `열람, 정정, 삭제, 처리 제한, 이동 및 반대할 권리.`,
      `언제든지 동의를 철회할 권리(푸시 알림, 마케팅).`,
      `거주지의 개인정보 보호 감독기관(예: 프랑스 CNIL)에 민원을 제기할 권리.`
    ]},
    { type: "p", html: `권리 행사는 <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>으로 요청하십시오. 당사는 30일 이내에 답변합니다.` },
    { type: "h2", html: `6. 국외 이전` },
    { type: "p", html: `당사의 일부 처리자는 유럽경제지역 외부에 소재합니다. 이전은 유럽위원회의 표준계약조항(SCC) 및 영국과 홍콩 법률상 이에 상응하는 보호 조치에 의해 보호됩니다.` },
    { type: "h2", html: `7. 쿠키` },
    { type: "p", html: `웹사이트는 인증 및 환경설정을 위해 반드시 필요한 쿠키만 사용합니다. 당사는 광고 또는 추적 쿠키를 사용하지 않습니다. 모바일 앱은 로컬 저장소와 푸시 전송을 위한 알림 토큰을 사용합니다.` },
    { type: "h2", html: `8. 아동` },
    { type: "p", html: `본 서비스는 16세 미만의 아동을 대상으로 하지 않습니다. 당사는 미성년자의 정보를 고의로 수집하지 않습니다.` },
    { type: "h2", html: `9. 변경` },
    { type: "p", html: `본 정책의 중대한 변경 사항은 효력 발생 최소 30일 전에 앱 내 및 이메일(제품 업데이트 수신에 동의한 경우)로 통지됩니다.` },
    { type: "h2", html: `10. 문의` },
    { type: "p", html: `개인정보 보호 문의: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  ja: {
    lastUpdated: "2026年4月25日",
    sections: [
    { type: "p", html: `CARDELLI HERMANOS LIMITED（HoPetSitとして事業を行う。以下「当社」）は、HoPetSitモバイルアプリケーションおよびウェブサイト（以下「本サービス」）を通じて収集される個人データの管理者です。本ページでは、当社が何を収集し、その理由、保管期間、およびお客様の権利について、EU一般データ保護規則（GDPR）、英国GDPRならびに香港PDPOに従って説明します。` },
    { type: "h2", html: `1. 当社が収集する情報` },
    { type: "ul", html: [
      `<strong>アカウント情報:</strong> 氏名、メールアドレス、電話番号（任意）、都市、役割、パスワードのハッシュ。`,
      `<strong>プロフィール情報:</strong> アバター、自己紹介、対応言語、提供サービス、料金、対応可能日時。`,
      `<strong>予約情報:</strong> 日程、ペット、料金、ステータス、レビュー。`,
      `<strong>決済情報:</strong> 規制を受けた決済事業者が発行するトークン — 当社がお客様のカード番号を確認することはありません。保存済みカードを表示するため、下4桁とカードブランドを保管します。`,
      `<strong>コミュニケーション:</strong> チャットメッセージ、サポートへのお問い合わせ、お問い合わせフォームの送信内容。`,
      `<strong>技術情報:</strong> IPアドレス、デバイスの種類、アプリのバージョン、言語、クラッシュレポート。`,
      `<strong>位置情報:</strong> お近くの提供者を探す場合、または依頼を掲載する場合に、お客様が明示的に位置情報の許可を与えたときに限ります。`
    ]},
    { type: "h2", html: `2. 処理の目的（法的根拠）` },
    { type: "ul", html: [
      `<strong>契約:</strong> アカウントの作成および運用、予約と決済の処理。`,
      `<strong>正当な利益:</strong> 不正防止、コンテンツのモデレーション、プロダクト分析。`,
      `<strong>同意:</strong> マーケティングメール、プッシュ通知、位置情報へのアクセス。`,
      `<strong>法的義務:</strong> 税務記録、マネーロンダリング防止法令の遵守。`
    ]},
    { type: "h2", html: `3. 第三者への提供` },
    { type: "p", html: `当社は以下との間でデータを共有します:` },
    { type: "ul", html: [
      `カード決済およびIBANへの支払いのための決済処理業者（PCI-DSS準拠）。`,
      `厳格なデータ処理契約に基づくクラウドインフラ（Render、MongoDB、Cloudinary）。`,
      `予約に必要な範囲に限り、他の利用者（例：ご予約いただいたシッターにお客様の氏名とアバターが表示されます）。`,
      `法令で義務付けられる場合の当局。`
    ]},
    { type: "p", html: `当社はお客様のデータを販売<strong>しません</strong>。また、プラットフォームをまたぐ広告には利用しません。` },
    { type: "h2", html: `4. 保存期間` },
    { type: "p", html: `アカウント情報は、アカウントが有効である間および削除後24か月間（不正防止のため）保管されます。予約および決済の記録は、税務上の要請により10年間保管されます。チャットメッセージは会話が存続する間保管され、論理削除されたメッセージは管理者モデレーターのみが引き続き閲覧できます。` },
    { type: "h2", html: `5. お客様の権利` },
    { type: "ul", html: [
      `アクセス、訂正、消去、処理の制限、データポータビリティおよび異議申立ての権利。`,
      `いつでも同意を撤回する権利（プッシュ通知、マーケティング）。`,
      `お住まいの地域のデータ保護監督機関（例：フランスのCNIL）に苦情を申し立てる権利。`
    ]},
    { type: "p", html: `権利の行使は<a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>までお申し出ください。当社は30日以内に回答します。` },
    { type: "h2", html: `6. 国際的なデータ移転` },
    { type: "p", html: `当社の処理者の一部は欧州経済領域外に所在しています。移転は、欧州委員会の標準契約条項（SCC）ならびに英国および香港の法律に基づく同等の保護措置によって保護されます。` },
    { type: "h2", html: `7. Cookie` },
    { type: "p", html: `本ウェブサイトは、認証および設定のために厳密に必要なCookieのみを使用します。当社は広告用または追跡用のCookieを使用しません。モバイルアプリは、ローカルストレージとプッシュ配信のための通知トークンを使用します。` },
    { type: "h2", html: `8. 未成年者` },
    { type: "p", html: `本サービスは16歳未満のお子様を対象としていません。当社が未成年者のデータを故意に収集することはありません。` },
    { type: "h2", html: `9. 変更` },
    { type: "p", html: `本ポリシーの重要な変更は、効力発生の少なくとも30日前に、アプリ内および（製品アップデートの受信に同意されている場合は）メールにて通知します。` },
    { type: "h2", html: `10. お問い合わせ` },
    { type: "p", html: `データ保護に関するお問い合わせ: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
  // v546 — polonais : version ANGLAISE reprise telle quelle (un texte
  // juridique ne se traduit pas automatiquement ; à faire relire par un
  // traducteur juridique avant une version polonaise).
  pl: {
    lastUpdated: "April 25, 2026",
    sections: [
    { type: "p", html: `CARDELLI HERMANOS LIMITED (trading as HoPetSit) ("we", "us") is the data controller of personal data collected through the HoPetSit mobile application and website (the "Service"). This page explains what we collect, why, how long we keep it, and your rights — in accordance with the EU General Data Protection Regulation (GDPR), the UK GDPR and Hong Kong PDPO.` },
    { type: "h2", html: `1. Data we collect` },
    { type: "ul", html: [
      `<strong>Account data:</strong> name, email, phone (optional), city, role, password hash.`,
      `<strong>Profile data:</strong> avatar, bio, languages, services offered, rates, availability.`,
      `<strong>Booking data:</strong> dates, pets, prices, status, reviews.`,
      `<strong>Payment data:</strong> a token from our regulated payment provider — we never see your card number. Last 4 digits and brand are stored to display saved cards.`,
      `<strong>Communications:</strong> chat messages, support tickets, contact-form submissions.`,
      `<strong>Technical data:</strong> IP address, device type, app version, language, crash reports.`,
      `<strong>Location:</strong> only when you explicitly grant location permission to find providers near you or to publish a request.`
    ]},
    { type: "h2", html: `2. Why we process it (legal basis)` },
    { type: "ul", html: [
      `<strong>Contract:</strong> creating and operating your account, processing bookings and payments.`,
      `<strong>Legitimate interest:</strong> fraud prevention, content moderation, product analytics.`,
      `<strong>Consent:</strong> marketing emails, push notifications, location access.`,
      `<strong>Legal obligation:</strong> tax records, anti-money-laundering compliance.`
    ]},
    { type: "h2", html: `3. Sharing` },
    { type: "p", html: `We share data with:` },
    { type: "ul", html: [
      `The payment processor (PCI-DSS compliant) for card transactions and IBAN payouts.`,
      `Cloud infrastructure (Render, MongoDB, Cloudinary) under strict data-processing agreements.`,
      `Other users only as needed for a booking (e.g. your name and avatar are shown to the sitter you booked).`,
      `Authorities when required by law.`
    ]},
    { type: "p", html: `We do <strong>not</strong> sell your data and do not use it for cross-platform advertising.` },
    { type: "h2", html: `4. Retention` },
    { type: "p", html: `Account data is kept while your account is active and 24 months after deletion (for fraud prevention). Booking and payment records are kept 10 years for tax compliance. Chat messages are kept for the lifetime of the conversation; soft-deleted messages remain visible to admin moderators only.` },
    { type: "h2", html: `5. Your rights` },
    { type: "ul", html: [
      `Right of access, rectification, erasure, restriction, portability and objection.`,
      `Right to withdraw consent at any time (push notifications, marketing).`,
      `Right to lodge a complaint with your local data-protection authority (e.g. CNIL in France).`
    ]},
    { type: "p", html: `Exercise your rights at <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. We answer within 30 days.` },
    { type: "h2", html: `6. International transfers` },
    { type: "p", html: `Some of our processors are based outside the European Economic Area. Transfers are protected by the European Commission's Standard Contractual Clauses (SCCs) and equivalent safeguards under UK and Hong Kong law.` },
    { type: "h2", html: `7. Cookies` },
    { type: "p", html: `The website uses strictly necessary cookies for authentication and preferences. We do not use advertising or tracking cookies. The mobile app uses local storage and a notification token for push delivery.` },
    { type: "h2", html: `8. Children` },
    { type: "p", html: `The Service is not directed to children under 16. We do not knowingly collect data from minors.` },
    { type: "h2", html: `9. Changes` },
    { type: "p", html: `Material changes to this policy are notified in-app and by email (when you have opted in to product updates) at least 30 days before they take effect.` },
    { type: "h2", html: `10. Contact` },
    { type: "p", html: `Data Protection contact: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>` },
  ],
  },
};

export const REFUND: LegalDocByLang = {
  en: {
    lastUpdated: "April 25, 2026",
    sections: [
    { type: "p", html: `This Refund Policy applies to all bookings made through the HoPetSit marketplace. It complements the <a href="/terms">Terms of Service</a> and reflects how cancellations and refunds are actually executed by our payment processor (Airwallex).` },
    { type: "h2", html: `1. How payments are held` },
    { type: "p", html: `When an owner pays for a confirmed booking, the funds are captured by our regulated payment processor (Airwallex) and held in escrow. They are released to the provider's registered bank account <strong>24 hours after the service ends</strong> — this dispute window protects the owner if anything goes wrong during the service.` },
    { type: "h2", html: `2. Cancellation by the owner — 72-hour free window` },
    { type: "ul", html: [
      `<strong>More than 72 hours before the service starts:</strong> You can self-cancel from the app. The booking is cancelled immediately and you receive a <strong>100% automatic refund</strong> (no questions asked). Funds typically reach your bank within 5–10 business days.`,
      `<strong>72 hours or less before the service starts:</strong> Self-cancellation is no longer available. You must request a <strong>mutual cancellation</strong> from your provider in the chat, or open a formal dispute via <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. Refunds within this window are reviewed case-by-case based on the reason and any evidence.`
    ]},
    { type: "h2", html: `3. Cancellation by the provider` },
    { type: "p", html: `If your sitter or walker cancels a confirmed booking — at any time before the service starts — you receive a <strong>100% automatic refund</strong>. The provider may incur a cancellation fee, visibility downgrade or platform suspension if cancellations become repeated, to protect the trust of owners on the platform.` },
    { type: "h2", html: `4. Service not delivered (no-show, sitter unreachable)` },
    { type: "p", html: `If the service was paid for but never delivered, you can open a dispute within <strong>24 hours of the scheduled service end</strong> via the chat or by emailing <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. After verification (chat history, photos, GPS check-ins, ratings), we issue a full refund within 5 business days.` },
    { type: "h2", html: `5. Service materially different from what was agreed` },
    { type: "p", html: `Partial refunds may be granted at our discretion when the service was materially different from what was agreed (significantly shorter duration, conditions clearly violated, etc.). Both parties have the opportunity to share evidence in the dispute.` },
    { type: "h2", html: `6. Force majeure` },
    { type: "p", html: `Documented force majeure events affecting either party (severe illness with medical proof, natural disaster, government-imposed travel ban, death of the pet, etc.) are reviewed case-by-case regardless of the standard timeline. Refunds may be granted on presentation of appropriate evidence.` },
    { type: "h2", html: `7. How refunds are issued` },
    { type: "p", html: `Refunds are issued back to the original payment method (the card used at checkout, via Airwallex). Funds typically arrive within <strong>5 to 10 business days</strong> depending on your bank.` },
    { type: "h2", html: `8. Chargebacks` },
    { type: "p", html: `We strongly encourage owners to use HoPetSit's internal dispute mechanism before initiating a chargeback with their card issuer. Owners initiating chargebacks without first contacting us, or while a dispute is already active, may forfeit our internal resolution process and may be permanently removed from the platform. We cooperate fully with Airwallex on legitimate chargeback investigations.` },
    { type: "h2", html: `9. Contact` },
    { type: "p", html: `Refund requests, disputes and questions: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> · we aim to reply within 48 hours.` },
  ],
  },
  fr: {
    lastUpdated: "25 avril 2026",
    sections: [
    { type: "p", html: `Cette politique de remboursement s'applique à toutes les réservations effectuées via le marché HoPetSit. Il complète les <a href="/terms">Terms of Service</a> et reflète la manière dont les annulations et les remboursements sont réellement exécutés par notre processeur de paiement (Airwallex).` },
    { type: "h2", html: `1. Comment les paiements sont retenus` },
    { type: "p", html: `Lorsqu'un propriétaire paie pour une réservation confirmée, les fonds sont capturés par notre processeur de paiement réglementé (Airwallex) et conservés sous séquestre. Ils sont déposés sur le compte bancaire enregistré du fournisseur <strong>24 heures après la fin du service</strong> — cette fenêtre de litige protège le propriétaire en cas de problème pendant le service.` },
    { type: "h2", html: `2. Annulation par le propriétaire — Fenêtre gratuite de 72 heures` },
    { type: "ul", html: [
      `<strong>Plus de 72 heures avant le début du service :</strong> Vous pouvez vous annuler vous-même depuis l'application. La réservation est annulée immédiatement et vous recevez un remboursement automatique <strong>100%</strong> (sans poser de questions). Les fonds parviennent généralement à votre banque dans un délai de 5 à 10 jours ouvrables.`,
      `<strong>72 heures ou moins avant le démarrage du service :</strong> L'auto-annulation n'est plus disponible. Vous devez demander une <strong>annulation mutuelle</strong> à votre fournisseur dans le chat, ou ouvrir un litige formel via <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. Les remboursements dans cette fenêtre sont examinés au cas par cas en fonction du motif et de toute preuve.`
    ]},
    { type: "h2", html: `3. Annulation par le fournisseur` },
    { type: "p", html: `Si votre gardien ou votre promeneur annule une réservation confirmée — à tout moment avant le début du service — vous recevez un remboursement automatique <strong>100 %</strong>. Le fournisseur peut encourir des frais d'annulation, une dégradation de la visibilité ou une suspension de la plateforme si les annulations se répètent, afin de protéger la confiance des propriétaires sur la plateforme.` },
    { type: "h2", html: `4. Service non délivré (non-présentation, gardien injoignable)` },
    { type: "p", html: `Si le service a été payé mais n'a jamais été livré, vous pouvez ouvrir un litige dans les <strong>24 heures suivant la fin du service prévu</strong> via le chat ou en envoyant un e-mail à <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. After verification (chat history, photos, GPS check-ins, ratings), we issue a full refund within 5 business days.` },
    { type: "h2", html: `5. Service sensiblement différent de ce qui a été convenu` },
    { type: "p", html: `Des remboursements partiels peuvent être accordés à notre discrétion lorsque la prestation était sensiblement différente de celle convenue (durée nettement plus courte, conditions clairement violées, etc.). Les deux parties ont la possibilité de partager des preuves dans le cadre du différend.` },
    { type: "h2", html: `6. Force majeure` },
    { type: "p", html: `Les événements de force majeure documentés affectant l'une ou l'autre des parties (maladie grave avec preuve médicale, catastrophe naturelle, interdiction de voyager imposée par le gouvernement, décès de l'animal, etc.) sont examinés au cas par cas quel que soit le calendrier standard. Les remboursements peuvent être accordés sur présentation de justificatifs appropriés.` },
    { type: "h2", html: `7. Comment les remboursements sont émis` },
    { type: "p", html: `Les remboursements sont effectués sur le mode de paiement d'origine (la carte utilisée lors du paiement, via Airwallex). Les fonds arrivent généralement dans un délai <strong>5 à 10 jours ouvrables</strong> selon votre banque.` },
    { type: "h2", html: `8. Rétrofacturations` },
    { type: "p", html: `Nous encourageons fortement les propriétaires à utiliser le mécanisme de règlement des litiges interne de HoPetSit avant de lancer une rétrofacturation auprès de l'émetteur de leur carte. Les propriétaires qui lancent des rétrofacturations sans nous contacter au préalable, ou alors qu'un litige est déjà actif, peuvent renoncer à notre processus de résolution interne et peuvent être définitivement supprimés de la plateforme. Nous coopérons pleinement avec Airwallex dans le cadre d'enquêtes légitimes de rétrofacturation.` },
    { type: "h2", html: `9. Contacter` },
    { type: "p", html: `Demandes de remboursement, litiges et questions : <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> · nous visons à répondre dans les 48 heures.` },
  ],
  },
  es: {
    lastUpdated: "25 de abril de 2026",
    sections: [
    { type: "p", html: `Esta Política de reembolso se aplica a todas las reservas realizadas a través del mercado HoPetSit. Complementa los <a href="/terms">Términos de servicio</a> y refleja cómo nuestro procesador de pagos (Airwallex) ejecuta realmente las cancelaciones y los reembolsos.` },
    { type: "h2", html: `1. Cómo se realizan los pagos` },
    { type: "p", html: `Cuando un propietario paga una reserva confirmada, los fondos son capturados por nuestro procesador de pagos regulado (Airwallex) y mantenidos en depósito de garantía. Se liberan a la cuenta bancaria registrada del proveedor <strong>24 horas después de que finaliza el servicio</strong>; esta ventana de disputa protege al propietario si algo sale mal durante el servicio.` },
    { type: "h2", html: `2. Cancelación por parte del propietario: ventana gratuita de 72 horas` },
    { type: "ul", html: [
      `<strong>Más de 72 horas antes de que comience el servicio:</strong> Puedes autocancelar desde la aplicación. La reserva se cancela inmediatamente y recibes un reembolso <strong>100% automático</strong> (sin preguntas). Los fondos suelen llegar a su banco en un plazo de 5 a 10 días hábiles.`,
      `<strong>72 horas o menos antes de que comience el servicio:</strong> La autocancelación ya no está disponible. Debes solicitar una <strong>cancelación mutua</strong> a tu proveedor en el chat, o abrir una disputa formal a través de <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. Los reembolsos dentro de este plazo se revisan caso por caso según el motivo y cualquier evidencia.`
    ]},
    { type: "h2", html: `3. Cancelación por parte del proveedor` },
    { type: "p", html: `Si su niñera o paseador cancela una reserva confirmada, en cualquier momento antes de que comience el servicio, recibirá un reembolso <strong>100 % automático</strong>. El proveedor puede incurrir en una tarifa de cancelación, una degradación de la visibilidad o la suspensión de la plataforma si las cancelaciones se repiten, para proteger la confianza de los propietarios en la plataforma.` },
    { type: "h2", html: `4. Servicio no entregado (no presentado, niñera inalcanzable)` },
    { type: "p", html: `Si el servicio se pagó pero nunca se entregó, puede abrir una disputa dentro de las <strong>24 horas posteriores a la finalización del servicio programado</strong> a través del chat o enviando un correo electrónico a <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. Después de la verificación (historial de chat, fotos, registros de GPS, calificaciones), emitimos un reembolso completo dentro de los 5 días hábiles.` },
    { type: "h2", html: `5. Servicio sustancialmente diferente al acordado.` },
    { type: "p", html: `Se podrán conceder reembolsos parciales a nuestra discreción cuando el servicio sea materialmente diferente de lo acordado (duración significativamente más corta, condiciones claramente violadas, etc.). Ambas partes tienen la oportunidad de compartir pruebas en la disputa.` },
    { type: "h2", html: `6. Fuerza mayor` },
    { type: "p", html: `Los eventos de fuerza mayor documentados que afectan a cualquiera de las partes (enfermedad grave con prueba médica, desastre natural, prohibición de viajar impuesta por el gobierno, muerte de la mascota, etc.) se revisan caso por caso, independientemente del cronograma estándar. Se podrán conceder reembolsos previa presentación de pruebas adecuadas.` },
    { type: "h2", html: `7. Cómo se emiten los reembolsos` },
    { type: "p", html: `Los reembolsos se emiten al método de pago original (la tarjeta utilizada al finalizar la compra, a través de Airwallex). Los fondos suelen llegar en un plazo de <strong>5 a 10 días hábiles</strong>, según su banco.` },
    { type: "h2", html: `8. Devoluciones de cargo` },
    { type: "p", html: `Recomendamos encarecidamente a los propietarios que utilicen el mecanismo de disputa interno de HoPetSit antes de iniciar una devolución de cargo con el emisor de su tarjeta. Los propietarios que inicien devoluciones de cargo sin contactarnos primero, o mientras una disputa ya esté activa, pueden perder nuestro proceso de resolución interna y pueden ser eliminados permanentemente de la plataforma. Cooperamos plenamente con Airwallex en investigaciones legítimas de contracargos.` },
    { type: "h2", html: `9. Contacto` },
    { type: "p", html: `Solicitudes de reembolso, disputas y preguntas: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> · nuestro objetivo es responder dentro de las 48 horas.` },
  ],
  },
  de: {
    lastUpdated: "25. April 2026",
    sections: [
    { type: "p", html: `Diese Rückerstattungsrichtlinie gilt für alle Buchungen, die über den HoPetSit-Marktplatz vorgenommen werden. Es ergänzt die <a href="/terms">Terms of Service</a> und spiegelt wider, wie Stornierungen und Rückerstattungen tatsächlich von unserem Zahlungsabwickler (Airwallex) durchgeführt werden.` },
    { type: "h2", html: `1. Wie Zahlungen abgewickelt werden` },
    { type: "p", html: `Wenn ein Eigentümer für eine bestätigte Buchung bezahlt, werden die Gelder von unserem regulierten Zahlungsabwickler (Airwallex) erfasst und treuhänderisch verwahrt. Sie werden <strong>24 Stunden nach Ende des Dienstes auf das registrierte Bankkonto des Anbieters überwiesen.` },
    { type: "h2", html: `2. Stornierung durch den Eigentümer – 72 Stunden freies Fenster` },
    { type: "ul", html: [
      `<strong>Mehr als 72 Stunden vor Beginn des Dienstes:</strong> Sie können über die App selbst kündigen. Die Buchung wird sofort storniert und Sie erhalten eine <strong>100 % automatische Rückerstattung</strong> (keine Fragen gestellt). Das Geld erreicht Ihre Bank in der Regel innerhalb von 5–10 Werktagen.`,
      `<strong>72 Stunden oder weniger vor Beginn des Dienstes:</strong> Selbstkündigung ist nicht mehr verfügbar. Sie müssen bei Ihrem Anbieter im Chat eine <strong>gegenseitige Stornierung</strong> beantragen oder einen formellen Streit über <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> eröffnen. Rückerstattungen innerhalb dieses Zeitraums werden von Fall zu Fall auf der Grundlage des Grunds und etwaiger Beweise geprüft.`
    ]},
    { type: "h2", html: `3. Stornierung durch den Anbieter` },
    { type: "p", html: `Wenn Ihr Sitter oder Wanderer eine bestätigte Buchung storniert – zu irgendeinem Zeitpunkt vor Beginn des Dienstes – erhalten Sie eine <strong>100 % automatische Rückerstattung</strong>. Um das Vertrauen der Eigentümer in die Plattform zu schützen, kann der Anbieter bei wiederholten Stornierungen eine Stornierungsgebühr, eine Herabstufung der Sichtbarkeit oder eine Sperrung der Plattform verlangen.` },
    { type: "h2", html: `4. Service nicht erbracht (Nichterscheinen, Sitter nicht erreichbar)` },
    { type: "p", html: `Wenn der Service bezahlt, aber nie geliefert wurde, können Sie innerhalb von <strong>24 Stunden nach dem geplanten Serviceende</strong> über den Chat oder per E-Mail an <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> einen Streitfall eröffnen. Nach der Überprüfung (Chatverlauf, Fotos, GPS-Check-ins, Bewertungen) erstatten wir Ihnen den vollen Betrag innerhalb von 5 Werktagen.` },
    { type: "h2", html: `5. Die Leistung weicht wesentlich von der vereinbarten Leistung ab` },
    { type: "p", html: `Teilweise Rückerstattungen können nach unserem Ermessen gewährt werden, wenn die Leistung wesentlich von der vereinbarten Leistung abweicht (deutlich kürzere Dauer, offensichtliche Verletzung von Bedingungen usw.). Beide Parteien haben die Möglichkeit, im Streit Beweise auszutauschen.` },
    { type: "h2", html: `6. Höhere Gewalt` },
    { type: "p", html: `Dokumentierte Ereignisse höherer Gewalt, die eine Partei betreffen (schwere Krankheit mit ärztlichem Nachweis, Naturkatastrophe, staatliches Reiseverbot, Tod des Haustieres usw.), werden unabhängig von der Standardfrist im Einzelfall geprüft. Gegen Vorlage entsprechender Nachweise kann eine Rückerstattung gewährt werden.` },
    { type: "h2", html: `7. Wie Rückerstattungen erfolgen` },
    { type: "p", html: `Rückerstattungen erfolgen über die ursprüngliche Zahlungsmethode (die beim Bezahlvorgang verwendete Karte, über Airwallex). Das Geld kommt je nach Bank in der Regel innerhalb von <strong>5 bis 10 Werktagen</strong> an.` },
    { type: "h2", html: `8. Rückbuchungen` },
    { type: "p", html: `Wir empfehlen Eigentümern dringend, den internen Streitbeilegungsmechanismus von HoPetSit zu nutzen, bevor sie eine Rückbuchung bei ihrem Kartenaussteller einleiten. Eigentümer, die Rückbuchungen einleiten, ohne uns vorher zu kontaktieren oder während ein Streit bereits aktiv ist, können unseren internen Lösungsprozess verlieren und dauerhaft von der Plattform entfernt werden. Bei rechtmäßigen Rückbuchungsuntersuchungen arbeiten wir uneingeschränkt mit Airwallex zusammen.` },
    { type: "h2", html: `9. Kontakt` },
    { type: "p", html: `Rückerstattungsanträge, Streitigkeiten und Fragen: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> · Wir sind bestrebt, innerhalb von 48 Stunden zu antworten.` },
  ],
  },
  it: {
    lastUpdated: "25 aprile 2026",
    sections: [
    { type: "p", html: `La presente Politica di rimborso si applica a tutte le prenotazioni effettuate tramite il mercato HoPetSit. Integra i <a href="/terms">Termini di servizio</a> e riflette il modo in cui le cancellazioni e i rimborsi vengono effettivamente eseguiti dal nostro processore di pagamento (Airwallex).` },
    { type: "h2", html: `1. Come vengono tenuti i pagamenti` },
    { type: "p", html: `Quando un proprietario paga per una prenotazione confermata, i fondi vengono acquisiti dal nostro processore di pagamento regolamentato (Airwallex) e conservati in garanzia. Vengono rilasciati sul conto bancario registrato del fornitore <strong>24 ore dopo la fine del servizio</strong>: questa finestra di controversia protegge il proprietario se qualcosa va storto durante il servizio.` },
    { type: "h2", html: `2. Cancellazione da parte del proprietario: periodo gratuito di 72 ore` },
    { type: "ul", html: [
      `<strong>Più di 72 ore prima dell'inizio del servizio:</strong> Puoi annullare autonomamente dall'app. La prenotazione viene annullata immediatamente e riceverai un <strong>rimborso automatico al 100%</strong> (senza fare domande). In genere i fondi raggiungono la tua banca entro 5-10 giorni lavorativi.`,
      `<strong>72 ore o meno prima dell'inizio del servizio:</strong> L'annullamento automatico non è più disponibile. Devi richiedere una <strong>cancellazione reciproca</strong> dal tuo provider nella chat o aprire una controversia formale tramite <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. I rimborsi all'interno di questa finestra vengono esaminati caso per caso in base al motivo e alle eventuali prove.`
    ]},
    { type: "h2", html: `3. Cancellazione da parte del fornitore` },
    { type: "p", html: `Se il tuo sitter o walker annulla una prenotazione confermata, in qualsiasi momento prima dell'inizio del servizio, riceverai un <strong>rimborso automatico al 100%</strong>. Il fornitore può incorrere in una penale di cancellazione, downgrade della visibilità o sospensione della piattaforma se le cancellazioni si ripetono, per proteggere la fiducia dei proprietari sulla piattaforma.` },
    { type: "h2", html: `4. Servizio non erogato (mancata presentazione, sitter irraggiungibile)` },
    { type: "p", html: `Se il servizio è stato pagato ma mai consegnato, puoi aprire una controversia entro <strong>24 ore dal servizio previsto end</strong> tramite la chat o inviando un'e-mail a <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. Dopo la verifica (cronologia chat, foto, check-in GPS, valutazioni), emettiamo un rimborso completo entro 5 giorni lavorativi.` },
    { type: "h2", html: `5. Servizio sostanzialmente diverso da quanto concordato` },
    { type: "p", html: `Rimborsi parziali potranno essere concessi a nostra discrezione qualora il servizio fosse sostanzialmente diverso da quanto concordato (durata notevolmente inferiore, condizioni palesemente violate, ecc.). Entrambe le parti hanno la possibilità di condividere le prove nella controversia.` },
    { type: "h2", html: `6. Forza maggiore` },
    { type: "p", html: `Gli eventi di forza maggiore documentati che colpiscono entrambe le parti (malattia grave con prova medica, disastro naturale, divieto di viaggio imposto dal governo, morte dell'animale domestico, ecc.) vengono esaminati caso per caso indipendentemente dalla tempistica standard. I rimborsi possono essere concessi dietro presentazione di prove adeguate.` },
    { type: "h2", html: `7. Come vengono emessi i rimborsi` },
    { type: "p", html: `I rimborsi vengono accreditati sul metodo di pagamento originale (la carta utilizzata al momento del pagamento, tramite Airwallex). I fondi in genere arrivano entro <strong>5 e 10 giorni lavorativi</strong> a seconda della banca.` },
    { type: "h2", html: `8. Riaddebiti` },
    { type: "p", html: `Incoraggiamo vivamente i proprietari a utilizzare il meccanismo di controversia interno di HoPetSit prima di avviare uno storno di addebito con l'emittente della carta. I proprietari che avviano storni di addebito senza prima contattarci, o mentre una controversia è già attiva, potrebbero rinunciare al nostro processo di risoluzione interno e potrebbero essere rimossi permanentemente dalla piattaforma. Collaboriamo pienamente con Airwallex nelle legittime indagini sui riaddebiti.` },
    { type: "h2", html: `9. Contatto` },
    { type: "p", html: `Richieste di rimborso, controversie e domande: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> · miriamo a rispondere entro 48 ore.` },
  ],
  },
  pt: {
    lastUpdated: "25 de abril de 2026",
    sections: [
    { type: "p", html: `Esta Política de Reembolso se aplica a todas as reservas feitas através do mercado HoPetSit. Ele complementa os <a href="/terms">Termos de serviço</a> e reflete como os cancelamentos e reembolsos são realmente executados pelo nosso processador de pagamentos (Airwallex).` },
    { type: "h2", html: `1. Como os pagamentos são retidos` },
    { type: "p", html: `Quando um proprietário paga por uma reserva confirmada, os fundos são capturados pelo nosso processador de pagamentos regulamentado (Airwallex) e mantidos em depósito. Eles são liberados para a conta bancária cadastrada do provedor <strong>24 horas após o término do serviço</strong> — essa janela de disputa protege o proprietário caso algo dê errado durante o serviço.` },
    { type: "h2", html: `2. Cancelamento por parte do proprietário — janela gratuita de 72 horas` },
    { type: "ul", html: [
      `<strong>Mais de 72 horas antes do início do serviço:</strong> Você pode cancelar automaticamente no aplicativo. A reserva é cancelada imediatamente e você recebe um reembolso automático <strong>100%</strong> (sem perguntas). Os fundos normalmente chegam ao seu banco dentro de 5 a 10 dias úteis.`,
      `<strong>72 horas ou menos antes do início do serviço:</strong> O autocancelamento não está mais disponível. Você deve solicitar um cancelamento mútuo <strong></strong> ao seu provedor no chat ou abrir uma disputa formal via <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. Os reembolsos dentro desta janela são analisados ​​caso a caso com base no motivo e em qualquer evidência.`
    ]},
    { type: "h2", html: `3. Cancelamento pelo provedor` },
    { type: "p", html: `Se o seu babá ou acompanhante cancelar uma reserva confirmada – a qualquer momento antes do início do serviço – você receberá um reembolso automático de <strong>100%</strong>. O fornecedor pode incorrer numa taxa de cancelamento, redução de visibilidade ou suspensão da plataforma se os cancelamentos se repetirem, para proteger a confiança dos proprietários na plataforma.` },
    { type: "h2", html: `4. Serviço não entregue (não comparecimento, babá inacessível)` },
    { type: "p", html: `Se o serviço foi pago, mas nunca entregue, você pode abrir uma disputa dentro de <strong>24 horas após o término do serviço agendado</strong> por meio do chat ou enviando um e-mail para <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. Após a verificação (histórico de bate-papo, fotos, check-ins de GPS, avaliações), emitimos um reembolso total em até 5 dias úteis.` },
    { type: "h2", html: `5. Serviço materialmente diferente do acordado` },
    { type: "p", html: `Reembolsos parciais podem ser concedidos a nosso critério quando o serviço for materialmente diferente do acordado (duração significativamente mais curta, condições claramente violadas, etc.). Ambas as partes têm a oportunidade de compartilhar evidências na disputa.` },
    { type: "h2", html: `6. Força maior` },
    { type: "p", html: `Eventos de força maior documentados que afetam qualquer uma das partes (doença grave com comprovação médica, desastre natural, proibição de viagem imposta pelo governo, morte do animal de estimação, etc.) são revisados ​​caso a caso, independentemente do cronograma padrão. Os reembolsos poderão ser concedidos mediante apresentação de provas adequadas.` },
    { type: "h2", html: `7. Como são emitidos os reembolsos` },
    { type: "p", html: `Os reembolsos são emitidos de volta para o método de pagamento original (o cartão usado na finalização da compra, via Airwallex). Os fundos normalmente chegam dentro de <strong>5 a 10 dias úteis</strong> dependendo do seu banco.` },
    { type: "h2", html: `8. Estornos` },
    { type: "p", html: `Encorajamos fortemente os proprietários a usar o mecanismo de disputa interno do HoPetSit antes de iniciar um estorno junto ao emissor do cartão. Os proprietários que iniciarem estornos sem primeiro entrar em contato conosco, ou enquanto uma disputa já estiver ativa, poderão perder nosso processo de resolução interno e ser removidos permanentemente da plataforma. Cooperamos totalmente com a Airwallex em investigações legítimas de estornos.` },
    { type: "h2", html: `9. Contato` },
    { type: "p", html: `Solicitações de reembolso, disputas e dúvidas: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> · pretendemos responder dentro de 48 horas.` },
  ],
  },
  ko: {
    lastUpdated: "2026년 4월 25일",
    sections: [
    { type: "p", html: `본 환불 정책은 HoPetSit 마켓플레이스를 통해 이루어진 모든 예약에 적용됩니다. 본 정책은 <a href="/terms">서비스 이용약관</a>을 보완하며, 당사의 결제 처리업체(Airwallex)가 취소와 환불을 실제로 어떻게 실행하는지를 반영합니다.` },
    { type: "h2", html: `1. 결제 대금의 보관 방식` },
    { type: "p", html: `소유자가 확정된 예약 대금을 결제하면, 해당 자금은 당사의 규제 대상 결제 처리업체(Airwallex)가 수취하여 에스크로에 보관합니다. 자금은 <strong>서비스 종료 24시간 후</strong>에 제공자가 등록한 은행 계좌로 지급되며, 이 분쟁 제기 기간은 서비스 중 문제가 발생한 경우 소유자를 보호합니다.` },
    { type: "h2", html: `2. 소유자에 의한 취소 — 72시간 무료 취소 기간` },
    { type: "ul", html: [
      `<strong>서비스 시작 72시간 이전:</strong> 앱에서 직접 취소할 수 있습니다. 예약은 즉시 취소되며 <strong>100% 자동 환불</strong>을 받습니다(사유를 묻지 않습니다). 자금은 일반적으로 영업일 기준 5~10일 이내에 은행 계좌로 입금됩니다.`,
      `<strong>서비스 시작 72시간 이내:</strong> 직접 취소는 더 이상 이용할 수 없습니다. 채팅에서 제공자에게 <strong>상호 취소</strong>를 요청하거나 <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>을 통해 공식 분쟁을 제기해야 합니다. 이 기간 내의 환불은 사유와 제출된 증빙을 바탕으로 개별적으로 검토됩니다.`
    ]},
    { type: "h2", html: `3. 제공자에 의한 취소` },
    { type: "p", html: `펫시터 또는 도그워커가 확정된 예약을 취소하는 경우 — 서비스 시작 전이라면 언제든지 — 귀하는 <strong>100% 자동 환불</strong>을 받습니다. 취소가 반복될 경우, 플랫폼 내 소유자의 신뢰를 보호하기 위해 제공자에게 취소 수수료, 노출 순위 하락 또는 플랫폼 이용 정지가 적용될 수 있습니다.` },
    { type: "h2", html: `4. 서비스 미이행(노쇼, 펫시터 연락 두절)` },
    { type: "p", html: `대금을 결제했으나 서비스가 이행되지 않은 경우, <strong>예정된 서비스 종료 후 24시간 이내</strong>에 채팅 또는 <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>으로 이메일을 보내 분쟁을 제기할 수 있습니다. 확인 절차(채팅 기록, 사진, GPS 체크인, 평점) 후 영업일 기준 5일 이내에 전액 환불해 드립니다.` },
    { type: "h2", html: `5. 합의된 내용과 실질적으로 다른 서비스` },
    { type: "p", html: `서비스가 합의된 내용과 실질적으로 다른 경우(현저히 짧은 이용 시간, 조건의 명백한 위반 등) 당사의 재량으로 부분 환불이 승인될 수 있습니다. 양 당사자는 분쟁 절차에서 증빙을 제출할 기회를 갖습니다.` },
    { type: "h2", html: `6. 불가항력` },
    { type: "p", html: `당사자 일방에게 영향을 미치며 문서로 입증된 불가항력 사유(의료 증빙이 있는 중병, 자연재해, 정부의 여행 금지 조치, 반려동물의 사망 등)는 표준 기한과 관계없이 개별적으로 검토됩니다. 적절한 증빙을 제출하면 환불이 승인될 수 있습니다.` },
    { type: "h2", html: `7. 환불 방식` },
    { type: "p", html: `환불은 최초 결제 수단(결제 시 사용한 카드, Airwallex를 통해)으로 이루어집니다. 자금은 거래 은행에 따라 일반적으로 <strong>영업일 기준 5~10일</strong> 이내에 입금됩니다.` },
    { type: "h2", html: `8. 지급 거절(차지백)` },
    { type: "p", html: `당사는 소유자가 카드 발급사에 지급 거절을 신청하기 전에 HoPetSit의 내부 분쟁 처리 절차를 이용할 것을 강력히 권장합니다. 당사에 먼저 연락하지 않거나 분쟁이 이미 진행 중인 상태에서 지급 거절을 신청하는 소유자는 당사의 내부 해결 절차를 이용할 수 없게 되며 플랫폼에서 영구적으로 배제될 수 있습니다. 당사는 정당한 지급 거절 조사에 대해 Airwallex에 전적으로 협조합니다.` },
    { type: "h2", html: `9. 문의` },
    { type: "p", html: `환불 요청, 분쟁 및 문의: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> · 당사는 48시간 이내 답변을 목표로 합니다.` },
  ],
  },
  ja: {
    lastUpdated: "2026年4月25日",
    sections: [
    { type: "p", html: `本返金ポリシーは、HoPetSitマーケットプレイスを通じて行われたすべての予約に適用されます。本ポリシーは<a href="/terms">利用規約</a>を補完し、当社の決済処理業者（Airwallex）によってキャンセルおよび返金が実際にどのように実行されるかを示すものです。` },
    { type: "h2", html: `1. 支払いの保管方法` },
    { type: "p", html: `飼い主が確定した予約の代金を支払うと、その資金は当社の規制を受けた決済処理業者（Airwallex）によって回収され、エスクローに保管されます。資金は<strong>サービス終了の24時間後</strong>に提供者が登録した銀行口座へ払い出されます。この異議申立て期間は、サービス中に問題が生じた場合に飼い主を保護します。` },
    { type: "h2", html: `2. 飼い主によるキャンセル — 72時間の無料キャンセル期間` },
    { type: "ul", html: [
      `<strong>サービス開始の72時間より前:</strong> アプリからご自身でキャンセルできます。予約は直ちにキャンセルされ、<strong>100%の自動返金</strong>を受けられます（理由は問いません）。資金は通常、5〜10営業日以内にお客様の銀行口座に入金されます。`,
      `<strong>サービス開始の72時間前以降:</strong> ご自身によるキャンセルはできません。チャットで提供者に<strong>相互キャンセル</strong>を依頼するか、<a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>から正式な異議申立てを行う必要があります。この期間内の返金は、理由および提出された証拠に基づき個別に審査されます。`
    ]},
    { type: "h2", html: `3. 提供者によるキャンセル` },
    { type: "p", html: `シッターまたはウォーカーが確定済みの予約をキャンセルした場合 — サービス開始前であればいつでも — お客様は<strong>100%の自動返金</strong>を受けられます。キャンセルが繰り返される場合、プラットフォーム上の飼い主の信頼を守るため、提供者にはキャンセル料、表示順位の引き下げ、またはプラットフォームの利用停止が科されることがあります。` },
    { type: "h2", html: `4. サービスが提供されなかった場合（無断不履行、シッターと連絡が取れない）` },
    { type: "p", html: `代金を支払ったにもかかわらずサービスが提供されなかった場合、<strong>予定されたサービス終了から24時間以内</strong>に、チャットまたは<a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>宛のメールで異議申立てを行うことができます。確認（チャット履歴、写真、GPSチェックイン、評価）の後、5営業日以内に全額を返金します。` },
    { type: "h2", html: `5. 合意内容と実質的に異なるサービス` },
    { type: "p", html: `サービスが合意内容と実質的に異なる場合（所要時間が著しく短い、条件が明らかに守られていない等）、当社の裁量により一部返金が認められることがあります。双方の当事者は、異議申立ての手続において証拠を提出する機会を有します。` },
    { type: "h2", html: `6. 不可抗力` },
    { type: "p", html: `いずれかの当事者に影響を及ぼす、書面で証明された不可抗力事由（医師の証明がある重篤な疾病、自然災害、政府による渡航禁止措置、ペットの死亡等）は、標準の期限にかかわらず個別に審査されます。適切な証拠の提示により返金が認められる場合があります。` },
    { type: "h2", html: `7. 返金の方法` },
    { type: "p", html: `返金は、元のお支払い方法（購入手続き時に使用したカード、Airwallex経由）へ行われます。資金は通常、ご利用の銀行に応じて<strong>5〜10営業日</strong>以内に着金します。` },
    { type: "h2", html: `8. チャージバック` },
    { type: "p", html: `当社は、カード発行会社にチャージバックを申し立てる前に、HoPetSitの内部の異議申立て手続をご利用いただくことを強く推奨します。当社に事前に連絡することなく、または既に異議申立てが進行中の状態でチャージバックを申し立てた飼い主は、当社の内部解決手続を利用できなくなり、プラットフォームから恒久的に排除される場合があります。当社は、正当なチャージバック調査についてAirwallexに全面的に協力します。` },
    { type: "h2", html: `9. お問い合わせ` },
    { type: "p", html: `返金のご依頼、異議申立ておよびご質問: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> · 48時間以内の返信を目指しています。` },
  ],
  },
  // v546 — polonais : version ANGLAISE reprise telle quelle (un texte
  // juridique ne se traduit pas automatiquement ; à faire relire par un
  // traducteur juridique avant une version polonaise).
  pl: {
    lastUpdated: "April 25, 2026",
    sections: [
    { type: "p", html: `This Refund Policy applies to all bookings made through the HoPetSit marketplace. It complements the <a href="/terms">Terms of Service</a> and reflects how cancellations and refunds are actually executed by our payment processor (Airwallex).` },
    { type: "h2", html: `1. How payments are held` },
    { type: "p", html: `When an owner pays for a confirmed booking, the funds are captured by our regulated payment processor (Airwallex) and held in escrow. They are released to the provider's registered bank account <strong>24 hours after the service ends</strong> — this dispute window protects the owner if anything goes wrong during the service.` },
    { type: "h2", html: `2. Cancellation by the owner — 72-hour free window` },
    { type: "ul", html: [
      `<strong>More than 72 hours before the service starts:</strong> You can self-cancel from the app. The booking is cancelled immediately and you receive a <strong>100% automatic refund</strong> (no questions asked). Funds typically reach your bank within 5–10 business days.`,
      `<strong>72 hours or less before the service starts:</strong> Self-cancellation is no longer available. You must request a <strong>mutual cancellation</strong> from your provider in the chat, or open a formal dispute via <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. Refunds within this window are reviewed case-by-case based on the reason and any evidence.`
    ]},
    { type: "h2", html: `3. Cancellation by the provider` },
    { type: "p", html: `If your sitter or walker cancels a confirmed booking — at any time before the service starts — you receive a <strong>100% automatic refund</strong>. The provider may incur a cancellation fee, visibility downgrade or platform suspension if cancellations become repeated, to protect the trust of owners on the platform.` },
    { type: "h2", html: `4. Service not delivered (no-show, sitter unreachable)` },
    { type: "p", html: `If the service was paid for but never delivered, you can open a dispute within <strong>24 hours of the scheduled service end</strong> via the chat or by emailing <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>. After verification (chat history, photos, GPS check-ins, ratings), we issue a full refund within 5 business days.` },
    { type: "h2", html: `5. Service materially different from what was agreed` },
    { type: "p", html: `Partial refunds may be granted at our discretion when the service was materially different from what was agreed (significantly shorter duration, conditions clearly violated, etc.). Both parties have the opportunity to share evidence in the dispute.` },
    { type: "h2", html: `6. Force majeure` },
    { type: "p", html: `Documented force majeure events affecting either party (severe illness with medical proof, natural disaster, government-imposed travel ban, death of the pet, etc.) are reviewed case-by-case regardless of the standard timeline. Refunds may be granted on presentation of appropriate evidence.` },
    { type: "h2", html: `7. How refunds are issued` },
    { type: "p", html: `Refunds are issued back to the original payment method (the card used at checkout, via Airwallex). Funds typically arrive within <strong>5 to 10 business days</strong> depending on your bank.` },
    { type: "h2", html: `8. Chargebacks` },
    { type: "p", html: `We strongly encourage owners to use HoPetSit's internal dispute mechanism before initiating a chargeback with their card issuer. Owners initiating chargebacks without first contacting us, or while a dispute is already active, may forfeit our internal resolution process and may be permanently removed from the platform. We cooperate fully with Airwallex on legitimate chargeback investigations.` },
    { type: "h2", html: `9. Contact` },
    { type: "p", html: `Refund requests, disputes and questions: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> · we aim to reply within 48 hours.` },
  ],
  },
};

export const IMPRINT: LegalDocByLang = {
  en: {
    lastUpdated: "April 25, 2026",
    sections: [
    { type: "h2", html: `Operating company` },
    { type: "p", html: `<strong>CARDELLI HERMANOS LIMITED</strong><br/>Trading as <strong>HoPetSit</strong><br/>Hong Kong Companies Registry — CR Number: <strong>2671528</strong><br/>Registered office: Flat/Rm A, 12/F, ZJ 300, 300 Lockhart Road, Wan Chai, Hong Kong<br/>Director: Daniel Cardelli` },
    { type: "h2", html: `Contact` },
    { type: "p", html: `General contact: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a><br/>Press &amp; partnerships: same address with subject "Press" or "Partnership".` },
    { type: "h2", html: `Hosting` },
    { type: "p", html: `<strong>Application backend:</strong> Render Inc., 525 Brannan St, San Francisco, CA 94107, United States.<br/><strong>Website:</strong> Vercel Inc., 440 N Barranca Ave #4133, Covina, CA 91723, United States.<br/><strong>Database:</strong> MongoDB Inc., 1633 Broadway, 38th Floor, New York, NY 10019, United States.` },
    { type: "h2", html: `Payment processing` },
    { type: "p", html: `Card payments and payouts are processed by a regulated payment institution (currently in transition). Funds are held in segregated accounts pursuant to applicable e-money rules.` },
    { type: "h2", html: `Intellectual property` },
    { type: "p", html: `The HoPetSit name, logo, mobile application, source code and website content are protected by copyright. © CARDELLI HERMANOS LIMITED. All rights reserved.` },
    { type: "h2", html: `Editor of publication` },
    { type: "p", html: `Daniel Cardelli, Director of CARDELLI HERMANOS LIMITED.` },
    { type: "h2", html: `Dispute resolution` },
    { type: "p", html: `For consumers in the EU, the European Commission provides an online dispute resolution platform at <a href="https://ec.europa.eu/consumers/odr" rel="noopener" target="_blank">ec.europa.eu/consumers/odr</a>. We are however available to resolve disputes directly via <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> within 48 hours.` },
  ],
  },
  fr: {
    lastUpdated: "25 avril 2026",
    sections: [
    { type: "h2", html: `Société d'exploitation` },
    { type: "p", html: `<strong>CARDELLI HERMANOS LIMITED</strong><br/>Trading sous le nom de <strong>HoPetSit</strong><br/>Registre des sociétés de Hong Kong — Numéro CR : <strong>2671528</strong><br/>Siège social : Flat/Rm A, 12/F, ZJ 300, 300 Lockhart Road, Wan Chai, Hong Kong<br/>Réalisateur : Daniel Cardelli` },
    { type: "h2", html: `Contact` },
    { type: "p", html: `Contact général : <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a><br/>Press &amp; partenariats : même adresse avec pour sujet « Presse » ou « Partenariat ».` },
    { type: "h2", html: `Hébergement` },
    { type: "p", html: `<strong>Application backend :</strong> Render Inc., 525 Brannan St, San Francisco, CA 94107, États-Unis.<br/><strong>Site Web :</strong> Vercel Inc., 440 N Barranca Ave #4133, Covina, CA 91723, États-Unis.<br/><strong>Base de données :</strong> MongoDB Inc., 1633 Broadway, 38e étage, New York, NY 10019, États-Unis.` },
    { type: "h2", html: `Traitement des paiements` },
    { type: "p", html: `Les paiements et paiements par carte sont traités par un établissement de paiement réglementé (actuellement en transition). Les fonds sont détenus sur des comptes séparés conformément aux règles applicables en matière de monnaie électronique.` },
    { type: "h2", html: `Propriété intellectuelle` },
    { type: "p", html: `Le nom HoPetSit, le logo, l'application mobile, le code source et le contenu du site Internet sont protégés par le droit d'auteur. © CARDELLI HERMANOS LIMITÉE. Tous droits réservés.` },
    { type: "h2", html: `Editeur de publication` },
    { type: "p", html: `Daniel Cardelli, directeur de CARDELLI HERMANOS LIMITED.` },
    { type: "h2", html: `Résolution des litiges` },
    { type: "p", html: `Pour les consommateurs de l'UE, la Commission européenne propose une plateforme de résolution des litiges en ligne sur <a href="https://ec.europa.eu/consumers/odr" rel="noopener" target="_blank">ec.europa.eu/consumers/odr</a>. Nous sommes cependant disponibles pour résoudre les litiges directement via <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> dans un délai de 48 heures.` },
  ],
  },
  es: {
    lastUpdated: "25 de abril de 2026",
    sections: [
    { type: "h2", html: `Empresa operadora` },
    { type: "p", html: `<strong>CARDELLI HERMANOS LIMITED</strong><br/>Trading as <strong>HoPetSit</strong><br/>Registro de empresas de Hong Kong: Número CR: <strong>2671528</strong><br/>Domicilio social: Flat/Rm A, 12/F, ZJ 300, 300 Lockhart Road, Wan Chai, Hong Kong<br/>Director: Daniel Cardelli` },
    { type: "h2", html: `Contacto` },
    { type: "p", html: `Contacto general: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a><br/>Press &amp; asociaciones: misma dirección con asunto "Prensa" o "Asociación".` },
    { type: "h2", html: `Alojamiento` },
    { type: "p", html: `<strong>Backend de la aplicación:</strong> Render Inc., 525 Brannan St, San Francisco, CA 94107, Estados Unidos.<br/><strong>Sitio web:</strong> Vercel Inc., 440 N Barranca Ave #4133, Covina, CA 91723, Estados Unidos.<br/><strong>Base de datos:</strong> MongoDB Inc., 1633 Broadway, piso 38, Nueva York, NY 10019, Estados Unidos.` },
    { type: "h2", html: `Procesamiento de pagos` },
    { type: "p", html: `Los pagos y retiros con tarjeta son procesados ​​por una institución de pago regulada (actualmente en transición). Los fondos se mantienen en cuentas segregadas de conformidad con las normas aplicables de dinero electrónico.` },
    { type: "h2", html: `Propiedad intelectual` },
    { type: "p", html: `El nombre, el logotipo, la aplicación móvil, el código fuente y el contenido del sitio web de HoPetSit están protegidos por derechos de autor. © CARDELLI HERMANOS LIMITED. Reservados todos los derechos.` },
    { type: "h2", html: `editor de publicación` },
    { type: "p", html: `Daniel Cardelli, Director de CARDELLI HERMANOS LIMITED.` },
    { type: "h2", html: `Resolución de disputas` },
    { type: "p", html: `Para los consumidores de la UE, la Comisión Europea ofrece una plataforma de resolución de disputas en línea en <a href="https://ec.europa.eu/consumers/odr" rel="noopener" target="_blank">ec.europa.eu/consumers/odr</a>. Sin embargo, estamos disponibles para resolver disputas directamente a través de <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> dentro de las 48 horas.` },
  ],
  },
  de: {
    lastUpdated: "25. April 2026",
    sections: [
    { type: "h2", html: `Betreibergesellschaft` },
    { type: "p", html: `<strong>CARDELLI HERMANOS LIMITED</strong><br/>Terfahren unter dem Namen <strong>HoPetSit</strong><br/>Handelsregister von Hongkong – CR-Nummer: Kong<br/>Regie: Daniel Cardelli` },
    { type: "h2", html: `Kontakt` },
    { type: "p", html: `Allgemeiner Kontakt: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a><br/>Press &amp; Partnerschaften: gleiche Adresse mit Betreff „Presse“ oder „Partnerschaft“.` },
    { type: "h2", html: `Hosting` },
    { type: "p", html: `<strong>Anwendungs-Backend:</strong> Render Inc., 525 Brannan St, San Francisco, CA 94107, Vereinigte Staaten Inc., 1633 Broadway, 38th Floor, New York, NY 10019, Vereinigte Staaten.` },
    { type: "h2", html: `Zahlungsabwicklung` },
    { type: "p", html: `Kartenzahlungen und Auszahlungen werden von einem regulierten Zahlungsinstitut abgewickelt (derzeit im Übergang). Die Gelder werden gemäß den geltenden E-Geld-Regeln auf getrennten Konten gehalten.` },
    { type: "h2", html: `Geistiges Eigentum` },
    { type: "p", html: `Der Name, das Logo, die mobile Anwendung, der Quellcode und der Inhalt der Website von HoPetSit sind urheberrechtlich geschützt. © CARDELLI HERMANOS LIMITED. Alle Rechte vorbehalten.` },
    { type: "h2", html: `Herausgeber der Publikation` },
    { type: "p", html: `Daniel Cardelli, Direktor von CARDELLI HERMANOS LIMITED.` },
    { type: "h2", html: `Streitbeilegung` },
    { type: "p", html: `Für Verbraucher in der EU stellt die Europäische Kommission unter <a href="https://ec.europa.eu/consumers/odr" rel="noopener" target="_blank">ec.europa.eu/consumers/odr</a> eine Plattform zur Online-Streitbeilegung bereit. Wir stehen jedoch zur Verfügung, um Streitigkeiten innerhalb von 48 Stunden direkt über <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> zu lösen.` },
  ],
  },
  it: {
    lastUpdated: "25 aprile 2026",
    sections: [
    { type: "h2", html: `Società operativa` },
    { type: "p", html: `<strong>CARDELLI HERMANOS LIMITED</strong><br/>Trading as <strong>HoPetSit</strong><br/>Registro delle imprese di Hong Kong - Numero CR: <strong>2671528</strong><br/>Sede legale: Flat/Rm A, 12/F, ZJ 300, 300 Lockhart Road, Wan Chai, Hong Kong<br/>Regia: Daniel Cardelli` },
    { type: "h2", html: `Contatto` },
    { type: "p", html: `Contatto generale: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a><br/>Press &amp; partnership: stesso indirizzo con oggetto "Stampa" o "Partnership".` },
    { type: "h2", html: `Ospitare` },
    { type: "p", html: `<strong>Backend dell'applicazione:</strong> Render Inc., 525 Brannan St, San Francisco, CA 94107, Stati Uniti.<br/><strong>Sito Web:</strong> Vercel Inc., 440 N Barranca Ave #4133, Covina, CA 91723, Stati Uniti.<br/><strong>Database:</strong> MongoDB Inc., 1633 Broadway, 38° piano, New York, NY 10019, Stati Uniti.` },
    { type: "h2", html: `Elaborazione dei pagamenti` },
    { type: "p", html: `I pagamenti e i pagamenti con carta vengono elaborati da un istituto di pagamento regolamentato (attualmente in fase di transizione). I fondi sono tenuti in conti separati in conformità alle norme applicabili sulla moneta elettronica.` },
    { type: "h2", html: `Proprietà intellettuale` },
    { type: "p", html: `Il nome, il logo, l'applicazione mobile, il codice sorgente e il contenuto del sito web di HoPetSit sono protetti da copyright. © CARDELLI HERMANOS LIMITED. Tutti i diritti riservati.` },
    { type: "h2", html: `Redattore della pubblicazione` },
    { type: "p", html: `Daniel Cardelli, Direttore di CARDELLI HERMANOS LIMITED.` },
    { type: "h2", html: `Risoluzione delle controversie` },
    { type: "p", html: `Per i consumatori nell'UE, la Commissione europea fornisce una piattaforma di risoluzione delle controversie online all'indirizzo <a href="https://ec.europa.eu/consumers/odr" rel="noopener" target="_blank">ec.europa.eu/consumers/odr</a>. Siamo comunque disponibili a risolvere le controversie direttamente tramite <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> entro 48 ore.` },
  ],
  },
  pt: {
    lastUpdated: "25 de abril de 2026",
    sections: [
    { type: "h2", html: `Empresa operacional` },
    { type: "p", html: `<strong>CARDELLI HERMANOS LIMITED</strong><br/>Trading como <strong>HoPetSit</strong><br/>Registro de empresas de Hong Kong - Número CR: <strong>2671528</strong><br/>Escritório registrado: Flat/Rm A, 12/F, ZJ 300, 300 Lockhart Road, Wan Chai, Hong Kong<br/>Diretor: Daniel Cardelli` },
    { type: "h2", html: `Contato` },
    { type: "p", html: `Contato geral: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a><br/>Press &amp; parcerias: mesmo endereço com assunto “Imprensa” ou “Parceria”.` },
    { type: "h2", html: `Hospedagem` },
    { type: "p", html: `<strong>Backend do aplicativo:</strong> Render Inc., 525 Brannan St, San Francisco, CA 94107, Estados Unidos.<br/><strong>Website:</strong> Vercel Inc., 440 N Barranca Ave #4133, Covina, CA 91723, Estados Unidos.<br/><strong>Banco de dados:</strong> MongoDB Inc., 1633 Broadway, 38th Floor, Nova York, NY 10019, Estados Unidos.` },
    { type: "h2", html: `Processamento de pagamento` },
    { type: "p", html: `Os pagamentos e pagamentos com cartão são processados ​​por uma instituição de pagamento regulamentada (atualmente em transição). Os fundos são mantidos em contas segregadas de acordo com as regras de moeda eletrónica aplicáveis.` },
    { type: "h2", html: `Propriedade intelectual` },
    { type: "p", html: `O nome, logotipo, aplicativo móvel, código-fonte e conteúdo do site do HoPetSit são protegidos por direitos autorais. © CARDELLI HERMANOS LIMITED. Todos os direitos reservados.` },
    { type: "h2", html: `Editor da publicação` },
    { type: "p", html: `Daniel Cardelli, Diretor da CARDELLI HERMANOS LIMITED.` },
    { type: "h2", html: `Resolução de disputas` },
    { type: "p", html: `Para os consumidores na UE, a Comissão Europeia oferece uma plataforma de resolução de litígios online em <a href="https://ec.europa.eu/consumers/odr" rel="noopener" target="_blank">ec.europa.eu/consumers/odr</a>. No entanto, estamos disponíveis para resolver disputas diretamente através de <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> dentro de 48 horas.` },
  ],
  },
  ko: {
    lastUpdated: "2026년 4월 25일",
    sections: [
    { type: "h2", html: `운영 회사` },
    { type: "p", html: `<strong>CARDELLI HERMANOS LIMITED</strong><br/><strong>HoPetSit</strong>이라는 상호로 영업<br/>홍콩 회사등기소 — CR 번호: <strong>2671528</strong><br/>등록 사무소: Flat/Rm A, 12/F, ZJ 300, 300 Lockhart Road, Wan Chai, Hong Kong<br/>이사: Daniel Cardelli` },
    { type: "h2", html: `연락처` },
    { type: "p", html: `일반 문의: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a><br/>언론 및 제휴: 동일한 주소로 제목에 "Press" 또는 "Partnership"을 기재해 주십시오.` },
    { type: "h2", html: `호스팅` },
    { type: "p", html: `<strong>애플리케이션 백엔드:</strong> Render Inc., 525 Brannan St, San Francisco, CA 94107, United States.<br/><strong>웹사이트:</strong> Vercel Inc., 440 N Barranca Ave #4133, Covina, CA 91723, United States.<br/><strong>데이터베이스:</strong> MongoDB Inc., 1633 Broadway, 38th Floor, New York, NY 10019, United States.` },
    { type: "h2", html: `결제 처리` },
    { type: "p", html: `카드 결제 및 지급은 규제 대상 결제 기관(현재 전환 중)에 의해 처리됩니다. 자금은 적용되는 전자화폐 규정에 따라 분리된 계좌에 보관됩니다.` },
    { type: "h2", html: `지식재산권` },
    { type: "p", html: `HoPetSit의 명칭, 로고, 모바일 애플리케이션, 소스 코드 및 웹사이트 콘텐츠는 저작권으로 보호됩니다. © CARDELLI HERMANOS LIMITED. 모든 권리를 보유합니다.` },
    { type: "h2", html: `발행 책임자` },
    { type: "p", html: `Daniel Cardelli, CARDELLI HERMANOS LIMITED 이사.` },
    { type: "h2", html: `분쟁 해결` },
    { type: "p", html: `EU 소비자를 위해 유럽위원회는 <a href="https://ec.europa.eu/consumers/odr" rel="noopener" target="_blank">ec.europa.eu/consumers/odr</a>에서 온라인 분쟁 해결 플랫폼을 제공합니다. 다만 당사는 <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>을 통해 48시간 이내에 분쟁을 직접 해결해 드릴 수도 있습니다.` },
  ],
  },
  ja: {
    lastUpdated: "2026年4月25日",
    sections: [
    { type: "h2", html: `運営会社` },
    { type: "p", html: `<strong>CARDELLI HERMANOS LIMITED</strong><br/><strong>HoPetSit</strong>として事業を行う<br/>香港会社登記所 — CR番号: <strong>2671528</strong><br/>登記上の事務所: Flat/Rm A, 12/F, ZJ 300, 300 Lockhart Road, Wan Chai, Hong Kong<br/>取締役: Daniel Cardelli` },
    { type: "h2", html: `お問い合わせ` },
    { type: "p", html: `一般的なお問い合わせ: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a><br/>報道および提携: 同じアドレス宛に、件名を「Press」または「Partnership」としてご連絡ください。` },
    { type: "h2", html: `ホスティング` },
    { type: "p", html: `<strong>アプリケーションのバックエンド:</strong> Render Inc., 525 Brannan St, San Francisco, CA 94107, United States.<br/><strong>ウェブサイト:</strong> Vercel Inc., 440 N Barranca Ave #4133, Covina, CA 91723, United States.<br/><strong>データベース:</strong> MongoDB Inc., 1633 Broadway, 38th Floor, New York, NY 10019, United States.` },
    { type: "h2", html: `決済処理` },
    { type: "p", html: `カード決済および支払いは、規制を受けた決済機関（現在移行中）によって処理されます。資金は、適用される電子マネー規則に従い分別管理された口座に保管されます。` },
    { type: "h2", html: `知的財産` },
    { type: "p", html: `HoPetSitの名称、ロゴ、モバイルアプリケーション、ソースコードおよびウェブサイトのコンテンツは著作権によって保護されています。© CARDELLI HERMANOS LIMITED. 無断転載を禁じます。` },
    { type: "h2", html: `発行責任者` },
    { type: "p", html: `Daniel Cardelli、CARDELLI HERMANOS LIMITED 取締役。` },
    { type: "h2", html: `紛争解決` },
    { type: "p", html: `EU域内の消費者向けに、欧州委員会は<a href="https://ec.europa.eu/consumers/odr" rel="noopener" target="_blank">ec.europa.eu/consumers/odr</a>においてオンライン紛争解決プラットフォームを提供しています。ただし当社は、<a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>を通じて48時間以内に紛争を直接解決することも可能です。` },
  ],
  },
  // v546 — polonais : version ANGLAISE reprise telle quelle (un texte
  // juridique ne se traduit pas automatiquement ; à faire relire par un
  // traducteur juridique avant une version polonaise).
  pl: {
    lastUpdated: "April 25, 2026",
    sections: [
    { type: "h2", html: `Operating company` },
    { type: "p", html: `<strong>CARDELLI HERMANOS LIMITED</strong><br/>Trading as <strong>HoPetSit</strong><br/>Hong Kong Companies Registry — CR Number: <strong>2671528</strong><br/>Registered office: Flat/Rm A, 12/F, ZJ 300, 300 Lockhart Road, Wan Chai, Hong Kong<br/>Director: Daniel Cardelli` },
    { type: "h2", html: `Contact` },
    { type: "p", html: `General contact: <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a><br/>Press &amp; partnerships: same address with subject "Press" or "Partnership".` },
    { type: "h2", html: `Hosting` },
    { type: "p", html: `<strong>Application backend:</strong> Render Inc., 525 Brannan St, San Francisco, CA 94107, United States.<br/><strong>Website:</strong> Vercel Inc., 440 N Barranca Ave #4133, Covina, CA 91723, United States.<br/><strong>Database:</strong> MongoDB Inc., 1633 Broadway, 38th Floor, New York, NY 10019, United States.` },
    { type: "h2", html: `Payment processing` },
    { type: "p", html: `Card payments and payouts are processed by a regulated payment institution (currently in transition). Funds are held in segregated accounts pursuant to applicable e-money rules.` },
    { type: "h2", html: `Intellectual property` },
    { type: "p", html: `The HoPetSit name, logo, mobile application, source code and website content are protected by copyright. © CARDELLI HERMANOS LIMITED. All rights reserved.` },
    { type: "h2", html: `Editor of publication` },
    { type: "p", html: `Daniel Cardelli, Director of CARDELLI HERMANOS LIMITED.` },
    { type: "h2", html: `Dispute resolution` },
    { type: "p", html: `For consumers in the EU, the European Commission provides an online dispute resolution platform at <a href="https://ec.europa.eu/consumers/odr" rel="noopener" target="_blank">ec.europa.eu/consumers/odr</a>. We are however available to resolve disputes directly via <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> within 48 hours.` },
  ],
  },
};

export const LEGAL_DOCS = {
  terms: TERMS,
  privacy: PRIVACY,
  refund: REFUND,
  imprint: IMPRINT,
} as const;

export type LegalDocSlug = keyof typeof LEGAL_DOCS;
