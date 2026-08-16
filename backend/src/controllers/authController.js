const dayjs = require('dayjs');
const jwt = require('jsonwebtoken');

const Owner = require('../models/Owner');
const Admin = require('../models/Admin');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const VerificationCode = require('../models/VerificationCode');
const { sendVerificationEmail, sendPasswordResetEmail } = require('../services/emailService');
// v23.1 part 133 — Phase 7 audit P7-7 : OTP stocké en SHA-256.
const { generateVerificationCode, hashCode, compareCode } = require('../utils/code');
const { sanitizeUser } = require('../utils/sanitize');
const firebaseAdmin = require('../config/firebaseAdmin');
const { normalizeCurrency, DEFAULT_CURRENCY } = require('../utils/currency');
const logger = require('../utils/logger');

// v532 — meme source que PATCH /users/me/accept-terms (userController)
// pour que la version acceptee a l inscription soit coherente.
const TERMS_VERSION = process.env.TERMS_VERSION || 'v1.0';

const OWNER_SERVICES = ['Pet Sitting', 'House Sitting', 'Day Care', 'Long Stay'];
const SITTER_SERVICES = [...OWNER_SERVICES, 'Dog Walking'];
// Walker services focused on walking variants.
const WALKER_SERVICES = ['Dog Walking', 'Solo Walk', 'Group Walk', 'Puppy Walk'];
// Shared list of all valid roles across the platform.
const VALID_ROLES = ['owner', 'sitter', 'walker'];

const isValidEmail = (value) => {
  if (!value || typeof value !== 'string') return false;
  const trimmed = value.trim();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed);
};

const parseOptionalNonNegativeRate = (value, fieldName) => {
  if (value === undefined || value === null || value === '') return undefined;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new Error(`${fieldName} must be a non-negative number.`);
  }
  return parsed;
};

const signAuthToken = (payload, options = {}) => {
  if (!process.env.JWT_SECRET) {
    throw new Error('JWT_SECRET environment variable is not configured.');
  }
  return jwt.sign(payload, process.env.JWT_SECRET, {
    // v23.1 part 37 — Daniel : pas d'auto-logout sauf si user logout ou
    // app fermée. JWT 30j (au lieu de 7j) → user reste connecté ~1 mois.
    // v23.1.254 — Daniel (fondateur, teste en permanence) en avait marre du
    // "Session expirée" tous les 30j → token allongé à 365j. JWT_SECRET
    // reste stable (env Render) donc rien n'invalide les tokens existants ;
    // les nouveaux durent 1 an.
    expiresIn: '365d',
    ...options,
  });
};

const findAccountByEmail = async (email) => {
  const lower = email.toLowerCase();
  const owner = await Owner.findOne({ email: lower });
  if (owner) {
    return { role: 'owner', account: owner };
  }
  const sitter = await Sitter.findOne({ email: lower });
  if (sitter) {
    return { role: 'sitter', account: sitter };
  }
  const walker = await Walker.findOne({ email: lower });
  if (walker) {
    return { role: 'walker', account: walker };
  }
  return null;
};


/**
 * v22.5 — Bug R1 : returns the list of roles this account exists as in the
 * DB, looking across all 3 role collections by email (and oldId when
 * available). Each item: { role, _id }. Used at login to surface a
 * multi-role picker in the UI when length > 1.
 *
 * Defensive: never throws — on Mongo error returns [] so the login flow
 * keeps working.
 */
const findAvailableRolesForAccount = async (email, oldId) => {
  if (!email) return [];
  try {
    const lower = email.toLowerCase();
    const filters = [{ email: lower }];
    if (oldId) filters.push({ oldId });
    const orFilter = { $or: filters };
    const [owners, sitters, walkers] = await Promise.all([
      Owner.find(orFilter).select('_id email oldId').lean(),
      Sitter.find(orFilter).select('_id email oldId').lean(),
      Walker.find(orFilter).select('_id email oldId').lean(),
    ]);
    const results = [];
    if (owners.length) results.push({ role: 'owner', _id: owners[0]._id });
    if (sitters.length) results.push({ role: 'sitter', _id: sitters[0]._id });
    if (walkers.length) results.push({ role: 'walker', _id: walkers[0]._id });
    return results;
  } catch (err) {
    logger.error({ err }, '[findAvailableRolesForAccount] failed');
    return [];
  }
};

const generateRandomPassword = () => {
  return `firebase_${Math.random().toString(36).slice(2)}_${Date.now().toString(36)}`;
};

/**
 * Processes location data from frontend. Optional: returns undefined when no valid coordinates.
 * Only returns a location object when valid [lng, lat] exist (safe for MongoDB 2dsphere index).
 *
 * @param {Object} locationData - Location data from request
 * @returns {Object|undefined} GeoJSON Point with coordinates, or undefined
 */
const processLocationData = (locationData) => {
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

  return {
    type: 'Point',
    coordinates: [longitude, latitude],
    city: (locationData.city || '').trim(),
  };
};

