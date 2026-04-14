/**
 * HOPETSIT - PRICING & COMMISSION POLICY SEED DATA
 * 
 * This script seeds the database with pricing data according to client requirements:
 * - Sitters with location types (standard/large_city)
 * - Sitters with custom pricing for each service type
 * - Example bookings with complete pricing breakdown
 * - All following the exact pricing structure from client document
 */

require('dotenv').config();
const mongoose = require('mongoose');

const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Booking = require('../models/Booking');
const {
  calculateTotalWithAddOns,
  getRecommendedPriceRange,
  SERVICE_TYPES,
  LOCATION_TYPES,
} = require('../utils/pricing');
const { DEFAULT_CURRENCY } = require('../utils/currency');
const logger = require('../utils/logger');

const MONGODB_URI = process.env.MONGODB_URI;

/**
 * Seed sitters with pricing data
 */
async function seedSitters() {
  logger.info('🌱 Seeding sitters with pricing data...');

  // Find or create sitters with different location types and pricing
  const sittersData = [
    {
      // Standard area sitter - Home Visit pricing within recommended range
      email: 'sitter.standard@hopetsit.com',
      name: 'Emma Johnson',
      password: 'Password123!',
      mobile: '+1234567890',
      location: {
        city: 'Springfield',
        locationType: LOCATION_TYPES.STANDARD,
      },
      servicePricing: {
        homeVisit: {
          basePrice: 12, // Within recommended 10-15€ range
          currency: DEFAULT_CURRENCY,
        },
        dogWalking30: {
          basePrice: 12, // Within recommended 10-15€ range
          currency: DEFAULT_CURRENCY,
        },
        dogWalking60: {
          basePrice: 17, // Within recommended 15-20€ range
          currency: DEFAULT_CURRENCY,
        },
        overnightStay: {
          basePrice: 30, // Within recommended 25-35€ range
          currency: DEFAULT_CURRENCY,
        },
      },
      service: ['Pet Sitting'],
      verified: true,
      acceptedTerms: true,
    },
    {
      // Large city sitter - Home Visit pricing within recommended range
      email: 'sitter.largecity@hopetsit.com',
      name: 'Michael Chen',
      password: 'Password123!',
      mobile: '+1234567891',
      location: {
        city: 'New York',
        locationType: LOCATION_TYPES.LARGE_CITY,
      },
      servicePricing: {
        homeVisit: {
          basePrice: 18, // Within recommended 15-20€ range
          currency: DEFAULT_CURRENCY,
        },
        dogWalking30: {
          basePrice: 13, // Within recommended 10-15€ range
          currency: DEFAULT_CURRENCY,
        },
        dogWalking60: {
          basePrice: 18, // Within recommended 15-20€ range
          currency: DEFAULT_CURRENCY,
        },
        overnightStay: {
          basePrice: 40, // Within recommended 30-45€ range
          currency: DEFAULT_CURRENCY,
        },
      },
      service: ['Pet Sitting'],
      verified: true,
      acceptedTerms: true,
    },
    {
      // Standard area sitter - Dog Walking specialist
      email: 'sitter.dogwalker@hopetsit.com',
      name: 'Sarah Williams',
      password: 'Password123!',
      mobile: '+1234567892',
      location: {
        city: 'Portland',
        locationType: LOCATION_TYPES.STANDARD,
      },
      servicePricing: {
        homeVisit: {
          basePrice: 11, // Within recommended 10-15€ range
          currency: DEFAULT_CURRENCY,
        },
        dogWalking30: {
          basePrice: 10, // Minimum of recommended 10-15€ range
          currency: DEFAULT_CURRENCY,
        },
        dogWalking60: {
          basePrice: 15, // Minimum of recommended 15-20€ range
          currency: DEFAULT_CURRENCY,
        },
        overnightStay: {
          basePrice: 28, // Slightly below recommended 25-35€ range (sitter's choice)
          currency: DEFAULT_CURRENCY,
        },
      },
      service: ['Dog Walking'],
      verified: true,
      acceptedTerms: true,
    },
    {
      // Large city sitter - Premium pricing
      email: 'sitter.premium@hopetsit.com',
      name: 'David Martinez',
      password: 'Password123!',
      mobile: '+1234567893',
      location: {
        city: 'London',
        locationType: LOCATION_TYPES.LARGE_CITY,
      },
      servicePricing: {
        homeVisit: {
          basePrice: 20, // Maximum of recommended 15-20€ range
          currency: DEFAULT_CURRENCY,
        },
        dogWalking30: {
          basePrice: 15, // Maximum of recommended 10-15€ range
          currency: DEFAULT_CURRENCY,
        },
        dogWalking60: {
          basePrice: 20, // Maximum of recommended 15-20€ range
          currency: DEFAULT_CURRENCY,
        },
        overnightStay: {
          basePrice: 45, // Maximum of recommended 30-45€ range
          currency: DEFAULT_CURRENCY,
        },
      },
      service: ['Pet Sitting'],
      verified: true,
      acceptedTerms: true,
    },
    {
      // Standard area sitter - Overnight Stay specialist
      email: 'sitter.overnight@hopetsit.com',
      name: 'Lisa Anderson',
      password: 'Password123!',
      mobile: '+1234567894',
      location: {
        city: 'Austin',
        locationType: LOCATION_TYPES.STANDARD,
      },
      servicePricing: {
        homeVisit: {
          basePrice: 13, // Within recommended 10-15€ range
          currency: DEFAULT_CURRENCY,
        },
        dogWalking30: {
          basePrice: 11, // Within recommended 10-15€ range
          currency: DEFAULT_CURRENCY,
        },
        dogWalking60: {
          basePrice: 16, // Within recommended 15-20€ range
          currency: DEFAULT_CURRENCY,
        },
        overnightStay: {
          basePrice: 32, // Within recommended 25-35€ range
          currency: DEFAULT_CURRENCY,
        },
      },
      service: ['House Sitting'],
      verified: true,
      acceptedTerms: true,
    },
  ];

  const seededSitters = [];
  for (const sitterData of sittersData) {
    try {
      let sitter = await Sitter.findOne({ email: sitterData.email });
      if (sitter) {
        // Update existing sitter with pricing data
        sitter.location = sitterData.location;
        sitter.servicePricing = sitterData.servicePricing;
        sitter.service = Array.isArray(sitterData.service) ? sitterData.service : (sitterData.service ? [sitterData.service] : []);
        await sitter.save();
        logger.info(`✅ Updated sitter: ${sitterData.name}`);
      } else {
        // Create new sitter
        sitter = await Sitter.create(sitterData);
        logger.info(`✅ Created sitter: ${sitterData.name}`);
      }
      seededSitters.push(sitter);
    } catch (error) {
      logger.error(`❌ Error seeding sitter ${sitterData.name}:`, error.message);
    }
  }

  return seededSitters;
}

