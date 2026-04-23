const round2 = (n) => Number(Number(n || 0).toFixed(2));

const parseDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
};

const pickEffectiveStartEnd = ({ startDate, endDate, serviceDate, durationMinutes }) => {
  const start = parseDate(startDate) || parseDate(serviceDate);
  if (!start) return { start: null, end: null };

  let end = parseDate(endDate);
  if (!end || end <= start) {
    if (Number.isFinite(Number(durationMinutes)) && Number(durationMinutes) > 0) {
      end = new Date(start.getTime() + Number(durationMinutes) * 60 * 1000);
    } else {
      end = new Date(start.getTime() + 60 * 60 * 1000);
    }
  }
  return { start, end };
};

const calculateTierBasePrice = ({ hourlyRate, dailyRate, weeklyRate, monthlyRate, startDate, endDate, serviceDate, durationMinutes }) => {
  const h = Number(hourlyRate) || 0;
  const d = Number(dailyRate) || 0;
  const w = Number(weeklyRate) || 0;
  const m = Number(monthlyRate) || 0;
  // v18.9.5 — accepte aussi dailyRate. Si seul dailyRate est dispo, on
  // dérive un hourly fallback pour les courts créneaux (<8h) et on bascule
  // sur dailyRate dès qu'on atteint ~1 jour complet.
  const hEffective = h > 0 ? h : (d > 0 ? d / 8 : 0);
  if (hEffective <= 0) {
    throw new Error('Sitter hourlyRate or dailyRate must be set to calculate booking total.');
  }

  const { start, end } = pickEffectiveStartEnd({ startDate, endDate, serviceDate, durationMinutes });
  if (!start || !end) throw new Error('Valid startDate/serviceDate is required for pricing.');

  // v18.7 BUG FIX : avant v18.7, `Math.max(hoursRaw, 1)` forçait un minimum
  // de 1h. Résultat : une promenade de 30 min (0.5h) devenait 1h, et l'owner
  // payait 1 × hourlyRate au lieu de 0.5 × hourlyRate. Ex : walker à €7/h,
  // walk de 30 min → facture €7 au lieu de €3.50.
  const parsedDuration = Number(durationMinutes);
  const hasExplicitDuration =
    Number.isFinite(parsedDuration) && parsedDuration > 0 && parsedDuration < 60;
  const rawHours = (end.getTime() - start.getTime()) / (1000 * 60 * 60);
  const hoursRaw = hasExplicitDuration ? rawHours : Math.max(rawHours, 1);
  const totalHours = round2(hoursRaw);
  const totalDays = Math.max(1, Math.ceil(hoursRaw / 24));

  let pricingTier = 'hourly';
  let appliedRate = hEffective;
  let basePrice = totalHours * hEffective;

  if (totalDays >= 30 && m > 0) {
    pricingTier = 'monthly';
    appliedRate = m;
    const fullMonths = Math.floor(totalDays / 30);
    const remDays = totalDays % 30;
    const dailyFromMonth = m / 30;
    basePrice = fullMonths * m + remDays * dailyFromMonth;
  } else if (totalDays >= 7 && w > 0) {
    pricingTier = 'weekly';
    appliedRate = w;
    const fullWeeks = Math.floor(totalDays / 7);
    const remDays = totalDays % 7;
    const dailyFromWeek = w / 7;
    basePrice = fullWeeks * w + remDays * dailyFromWeek;
  } else if (totalDays >= 1 && d > 0 && hoursRaw >= 8) {
    // v18.9.5 — tier "daily" dès ~1 journée complète. Avant v18.9.5, un
    // booking 1 jour (24h) facturait 24 × hourly_derived = 24 × (d/8) = 3×d,
    // ce qui explosait la facture (ou l'écrasait si hourly dérivé bas).
    // Désormais : dayCount × dailyRate + fraction hourly pour le reste.
    pricingTier = 'daily';
    appliedRate = d;
    const fullDays = Math.floor(hoursRaw / 24);
    const remHours = hoursRaw - fullDays * 24;
    basePrice = fullDays * d + (remHours > 0 ? remHours * hEffective : 0);
  }

  return {
    pricingTier,
    appliedRate: round2(appliedRate),
    totalHours,
    totalDays,
    basePrice: round2(basePrice),
    effectiveStartDate: start.toISOString(),
    effectiveEndDate: end.toISOString(),
  };
};

module.exports = {
  calculateTierBasePrice,
};

