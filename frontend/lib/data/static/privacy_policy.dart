/// Sprint 8 step 3 — Privacy Policy in 6 languages.
///
/// AI-DRAFTED FIRST PASS — MUST BE REVIEWED BY A QUALIFIED LAWYER.
library;

const String privacyVersion = '1.0';

const String _privacyEn = r"""
⚠️ AI-DRAFTED: first pass to satisfy Play Store / App Store requirements.
MUST be reviewed by a qualified lawyer before production use.

# HopeTSIT — Privacy Policy

Version 1.0

## 1. Data controller

**CARDELLI HERMANOS LIMITED**, Flat/RM A 12/F ZJ 300, 300 Lockhart Road, Wan Chai, Hong Kong. Contact: hopetsit@gmail.com.

## 2. Data we collect

- **Account data**: name, email, password (hashed), phone, country, language, avatar.
- **Pet profile data**: breed, age, vaccinations, behaviour, veterinarians, authorisations.
- **Booking / payment data**: history, amounts, commissions. Card details are tokenised by Stripe; we never see the full card number.
- **Location data**: GPS coordinates (for "near me" discovery and live walk tracking — sitter side only, during active walks).
- **Content**: posts, messages, photos.
- **Technical data**: device type, OS, IP address, crash logs, FCM tokens.
- **Identity verification** (sitters only): government ID image, stored encrypted, visible only to administrators and the sitter.

## 3. Purposes and legal bases

| Purpose | Legal basis |
|---|---|
| Account creation and authentication | Contract execution |
| Booking and payment processing | Contract execution |
| Live walk tracking | Explicit consent (sitter) |
| Push notifications | Consent + legitimate interest |
| Marketing emails | Consent (opt-in only) |
| Fraud prevention and moderation | Legitimate interest |
| Statistics and service improvement | Legitimate interest |

## 4. Sharing with third parties (sub-processors)

- **Stripe** (Ireland / US): payment processing.
- **Firebase / Google LLC** (US): authentication, push notifications, crash reporting, analytics.
- **Cloudinary** (US): media storage.
- **MongoDB Atlas** (US / EU): database hosting.
- **Google Maps** (US): geolocation display.
- **Render.com** (US / EU): backend hosting.

All sub-processors are bound by data-protection agreements. International transfers rely on Standard Contractual Clauses where applicable.

## 5. Storage duration

- Active account: duration of use.
- Closed account: 30 days before full deletion, except billing records (3 years as per tax law).
- Encrypted identity documents: 3 years after verification, then destroyed.

## 6. Your rights (GDPR / applicable law)

- Access, rectification, erasure, portability, restriction, objection.
- Right to withdraw consent at any time.
- Right to lodge a complaint with your local data-protection authority.

Exercise your rights: **hopetsit@gmail.com**. Response within 30 days.

## 7. Security

- TLS encryption in transit.
- AES-256-GCM encryption at rest for sensitive fields (IBAN, card number, PayPal email, identity documents).
- Password hashing with bcrypt.
- Access to personal data restricted to authorised personnel.

## 8. Children

HopeTSIT is not intended for users under 18. We do not knowingly collect data from minors.

## 9. Changes

We may update this Policy. Users are notified 30 days before the new version enters into force.

## 10. Contact

For any privacy request: **hopetsit@gmail.com**.
""";

