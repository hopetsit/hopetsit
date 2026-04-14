# HOPETSIT - Pricing & Commission Seed Data

This seed script populates the database with pricing data according to the client's exact requirements.

## What Gets Seeded

### 1. Sitters with Pricing Data
- **5 example sitters** with different location types and pricing strategies:
  - Standard area sitter (Springfield) - Mid-range pricing
  - Large city sitter (New York) - Higher pricing
  - Dog walking specialist (Portland) - Standard area
  - Premium sitter (London) - Maximum recommended pricing
  - Overnight stay specialist (Austin) - Standard area

### 2. Service Pricing
Each sitter has custom pricing for:
- **Home Visit**: 10-15€ (standard) / 15-20€ (large city)
- **Dog Walking 30min**: 10-15€
- **Dog Walking 60min**: 15-20€
- **Overnight Stay**: 25-35€ (standard) / 30-45€ (large city)

### 3. Example Bookings
- **6 example bookings** with complete pricing breakdown:
  - Home Visit with add-ons (extra animals, medication)
  - Dog Walking 30 minutes
  - Dog Walking 60 minutes with late evening add-on
  - Overnight Stay (large city)
  - Premium Home Visit
  - Overnight Stay (standard area)

### 4. Pricing Breakdown
Each booking includes:
- Base price
- Add-ons (if any)
- Total price (what owner pays)
- Commission (20% of total)
- Net payout (80% to sitter)
- Recommended price range (for reference)

## How to Run

```bash
npm run seed:pricing
```

Or directly:
```bash
node src/scripts/seedPricing.js
```

## Requirements

- MongoDB connection string in `.env` file as `MONGODB_URI`
- Database should be accessible

## What the Script Does

1. Connects to MongoDB
2. Creates/updates test owner (if needed)
3. Seeds 5 sitters with location and pricing data
4. Seeds 6 bookings with complete pricing breakdown
5. All pricing follows client's exact requirements:
   - 20% platform commission
   - Recommended price ranges based on service type, duration, and location
   - Add-ons support (extra animals, medication, late evening walks)

## Pricing Structure (As Per Client)

### Platform Commission
- **Standard Rate**: 20% of booking amount
- **Example**: 20€ booking → 4€ commission → 16€ sitter payout

### Recommended Price Ranges

#### Home Visit (30-45 minutes)
- Standard area: 10-15€
- Large cities: 15-20€
- Add-ons: Extra animals (+3-5€), Medication (+5€)

#### Dog Walking
- 30 minutes: 10-15€
- 60 minutes: 15-20€
- Add-ons: Additional dog (+5€), Late evening (+3-5€)

#### Overnight Stay / Pet Boarding
- Standard area: 25-35€ per night
- Large cities: 30-45€ per night

## Notes

- The script will update existing sitters if they already exist (by email)
- Bookings are created with realistic dates (future dates)
- All prices are in EUR as per client requirements
- Commission is automatically calculated at 20%