const signup = async (req, res) => {
  try {
    const { role, user } = req.body;

    if (!role || !VALID_ROLES.includes(role)) {
      return res.status(400).json({
        error: `Invalid role. Expected one of: ${VALID_ROLES.map((r) => `"${r}"`).join(', ')}.`,
      });
    }

    if (!user?.email || !user?.password || !user?.name) {
      return res.status(400).json({ error: 'Missing required fields: name, email, password.' });
    }

    const email = user.email.toLowerCase();
    const mobile = (user.mobile || '').trim();
    const countryCode = (user.countryCode || '').toString().trim();
    const paypalEmailRaw = user.paypalEmail;
    const paypalEmail =
      paypalEmailRaw && typeof paypalEmailRaw === 'string' && paypalEmailRaw.trim()
        ? paypalEmailRaw.trim().toLowerCase()
        : '';
    // v23.1.388 — Daniel : « un compte = 3 profils ». L'email ne doit être
    // unique QUE pour le rôle demandé : un owner peut ouvrir un profil
    // sitter/walker (et inversement) avec le MÊME email. Ses données
    // partagées (nom, tél, adresse, CB, IBAN…) et ses forfaits sont
    // hérités du compte existant (cf. _siblingSource plus bas).
    const existingOwner = await Owner.findOne({ email });
    const existingSitter = await Sitter.findOne({ email });
    const existingWalker = await Walker.findOne({ email });
    const existingForRole =
      role === 'owner' ? existingOwner : role === 'sitter' ? existingSitter : existingWalker;
    if (existingForRole) {
      // v404 — Daniel : "ça dit compte existe déjà alors que j'ai pas vérifié
      // mon mail". Si le compte existe mais N'EST PAS vérifié, on ne bloque PAS :
      // on (re)génère + renvoie le code de vérif et on répond comme un signup
      // frais (200, SANS token, needsVerification) → web ET app basculent sur la
      // saisie du code (l'app gère déjà "pas de token → écran de vérification").
      if (existingForRole.verified === false) {
        try {
          const verificationCode = generateVerificationCode();
          await VerificationCode.findOneAndUpdate(
            { email, purpose: 'email_verification' },
            {
              email,
              code: hashCode(verificationCode),
              expiresAt: dayjs().add(10, 'minute').toDate(),
              purpose: 'email_verification',
              verified: false,
            },
            { upsert: true, new: true, setDefaultsOnInsert: true },
          );
          await sendVerificationEmail(email, verificationCode);
        } catch (e) {
          logger.error('[signup] resend code for unverified existing account failed', e);
        }
        return res.status(200).json({
          role,
          user: sanitizeUser(existingForRole, { includeEmail: true }),
          message: 'Account exists but not verified. Verification code re-sent.',
          needsVerification: true,
        });
      }
      return res.status(409).json({ error: 'User with this email already exists.' });
    }
    // Compte frère le plus pertinent comme source de copie (sitter/walker
    // d'abord — ils portent l'IBAN — sinon owner).
    const _siblingSource = existingSitter || existingWalker || existingOwner || null;

    // Process location data (optional: only when valid coordinates provided)
    const location = processLocationData(user.location);

    // Determine and validate currency. If provided, it must be USD or EUR.
    // If omitted, default to DEFAULT_CURRENCY (backwards compatible).
    let ownerCurrency = DEFAULT_CURRENCY;
    let sitterCurrency = DEFAULT_CURRENCY;
    if (user && Object.prototype.hasOwnProperty.call(user, 'currency')) {
      // Validate explicit currency from client
      ownerCurrency = normalizeCurrency(user.currency, { required: true });
      sitterCurrency = ownerCurrency;
    }

    let weeklyRate;
    let monthlyRate;
    try {
      weeklyRate = parseOptionalNonNegativeRate(user.weeklyRate, 'weeklyRate');
      monthlyRate = parseOptionalNonNegativeRate(user.monthlyRate, 'monthlyRate');
    } catch (rateError) {
      return res.status(400).json({ error: rateError.message });
    }

    const ownerPayload = {
      name: user.name,
      email,
      mobile,
      countryCode,
      // Sprint 6.5 step 2 — ISO-2 country collecté au wizard (indicatif/devise).
      country: (user.country || '').toString().toUpperCase().trim(),
      password: user.password,
      language: user.language || '',
      address: user.address || '',
      currency: ownerCurrency,
      acceptedTerms: !!user.acceptedTerms,
      // v532 — tracabilite du consentement : les champs existaient dans
      // les 3 schemas mais n etaient JAMAIS renseignes a l inscription.
      ...(user.acceptedTerms
        ? { termsAcceptedAt: new Date(), termsVersion: TERMS_VERSION }
        : {}),
      service: Array.isArray(user.service) ? user.service : user.service ? [user.service] : [],
      verified: false,
    };
    if (location) ownerPayload.location = location;
    // v445 — synchro inscription↔profil (owner) : champs collectés par le wizard
    // 5 étapes (cf sign_up_controller _buildUserPayload). Sans ça, Owner.create
    // ne persistait QUE les champs ci-dessus → bio / dateOfBirth / préférences /
    // recherche saisis à l'inscription étaient DROPPÉS (réapparaissaient vides
    // dans « Modifier le profil »). Tous ADDITIFS (présents dans Owner.js).
    if (typeof user.bio === 'string' && user.bio.trim()) {
      ownerPayload.bio = user.bio.trim();
    }
    if (typeof user.dateOfBirth === 'string' && user.dateOfBirth.trim()) {
      ownerPayload.dateOfBirth = user.dateOfBirth.trim();
    }
    if (user.searchPreferences && typeof user.searchPreferences === 'object') {
      ownerPayload.searchPreferences = {
        services: Array.isArray(user.searchPreferences.services)
          ? user.searchPreferences.services
          : [],
        radiusKm:
          Number.isFinite(Number(user.searchPreferences.radiusKm)) &&
          Number(user.searchPreferences.radiusKm) > 0
            ? Number(user.searchPreferences.radiusKm)
            : 20,
        preferredLanguage: (user.searchPreferences.preferredLanguage || '').toString(),
      };
    }
    if (user.preferences && typeof user.preferences === 'object') {
      ownerPayload.preferences = {
        sendPhotosVideos: user.preferences.sendPhotosVideos !== false,
        quickReplies: user.preferences.quickReplies !== false,
        flexibleCancellation: user.preferences.flexibleCancellation !== false,
        pawMapInsurance: user.preferences.pawMapInsurance !== false,
        notifications: user.preferences.notifications !== false,
      };
    }

    const sitterPayload = {
      name: user.name,
      email,
      mobile,
      countryCode,
      password: user.password,
      language: user.language || '',
      address: user.address || '',
      currency: sitterCurrency,
      rate: user.rate || '',
      skills: user.skills || '',
      bio: user.bio || '',
      hourlyRate: Number(user.hourlyRate) || Number(user.rate) || 0,
      dailyRate: Number(user.dailyRate) || 0,
      weeklyRate: weeklyRate ?? 0,
      monthlyRate: monthlyRate ?? 0,
      defaultRateType: ['hour', 'day', 'week', 'month'].includes(user.defaultRateType)
        ? user.defaultRateType
        : 'hour',
      acceptedTerms: !!user.acceptedTerms,
      // v532 — tracabilite du consentement : les champs existaient dans
      // les 3 schemas mais n etaient JAMAIS renseignes a l inscription.
      ...(user.acceptedTerms
        ? { termsAcceptedAt: new Date(), termsVersion: TERMS_VERSION }
        : {}),
      service: Array.isArray(user.service) ? user.service : user.service ? [user.service] : [],
      verified: false,
      rating: Number(user.rating) || 0,
      reviewsCount: Number(user.reviewsCount) || 0,
      feedback: Array.isArray(user.feedback) ? user.feedback : [],
    };
    // v444 — supplément « animal supplémentaire » + temps de réponse saisis au
    // wizard d'inscription (cf sign_up_controller). Persistés ici pour que la
    // valeur corresponde à ce que montre l'onglet Tarifs du profil (my_rates).
    {
      const extraPet = Number(user.extraPetRate ?? user.additionalAnimalFee);
      if (Number.isFinite(extraPet) && extraPet >= 0) {
        sitterPayload.extraPetRate = extraPet;
      }
      const rtm = Number(user.responseTimeMinutes);
      if (Number.isFinite(rtm) && rtm > 0) {
        sitterPayload.responseTimeMinutes = Math.round(rtm);
      }
    }
    // v445 — synchro inscription↔profil (sitter) : champs du wizard 5 étapes
    // qui n'étaient PAS recopiés dans sitterPayload → Sitter.create les
    // DROPPAIT (dateOfBirth / animaux acceptés / expérience / rayon / pays /
    // préférences réapparaissaient vides dans « Modifier le profil »). ADDITIF
    // (tous présents dans Sitter.js).
    sitterPayload.country = (user.country || '').toString().toUpperCase().trim();
    if (typeof user.dateOfBirth === 'string' && user.dateOfBirth.trim()) {
      sitterPayload.dateOfBirth = user.dateOfBirth.trim();
    }
    if (Array.isArray(user.experienceTags)) {
      sitterPayload.experienceTags = user.experienceTags;
    }
    if (Array.isArray(user.acceptedPetTypes)) {
      sitterPayload.acceptedPetTypes = user.acceptedPetTypes;
    }
    {
      const km = Number(user.coverageRadiusKm);
      if (Number.isFinite(km) && km > 0) sitterPayload.coverageRadiusKm = km;
    }
    if (user.preferences && typeof user.preferences === 'object') {
      sitterPayload.preferences = {
        sendPhotosVideos: user.preferences.sendPhotosVideos !== false,
        quickReplies: user.preferences.quickReplies !== false,
        flexibleCancellation: user.preferences.flexibleCancellation !== false,
        pawMapInsurance: user.preferences.pawMapInsurance !== false,
        notifications: user.preferences.notifications !== false,
      };
    }
    if (paypalEmail) {
      if (!isValidEmail(paypalEmail)) {
        return res.status(400).json({ error: 'paypalEmail must be a valid email address.' });
      }
      sitterPayload.paypalEmail = paypalEmail;
    }
    if (location) {
      sitterPayload.location = {
        ...location,
        locationType: user.location?.locationType || 'standard',
      };
    }

    // ── Walker payload (role === 'walker') ────────────────────────────
    // Walkers share most of the Sitter structure (auth, payout, moderation,
    // boost) but have their own pricing model (walkRates, per-duration) and
    // walker-specific fields (acceptedPetTypes, coverageRadiusKm, insurance).
    const walkerCurrency = sitterCurrency; // same normalization as sitter
    const walkerPayload = {
      name: user.name,
      email,
      mobile,
      countryCode,
      password: user.password,
      language: user.language || '',
      address: user.address || '',
      currency: walkerCurrency,
      skills: user.skills || '',
      bio: user.bio || '',
      acceptedTerms: !!user.acceptedTerms,
      // v532 — tracabilite du consentement : les champs existaient dans
      // les 3 schemas mais n etaient JAMAIS renseignes a l inscription.
      ...(user.acceptedTerms
        ? { termsAcceptedAt: new Date(), termsVersion: TERMS_VERSION }
        : {}),
      service: Array.isArray(user.service)
        ? user.service
        : user.service
          ? [user.service]
          : ['dog_walking'],
      verified: false,
      acceptedPetTypes: Array.isArray(user.acceptedPetTypes)
        ? user.acceptedPetTypes
        : ['dog_small', 'dog_medium', 'dog_large'],
      maxPetsPerWalk:
        Number.isInteger(user.maxPetsPerWalk) && user.maxPetsPerWalk >= 1 && user.maxPetsPerWalk <= 10
          ? user.maxPetsPerWalk
          : 1,
      hasInsurance: !!user.hasInsurance,
      coverageCity: (user.coverageCity || user.location?.city || '').toString().trim(),
      // v532 — on BORNE au lieu de réinitialiser. AVANT : toute valeur hors
      // [1,50] retombait à 3 km — un promeneur qui choisissait 100 km dans le
      // wizard se retrouvait à 3 km sans aucun message. Désormais 100 est
      // accepté (max du modèle) et une valeur aberrante est ramenée dans les
      // bornes plutôt qu'écrasée.
      coverageRadiusKm: (() => {
        const km = Number(user.coverageRadiusKm);
        if (!Number.isFinite(km) || km <= 0) return 3;
        return Math.min(100, Math.max(1, Math.round(km)));
      })(),
      // v23.1 part 141 — Daniel : 'ValidationError walkRates.0.basePrice
      // walkRates.0.durationMinutes'. Le frontend envoie historiquement
      // {duration, amount, currency} (cf sign_up_controller.dart) mais
      // le Walker model attend {durationMinutes, basePrice, currency}.
      // On normalise ici pour tolérer les 2 formats : si un objet a
      // `duration`/`amount` on les renomme. Sinon on passe tel quel.
      walkRates: Array.isArray(user.walkRates)
        ? user.walkRates
            .filter((r) => r && typeof r === 'object')
            .map((r) => ({
              durationMinutes: r.durationMinutes ?? r.duration,
              basePrice: r.basePrice ?? r.amount,
              currency: r.currency || 'EUR',
              enabled: r.enabled !== false,
            }))
            .filter((r) =>
              Number.isFinite(r.durationMinutes) &&
              Number.isFinite(r.basePrice),
            )
        : [],
      defaultWalkDurationMinutes:
        Number.isInteger(user.defaultWalkDurationMinutes) &&
        user.defaultWalkDurationMinutes >= 15 &&
        user.defaultWalkDurationMinutes <= 300 &&
        user.defaultWalkDurationMinutes % 15 === 0
          ? user.defaultWalkDurationMinutes
          : 30,
      feedback: [],
    };
    // v444 — supplément animal + temps de réponse saisis au wizard (walker).
    // Persistés pour matcher l'onglet Tarifs du profil (my_rates_screen).
    {
      const extraPet = Number(user.extraPetRate ?? user.additionalAnimalFee);
      if (Number.isFinite(extraPet) && extraPet >= 0) {
        walkerPayload.extraPetRate = extraPet;
      }
      const rtm = Number(user.responseTimeMinutes);
      if (Number.isFinite(rtm) && rtm > 0) {
        walkerPayload.responseTimeMinutes = Math.round(rtm);
      }
    }
    // v445 — synchro inscription↔profil (walker) : champs du wizard 5 étapes
    // non recopiés dans walkerPayload → Walker.create les DROPPAIT (date de
    // naissance / expérience / jours dispo / pays / préférences réapparaissaient
    // vides). acceptedPetTypes + coverageRadiusKm sont déjà gérés plus haut.
    // ADDITIF (tous présents dans Walker.js).
    walkerPayload.country = (user.country || '').toString().toUpperCase().trim();
    if (typeof user.dateOfBirth === 'string' && user.dateOfBirth.trim()) {
      walkerPayload.dateOfBirth = user.dateOfBirth.trim();
    }
    if (Array.isArray(user.experienceTags)) {
      walkerPayload.experienceTags = user.experienceTags;
    }
    if (Array.isArray(user.availableDays)) {
      walkerPayload.availableDays = user.availableDays;
    }
    if (user.preferences && typeof user.preferences === 'object') {
      walkerPayload.preferences = {
        sendPhotosVideos: user.preferences.sendPhotosVideos !== false,
        quickReplies: user.preferences.quickReplies !== false,
        flexibleCancellation: user.preferences.flexibleCancellation !== false,
        pawMapInsurance: user.preferences.pawMapInsurance !== false,
        notifications: user.preferences.notifications !== false,
      };
    }
    if (paypalEmail) {
      // paypalEmail was already validated above for sitter payload.
      walkerPayload.paypalEmail = paypalEmail;
    }
    if (location) {
      walkerPayload.location = {
        ...location,
        locationType: user.location?.locationType || 'standard',
      };
    }

    // Sprint 7 step 3 — referral code & referrer.
    const referralInput = (user.referralCode || user.referredBy || '').toString().toUpperCase().trim();
    const { generateUniqueReferralCode } = require('../utils/referralCode');
    // Extend referral uniqueness check to include Walker model.
    const newReferralCode = await generateUniqueReferralCode({ Owner, Sitter, Walker }).catch(() => null);
    if (role === 'owner') {
      if (newReferralCode) ownerPayload.referralCode = newReferralCode;
      if (referralInput) ownerPayload.referredBy = referralInput;
    } else if (role === 'sitter') {
      if (newReferralCode) sitterPayload.referralCode = newReferralCode;
      if (referralInput) sitterPayload.referredBy = referralInput;
    } else {
      // walker
      if (newReferralCode) walkerPayload.referralCode = newReferralCode;
      if (referralInput) walkerPayload.referredBy = referralInput;
    }

    let newUser;
    if (role === 'owner') {
      newUser = await Owner.create(ownerPayload);
    } else if (role === 'sitter') {
      newUser = await Sitter.create(sitterPayload);
    } else {
      // walker
      newUser = await Walker.create(walkerPayload);
    }

    // v23.1.388 — héritage depuis le compte frère (même email, autre rôle) :
    // 1) données partagées (nom, tél, adresse, avatar, CB, IBAN…) copiées
    //    via la MÊME liste SHARED_FIELDS que userSyncService (cohérence) ;
    // 2) email déjà vérifié sur le frère → pas de re-vérification ;
    // 3) forfaits (PawFollow/PawSpot/Premium/Famille) propagés — il garde
    //    ses jours restants sur le nouveau profil. Best-effort non bloquant.
    let inheritedFromSibling = false;
    if (_siblingSource) {
      try {
        const Model = role === 'owner' ? Owner : role === 'sitter' ? Sitter : Walker;
        const SHARED = [
          'name', 'firstName', 'lastName', 'fullName',
          'mobile', 'phone', 'phoneNumber', 'countryCode',
          'avatar', 'profileImage', 'dateOfBirth', 'dob', 'gender',
          'address', 'city', 'postalCode', 'country', 'location',
          'language', 'currency', 'bio', 'skills', 'card',
          ...(role === 'owner' ? [] : [
            'ibanHolder', 'ibanNumber', 'ibanBic', 'ibanVerified',
            'payoutMethod', 'paypalEmail', 'paypalConnectedAt',
          ]),
          'verified', 'isStaff',
        ];
        // v532 — l'héritage ne doit COMPLÉTER que ce que le wizard n'a pas
        // rempli. AVANT, il écrasait systématiquement : un propriétaire qui
        // ouvrait un profil sitter voyait la bio, la ville, la devise et la
        // langue saisies aux étapes 2-4 remplacées par celles de son compte
        // propriétaire — tout le travail du wizard devenait invisible.
        // On considère « déjà renseigné » toute valeur non vide sur le
        // document fraîchement créé (chaîne, tableau, objet ou nombre).
        const isFilled = (v) => {
          if (v === undefined || v === null || v === '') return false;
          if (Array.isArray(v)) return v.length > 0;
          if (typeof v === 'object') {
            // location : { type:'Point', coordinates:[0,0] } = non renseigné
            if (Array.isArray(v.coordinates)) {
              return v.coordinates.length === 2 &&
                !(Number(v.coordinates[0]) === 0 && Number(v.coordinates[1]) === 0);
            }
            return Object.values(v).some((x) => x !== undefined && x !== null && x !== '');
          }
          return true;
        };
        const copy = {};
        for (const k of SHARED) {
          const v = _siblingSource[k];
          if (v === undefined || v === null || v === '') continue;
          // 'verified' et 'isStaff' restent hérités inconditionnellement :
          // ce sont des statuts de compte, pas des saisies du wizard.
          if (k !== 'verified' && k !== 'isStaff' && isFilled(newUser[k])) continue;
          copy[k] = v;
        }
        if (Object.keys(copy).length) {
          await Model.updateOne({ _id: newUser._id }, { $set: copy });
          inheritedFromSibling = true;
          // Recharge pour renvoyer le profil complété au client.
          newUser = await Model.findById(newUser._id);
        }
        // Forfaits : union des timers entre tous les rôles de cet email.
        const siblingModelName = existingSitter ? 'Sitter' : existingWalker ? 'Walker' : 'Owner';
        const { syncAllRolesByEmail } = require('../models/UserSubscription');
        await syncAllRolesByEmail(_siblingSource._id, siblingModelName);
        logger.info(`[signup] ${role} ${newUser._id} hérite du profil frère (${email})`);
      } catch (inheritErr) {
        logger.warn(`[signup] héritage frère non appliqué : ${inheritErr.message}`);
      }
    }

    // Sprint 7 step 3 — record pending Referral if a valid code was provided.
    if (referralInput) {
      try {
        const { createPendingReferral } = require('../services/referralService');
        await createPendingReferral({
          referralCode: referralInput,
          referredUserId: newUser._id,
          referredRole: role,
        });
      } catch (e) {
        logger.warn('createPendingReferral failed', e.message);
      }
    }

    const verificationCode = generateVerificationCode();
    await VerificationCode.findOneAndUpdate(
      { email, purpose: 'email_verification' },
      {
        email,
        code: hashCode(verificationCode),
        expiresAt: dayjs().add(10, 'minute').toDate(),
        purpose: 'email_verification',
        verified: false,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    try {
      await sendVerificationEmail(email, verificationCode);
    } catch (emailError) {
      logger.error('Failed to send verification email', emailError);
    }

    // v23.1 part 127 — Phase 3 audit P3-1 : NE JAMAIS renvoyer le code
    // de vérification dans la réponse HTTP. Le client doit lire son email
    // pour récupérer le code, sinon n'importe qui crée un compte et
    // se vérifie sans accès au mailbox → bypass total de l'anti-bot.
    res.status(201).json({
      role,
      user: sanitizeUser(newUser, { includeEmail: true }),
      message: 'Account created. Please verify your email.',
    });
  } catch (error) {
    logger.error('Signup error', error);
    if (error.message && error.message.includes('currency must be either USD or EUR.')) {
      return res.status(400).json({ error: error.message });
    }
    // v23.1 part 140 — Daniel : "Échec de l'inscription unable to create
    // account" sans détail → débugage impossible. On expose maintenant
    // error.name + error.message côté client (Mongoose ValidationError
    // messages sont safes : ils disent juste "Path `X` is required" ou
    // "X must be ..."). Si c'est une erreur DB / système → fallback générique.
    const safeName = error?.name || 'Error';
    let detail = error?.message || 'Unable to create account.';
    // Limit length to avoid leaking long stacks
    detail = String(detail).slice(0, 500);
    // Si Mongoose validation error, on liste les champs problématiques
    if (error?.name === 'ValidationError' && error?.errors) {
      const fields = Object.keys(error.errors).join(', ');
      detail = `Validation failed on: ${fields}. ${detail}`;
    }
    res.status(500).json({
      error: 'Unable to create account. Please try again later.',
      details: `[${safeName}] ${detail}`,
    });
  }
};

const login = async (req, res) => {
  try {
    const { email, password, role: preferredRole } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required.' });
    }

    // v425 — Daniel : "créé promeneur → ouvre sitter". findAccountByEmail
    // résout le rôle par ordre FIXE owner>sitter>walker, donc un email
    // multi-rôles se connecte toujours sur le rôle de plus haute priorité.
    // Si le client précise `role` (ex. juste après inscription promeneur) ET
    // qu'un compte existe pour CE rôle, on se connecte dessus en priorité.
    let result = null;
    if (preferredRole && VALID_ROLES.includes(preferredRole)) {
      const Model =
        preferredRole === 'owner' ? Owner : preferredRole === 'sitter' ? Sitter : Walker;
      const account = await Model.findOne({ email: String(email).toLowerCase() });
      if (account) result = { role: preferredRole, account };
    }
    if (!result) {
      result = await findAccountByEmail(email);
    }

    if (!result) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const passwordMatches = await result.account.comparePassword(password);
    if (!passwordMatches) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    // Sprint 7 step 6 — block suspended/banned accounts at login.
    if (result.account.status && result.account.status !== 'active') {
      const msg = result.account.status === 'suspended'
        ? 'Account suspended. Please contact support.'
        : 'Account banned.';
      return res.status(401).json({ error: msg, status: result.account.status });
    }

    if (!result.account.verified) {
      const userEmail = (result.account.email || email).toString().toLowerCase();
      const verificationCode = generateVerificationCode();
      await VerificationCode.findOneAndUpdate(
        { email: userEmail, purpose: 'email_verification' },
        {
          email: userEmail,
          code: hashCode(verificationCode),
          expiresAt: dayjs().add(10, 'minute').toDate(),
          purpose: 'email_verification',
          verified: false,
        },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      );
      try {
        await sendVerificationEmail(userEmail, verificationCode);
      } catch (emailError) {
        logger.error('Failed to send verification email on login', emailError);
      }
      return res.status(403).json({
        error: 'Email not verified. Please verify your account.',
        message: 'A new verification code has been sent to your email.',
      });
    }

    const token = signAuthToken({ id: result.account._id.toString(), role: result.role });

    // v22.5 — Bug R1 : multi-role detection
    const availableRoles = await findAvailableRolesForAccount(
      result.account.email,
      result.account.oldId,
    );

    res.json({
      role: result.role,
      token,
      user: sanitizeUser(result.account, { includeEmail: true }),
      availableRoles,
    });
  } catch (error) {
    logger.error('Login error', error);
    if (error.message && error.message.includes('JWT_SECRET')) {
      return res.status(500).json({ error: 'Authentication service is not configured.' });
    }
    res.status(500).json({ error: 'Unable to login. Please try again later.' });
  }
};

/**
 * Google / Firebase authentication.
 * Frontend must authenticate with Firebase and send a Firebase ID token.
 *
 * Flow:
 * 1. Verify Firebase ID token
 * 2. Extract uid, email, name, picture, firebase.sign_in_provider
 * 3. If user with email exists (owner or sitter) -> link firebaseUid/authProvider if needed and login (return token)
 * 4. If not -> create new user (verified: false), send verification code, return signup-style response (no token)
 */
const googleAuth = async (req, res) => {
  try {
    const { idToken, role, user } = req.body || {};

    if (!idToken) {
      return res.status(400).json({ error: 'idToken is required.' });
    }

    let decoded;
    try {
      decoded = await firebaseAdmin.auth().verifyIdToken(idToken);
    } catch (verifyError) {
      logger.error('Firebase ID token verification failed', verifyError);
      return res.status(401).json({ error: 'Invalid or expired Firebase ID token.' });
    }

    const {
      uid,
      email,
      name,
      picture,
      firebase: firebaseInfo,
    } = decoded;

    if (!email) {
      return res.status(400).json({ error: 'Firebase token does not contain a valid email.' });
    }

    const signInProvider = firebaseInfo?.sign_in_provider || 'firebase';

    // Always resolve user by email to avoid duplicate accounts and
    // ensure password + Google logins with same email map to same account.
    let result = await findAccountByEmail(email);

    // Existing user -> update firebase fields if needed and login.
    if (result) {
      const account = result.account;

      // Build updates without calling account.save() directly.
      // This avoids Mongoose re-applying default location values that break the geospatial index.
      const updates = {};
      let needsUpdate = false;

      if (!account.firebaseUid) {
        updates.firebaseUid = uid;
        needsUpdate = true;
      }
      if (account.authProvider !== 'google') {
        updates.authProvider = 'google';
        needsUpdate = true;
      }
      if (!account.verified) {
        updates.verified = true;
        needsUpdate = true;
      }
      if (picture && (!account.avatar || !account.avatar.url)) {
        const currentAvatar = account.avatar || {};
        updates.avatar = {
          ...currentAvatar,
          url: picture,
        };
        needsUpdate = true;
      }

      // Handle potentially invalid location for geo index
      const loc = account.location;
      const hasValidCoordinates =
        loc &&
        Array.isArray(loc.coordinates) &&
        loc.coordinates.length === 2 &&
        typeof loc.coordinates[0] === 'number' &&
        typeof loc.coordinates[1] === 'number';

      const updateOps = {};
      if (needsUpdate) {
        updateOps.$set = updates;
      }
      if (!hasValidCoordinates && loc !== undefined) {
        // Explicitly remove invalid location so MongoDB 2dsphere index won't choke
        updateOps.$unset = { location: '' };
      }

      if (Object.keys(updateOps).length > 0) {
        // Pick the right collection based on the existing user's role.
        const RoleModel = {
          owner: Owner,
          sitter: Sitter,
          walker: Walker,
        }[result.role] || Sitter;
        await RoleModel.updateOne({ _id: account._id }, updateOps);

        // Reflect updates in memory for response
        if (updates.firebaseUid) {
          account.firebaseUid = updates.firebaseUid;
        }
        if (updates.authProvider) {
          account.authProvider = updates.authProvider;
        }
        if (updates.verified !== undefined) {
          account.verified = updates.verified;
        }
        if (updates.avatar) {
          account.avatar = updates.avatar;
        }
        if (!hasValidCoordinates && loc !== undefined) {
          account.location = undefined;
        }
      }

      const token = signAuthToken({ id: account._id.toString(), role: result.role });

      // v22.5 — Bug R1 : multi-role detection
      const availableRoles = await findAvailableRolesForAccount(
        account.email,
        account.oldId,
      );

      return res.json({
        existingUser: true,
        role: result.role,
        provider: signInProvider,
        token,
        user: sanitizeUser(account, { includeEmail: true }),
        availableRoles,
      });
    }

    // New user creation requires a role so we know which collection to use.
    // v23.1 part 137 — fix Daniel : le front catch ce 400 avec code
    // ROLE_REQUIRED pour rediriger l'utilisateur vers SignUpAs (choix
    // owner/sitter/walker) au lieu de créer un Sitter par défaut.
    if (!role || !VALID_ROLES.includes(role)) {
      return res.status(400).json({
        error: `Role is required for new Google users and must be one of: ${VALID_ROLES.map((r) => `"${r}"`).join(', ')}.`,
        code: 'ROLE_REQUIRED',
      });
    }

    const normalizedEmail = email.toLowerCase();
    const displayName = name || decoded.name || decoded.email || 'User';

    // Process location data if provided
    const location = processLocationData(user?.location);

    // Currency: validate when provided, otherwise default for backwards compatibility
    let baseCurrency = DEFAULT_CURRENCY;
    if (user && Object.prototype.hasOwnProperty.call(user, 'currency')) {
      baseCurrency = normalizeCurrency(user.currency, { required: true });
    }

    const baseFields = {
      name: displayName,
      email: normalizedEmail,
      mobile: '',
      countryCode: (user?.countryCode || '').toString().trim(),
      password: generateRandomPassword(),
      language: '',
      address: '',
      currency: baseCurrency,
      acceptedTerms: false,
      service: [],
      verified: true,
      firebaseUid: uid,
      authProvider: 'google',
      avatar: {
        url: picture || '',
        publicId: '',
      },
    };
    if (location) baseFields.location = location;

    let newUser;
    if (role === 'owner') {
      newUser = await Owner.create(baseFields);
    } else if (role === 'sitter') {
      const paypalEmailRaw = user?.paypalEmail;
      const paypalEmail =
        paypalEmailRaw && typeof paypalEmailRaw === 'string' && paypalEmailRaw.trim()
          ? paypalEmailRaw.trim().toLowerCase()
          : '';
      if (paypalEmail && !isValidEmail(paypalEmail)) {
        return res.status(400).json({ error: 'paypalEmail must be a valid email address.' });
      }
      let hourlyRateFromRequest;
      let weeklyRateFromRequest;
      let monthlyRateFromRequest;
      try {
        hourlyRateFromRequest = parseOptionalNonNegativeRate(user?.hourlyRate, 'hourlyRate');
        weeklyRateFromRequest = parseOptionalNonNegativeRate(user?.weeklyRate, 'weeklyRate');
        monthlyRateFromRequest = parseOptionalNonNegativeRate(user?.monthlyRate, 'monthlyRate');
      } catch (rateError) {
        return res.status(400).json({ error: rateError.message });
      }
      const sitterFields = {
        ...baseFields,
        rate: '',
        skills: '',
        bio: '',
        hourlyRate: hourlyRateFromRequest ?? 0,
        weeklyRate: weeklyRateFromRequest ?? 0,
        monthlyRate: monthlyRateFromRequest ?? 0,
        // v449 — Daniel : « temps de réponse rempli à l'inscription ne s'affiche
        // pas ». L'inscription Google/Apple droppait responseTimeMinutes +
        // extraPetRate (seul le signup email/mdp les persistait). Ajoutés ici.
        ...(Number.isFinite(Number(user?.extraPetRate ?? user?.additionalAnimalFee)) &&
          Number(user?.extraPetRate ?? user?.additionalAnimalFee) >= 0
            ? { extraPetRate: Number(user.extraPetRate ?? user.additionalAnimalFee) }
            : {}),
        ...(Number.isFinite(Number(user?.responseTimeMinutes)) &&
          Number(user.responseTimeMinutes) > 0
            ? { responseTimeMinutes: Math.round(Number(user.responseTimeMinutes)) }
            : {}),
        rating: 0,
        reviewsCount: 0,
        feedback: [],
        ...(paypalEmail ? { paypalEmail } : {}),
      };
      if (location) {
        sitterFields.location = {
          ...location,
          locationType: user?.location?.locationType || 'standard',
        };
      }
      newUser = await Sitter.create(sitterFields);
    } else {
      // walker
      const paypalEmailRaw = user?.paypalEmail;
      const paypalEmail =
        paypalEmailRaw && typeof paypalEmailRaw === 'string' && paypalEmailRaw.trim()
          ? paypalEmailRaw.trim().toLowerCase()
          : '';
      if (paypalEmail && !isValidEmail(paypalEmail)) {
        return res.status(400).json({ error: 'paypalEmail must be a valid email address.' });
      }
      const walkerFields = {
        ...baseFields,
        service: Array.isArray(user?.service) && user.service.length ? user.service : ['dog_walking'],
        skills: '',
        bio: '',
        acceptedPetTypes: Array.isArray(user?.acceptedPetTypes)
          ? user.acceptedPetTypes
          : ['dog_small', 'dog_medium', 'dog_large'],
        maxPetsPerWalk:
          Number.isInteger(user?.maxPetsPerWalk) && user.maxPetsPerWalk >= 1 && user.maxPetsPerWalk <= 10
            ? user.maxPetsPerWalk
            : 1,
        hasInsurance: !!user?.hasInsurance,
        coverageCity: (user?.coverageCity || user?.location?.city || '').toString().trim(),
        coverageRadiusKm:
          Number.isFinite(Number(user?.coverageRadiusKm)) &&
          Number(user?.coverageRadiusKm) >= 1 &&
          Number(user?.coverageRadiusKm) <= 50
            ? Number(user.coverageRadiusKm)
            : 3,
        walkRates: Array.isArray(user?.walkRates) ? user.walkRates : [],
        defaultWalkDurationMinutes:
          Number.isInteger(user?.defaultWalkDurationMinutes) &&
          user.defaultWalkDurationMinutes >= 15 &&
          user.defaultWalkDurationMinutes <= 300 &&
          user.defaultWalkDurationMinutes % 15 === 0
            ? user.defaultWalkDurationMinutes
            : 30,
        // v449 — idem sitter : l'inscription Google/Apple droppait
        // responseTimeMinutes + extraPetRate. Ajoutés (gardés si fournis).
        ...(Number.isFinite(Number(user?.extraPetRate ?? user?.additionalAnimalFee)) &&
          Number(user?.extraPetRate ?? user?.additionalAnimalFee) >= 0
            ? { extraPetRate: Number(user.extraPetRate ?? user.additionalAnimalFee) }
            : {}),
        ...(Number.isFinite(Number(user?.responseTimeMinutes)) &&
          Number(user.responseTimeMinutes) > 0
            ? { responseTimeMinutes: Math.round(Number(user.responseTimeMinutes)) }
            : {}),
        rating: 0,
        reviewsCount: 0,
        feedback: [],
        ...(paypalEmail ? { paypalEmail } : {}),
      };
      if (location) {
        walkerFields.location = {
          ...location,
          locationType: user?.location?.locationType || 'standard',
        };
      }
      newUser = await Walker.create(walkerFields);
    }

    const token = signAuthToken({ id: newUser._id.toString(), role });

    return res.status(201).json({
      existingUser: false,
      role,
      provider: signInProvider,
      token,
      user: sanitizeUser(newUser, { includeEmail: true }),
    });
  } catch (error) {
    // v22.5 — DEBUG : pino n'imprime pas un Error passé en 2e arg, donc le
    // stack trace était perdu. On passe { err } + console.error fallback.
    logger.error({ err: error, stack: error?.stack, message: error?.message }, '❌ Google auth error');
    console.error('[googleAuth] EXPLICIT ERROR:', error);
    if (error.message && error.message.includes('currency must be either USD or EUR.')) {
      return res.status(400).json({ error: error.message });
    }
    if (error.message && error.message.includes('JWT_SECRET')) {
      return res.status(500).json({ error: 'Authentication service is not configured.' });
    }
    // v22.5 — DEBUG : on remonte le détail au client pour voir la vraie
    // cause sur le tél sans dépendre des logs Render. À simplifier après.
    res.status(500).json({
      error: 'Unable to authenticate with Google.',
      details: error?.message || String(error),
    });
  }
};

/**
 * Apple Sign-In / Firebase authentication.
 * Frontend must authenticate with Firebase (Apple provider) and send a Firebase ID token.
 *
 * Flow:
 * 1. Verify Firebase ID token
 * 2. Extract uid, email, name, picture, firebase.sign_in_provider
 * 3. If user with email exists (owner or sitter) -> link firebaseUid/authProvider if needed and login (return token)
 * 4. If not -> create new user (verified: true), return signup-style response with token
 */
const appleAuth = async (req, res) => {
  try {
    const { idToken, role, user } = req.body || {};

    if (!idToken) {
      return res.status(400).json({ error: 'idToken is required.' });
    }

    let decoded;
    try {
      decoded = await firebaseAdmin.auth().verifyIdToken(idToken);
    } catch (verifyError) {
      logger.error('Firebase ID token verification failed', verifyError);
      return res.status(401).json({ error: 'Invalid or expired Firebase ID token.' });
    }

    const {
      uid,
      email,
      name,
      picture,
      firebase: firebaseInfo,
    } = decoded;

    // Apple Sign-In may not always provide email (if user chose to hide it)
    // In that case, Firebase provides a private relay email
    if (!email) {
      return res.status(400).json({ error: 'Firebase token does not contain a valid email.' });
    }

    const signInProvider = firebaseInfo?.sign_in_provider || 'apple.com';

    // Always resolve user by email to avoid duplicate accounts and
    // ensure password + Google + Apple logins with same email map to same account.
    let result = await findAccountByEmail(email);

    // Existing user -> update firebase fields if needed and login.
    if (result) {
      const account = result.account;

      // Build updates without calling account.save() directly.
      // This avoids Mongoose re-applying default location values that break the geospatial index.
      const updates = {};
      let needsUpdate = false;

      if (!account.firebaseUid) {
        updates.firebaseUid = uid;
        needsUpdate = true;
      }
      if (account.authProvider !== 'apple') {
        updates.authProvider = 'apple';
        needsUpdate = true;
      }
      if (!account.verified) {
        updates.verified = true;
        needsUpdate = true;
      }
      if (picture && (!account.avatar || !account.avatar.url)) {
        const currentAvatar = account.avatar || {};
        updates.avatar = {
          ...currentAvatar,
          url: picture,
        };
        needsUpdate = true;
      }

      // Handle potentially invalid location for geo index
      const loc = account.location;
      const hasValidCoordinates =
        loc &&
        Array.isArray(loc.coordinates) &&
        loc.coordinates.length === 2 &&
        typeof loc.coordinates[0] === 'number' &&
        typeof loc.coordinates[1] === 'number';

      const updateOps = {};
      if (needsUpdate) {
        updateOps.$set = updates;
      }
      if (!hasValidCoordinates && loc !== undefined) {
        // Explicitly remove invalid location so MongoDB 2dsphere index won't choke
        updateOps.$unset = { location: '' };
      }

      if (Object.keys(updateOps).length > 0) {
        // Pick the right collection based on the existing user's role (3-role aware).
        const RoleModel = {
          owner: Owner,
          sitter: Sitter,
          walker: Walker,
        }[result.role] || Sitter;
        await RoleModel.updateOne({ _id: account._id }, updateOps);

        // Reflect updates in memory for response
        if (updates.firebaseUid) {
          account.firebaseUid = updates.firebaseUid;
        }
        if (updates.authProvider) {
          account.authProvider = updates.authProvider;
        }
        if (updates.verified !== undefined) {
          account.verified = updates.verified;
        }
        if (updates.avatar) {
          account.avatar = updates.avatar;
        }
        if (!hasValidCoordinates && loc !== undefined) {
          account.location = undefined;
        }
      }

      const token = signAuthToken({ id: account._id.toString(), role: result.role });
      return res.json({
        existingUser: true,
        role: result.role,
        provider: signInProvider,
        token,
        user: sanitizeUser(account, { includeEmail: true }),
      });
    }

    // New user creation requires a role so we know which collection to use.
    // v23.1 part 137 — code ROLE_REQUIRED pour que le front détecte et
    // redirige vers SignUpAs.
    if (!role || !VALID_ROLES.includes(role)) {
      return res.status(400).json({
        error: `Role is required for new Apple users and must be one of: ${VALID_ROLES.map((r) => `"${r}"`).join(', ')}.`,
        code: 'ROLE_REQUIRED',
      });
    }

    const normalizedEmail = email.toLowerCase();
    // Apple Sign-In may provide name in the first request, but subsequent logins may not
    // Use name from token, decoded name, or fallback to email/User
    const displayName = name || decoded.name || decoded.email?.split('@')[0] || 'User';

    // Process location data if provided
    const location = processLocationData(user?.location);

    // Currency: validate when provided, otherwise default for backwards compatibility
    let baseCurrency = DEFAULT_CURRENCY;
    if (user && Object.prototype.hasOwnProperty.call(user, 'currency')) {
      baseCurrency = normalizeCurrency(user.currency, { required: true });
    }

    const baseFields = {
      name: displayName,
      email: normalizedEmail,
      mobile: '',
      countryCode: (user?.countryCode || '').toString().trim(),
      password: generateRandomPassword(),
      language: '',
      address: '',
      currency: baseCurrency,
      acceptedTerms: false,
      service: [],
      verified: true,
      firebaseUid: uid,
      authProvider: 'apple',
      avatar: {
        url: picture || '',
        publicId: '',
      },
    };
    if (location) baseFields.location = location;

    let newUser;
    if (role === 'owner') {
      newUser = await Owner.create(baseFields);
    } else if (role === 'sitter') {
      const paypalEmailRaw = user?.paypalEmail;
      const paypalEmail =
        paypalEmailRaw && typeof paypalEmailRaw === 'string' && paypalEmailRaw.trim()
          ? paypalEmailRaw.trim().toLowerCase()
          : '';
      if (paypalEmail && !isValidEmail(paypalEmail)) {
        return res.status(400).json({ error: 'paypalEmail must be a valid email address.' });
      }
      let hourlyRateFromRequest;
      let weeklyRateFromRequest;
      let monthlyRateFromRequest;
      try {
        hourlyRateFromRequest = parseOptionalNonNegativeRate(user?.hourlyRate, 'hourlyRate');
        weeklyRateFromRequest = parseOptionalNonNegativeRate(user?.weeklyRate, 'weeklyRate');
        monthlyRateFromRequest = parseOptionalNonNegativeRate(user?.monthlyRate, 'monthlyRate');
      } catch (rateError) {
        return res.status(400).json({ error: rateError.message });
      }
      const sitterFields = {
        ...baseFields,
        rate: '',
        skills: '',
        bio: '',
        hourlyRate: hourlyRateFromRequest ?? 0,
        weeklyRate: weeklyRateFromRequest ?? 0,
        monthlyRate: monthlyRateFromRequest ?? 0,
        // v449 — Daniel : « temps de réponse rempli à l'inscription ne s'affiche
        // pas ». L'inscription Google/Apple droppait responseTimeMinutes +
        // extraPetRate (seul le signup email/mdp les persistait). Ajoutés ici.
        ...(Number.isFinite(Number(user?.extraPetRate ?? user?.additionalAnimalFee)) &&
          Number(user?.extraPetRate ?? user?.additionalAnimalFee) >= 0
            ? { extraPetRate: Number(user.extraPetRate ?? user.additionalAnimalFee) }
            : {}),
        ...(Number.isFinite(Number(user?.responseTimeMinutes)) &&
          Number(user.responseTimeMinutes) > 0
            ? { responseTimeMinutes: Math.round(Number(user.responseTimeMinutes)) }
            : {}),
        rating: 0,
        reviewsCount: 0,
        feedback: [],
        ...(paypalEmail ? { paypalEmail } : {}),
      };
      if (location) {
        sitterFields.location = {
          ...location,
          locationType: user?.location?.locationType || 'standard',
        };
      }
      newUser = await Sitter.create(sitterFields);
    } else {
      // walker
      const paypalEmailRaw = user?.paypalEmail;
      const paypalEmail =
        paypalEmailRaw && typeof paypalEmailRaw === 'string' && paypalEmailRaw.trim()
          ? paypalEmailRaw.trim().toLowerCase()
          : '';
      if (paypalEmail && !isValidEmail(paypalEmail)) {
        return res.status(400).json({ error: 'paypalEmail must be a valid email address.' });
      }
      const walkerFields = {
        ...baseFields,
        service: Array.isArray(user?.service) && user.service.length ? user.service : ['dog_walking'],
        skills: '',
        bio: '',
        acceptedPetTypes: Array.isArray(user?.acceptedPetTypes)
          ? user.acceptedPetTypes
          : ['dog_small', 'dog_medium', 'dog_large'],
        maxPetsPerWalk:
          Number.isInteger(user?.maxPetsPerWalk) && user.maxPetsPerWalk >= 1 && user.maxPetsPerWalk <= 10
            ? user.maxPetsPerWalk
            : 1,
        hasInsurance: !!user?.hasInsurance,
        coverageCity: (user?.coverageCity || user?.location?.city || '').toString().trim(),
        coverageRadiusKm:
          Number.isFinite(Number(user?.coverageRadiusKm)) &&
          Number(user?.coverageRadiusKm) >= 1 &&
          Number(user?.coverageRadiusKm) <= 50
            ? Number(user.coverageRadiusKm)
            : 3,
        walkRates: Array.isArray(user?.walkRates) ? user.walkRates : [],
        defaultWalkDurationMinutes:
          Number.isInteger(user?.defaultWalkDurationMinutes) &&
          user.defaultWalkDurationMinutes >= 15 &&
          user.defaultWalkDurationMinutes <= 300 &&
          user.defaultWalkDurationMinutes % 15 === 0
            ? user.defaultWalkDurationMinutes
            : 30,
        // v449 — idem sitter : l'inscription Google/Apple droppait
        // responseTimeMinutes + extraPetRate. Ajoutés (gardés si fournis).
        ...(Number.isFinite(Number(user?.extraPetRate ?? user?.additionalAnimalFee)) &&
          Number(user?.extraPetRate ?? user?.additionalAnimalFee) >= 0
            ? { extraPetRate: Number(user.extraPetRate ?? user.additionalAnimalFee) }
            : {}),
        ...(Number.isFinite(Number(user?.responseTimeMinutes)) &&
          Number(user.responseTimeMinutes) > 0
            ? { responseTimeMinutes: Math.round(Number(user.responseTimeMinutes)) }
            : {}),
        rating: 0,
        reviewsCount: 0,
        feedback: [],
        ...(paypalEmail ? { paypalEmail } : {}),
      };
      if (location) {
        walkerFields.location = {
          ...location,
          locationType: user?.location?.locationType || 'standard',
        };
      }
      newUser = await Walker.create(walkerFields);
    }

    const token = signAuthToken({ id: newUser._id.toString(), role });

    return res.status(201).json({
      existingUser: false,
      role,
      provider: signInProvider,
      token,
      user: sanitizeUser(newUser, { includeEmail: true }),
    });
  } catch (error) {
    logger.error('Apple auth error', error);
    if (error.message && error.message.includes('currency must be either USD or EUR.')) {
      return res.status(400).json({ error: error.message });
    }
    if (error.message && error.message.includes('JWT_SECRET')) {
      return res.status(500).json({ error: 'Authentication service is not configured.' });
    }
    res.status(500).json({ error: 'Unable to authenticate with Apple. Please try again later.' });
  }
};

const verifyEmail = async (req, res) => {
  try {
    const { code } = req.body;
    const { email } = req.query;

    if (!email) {
      return res.status(400).json({ error: 'Email is required in query parameters.' });
    }

    if (!code) {
      return res.status(400).json({ error: 'Code is required.' });
    }

    const result = await findAccountByEmail(email);
    if (!result) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const record = await VerificationCode.findOne({ 
      email: email.toLowerCase(),
      purpose: 'email_verification'
    });
    if (!record) {
      return res.status(400).json({ error: 'No verification code found for this email.' });
    }

    if (dayjs(record.expiresAt).isBefore(dayjs())) {
      await VerificationCode.deleteOne({ email: email.toLowerCase() });
      return res.status(410).json({ error: 'Verification code expired. Please request a new code.' });
    }

    // v23.1 part 133 — Phase 7 audit P7-7 : record.code = hash SHA-256,
    // on compare via timingSafeEqual.
    if (!compareCode(code, record.code)) {
      return res.status(400).json({ error: 'Invalid verification code.' });
    }

    result.account.verified = true;
    await result.account.save();
    await VerificationCode.deleteOne({ email: email.toLowerCase() });

    // Generate JWT token after successful verification
    const token = signAuthToken({ id: result.account._id.toString(), role: result.role });

    res.json({
      message: 'Email verified successfully.',
      role: result.role,
      token,
      user: sanitizeUser(result.account, { includeEmail: true }),
    });
  } catch (error) {
    logger.error('Verification error', error);
    res.status(500).json({ error: 'Unable to verify email. Please try again later.' });
  }
};

const resendVerificationCode = async (req, res) => {
  try {
    const { email } = req.query;

    if (!email) {
      return res.status(400).json({ error: 'Email is required in query parameters.' });
    }

    const result = await findAccountByEmail(email);
    if (!result) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const verificationCode = generateVerificationCode();
    await VerificationCode.findOneAndUpdate(
      { email: email.toLowerCase(), purpose: 'email_verification' },
      {
        email: email.toLowerCase(),
        code: hashCode(verificationCode),
        expiresAt: dayjs().add(10, 'minute').toDate(),
        purpose: 'email_verification',
        verified: false,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    try {
      await sendVerificationEmail(email.toLowerCase(), verificationCode);
    } catch (emailError) {
      logger.error('Failed to resend verification email', emailError);
    }

    // v23.1 part 127 — Phase 3 audit P3-2 : idem signup, le code reste
    // côté email seulement.
    res.json({ message: 'Verification code resent.' });
  } catch (error) {
    logger.error('Resend code error', error);
    res.status(500).json({ error: 'Unable to resend verification code. Please try again later.' });
  }
};

const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ error: 'Email is required.' });
    }

    const result = await findAccountByEmail(email);
    if (!result) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const resetCode = generateVerificationCode();
    await VerificationCode.findOneAndUpdate(
      { email: email.toLowerCase() },
      {
        email: email.toLowerCase(),
        code: hashCode(resetCode),
        expiresAt: dayjs().add(10, 'minute').toDate(),
        purpose: 'password_reset',
        verified: false, // Reset verified status when new code is generated
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    try {
      await sendPasswordResetEmail(email.toLowerCase(), resetCode);
    } catch (emailError) {
      logger.error('Failed to send password reset email', emailError);
    }

    res.json({ message: 'Password reset code sent to email.' });
  } catch (error) {
    logger.error('Forgot password error', error);
    res.status(500).json({ error: 'Unable to process request. Please try again later.' });
  }
};