/**
 * Seed bookings with complete pricing breakdown
 */
async function seedBookings(sitters, owners) {
  logger.info('🌱 Seeding bookings with pricing data...');

  if (sitters.length === 0 || owners.length === 0) {
    logger.info('⚠️  No sitters or owners available. Skipping booking seed.');
    return;
  }

  const bookingsData = [
    {
      // Home Visit booking - Standard area - With add-ons
      owner: owners[0],
      sitter: sitters[0], // Standard area sitter
      petName: 'Max',
      description: 'Need someone to feed and check on Max',
      date: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString().split('T')[0], // 2 days from now
      timeSlot: '14:00',
      serviceType: SERVICE_TYPES.HOME_VISIT,
      duration: 45,
      locationType: LOCATION_TYPES.STANDARD,
      basePrice: 12,
      addOns: [
        {
          type: 'extraAnimals',
          description: 'Extra animal care',
          amount: 4,
          currency: DEFAULT_CURRENCY,
        },
        {
          type: 'medicationSpecialCare',
          description: 'Medication administration',
          amount: 5,
          currency: DEFAULT_CURRENCY,
        },
      ],
      status: 'accepted',
    },
    {
      // Dog Walking booking - Large city - 30 minutes
      owner: owners[0],
      sitter: sitters[1], // Large city sitter
      petName: 'Bella',
      description: 'Daily walk for Bella',
      date: new Date(Date.now() + 1 * 24 * 60 * 60 * 1000).toISOString().split('T')[0], // Tomorrow
      timeSlot: '09:00',
      serviceType: SERVICE_TYPES.DOG_WALKING,
      duration: 30,
      locationType: LOCATION_TYPES.LARGE_CITY,
      basePrice: 13,
      addOns: [],
      status: 'pending',
    },
    {
      // Dog Walking booking - Standard area - 60 minutes with late evening add-on
      owner: owners[0],
      sitter: sitters[2], // Dog walking specialist
      petName: 'Charlie',
      description: 'Evening walk for Charlie',
      date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString().split('T')[0], // 3 days from now
      timeSlot: '21:30',
      serviceType: SERVICE_TYPES.DOG_WALKING,
      duration: 60,
      locationType: LOCATION_TYPES.STANDARD,
      basePrice: 15,
      addOns: [
        {
          type: 'lateEveningWalk',
          description: 'Late evening walk (after 21:00)',
          amount: 4,
          currency: DEFAULT_CURRENCY,
        },
      ],
      status: 'accepted',
    },
    {
      // Overnight Stay booking - Large city
      owner: owners[0],
      sitter: sitters[1], // Large city sitter
      petName: 'Luna',
      description: 'Overnight care for Luna',
      date: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString().split('T')[0], // 5 days from now
      timeSlot: '18:00',
      serviceType: SERVICE_TYPES.OVERNIGHT_STAY,
      duration: 1, // 1 night
      locationType: LOCATION_TYPES.LARGE_CITY,
      basePrice: 40,
      addOns: [],
      status: 'pending',
    },
    {
      // Home Visit booking - Large city - Premium pricing
      owner: owners[0],
      sitter: sitters[3], // Premium sitter
      petName: 'Rocky',
      description: 'Premium home visit service',
      date: new Date(Date.now() + 4 * 24 * 60 * 60 * 1000).toISOString().split('T')[0], // 4 days from now
      timeSlot: '16:00',
      serviceType: SERVICE_TYPES.HOME_VISIT,
      duration: 45,
      locationType: LOCATION_TYPES.LARGE_CITY,
      basePrice: 20,
      addOns: [
        {
          type: 'extraAnimals',
          description: 'Extra animal care',
          amount: 5,
          currency: DEFAULT_CURRENCY,
        },
      ],
      status: 'accepted',
    },
    {
      // Overnight Stay booking - Standard area
      owner: owners[0],
      sitter: sitters[4], // Overnight specialist
      petName: 'Milo',
      description: 'Overnight boarding',
      date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0], // 7 days from now
      timeSlot: '17:00',
      serviceType: SERVICE_TYPES.OVERNIGHT_STAY,
      duration: 2, // 2 nights
      locationType: LOCATION_TYPES.STANDARD,
      basePrice: 32,
      addOns: [],
      status: 'pending',
    },
  ];

  const seededBookings = [];
  for (const bookingData of bookingsData) {
    try {
      // Get recommended price range for reference
      let recommendedRange = null;
      try {
        const recommended = getRecommendedPriceRange(
          bookingData.serviceType,
          bookingData.locationType,
          bookingData.serviceType === SERVICE_TYPES.DOG_WALKING ? bookingData.duration : null
        );
        recommendedRange = {
          min: recommended.min,
          max: recommended.max,
          currency: recommended.currency,
        };
      } catch (error) {
        logger.error('Error getting recommended range:', error.message);
      }

      // Calculate pricing breakdown with commission
      const pricingBreakdown = calculateTotalWithAddOns(bookingData.basePrice, bookingData.addOns);

      const booking = await Booking.create({
        ownerId: bookingData.owner._id,
        sitterId: bookingData.sitter._id,
        petName: bookingData.petName,
        description: bookingData.description,
        date: bookingData.date,
        timeSlot: bookingData.timeSlot,
        serviceType: bookingData.serviceType,
        duration: bookingData.duration,
        locationType: bookingData.locationType,
        pricing: {
          basePrice: pricingBreakdown.basePrice,
          addOns: pricingBreakdown.addOns || [],
          addOnsTotal: pricingBreakdown.addOnsTotal || 0,
          totalPrice: pricingBreakdown.totalPrice,
          commission: pricingBreakdown.commission,
          netPayout: pricingBreakdown.netPayout,
          commissionRate: pricingBreakdown.commissionRate,
          currency: pricingBreakdown.currency,
        },
        recommendedPriceRange: recommendedRange,
        status: bookingData.status,
      });

      logger.info(`✅ Created booking: ${bookingData.petName} - ${bookingData.serviceType} - Total: ${pricingBreakdown.totalPrice}€ (Commission: ${pricingBreakdown.commission}€, Payout: ${pricingBreakdown.netPayout}€)`);
      seededBookings.push(booking);
    } catch (error) {
      logger.error(`❌ Error seeding booking for ${bookingData.petName}:`, error.message);
    }
  }

  return seededBookings;
}

