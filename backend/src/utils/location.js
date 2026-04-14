/**
 * Location utilities for GeoJSON Point format (MongoDB 2dsphere).
 * Accepts various input formats: { lat, lng }, { latitude, longitude }, { coordinates: [lng, lat] }
 */

/**
 * Process location data from request. Returns undefined when invalid.
 * Only returns a location object when valid [lng, lat] exist (safe for MongoDB 2dsphere index).
 *
 * @param {Object} locationData - Location data from request
 * @param {Object} options - Optional: { locationType } for Sitter (standard | large_city)
 * @returns {Object|undefined} GeoJSON Point with coordinates and city, or undefined
 */
const processLocationData = (locationData, options = {}) => {
  if (!locationData || typeof locationData !== 'object') return undefined;

  let latitude = null;
  let longitude = null;

  if (locationData.coordinates && Array.isArray(locationData.coordinates)) {
    [longitude, latitude] = locationData.coordinates;
  } else if (locationData.lat !== undefined && locationData.lng !== undefined) {
    latitude = typeof locationData.lat === 'number' ? locationData.lat : parseFloat(locationData.lat);
    longitude = typeof locationData.lng === 'number' ? locationData.lng : parseFloat(locationData.lng);
  } else if (locationData.latitude !== undefined && locationData.longitude !== undefined) {
    latitude = typeof locationData.latitude === 'number' ? locationData.latitude : parseFloat(locationData.latitude);
    longitude = typeof locationData.longitude === 'number' ? locationData.longitude : parseFloat(locationData.longitude);
  }

  const valid =
    latitude != null && longitude != null &&
    !isNaN(latitude) && !isNaN(longitude) &&
    longitude >= -180 && longitude <= 180 &&
    latitude >= -90 && latitude <= 90;

  if (!valid) return undefined;

  const result = {
    type: 'Point',
    coordinates: [longitude, latitude],
    city: (locationData.city || '').trim(),
  };

  if (options.locationType && ['standard', 'large_city'].includes(options.locationType)) {
    result.locationType = options.locationType;
  }

  return result;
};

/**
 * Format location for API response (friendly format with lat, lng, city)
 * @param {Object} location - MongoDB location doc { type, coordinates, city, locationType? }
 * @returns {Object|null} { lat, lng, city, coordinates } or null
 */
const formatLocationForResponse = (location) => {
  if (!location || !location.coordinates || !Array.isArray(location.coordinates) || location.coordinates.length < 2) {
    return null;
  }
  const [lng, lat] = location.coordinates;
  return {
    lat,
    lng,
    city: location.city || '',
    coordinates: [lng, lat],
    ...(location.locationType && { locationType: location.locationType }),
  };
};

module.exports = {
  processLocationData,
  formatLocationForResponse,
};
