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

const calculateTierBasePrice = ({ hourlyRate, weeklyRate, monthlyRate, startDate, endDate, serviceDate, durationMinutes }) => {
  const h = Number(hourlyRate) || 0;
  const w = Number(weeklyRate) || 0;
  const m = Number(monthlyRate) || 0;
  if (h <= 0) {
    throw new Error('Sitter hourlyRate must be set to calculate booking total.');
  }

  const { start, end } = pickEffectiveStartEnd({ startDate, endDate, serviceDate, durationMinutes });
  if (!start || !end) throw new Error('Valid startDate/serviceDate is required for pricing.');

  const hoursRaw = Math.max((end.getTime() - start.getTime()) / (1000 * 60 * 60), 1);
  const totalHours = round2(hoursRaw);
  const totalDays = Math.max(1, Math.ceil(hoursRaw / 24));

  let pricingTier = 'hourly';
  let appliedRate = h;
  let basePrice = totalHours * h;

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

