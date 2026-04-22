import sys, subprocess

REPO = '/sessions/relaxed-jolly-pasteur/mnt/HopeTSIT_FINAL_FIXED/HopeTSIT_FINAL'

def head(path):
    return subprocess.check_output(
        ['git', 'show', f'HEAD:{path}'], cwd=REPO, encoding='utf-8'
    )

def write(path, content):
    with open(f'{REPO}/{path}', 'w') as f:
        f.write(content)

# ============ 1. Application.js model ============
am_path = 'backend/src/models/Application.js'
am = head(am_path)

old_sitter = "    sitterId: { type: mongoose.Schema.Types.ObjectId, ref: 'Sitter', required: true },"
new_provider = """    // Session v16.3b - support both sitter and walker applications.
    // Exactly ONE of sitterId/walkerId must be set (enforced by pre-validate).
    sitterId: { type: mongoose.Schema.Types.ObjectId, ref: 'Sitter', default: null },
    walkerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Walker', default: null },"""

if old_sitter not in am:
    sys.exit('Application.js sitterId pattern not found')
am = am.replace(old_sitter, new_provider, 1)

# Add pre-validate hook before module.exports
old_index = "applicationSchema.index({ ownerId: 1, sitterId: 1, status: 1, requestFingerprint: 1 });"
new_index = """applicationSchema.index({ ownerId: 1, sitterId: 1, status: 1, requestFingerprint: 1 });
applicationSchema.index({ ownerId: 1, walkerId: 1, status: 1, requestFingerprint: 1 });

// Session v16.3b - require exactly one of sitterId / walkerId.
applicationSchema.pre('validate', function enforceExactlyOneProvider(next) {
  const hasSitter = !!this.sitterId;
  const hasWalker = !!this.walkerId;
  if (hasSitter === hasWalker) {
    return next(new Error('Application must reference exactly one of sitterId or walkerId.'));
  }
  next();
});"""

if old_index not in am:
    sys.exit('Application.js index pattern not found')
am = am.replace(old_index, new_index, 1)
write(am_path, am)
print(f'Application.js: OK ({len(am)} bytes)')

# ============ 2. applicationController.js createApplication + helpers ============
ac_path = 'backend/src/controllers/applicationController.js'
ac = head(ac_path)

# Replace the core of createApplication: role detection + provider lookup + rate check
# Match from "const sitter = await Sitter.findById(sitterId);" to end of rate check
old_core = """    const sitter = await Sitter.findById(sitterId);
    if (!sitter) {
      return res.status(404).json({ error: 'Sitter not found.' });
    }

    // Ensure sitter has configured an hourly rate before sending applications
    if (!sitter.hourlyRate || sitter.hourlyRate <= 0) {
      return res.status(400).json({
        error: 'You must set your hourly rate before sending requests to owners.',
        details: 'Update your profile with a non-zero hourly rate and try again.',
      });
    }"""

