// v587 (point 8 de Daniel) — LIEU DU SERVICE d'une annonce, par type de service.
//
//   · garde multi-jours / garde à domicile / garderie de jour :
//       'at_owner' (chez moi) | 'at_sitter' (chez le gardien) — 'both' reste
//       accepté pour les anciennes annonces ;
//   · promenade : 'pickup' (récupérer chez moi) | 'meeting_point' (point de
//       rendez-vous, avec `meetingPoint` = adresse ou quartier) ;
//   · visites : toujours 'at_owner' (le gardien passe chez le propriétaire).
//
// RÉTROCOMPATIBLE : une ancienne app qui n'envoie rien garde le comportement
// d'avant (aucun champ ajouté → défaut du schéma). Une valeur qui ne va pas
// avec le service est ignorée, comme l'était déjà une valeur inconnue.

const SITTING_LOCATIONS = ['at_owner', 'at_sitter', 'both'];
const WALK_LOCATIONS = ['pickup', 'meeting_point'];
const ALL_SERVICE_LOCATIONS = [...SITTING_LOCATIONS, ...WALK_LOCATIONS];
const VISIT_SERVICES = ['home_visit', 'drop_in', 'drop_in_visit', 'pet_visit', 'visit', 'visits'];
const MEETING_POINT_MAX = 200;

const normServices = (serviceTypes) =>
  (Array.isArray(serviceTypes) ? serviceTypes : serviceTypes != null ? [serviceTypes] : [])
    .map((s) => String(s || '').trim().toLowerCase())
    .filter(Boolean);

/** Famille du service principal : 'walk' | 'visit' | 'sitting' | null. */
const serviceFamily = (serviceTypes) => {
  const list = normServices(serviceTypes);
  if (!list.length) return null;
  if (list.includes('dog_walking') || list.includes('walking')) return 'walk';
  if (list.some((s) => VISIT_SERVICES.includes(s))) return 'visit';
  return 'sitting';
};

const cleanMeetingPoint = (v) =>
  typeof v === 'string' ? v.trim().replace(/\s+/g, ' ').slice(0, MEETING_POINT_MAX) : '';

/**
 * Lieu à enregistrer pour ces services. Renvoie `{}` quand rien n'est à
 * écrire (le schéma garde son défaut), sinon `{ serviceLocation, meetingPoint }`.
 * `houseSittingVenue` (site, garde à domicile) sert de repli : owners_home →
 * at_owner, sitters_home → at_sitter.
 */
const resolveServiceLocation = ({ serviceTypes, serviceLocation, meetingPoint, houseSittingVenue } = {}) => {
  const family = serviceFamily(serviceTypes);
  const raw = typeof serviceLocation === 'string' ? serviceLocation.trim().toLowerCase() : '';
  if (family === 'visit') return { serviceLocation: 'at_owner', meetingPoint: '' };
  if (family === 'walk') {
    if (!WALK_LOCATIONS.includes(raw)) return {};
    return {
      serviceLocation: raw,
      meetingPoint: raw === 'meeting_point' ? cleanMeetingPoint(meetingPoint) : '',
    };
  }
  if (SITTING_LOCATIONS.includes(raw)) return { serviceLocation: raw, meetingPoint: '' };
  const venue = typeof houseSittingVenue === 'string' ? houseSittingVenue.trim().toLowerCase() : '';
  if (venue === 'owners_home') return { serviceLocation: 'at_owner', meetingPoint: '' };
  if (venue === 'sitters_home') return { serviceLocation: 'at_sitter', meetingPoint: '' };
  return {};
};

/** Copie le lieu d'une annonce (ou d'une candidature) vers la cible. */
const copyServiceLocation = (from, target) => {
  if (!from || !target) return target;
  const loc = typeof from.serviceLocation === 'string' ? from.serviceLocation : '';
  if (ALL_SERVICE_LOCATIONS.includes(loc)) {
    target.serviceLocation = loc;
    target.meetingPoint = loc === 'meeting_point' ? cleanMeetingPoint(from.meetingPoint) : '';
  }
  return target;
};

module.exports = {
  SITTING_LOCATIONS,
  WALK_LOCATIONS,
  ALL_SERVICE_LOCATIONS,
  MEETING_POINT_MAX,
  serviceFamily,
  resolveServiceLocation,
  copyServiceLocation,
};