/**
 * Verify password reset OTP (Step 2)
 * POST /auth/verify-password-reset-otp
 */
const verifyPasswordResetOtp = async (req, res) => {
  try {
    const { email, code } = req.body;

    if (!email || !code) {
      return res.status(400).json({ error: 'Email and code are required.' });
    }

    const result = await findAccountByEmail(email);
    if (!result) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const record = await VerificationCode.findOne({ 
      email: email.toLowerCase(),
      purpose: 'password_reset'
    });
    
    if (!record) {
      return res.status(400).json({ error: 'No password reset code found for this email. Please request a new code.' });
    }

    if (dayjs(record.expiresAt).isBefore(dayjs())) {
      await VerificationCode.deleteOne({ email: email.toLowerCase() });
      return res.status(410).json({ error: 'Reset code expired. Please request a new code.' });
    }

    // v23.1 part 133 — Phase 7 audit P7-7 : record.code = hash SHA-256,
    // on compare via timingSafeEqual.
    if (!compareCode(code, record.code)) {
      return res.status(400).json({ error: 'Invalid reset code.' });
    }

    // Mark OTP as verified
    record.verified = true;
    await record.save();

    res.json({ 
      message: 'OTP verified successfully. You can now reset your password.',
      verified: true
    });
  } catch (error) {
    logger.error('Verify password reset OTP error', error);
    res.status(500).json({ error: 'Unable to verify OTP. Please try again later.' });
  }
};

