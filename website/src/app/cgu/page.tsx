"use client";

import { useT } from "@/lib/i18n/LanguageProvider";
import { LegalPage } from "@/components/LegalPage";

export default function CguPage() {
  const { t } = useT();
  return (
    <LegalPage
      title={t("terms_title")}
      lastUpdated="30 avril 2026"
    >
      <p>
        Les présentes Conditions Générales d&apos;Utilisation (les
        &laquo;&nbsp;CGU&nbsp;&raquo;) régissent l&apos;utilisation de la
        marketplace HoPetSit (le &laquo;&nbsp;Service&nbsp;&raquo;), exploitée
        par CARDELLI HERMANOS LIMITED (sous la marque HoPetSit), société
        immatriculée à Hong Kong (la &laquo;&nbsp;Société&nbsp;&raquo;,
        &laquo;&nbsp;nous&nbsp;&raquo;).
      </p>

      <h2>1. Le Service</h2>
      <p>
        HoPetSit est une marketplace mettant en relation des propriétaires
        d&apos;animaux (&laquo;&nbsp;owners&nbsp;&raquo;) avec des
        petsitters et promeneurs canins indépendants à travers
        l&apos;Union européenne, le Royaume-Uni, la Suisse, la Norvège et
        les territoires adjacents. Nous <strong>ne sommes pas</strong>
        {" "}prestataires de services pour animaux. Nous facilitons la
        mise en relation, la messagerie sécurisée, le traitement des
        paiements et la résolution des litiges.
      </p>

      <h2>2. Éligibilité</h2>
      <ul>
        <li>
          Vous devez avoir au moins 18 ans pour vous inscrire en tant que
          petsitter ou promeneur.
        </li>
        <li>
          Les owners doivent avoir au moins 18 ans, ou utiliser la
          plateforme sous la supervision d&apos;un représentant légal.
        </li>
        <li>
          Vous devez fournir des informations exactes, à jour et complètes
          lors de l&apos;inscription.
        </li>
      </ul>

      <h2>3. Compte &amp; sécurité</h2>
      <p>
        Vous êtes responsable de l&apos;activité sur votre compte et de la
        confidentialité de vos identifiants. Notifiez-nous à{" "}
        <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>{" "}
        dès que vous suspectez un accès non autorisé.
      </p>

      <h2>4. Réservations &amp; paiements</h2>
      <p>
        L&apos;owner paie le prix du service plus une commission plateforme
        de 20&nbsp;%. Les paiements sont traités par notre prestataire de
        paiement régulé (Airwallex). Les fonds sont retenus en séquestre
        jusqu&apos;à 24 heures après la fin du service, puis libérés vers
        l&apos;IBAN enregistré du prestataire.
      </p>
      <p>
        Les prestataires reçoivent 80&nbsp;% du montant brut de la
        réservation, déduction faite des éventuels frais Airwallex liés au
        virement.
      </p>

      <h2>5. Annulations &amp; remboursements</h2>
      <p>
        L&apos;owner peut auto-annuler une réservation gratuitement{" "}
        <strong>jusqu&apos;à 72 heures avant le début du service</strong>{" "}
        (remboursement automatique à 100&nbsp;%). Au-delà, une annulation
        mutuelle ou un litige formel est requis. Voir la{" "}
        <a href="/remboursement">Politique de Remboursement</a> pour le
        détail complet.
      </p>

      <h2>6. Conduite</h2>
      <ul>
        <li>
          Pas de harcèlement, discours haineux ou comportement nuisible
          envers les autres utilisateurs ou les animaux.
        </li>
        <li>
          Pas de sollicitation de coordonnées personnelles pour
          contourner le système de paiement de la plateforme.
        </li>
        <li>
          Pas de fausses notes, fausses réservations ou abus de
          rétro-facturation.
        </li>
        <li>
          Les petsitters et promeneurs doivent respecter les lois locales
          de protection animale.
        </li>
      </ul>

      <h2>7. Avis &amp; réputation</h2>
      <p>
        Les deux parties peuvent laisser un avis après une réservation
        terminée. Les avis doivent refléter une expérience réelle. Nous
        pouvons supprimer les avis qui violent les présentes CGU ou la
        loi applicable.
      </p>

      <h2>8. Propriété intellectuelle</h2>
      <p>
        Le nom HoPetSit, le logo, l&apos;application, le site web et le
        contenu sont la propriété de CARDELLI HERMANOS LIMITED (sous la
        marque HoPetSit). Vous ne pouvez pas les copier, reproduire ou
        distribuer sans notre accord écrit préalable.
      </p>

      <h2>9. Responsabilité</h2>
      <p>
        Dans la mesure permise par la loi, CARDELLI HERMANOS LIMITED
        (sous la marque HoPetSit) n&apos;est pas responsable des dommages
        indirects ou consécutifs découlant d&apos;une réservation. Notre
        responsabilité globale pour toute réclamation est limitée aux
        commissions plateforme que nous avons collectées sur la
        réservation concernée.
      </p>

      <h2>10. Résiliation</h2>
      <p>
        Nous pouvons suspendre ou résilier les comptes qui violent les
        présentes CGU. Vous pouvez supprimer votre compte à tout moment
        depuis l&apos;application mobile ou en nous contactant.
      </p>

      <h2>11. Droit applicable</h2>
      <p>
        Les présentes CGU sont régies par le droit de Hong Kong SAR. Les
        litiges relèvent des tribunaux compétents de Hong Kong, sans
        préjudice des droits impératifs de protection du consommateur de
        votre pays de résidence.
      </p>

      <h2>12. Contact</h2>
      <p>
        Toute question :{" "}
        <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>
      </p>
    </LegalPage>
  );
}
