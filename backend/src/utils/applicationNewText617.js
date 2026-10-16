/**
 * 617 (ADA, 16/10/2026) — §D.3 : texte de la notification « candidature reçue »
 * envoyée au PROPRIÉTAIRE : « <Prénom du candidat> a répondu » / « <total>
 * candidat(s) sur ta demande · choisis et paie en 2 minutes ».
 *
 * Le type reste `application_new` (l'app et le site ouvrent déjà Choisir → Payer
 * avec `data.applicationId` / `postId`) ; seul le GABARIT change :
 * `application_new_617`, choisi par `templateType` à l'envoi et par le marqueur
 * `data.appNew617` quand la cloche re-rend le texte (renderNotificationContent).
 * Les anciennes notifications (sans marqueur) gardent l'ancien gabarit : rien ne
 * casse. Le rappel 615 (`application_reminder_615`) n'est pas concerné.
 */
const { deriveNameParts } = require('../utils/personName');

const TEMPLATE = 'application_new_617';

const firstNameOf = (doc) => {
  const { firstName } = deriveNameParts(doc || {});
  return firstName || String((doc && doc.name) || '').trim().split(/\s+/)[0] || '';
};

/**
 * Données à ajouter au `data` de la notification `application_new`.
 * @param {{provider:Object, pendingCount:number}} p provider = doc Sitter/Walker ; pendingCount = candidatures en attente sur la demande
 */
const applicationNewData617 = ({ provider, pendingCount }) => ({
  candidateName: firstNameOf(provider) || 'HoPetSit',
  candidates: String(Math.max(1, Math.floor(Number(pendingCount) || 1))),
  appNew617: '1',
});

module.exports = { TEMPLATE, applicationNewData617, firstNameOf };