/**
 * Reset password (Step 3) - requires verified OTP
 * POST /auth/reset-password
 */
const resetPassword = async (req, res) => {
  try {
    const { email, newPassword } = req.body;

    if (!email || !newPassword) {
      return res.status(400).json({ error: 'Email and newPassword are required.' });
    }

    const result = await findAccountByEmail(email);
    if (!result) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const record = await VerificationCode.findOne({ 
      email: email.toLowerCase(),
      purpose: 'password_reset'
    });
    
    if (!record) {
      return res.status(400).json({ error: 'No password reset code found for this email. Please request a new code.' });
    }

    // Check if OTP is verified
    if (!record.verified) {
      return res.status(400).json({ 
        error: 'OTP not verified. Please verify the OTP first using /auth/verify-password-reset-otp' 
      });
    }

    if (dayjs(record.expiresAt).isBefore(dayjs())) {
      await VerificationCode.deleteOne({ email: email.toLowerCase() });
      return res.status(410).json({ error: 'Reset code expired. Please request a new code.' });
    }

    // Reset password
    result.account.password = newPassword;
    await result.account.save();
    
    // Delete the verification code after successful password reset
    await VerificationCode.deleteOne({ email: email.toLowerCase() });

    res.json({ message: 'Password reset successful.' });
  } catch (error) {
    logger.error('Reset password error', error);
    res.status(500).json({ error: 'Unable to reset password. Please try again later.' });
  }
};