/**
 * Main seed function
 */
async function seedDatabase() {
  try {
    logger.info('🔌 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    logger.info('✅ Connected to MongoDB');

    // Clear existing pricing-related data (optional - comment out if you want to keep existing data)
    // await Booking.deleteMany({});
    // await Sitter.updateMany({}, { $unset: { location: '', servicePricing: '' } });

    // Get or create a test owner
    let owner = await Owner.findOne({ email: 'owner.test@hopetsit.com' });
    if (!owner) {
      owner = await Owner.create({
        name: 'Test Owner',
        email: 'owner.test@hopetsit.com',
        password: 'Password123!',
        verified: true,
        acceptedTerms: true,
      });
      logger.info('✅ Created test owner');
    } else {
      logger.info('✅ Using existing test owner');
    }

    // Seed sitters
    const sitters = await seedSitters();

    // Seed bookings
    const bookings = await seedBookings(sitters, [owner]);

    logger.info('\n📊 Seed Summary:');
    logger.info(`   - Sitters seeded: ${sitters.length}`);
    logger.info(`   - Bookings seeded: ${bookings.length}`);
    logger.info('\n✅ Database seeding completed successfully!');
    logger.info('\n💡 Pricing Structure:');
    logger.info('   - Platform Commission: 20%');
    logger.info('   - Service Types: home_visit, dog_walking, overnight_stay, long_stay');
    logger.info('   - Location Types: standard, large_city');
    logger.info('   - All pricing follows client requirements exactly');

    await mongoose.connection.close();
    logger.info('\n🔌 Database connection closed');
    process.exit(0);
  } catch (error) {
    logger.error('❌ Error seeding database:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

// Run seed if called directly
if (require.main === module) {
  seedDatabase();
}

module.exports = { seedDatabase };