const String _privacyFr = r"""
⚠️ RÉDIGÉ PAR IA : premier jet conforme aux exigences Play Store / App Store.
DOIT être relu par un avocat qualifié avant mise en production.

# HopeTSIT — Politique de confidentialité

Version 1.0

## 1. Responsable de traitement

**CARDELLI HERMANOS LIMITED**, Flat/RM A 12/F ZJ 300, 300 Lockhart Road, Wan Chai, Hong Kong. Contact : hopetsit@gmail.com.

## 2. Données collectées

- **Données de compte** : nom, email, mot de passe (haché), téléphone, pays, langue, avatar.
- **Profil animal** : race, âge, vaccinations, comportement, vétérinaires, autorisations.
- **Données de réservation / paiement** : historique, montants, commissions. Les détails de carte sont tokenisés par Stripe ; le numéro complet ne nous parvient jamais.
- **Données de localisation** : coordonnées GPS (pour le « près de chez moi » et le suivi de promenade en temps réel côté petsitter durant les promenades actives).
- **Contenus** : publications, messages, photos.
- **Données techniques** : type d'appareil, OS, adresse IP, journaux de crash, tokens FCM.
- **Vérification d'identité** (petsitters uniquement) : pièce d'identité, stockée chiffrée, visible uniquement par les administrateurs et le petsitter.

## 3. Finalités et bases légales

| Finalité | Base légale |
|---|---|
| Création de compte et authentification | Exécution du contrat |
| Traitement des réservations et paiements | Exécution du contrat |
| Suivi GPS des promenades | Consentement explicite (petsitter) |
| Notifications push | Consentement + intérêt légitime |
| Emails marketing | Consentement (opt-in) |
| Prévention de la fraude et modération | Intérêt légitime |
| Statistiques et amélioration du service | Intérêt légitime |

## 4. Partage avec des tiers (sous-traitants)

- **Stripe** (Irlande / États-Unis) : traitement des paiements.
- **Firebase / Google LLC** (États-Unis) : authentification, notifications push, crash reporting, analytics.
- **Cloudinary** (États-Unis) : stockage de médias.
- **MongoDB Atlas** (États-Unis / UE) : hébergement de la base de données.
- **Google Maps** (États-Unis) : affichage de géolocalisation.
- **Render.com** (États-Unis / UE) : hébergement backend.

Tous les sous-traitants sont liés par des accords de protection des données. Les transferts internationaux s'appuient sur les Clauses Contractuelles Types lorsque applicables.

## 5. Durée de conservation

- Compte actif : durée de l'utilisation.
- Compte clôturé : 30 jours avant suppression complète, hormis pièces de facturation (3 ans selon la loi fiscale).
- Pièces d'identité chiffrées : 3 ans après vérification, puis destruction.

## 6. Vos droits (RGPD / loi applicable)

- Accès, rectification, effacement, portabilité, limitation, opposition.
- Droit de retirer votre consentement à tout moment.
- Droit d'introduire une réclamation auprès de votre autorité locale de protection des données (ex. CNIL en France).

Pour exercer vos droits : **hopetsit@gmail.com**. Réponse sous 30 jours.

## 7. Sécurité

- Chiffrement TLS en transit.
- Chiffrement AES-256-GCM au repos pour les champs sensibles (IBAN, numéro de carte, email PayPal, pièces d'identité).
- Hachage des mots de passe via bcrypt.
- Accès aux données personnelles restreint au personnel autorisé.

## 8. Enfants

HopeTSIT n'est pas destiné aux utilisateurs de moins de 18 ans. Nous ne collectons pas sciemment de données de mineurs.

## 9. Modifications

La présente Politique peut être mise à jour. Les utilisateurs sont informés 30 jours avant l'entrée en vigueur de la nouvelle version.

## 10. Contact

Pour toute demande : **hopetsit@gmail.com**.
""";

const String _privacyEs = r"""
⚠️ REDACTADO POR IA — primer borrador. DEBE ser revisado por un abogado.

# HopeTSIT — Política de privacidad

Versión 1.0

## 1. Responsable del tratamiento
**CARDELLI HERMANOS LIMITED**, Hong Kong. Contacto: hopetsit@gmail.com.

## 2. Datos recogidos
Cuenta, perfil animal, reservas/pagos, ubicación GPS (opcional), contenidos, datos técnicos, verificación de identidad (cuidadores).

## 3. Finalidades y bases legales
Ejecución del contrato, consentimiento, interés legítimo.

## 4. Encargados
Stripe, Firebase, Cloudinary, MongoDB Atlas, Google Maps, Render.com.

## 5. Conservación
Vida útil de la cuenta + 30 días; 3 años para facturación; documentos de identidad 3 años tras verificación.

## 6. Derechos
Acceso, rectificación, supresión, portabilidad, limitación, oposición. Retirada del consentimiento. Reclamación ante la autoridad local. Ejerza sus derechos en **hopetsit@gmail.com**.

## 7. Seguridad
TLS, AES-256-GCM, bcrypt, accesos restringidos.

## 8. Menores
Servicio no destinado a menores de 18 años.

## 9. Modificaciones
Preaviso de 30 días.

## 10. Contacto
**hopetsit@gmail.com**.
""";