const changePassword = async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;
    const { newPassword, confirmPassword } = req.body || {};

    if (!userId || !role) {
      return res.status(403).json({ error: 'Authentication context missing.' });
    }

    if (!newPassword || !confirmPassword) {
      return res.status(400).json({ error: 'newPassword and confirmPassword are required.' });
    }

    if (typeof newPassword !== 'string' || newPassword.length < 8) {
      return res.status(400).json({ error: 'New password must be at least 8 characters long.' });
    }

    if (newPassword !== confirmPassword) {
      return res.status(400).json({ error: 'Passwords do not match.' });
    }

    // 3-role aware model dispatch.
    const Model = { owner: Owner, sitter: Sitter, walker: Walker }[role] || Owner;
    const account = await Model.findById(userId);

    if (!account) {
      return res.status(404).json({ error: 'User not found.' });
    }

    account.password = newPassword;
    await account.save();

    res.json({ message: 'Password updated successfully.' });
  } catch (error) {
    logger.error('Change password error', error);
    res.status(500).json({ error: 'Unable to change password. Please try again later.' });
  }
};

const chooseService = async (req, res) => {
  try {
    const { email } = req.query;
    const { service } = req.body || {};

    if (!email) {
      return res.status(400).json({ error: 'Email is required in query parameters.' });
    }

    const rawServices = Array.isArray(service) ? service : service != null ? [service] : [];
    const normalizedServices = rawServices
      .map((s) => (typeof s === 'string' ? s.trim() : typeof s === 'number' ? String(s).trim() : ''))
      .filter(Boolean);

    if (normalizedServices.length === 0) {
      return res.status(400).json({ error: 'Service is required (array of service names).' });
    }

    const result = await findAccountByEmail(email);
    if (!result) {
      return res.status(404).json({ error: 'User not found.' });
    }

    // Session v15 — all 3 roles can now pick any combination of the 4 generic
    // services (Pet Sitting, House Sitting, Day Care, Long Stay) plus Dog
    // Walking. Previously Owners and Walkers were silently stripped of Dog
    // Walking which made ChooseServiceScreen reject their full selection.
    const allowedServices = SITTER_SERVICES;
    const invalid = normalizedServices.filter((s) => !allowedServices.includes(s));
    if (invalid.length > 0) {
      return res.status(400).json({
        error: `Invalid service(s): ${invalid.join(', ')}. Allowed: ${allowedServices.join(', ')}.`,
      });
    }

    result.account.service = normalizedServices;
    await result.account.save();

    res.json({
      message: 'Service updated successfully.',
      role: result.role,
      user: sanitizeUser(result.account, { includeEmail: true }),
    });
  } catch (error) {
    logger.error('Choose service error', error);
    res.status(500).json({ error: 'Unable to update service. Please try again later.' });
  }
};

