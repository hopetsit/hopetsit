/**
 * v575 — Durées de promenade : une seule règle pour tout le backend.
 *
 * Audit P0-1 / P1-6 / P1-7 : le serveur n'acceptait QUE `duration === 30` ou
 * `60` (bookingController.createBooking + applicationController.createApplication)
 * alors que :
 *   - l'app propose 30 / 60 / 90 / 120 minutes ;
 *   - le modèle Walker (`walkRateEntrySchema`) accepte n'importe quel multiple
 *     de 15 entre 15 et 300 minutes.
 * Résultat : une promenade de 90 ou 120 min affichée dans l'app était refusée
 * en 400 par le serveur, et un promeneur n'ayant configuré QUE le palier 45 min
 * se voyait répondre « Walker must set at least one walk rate ».
 *
 * On aligne donc la validation sur `walkRateEntrySchema` et on généralise le
 * calcul du prix :
 *   1. palier EXACT dans `walkRates` → on facture ce palier, au centime près
 *      (c'est le prix que le promeneur a lui-même affiché) ;
 *   2. sinon → prorata du tarif horaire, déduit du palier 60 min s'il existe,
 *      sinon du palier le PLUS PROCHE de la durée demandée (le plus proche est
 *      le moins déformant : extrapoler 300 min depuis un palier 15 min donnerait
 *      un tarif horaire fantaisiste).
 * Ce choix conserve exactement l'ancien comportement pour 30 et 60 minutes.
 */

const WALK_DURATION_STEP = 15;
const WALK_DURATION_MIN = 15;
const WALK_DURATION_MAX = 300;

/** Durée de promenade acceptable : entier, multiple de 15, entre 15 et 300. */
const isValidWalkDuration = (value) => {
  const n = Number(value);
  return (
    Number.isInteger(n) &&
    n % WALK_DURATION_STEP === 0 &&
    n >= WALK_DURATION_MIN &&
    n <= WALK_DURATION_MAX
  );
};

/**
 * Arrondit une durée libre (fin − début d'une annonce, par exemple) au
 * multiple de 15 le plus proche, borné à [15, 300]. Renvoie `null` si la
 * valeur n'est pas exploitable.
 */
const roundToValidWalkDuration = (value) => {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return null;
  let rounded = Math.round(n / WALK_DURATION_STEP) * WALK_DURATION_STEP;
  if (rounded < WALK_DURATION_MIN) rounded = WALK_DURATION_MIN;
  if (rounded > WALK_DURATION_MAX) rounded = WALK_DURATION_MAX;
  return rounded;
};

/** Paliers réellement facturables (activés, prix > 0, durée exploitable). */
const usableWalkRates = (walkRates) =>
  (Array.isArray(walkRates) ? walkRates : []).filter((r) => {
    if (!r) return false;
    if (r.enabled === false) return false;
    const d = Number(r.durationMinutes);
    const p = Number(r.basePrice);
    return Number.isFinite(d) && d > 0 && Number.isFinite(p) && p > 0;
  });

const hourlyEquivalent = (rate) =>
  (Number(rate.basePrice) * 60) / Number(rate.durationMinutes);

/**
 * Tarif horaire à injecter dans `calculateTierBasePrice` pour que le prix
 * final corresponde à la règle décrite en tête de fichier.
 *
 * @param {Array} walkRates  tableau `walkRates` du promeneur
 * @param {number|null} duration durée demandée en minutes (peut être nulle)
 * @returns {{hourlyRate:number, basePrice:number|null, exact:boolean, matchedDuration:number}|null}
 *          `null` si le promeneur n'a AUCUN palier facturable.
 */
const resolveWalkPricing = (walkRates, duration) => {
  const rates = usableWalkRates(walkRates);
  if (rates.length === 0) return null;

  const d = Number(duration);
  const hasDuration = Number.isFinite(d) && d > 0;

  if (hasDuration) {
    const exact = rates.find((r) => Number(r.durationMinutes) === d);
    if (exact) {
      return {
        hourlyRate: hourlyEquivalent(exact),
        basePrice: Number(exact.basePrice),
        exact: true,
        matchedDuration: d,
      };
    }
  }

  // Référence : le palier 60 min (tarif horaire direct), sinon le palier le
  // plus proche de la durée demandée (à défaut de durée, le plus proche de 60).
  const target = hasDuration ? d : 60;
  const sixty = rates.find((r) => Number(r.durationMinutes) === 60);
  const reference =
    sixty ||
    rates
      .slice()
      .sort((a, b) => {
        const da = Math.abs(Number(a.durationMinutes) - target);
        const db = Math.abs(Number(b.durationMinutes) - target);
        if (da !== db) return da - db;
        return Number(a.durationMinutes) - Number(b.durationMinutes);
      })[0];

  const hourlyRate = hourlyEquivalent(reference);
  return {
    hourlyRate,
    basePrice: hasDuration ? (hourlyRate * d) / 60 : null,
    exact: false,
    matchedDuration: Number(reference.durationMinutes),
  };
};

const WALK_DURATION_ERROR =
  'duration is required for dog_walking. Valid values: any multiple of 15 minutes between 15 and 300.';

module.exports = {
  WALK_DURATION_STEP,
  WALK_DURATION_MIN,
  WALK_DURATION_MAX,
  WALK_DURATION_ERROR,
  isValidWalkDuration,
  roundToValidWalkDuration,
  usableWalkRates,
  resolveWalkPricing,
};