const String _privacyDe = r"""
⚠️ KI-ENTWURF — muss von einem qualifizierten Anwalt geprüft werden.

# HopeTSIT — Datenschutzrichtlinie

Version 1.0

## 1. Verantwortlicher
**CARDELLI HERMANOS LIMITED**, Hongkong. Kontakt: hopetsit@gmail.com.

## 2. Erhobene Daten
Konto, Tierprofil, Buchungen/Zahlungen, GPS-Daten (optional), Inhalte, technische Daten, Identitätsverifikation (Sitters).

## 3. Zwecke und Rechtsgrundlagen
Vertragserfüllung, Einwilligung, berechtigtes Interesse.

## 4. Auftragsverarbeiter
Stripe, Firebase, Cloudinary, MongoDB Atlas, Google Maps, Render.com.

## 5. Speicherdauer
Kontolaufzeit + 30 Tage; 3 Jahre für Abrechnungsunterlagen; verschlüsselte Ausweisdokumente 3 Jahre nach Prüfung.

## 6. Rechte
Auskunft, Berichtigung, Löschung, Übertragbarkeit, Einschränkung, Widerspruch. Widerruf der Einwilligung. Beschwerde bei lokaler Aufsichtsbehörde. Ausübung: **hopetsit@gmail.com**.

## 7. Sicherheit
TLS, AES-256-GCM, bcrypt, Zugangsbeschränkungen.

## 8. Kinder
Nicht für Nutzer unter 18 Jahren bestimmt.

## 9. Änderungen
30 Tage Vorankündigung.

## 10. Kontakt
**hopetsit@gmail.com**.
""";

const String _privacyIt = r"""
⚠️ REDATTO DA IA — prima bozza. DEVE essere revisionato da un avvocato.

# HopeTSIT — Informativa sulla privacy

Versione 1.0

## 1. Titolare del trattamento
**CARDELLI HERMANOS LIMITED**, Hong Kong. Contatto: hopetsit@gmail.com.

## 2. Dati raccolti
Account, profilo animale, prenotazioni/pagamenti, GPS (facoltativo), contenuti, dati tecnici, verifica identità (sitter).

## 3. Finalità e basi giuridiche
Esecuzione del contratto, consenso, interesse legittimo.

## 4. Responsabili del trattamento
Stripe, Firebase, Cloudinary, MongoDB Atlas, Google Maps, Render.com.

## 5. Conservazione
Durata dell'account + 30 giorni; 3 anni per fatturazione; documenti d'identità 3 anni dopo la verifica.

## 6. Diritti
Accesso, rettifica, cancellazione, portabilità, limitazione, opposizione. Revoca del consenso. Reclamo all'autorità locale. Esercizio: **hopetsit@gmail.com**.

## 7. Sicurezza
TLS, AES-256-GCM, bcrypt, accessi limitati.

## 8. Minori
Servizio non destinato a minori di 18 anni.

## 9. Modifiche
Preavviso di 30 giorni.

## 10. Contatto
**hopetsit@gmail.com**.
""";

const String _privacyPt = r"""
⚠️ REDIGIDO POR IA — primeiro esboço. DEVE ser revisto por um advogado.

# HopeTSIT — Política de privacidade

Versão 1.0

## 1. Responsável pelo tratamento
**CARDELLI HERMANOS LIMITED**, Hong Kong. Contacto: hopetsit@gmail.com.

## 2. Dados recolhidos
Conta, perfil do animal, reservas/pagamentos, GPS (opcional), conteúdos, dados técnicos, verificação de identidade (cuidadores).

## 3. Finalidades e bases legais
Execução do contrato, consentimento, interesse legítimo.

## 4. Subcontratantes
Stripe, Firebase, Cloudinary, MongoDB Atlas, Google Maps, Render.com.

## 5. Conservação
Duração da conta + 30 dias; 3 anos para faturação; documentos de identidade 3 anos após verificação.

## 6. Direitos
Acesso, retificação, apagamento, portabilidade, limitação, oposição. Revogação do consentimento. Reclamação à autoridade local. Exercício: **hopetsit@gmail.com**.

## 7. Segurança
TLS, AES-256-GCM, bcrypt, acessos restritos.

## 8. Menores
Serviço não destinado a menores de 18 anos.

## 9. Alterações
Pré-aviso de 30 dias.

## 10. Contacto
**hopetsit@gmail.com**.
""";

const Map<String, String> privacyPolicyByLocale = <String, String>{
  'en': _privacyEn,
  'fr': _privacyFr,
  'es': _privacyEs,
  'de': _privacyDe,
  'it': _privacyIt,
  'pt': _privacyPt,
};

String privacyPolicyForLocale(String languageCode) {
  final code = languageCode.toLowerCase();
  return privacyPolicyByLocale[code] ?? privacyPolicyByLocale['en']!;
}