new_core = """    // Session v16.3b - support BOTH sitter and walker applications. The
    // previous implementation assumed req.user was always a sitter, which
    // made walkers get a 404 when they tried to apply to an owner's post.
    // We also relax the rate check: sitters can now configure daily/weekly/
    // monthly instead of hourly (v15-6 flexible rates), so we accept ANY
    // non-zero rate. Walkers have their own `walkRates` array.
    const providerRole = req.user?.role;
    let provider = null;
    if (providerRole === 'walker') {
      const Walker = require('../models/Walker');
      provider = await Walker.findById(sitterId);
      if (!provider) {
        return res.status(404).json({ error: 'Walker not found.' });
      }
      // Derive an hourly equivalent from walkRates (same precedence as
      // bookingController): 60-min direct, else 30x2, else 90*(60/90), else 120/2.
      const findWalkRate = (min) => {
        const rate = (provider.walkRates || []).find(
          (r) => r.durationMinutes === min && r.enabled && r.basePrice > 0,
        );
        return rate ? rate.basePrice : null;
      };
      let derivedHourly = findWalkRate(60);
      if (!derivedHourly) {
        const half = findWalkRate(30);
        if (half) derivedHourly = half * 2;
      }
      if (!derivedHourly) {
        const ninety = findWalkRate(90);
        if (ninety) derivedHourly = ninety * (60 / 90);
      }
      if (!derivedHourly) {
        const twoHours = findWalkRate(120);
        if (twoHours) derivedHourly = twoHours / 2;
      }
      if (!derivedHourly || derivedHourly <= 0) {
        return res.status(400).json({
          error: 'You must set at least one walk rate before sending requests to owners.',
          details: 'Open your profile and set a price for 30 min or 60 min walks.',
        });
      }
      // Sitter-shim so the downstream pricing code keeps working.
      provider.hourlyRate = derivedHourly;
    } else {
      // Default sitter path.
      provider = await Sitter.findById(sitterId);
      if (!provider) {
        return res.status(404).json({ error: 'Sitter not found.' });
      }
      const hasAnyRate =
        (provider.hourlyRate && provider.hourlyRate > 0) ||
        (provider.dailyRate && provider.dailyRate > 0) ||
        (provider.weeklyRate && provider.weeklyRate > 0) ||
        (provider.monthlyRate && provider.monthlyRate > 0);
      if (!hasAnyRate) {
        return res.status(400).json({
          error: 'You must set at least one rate (hourly, daily, weekly or monthly) before sending requests to owners.',
          details: 'Update your profile with a non-zero rate and try again.',
        });
      }
      // Derive hourly fallback from the most specific rate available so
      // downstream tier math works (matches bookingController behavior).
      if (!provider.hourlyRate || provider.hourlyRate <= 0) {
        if (provider.dailyRate && provider.dailyRate > 0) {
          provider.hourlyRate = provider.dailyRate / 8;
        } else if (provider.weeklyRate && provider.weeklyRate > 0) {
          provider.hourlyRate = provider.weeklyRate / 56;
        } else if (provider.monthlyRate && provider.monthlyRate > 0) {
          provider.hourlyRate = provider.monthlyRate / 240;
        }
      }
    }
    // Alias so the existing code below reading `sitter.*` keeps working.
    const sitter = provider;"""

if old_core not in ac:
    sys.exit('applicationController core pattern not found')
ac = ac.replace(old_core, new_core, 1)

# Replace Application.create({sitterId, ...}) to store the right provider field
old_create = """    const application = await Application.create({
      sitterId,
      ownerId,"""

new_create = """    const application = await Application.create({
      // Session v16.3b - route to the correct provider field based on role.
      sitterId: providerRole === 'walker' ? null : sitterId,
      walkerId: providerRole === 'walker' ? sitterId : null,
      ownerId,"""

if old_create not in ac:
    sys.exit('applicationController create() pattern not found')
ac = ac.replace(old_create, new_create, 1)

# Fix notification actorRole (hardcoded 'sitter')
old_notif = """    await createNotificationSafe({
      recipientRole: 'owner',
      recipientId: ownerId,
      actorRole: 'sitter',
      actorId: sitterId,
      type: 'application_new',
      title: 'New request',
      body: trimmedDescription || 'A sitter sent you a request.',
      data: {
        applicationId: application._id.toString(),
        sitterId: sitterId.toString(),
      },
    });"""

new_notif = """    await createNotificationSafe({
      recipientRole: 'owner',
      recipientId: ownerId,
      // Session v16.3b - use the real provider role so the in-app notif
      // reaches the right bell and the actor shows the correct collection.
      actorRole: providerRole === 'walker' ? 'walker' : 'sitter',
      actorId: sitterId,
      type: 'application_new',
      title: 'New request',
      body: trimmedDescription || 'A pet-care provider sent you a request.',
      data: {
        applicationId: application._id.toString(),
        providerRole: providerRole === 'walker' ? 'walker' : 'sitter',
        providerId: sitterId.toString(),
      },
    });"""

