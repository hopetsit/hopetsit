import sys

with open('/tmp/uc.js', 'r') as f:
    uc = f.read()

old = """    } else if (targetRole === 'walker') {
      // Walker-specific defaults for a fresh role.
      newUserData.service = Array.isArray(userData.service) && userData.service.length
        ? userData.service
        : ['dog_walking'];
      newUserData.rating = 0;
      newUserData.reviewsCount = 0;
      newUserData.feedback = [];
      newUserData.acceptedPetTypes = ['dog_small', 'dog_medium', 'dog_large'];
      newUserData.maxPetsPerWalk = 1;
      newUserData.hasInsurance = false;
      newUserData.coverageCity = (originalLocation?.city || '').toString();
      newUserData.coverageRadiusKm = 3;
      newUserData.walkRates = [];
      newUserData.defaultWalkDurationMinutes = 30;
      newUserData.stripeConnectAccountId = null;
      newUserData.stripeConnectAccountStatus = 'not_connected';
    }"""

new = """    } else if (targetRole === 'walker') {
      // Walker-specific defaults for a fresh role.
      newUserData.service = Array.isArray(userData.service) && userData.service.length
        ? userData.service
        : ['dog_walking'];
      newUserData.rating = 0;
      newUserData.reviewsCount = 0;
      newUserData.feedback = [];
      newUserData.acceptedPetTypes = ['dog_small', 'dog_medium', 'dog_large'];
      newUserData.maxPetsPerWalk = 1;
      newUserData.hasInsurance = false;
      newUserData.coverageCity = (originalLocation?.city || '').toString();
      newUserData.coverageRadiusKm = 3;
      newUserData.walkRates = [];
      newUserData.defaultWalkDurationMinutes = 30;
      newUserData.stripeConnectAccountId = null;
      newUserData.stripeConnectAccountStatus = 'not_connected';
    } else if (targetRole === 'owner') {
      // Session v16.3 - explicit owner defaults. Because we use
      // `collection.insertOne()` at line ~875 (to bypass the location
      // default that breaks the 2dsphere index), Mongoose defaults are
      // NOT applied. Without this block, switching walker -> owner left
      // the Owner document missing required nested structures like
      // `servicePreferences`, which broke downstream reads and is the
      // root cause of the "Impossible de changer de role" error when
      // going directly walker -> owner (the walker -> sitter -> owner
      // path worked because the intermediate Sitter save rebuilt the
      // needed defaults).
      newUserData.servicePreferences = {
        atOwner: true,
        atSitter: false,
      };
      newUserData.isPremium = false;
      newUserData.status = 'active';
      newUserData.boostExpiry = null;
      newUserData.boostTier = null;
      newUserData.boostPurchases = [];
      newUserData.mapBoostExpiry = null;
      newUserData.mapBoostTier = null;
      newUserData.fcmTokens = Array.isArray(userData.fcmTokens)
        ? userData.fcmTokens
        : [];
      newUserData.termsAcceptedAt = userData.termsAcceptedAt || null;
      newUserData.termsVersion = userData.termsVersion || '';
      newUserData.referredBy = userData.referredBy || '';
      // Owner-side `service` list is conceptually "what services the owner
      // NEEDS for their pet" (legacy OWNER_SERVICES), not what they offer.
      // Clear any walker/sitter-provider values like 'dog_walking' that
      // would be meaningless on an Owner document.
      newUserData.service = [];
    }"""

if old not in uc:
    sys.exit('pattern not found in userController.js')
uc_new = uc.replace(old, new, 1)
out = '/sessions/relaxed-jolly-pasteur/mnt/HopeTSIT_FINAL_FIXED/HopeTSIT_FINAL/backend/src/controllers/userController.js'
with open(out, 'w') as f:
    f.write(uc_new)
print('userController.js written,', len(uc_new), 'bytes')