const adminLogin = async (req, res) => {
  // v23.1 part 128 — Phase 4 audit P4-2 :
  //   AVANT : tout le `debug` (steps, hash length, env presence, stack)
  //   était renvoyé au CLIENT, même en prod → info disclosure très utile
  //   pour un attaquant qui prépare son brute-force.
  //   MAINTENANT : on log côté server (logger.warn) ; le client reçoit
  //   uniquement les messages génériques. Le debug détaillé n'apparaît
  //   dans la réponse QU'EN DEV (NODE_ENV !== 'production').
  const isDev = process.env.NODE_ENV !== 'production';
  const debug = { steps: [] };
  const _debugBody = (extra) => (isDev ? { debug: { ...debug, ...extra } } : {});

  try {
    debug.steps.push('parse-body');
    const { email, password } = req.body || {};
    if (!email || !password) {
      logger.warn('[adminLogin] missing fields', {
        missingEmail: !email,
        missingPassword: !password,
      });
      return res.status(400).json({
        error: 'Email and password are required.',
        ..._debugBody({ missingEmail: !email, missingPassword: !password }),
      });
    }

    debug.steps.push('find-admin');
    const lowered = String(email).toLowerCase().trim();
    // v535 — demande de Daniel : le tableau de bord admin n'est accessible
    // QU'AVEC hopetsit@gmail.com. Liste blanche appliquée AVANT toute
    // recherche en base : même si un autre document Admin existait (seed
    // historique, insertion manuelle), il ne peut plus se connecter.
    // Surchargeable par ADMIN_ALLOWED_EMAIL sur Render si l'adresse change.
    const allowedAdmin = String(process.env.ADMIN_ALLOWED_EMAIL || 'hopetsit@gmail.com')
      .toLowerCase().trim();
    if (lowered !== allowedAdmin) {
      logger.warn('[adminLogin] email hors liste blanche', { email: lowered });
      return res.status(401).json({ error: 'Invalid admin credentials.' });
    }
    const admin = await Admin.findOne({ email: lowered });
    if (!admin) {
      logger.warn('[adminLogin] admin_not_found', { email: lowered });
      return res.status(401).json({
        error: 'Invalid admin credentials.',
        ..._debugBody({ reason: 'admin_not_found', emailLooked: lowered }),
      });
    }

    debug.steps.push('verify-password');
    let ok = false;
    try {
      ok = await admin.verifyPassword(password);
    } catch (e) {
      logger.error('[adminLogin] verifyPassword threw', e);
      return res.status(500).json({
        error: 'Admin login failed.',
        ..._debugBody({ reason: 'verifyPassword_threw', message: e.message }),
      });
    }

    if (!ok) {
      logger.warn('[adminLogin] wrong_password', { email: lowered });
      return res.status(401).json({
        error: 'Invalid admin credentials.',
        ..._debugBody({ reason: 'wrong_password' }),
      });
    }

    debug.steps.push('sign-token');
    const token = signAuthToken({ id: admin._id.toString(), role: 'admin' });
    return res.json({
      role: 'admin',
      token,
      admin: { id: admin._id, email: admin.email, name: admin.name },
    });
  } catch (error) {
    logger.error('adminLogin error', error);
    return res.status(500).json({
      error: 'Admin login failed.',
      ..._debugBody({ fatal: error.message }),
    });
  }
};

