import sys
path = '/sessions/relaxed-jolly-pasteur/mnt/HopeTSIT_FINAL_FIXED/HopeTSIT_FINAL/backend/src/controllers/applicationController.js'
with open(path, 'r') as f:
    content = f.read()

# 1. Fix populate calls (ownerId + sitterId) to include walkerId
old_pop = "Application.findById(id).populate('ownerId').populate('sitterId');"
new_pop = "Application.findById(id).populate('ownerId').populate('sitterId').populate('walkerId');"
pop_count = content.count(old_pop)
content = content.replace(old_pop, new_pop)
print(f'Populate fix: {pop_count} replaced')

# 2. Fix appSitterId check to support walker
old_check = """    const appSitterId = application.sitterId?._id
      ? application.sitterId._id.toString()
      : application.sitterId.toString();
    if (appSitterId !== sitterId) {"""
new_check = """    // Session v16.3c - support walker cancellation too.
    const providerDoc = application.sitterId || application.walkerId;
    if (!providerDoc) {
      return res.status(404).json({ error: 'Application has no provider reference.' });
    }
    const appSitterId = providerDoc._id
      ? providerDoc._id.toString()
      : providerDoc.toString();
    if (appSitterId !== sitterId) {"""

if old_check in content:
    content = content.replace(old_check, new_check, 1)
    print('appSitterId check: applied')
else:
    # Show what's at lines 79-87
    lines = content.split('\n')
    for i in range(78, 88):
        safe = lines[i].replace('!', '<BANG>')
        print(f'L{i+1}: {safe!r}')
    sys.exit('pattern not found')

with open(path, 'w') as f:
    f.write(content)
print(f'Total size: {len(content)} bytes')
