const { SERVICE_TYPES } = require('./pricing');

const ALLOWED_SERVICE_TYPES = new Set(Object.values(SERVICE_TYPES));

/**
 * Resolve client / legacy service type strings to canonical booking enum values.
 */
const normalizeServiceType = (input) => {
  const raw = String(input ?? '').trim();
  if (!raw) return '';

  const lower = raw.toLowerCase();
  if (ALLOWED_SERVICE_TYPES.has(lower)) return lower;

  const upperKey = raw.toUpperCase().replace(/\s+/g, '_').replace(/-/g, '_');
  if (SERVICE_TYPES[upperKey]) return SERVICE_TYPES[upperKey];

  const snake = raw
    .replace(/([a-z])([A-Z])/g, '$1_$2')
    .replace(/[\s-]+/g, '_')
    .toLowerCase();
  if (ALLOWED_SERVICE_TYPES.has(snake)) return snake;

  const compact = lower.replace(/_/g, '');
  const compactMap = {
    homevisit: 'home_visit',
    dogwalking: 'dog_walking',
    overnightstay: 'overnight_stay',
    longstay: 'long_stay',
  };
  if (compactMap[compact]) return compactMap[compact];

  return lower;
};

/**
 * Normalize stored booking date to ISO + calendar day (UTC YYYY-MM-DD) for clients.
 */
const normalizeAgreementDates = (raw) => {
  if (raw == null || raw === '') {
    return {
      date: '',
      serviceDate: '',
      serviceDateCalendar: null,
    };
  }

  if (raw instanceof Date) {
    const iso = raw.toISOString();
    return {
      date: iso,
      serviceDate: iso,
      serviceDateCalendar: iso.slice(0, 10),
    };
  }

  const s = String(raw).trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) {
    const serviceDate = `${s}T00:00:00.000Z`;
    return {
      date: s,
      serviceDate,
      serviceDateCalendar: s,
    };
  }

  const d = new Date(s);
  if (!Number.isNaN(d.getTime())) {
    const iso = d.toISOString();
    return {
      date: iso,
      serviceDate: iso,
      serviceDateCalendar: iso.slice(0, 10),
    };
  }

  return {
    date: s,
    serviceDate: s,
    serviceDateCalendar: null,
  };
};

const toIsoFromApplicationDate = (value) => {
  if (value == null) return '';
  if (value instanceof Date) return value.toISOString();
  const s = String(value).trim();
  const d = new Date(s);
  if (!Number.isNaN(d.getTime())) return d.toISOString();
  return s;
};

/**
 * Agreement schedule: Booking is authoritative — it is created when the owner accepts
 * (or when the owner creates a request) and pricing is tied to it. The linked Application
 * is only a fallback if booking fields are missing, plus returned as applicationRequest for debugging.
 */
const mergeScheduleFromApplication = ({ bookingPlain, applicationLean }) => {
  const fromBookingType = normalizeServiceType(bookingPlain.serviceType);
  const fromBookingDates = normalizeAgreementDates(bookingPlain.date);
  const bookingTypeOk = Boolean(fromBookingType && ALLOWED_SERVICE_TYPES.has(fromBookingType));
  const bookingDateOk = Boolean(fromBookingDates.date);
  const bookingTimeOk = Boolean(bookingPlain.timeSlot && String(bookingPlain.timeSlot).trim());

  if (!applicationLean) {
    return {
      serviceType: fromBookingType,
      date: fromBookingDates.date,
      serviceDate: fromBookingDates.serviceDate,
      serviceDateCalendar: fromBookingDates.serviceDateCalendar,
      timeSlot: bookingPlain.timeSlot || '',
      scheduleSource: 'booking',
      applicationRequest: null,
    };
  }

  const fromAppType = normalizeServiceType(applicationLean.serviceType);
  const appDateIso = applicationLean.serviceDate
    ? toIsoFromApplicationDate(applicationLean.serviceDate)
    : '';
  const fromAppDates = appDateIso ? normalizeAgreementDates(appDateIso) : fromBookingDates;

  const serviceType = bookingTypeOk
    ? fromBookingType
    : fromAppType || fromBookingType;

  const dateBlock = bookingDateOk ? fromBookingDates : fromAppDates;

  const timeSlot = bookingTimeOk
    ? String(bookingPlain.timeSlot).trim()
    : applicationLean.timeSlot && String(applicationLean.timeSlot).trim()
      ? String(applicationLean.timeSlot).trim()
      : '';

  const scheduleSource =
    bookingTypeOk || bookingDateOk || bookingTimeOk ? 'booking' : 'application';

  return {
    serviceType,
    date: dateBlock.date || fromBookingDates.date,
    serviceDate: dateBlock.serviceDate || fromBookingDates.serviceDate,
    serviceDateCalendar:
      dateBlock.serviceDateCalendar != null
        ? dateBlock.serviceDateCalendar
        : fromBookingDates.serviceDateCalendar,
    timeSlot,
    scheduleSource,
    applicationRequest: {
      serviceType: fromAppType || null,
      serviceDate: appDateIso || null,
      timeSlot: applicationLean.timeSlot ? String(applicationLean.timeSlot) : '',
    },
  };
};

module.exports = {
  normalizeServiceType,
  normalizeAgreementDates,
  mergeScheduleFromApplication,
};