if old_notif not in ac:
    sys.exit('applicationController notif pattern not found')
ac = ac.replace(old_notif, new_notif, 1)

# Update populate on the application for walker (add walkerId)
old_populate1 = "    await application.populate(['ownerId', 'sitterId']);"
new_populate1 = "    await application.populate(['ownerId', 'sitterId', 'walkerId']);"
ac = ac.replace(old_populate1, new_populate1)

# Also the duplicate-check needs to account for walker too
old_dupe = """    const duplicatePending = await Application.findOne({
      ownerId,
      sitterId,
      status: 'pending',
      $or: dedupeOr,
    })
      .sort({ createdAt: -1 })
      .populate('ownerId')
      .populate('sitterId');"""

new_dupe = """    const duplicatePending = await Application.findOne({
      ownerId,
      // Session v16.3b - dedupe against the correct provider field.
      ...(providerRole === 'walker'
        ? { walkerId: sitterId }
        : { sitterId }),
      status: 'pending',
      $or: dedupeOr,
    })
      .sort({ createdAt: -1 })
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId');"""

if old_dupe not in ac:
    sys.exit('applicationController dedupe pattern not found')
ac = ac.replace(old_dupe, new_dupe, 1)

# listApplications: support walker filter by user role
old_list = """    // If user is authenticated (from /my endpoint), filter by their role
    if (userId && userRole) {
      if (userRole === 'owner') {
        filter.ownerId = userId;
      } else if (userRole === 'sitter') {
        filter.sitterId = userId;
      }
    } else {"""

new_list = """    // If user is authenticated (from /my endpoint), filter by their role
    if (userId && userRole) {
      if (userRole === 'owner') {
        filter.ownerId = userId;
      } else if (userRole === 'sitter') {
        filter.sitterId = userId;
      } else if (userRole === 'walker') {
        // Session v16.3b - walker-owned applications live under walkerId.
        filter.walkerId = userId;
      }
    } else {"""

if old_list not in ac:
    sys.exit('applicationController list filter pattern not found')
ac = ac.replace(old_list, new_list, 1)

# populate in list too
old_list_pop = """    const applications = await Application.find(filter)
      .sort({ createdAt: -1 })
      .populate('ownerId')
      .populate('sitterId')
      .populate('bookingId');"""

new_list_pop = """    const applications = await Application.find(filter)
      .sort({ createdAt: -1 })
      .populate('ownerId')
      .populate('sitterId')
      .populate('walkerId')
      .populate('bookingId');"""

if old_list_pop not in ac:
    sys.exit('applicationController list populate pattern not found')
ac = ac.replace(old_list_pop, new_list_pop, 1)

write(ac_path, ac)
print(f'applicationController.js: OK ({len(ac)} bytes)')

# ============ 3. sanitize.js - include walkerId in sanitizeApplication ============
sz_path = 'backend/src/utils/sanitize.js'
sz = head(sz_path)

old_sz = """  if (application.sitterId && typeof application.sitterId === 'object' && application.sitterId._id) {
    application.sitter = sanitizeUser(application.sitterId);
    delete application.sitterId;
  }"""

new_sz = """  if (application.sitterId && typeof application.sitterId === 'object' && application.sitterId._id) {
    application.sitter = sanitizeUser(application.sitterId);
    delete application.sitterId;
  }
  // Session v16.3b - expose walker as a first-class field when present.
  if (application.walkerId && typeof application.walkerId === 'object' && application.walkerId._id) {
    application.walker = sanitizeUser(application.walkerId);
    delete application.walkerId;
  }"""

if old_sz not in sz:
    sys.exit('sanitize.js application pattern not found')
sz = sz.replace(old_sz, new_sz, 1)
write(sz_path, sz)
print(f'sanitize.js: OK ({len(sz)} bytes)')

print('\nALL BUG 4 BACKEND EDITS APPLIED')
