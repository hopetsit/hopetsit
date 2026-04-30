"use client";

import { useT } from "@/lib/i18n/LanguageProvider";
import { LegalPage } from "@/components/LegalPage";

export default function RemboursementPage() {
  const { t } = useT();
  return (
    <LegalPage
      title={t("refund_title")}
      lastUpdated="30 avril 2026"
    >
      <p>
        Cette politique de remboursement s&apos;applique à toutes les
        réservations effectuées via la marketplace HoPetSit. Elle complète
        les{" "}
        <a href="/cgu">Conditions Générales d&apos;Utilisation</a> et reflète
        la manière dont les annulations et remboursements sont réellement
        exécutés par notre prestataire de paiement (Airwallex).
      </p>

      <h2>1. Comment les paiements sont retenus</h2>
      <p>
        Quand l&apos;owner paie une réservation confirmée, les fonds sont
        capturés par notre prestataire de paiement régulé (Airwallex) et
        retenus en séquestre. Ils sont libérés vers le compte bancaire du
        prestataire <strong>24 heures après la fin du service</strong>{" "}
        &mdash; cette fenêtre protège l&apos;owner en cas de problème
        pendant le service.
      </p>

      <h2>2. Annulation par l&apos;owner &mdash; fenêtre gratuite de 72h</h2>
      <ul>
        <li>
          <strong>Plus de 72 heures avant le début du service :</strong>{" "}
          Vous pouvez annuler vous-même depuis l&apos;application. La
          réservation est annulée immédiatement et vous recevez un{" "}
          <strong>remboursement automatique à 100&nbsp;%</strong> (sans
          justification). Les fonds reviennent typiquement sur votre carte
          en 5 à 10 jours ouvrés.
        </li>
        <li>
          <strong>72 heures ou moins avant le début du service :</strong>{" "}
          L&apos;auto-annulation n&apos;est plus disponible. Vous devez
          demander une <strong>annulation mutuelle</strong> auprès de votre
          prestataire dans le chat, ou ouvrir un litige formel via{" "}
          <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>.
          Les remboursements dans cette fenêtre sont étudiés au cas par cas
          en fonction du motif et des preuves fournies.
        </li>
      </ul>

      <h2>3. Annulation par le prestataire</h2>
      <p>
        Si votre petsitter ou promeneur annule une réservation confirmée,
        à n&apos;importe quel moment avant le début du service, vous
        recevez un <strong>remboursement automatique à 100&nbsp;%</strong>.
        Le prestataire peut être pénalisé en cas d&apos;annulations
        répétées (frais d&apos;annulation, baisse de visibilité ou
        suspension du compte) afin de protéger la confiance des owners sur
        la plateforme.
      </p>

      <h2>4. Service non délivré (no-show, prestataire injoignable)</h2>
      <p>
        Si le service a été payé mais n&apos;a jamais été délivré, vous
        pouvez ouvrir un litige dans les{" "}
        <strong>24 heures suivant la fin théorique du service</strong> via
        le chat ou par email à{" "}
        <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a>.
        Après vérification (historique du chat, photos, check-ins GPS,
        notes), nous procédons au remboursement intégral sous 5 jours
        ouvrés.
      </p>

      <h2>5. Service matériellement différent de ce qui était convenu</h2>
      <p>
        Des remboursements partiels peuvent être accordés à notre
        discrétion lorsque le service rendu était matériellement différent
        de ce qui était convenu (durée significativement plus courte,
        conditions clairement violées, etc.). Les deux parties ont la
        possibilité de fournir leurs preuves dans le cadre du litige.
      </p>

      <h2>6. Force majeure</h2>
      <p>
        Les événements de force majeure documentés affectant l&apos;une
        des parties (maladie grave avec justificatif médical, catastrophe
        naturelle, interdiction de déplacement gouvernementale, décès de
        l&apos;animal, etc.) sont étudiés au cas par cas indépendamment de
        la fenêtre standard. Des remboursements peuvent être accordés sur
        présentation des justificatifs appropriés.
      </p>

      <h2>7. Comment les remboursements sont effectués</h2>
      <p>
        Les remboursements sont effectués vers le moyen de paiement
        original (la carte utilisée au paiement, via Airwallex). Les fonds
        arrivent typiquement sous{" "}
        <strong>5 à 10 jours ouvrés</strong> selon votre banque.
      </p>

      <h2>8. Rétro-facturations (chargebacks)</h2>
      <p>
        Nous encourageons fortement les owners à utiliser le mécanisme de
        litige interne de HoPetSit avant d&apos;engager une rétro-facturation
        auprès de leur émetteur de carte. Les owners qui engagent une
        rétro-facturation sans nous avoir contactés au préalable, ou
        pendant qu&apos;un litige est déjà ouvert, perdent le bénéfice de
        notre processus interne et peuvent être définitivement exclus de
        la plateforme. Nous coopérons pleinement avec Airwallex sur les
        enquêtes légitimes de rétro-facturation.
      </p>

      <h2>9. Contact</h2>
      <p>
        Demandes de remboursement, litiges et questions :{" "}
        <a href="mailto:contact@hopetsit.com">contact@hopetsit.com</a> &middot;
        nous visons une réponse sous 48 heures.
      </p>
    </LegalPage>
  );
}