/**
 * POST /auth/refresh — v23.1.254
 *
 * Daniel : "confort total" — l'utilisateur actif ne doit JAMAIS voir
 * "Session expirée". Refresh à expiration glissante : `requireAuth` garantit
 * que le token actuel est encore valide, on en ré-émet un neuf (365j) avec
 * le même {id, role}. L'app l'appelle silencieusement au démarrage et au
 * retour de background → tant que l'app est ouverte au moins 1x/an, le
 * token ne périme jamais. Aucune donnée sensible requise (pas de mot de
 * passe) : on s'appuie uniquement sur le token déjà validé.
 */
const refreshToken = async (req, res) => {
  try {
    if (!req.user || !req.user.id || !req.user.role) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    const token = signAuthToken({
      id: String(req.user.id),
      role: String(req.user.role),
    });
    return res.json({ token, role: req.user.role });
  } catch (error) {
    logger.error('refreshToken error', error);
    if (error.message && error.message.includes('JWT_SECRET')) {
      return res
        .status(500)
        .json({ error: 'Authentication service is not configured.' });
    }
    return res
      .status(500)
      .json({ error: 'Unable to refresh session. Please try again later.' });
  }
};

module.exports = {
  signup,
  login,
  refreshToken,
  verifyEmail,
  resendVerificationCode,
  forgotPassword,
  verifyPasswordResetOtp,
  resetPassword,
  changePassword,
  chooseService,
  googleAuth,
  appleAuth,
  adminLogin,
  signAuthToken,
};

