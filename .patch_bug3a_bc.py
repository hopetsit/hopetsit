import sys
BANG = chr(33)
NEQ = BANG + '=='

with open('/tmp/bc.js', 'r') as f:
    bc = f.read()

# Build the accept/reject old/new strings using BANG so we don't trigger bash heredoc expansion
old_accept = (
"    const booking = await Booking.findById(id).populate('ownerId').populate('sitterId').populate('petIds');\n"
"    if (" + BANG + "booking) {\n"
"      return res.status(404).json({ error: 'Booking not found.' });\n"
"    }\n"
"\n"
"    if (booking.status " + NEQ + " 'pending') {\n"
"      return res.status(409).json({ error: `Booking already ${booking.status}.` });\n"
"    }\n"
"\n"
"    if (action === 'accept') {\n"
"      booking.status = 'accepted';\n"
"      booking.acceptedAt = new Date();\n"
"      await booking.save();\n"
"\n"
"      await createNotificationSafe({\n"
"        recipientRole: 'owner',\n"
"        recipientId: booking.ownerId?._id ? booking.ownerId._id.toString() : booking.ownerId.toString(),\n"
"        actorRole: 'sitter',\n"
"        actorId: booking.sitterId?._id ? booking.sitterId._id.toString() : booking.sitterId.toString(),\n"
"        type: 'booking_accepted',\n"
"        title: 'Booking accepted',\n"
"        body: 'Your booking request was accepted.',\n"
"        data: { bookingId: booking._id.toString() },\n"
"      });"
)

new_accept = (
"    const booking = await Booking.findById(id)\n"
"      .populate('ownerId')\n"
"      .populate('sitterId')\n"
"      .populate('walkerId')\n"
"      .populate('petIds');\n"
"    if (" + BANG + "booking) {\n"
"      return res.status(404).json({ error: 'Booking not found.' });\n"
"    }\n"
"\n"
"    if (booking.status " + NEQ + " 'pending') {\n"
"      return res.status(409).json({ error: `Booking already ${booking.status}.` });\n"
"    }\n"
"\n"
"    // Session v16.2 - derive actor info from whichever provider field is set\n"
"    // so walker accept/reject notifications reach the owner correctly.\n"
"    const isWalkerResponder = " + BANG + BANG + "booking.walkerId;\n"
"    const actorRoleForOwnerNotif = isWalkerResponder ? 'walker' : 'sitter';\n"
"    const actorIdForOwnerNotif = isWalkerResponder\n"
"      ? (booking.walkerId?._id ? booking.walkerId._id.toString() : booking.walkerId.toString())\n"
"      : (booking.sitterId?._id ? booking.sitterId._id.toString() : booking.sitterId.toString());\n"
"\n"
"    if (action === 'accept') {\n"
"      booking.status = 'accepted';\n"
"      booking.acceptedAt = new Date();\n"
"      await booking.save();\n"
"\n"
"      await createNotificationSafe({\n"
"        recipientRole: 'owner',\n"
"        recipientId: booking.ownerId?._id ? booking.ownerId._id.toString() : booking.ownerId.toString(),\n"
"        actorRole: actorRoleForOwnerNotif,\n"
"        actorId: actorIdForOwnerNotif,\n"
"        type: 'booking_accepted',\n"
"        title: 'Booking accepted',\n"
"        body: 'Your booking request was accepted.',\n"
"        data: { bookingId: booking._id.toString() },\n"
"      });"
)

if old_accept not in bc:
    print("OLD_ACCEPT not found. Searching for partial match...")
    # Try to locate with first line
    marker = "    if (action === 'accept') {\n      booking.status = 'accepted';"
    idx = bc.find(marker)
    print("action===accept marker at", idx)
    if idx >= 0:
        # Show 800 chars from 400 before marker
        print(repr(bc[max(0,idx-400):idx+400]))
    sys.exit(1)

bc_new = bc.replace(old_accept, new_accept)
if 'isWalkerResponder' not in bc_new:
    sys.exit('accept replace failed')
print('accept path: OK')

# 3a. createBooking notification
old_create = (
"    await createNotificationSafe({\n"
"      recipientRole: 'sitter',\n"
"      recipientId: sitterId,\n"
"      actorRole: 'owner',\n"
"      actorId: ownerId,\n"
"      type: 'booking_new',\n"
"      title: 'New booking request',\n"
"      body: trimmedDescription || 'You received a new booking request.',\n"
"      data: {\n"
"        bookingId: booking._id.toString(),\n"
"        ownerId: ownerId.toString(),\n"
"      },\n"
"    });"
)
new_create = (
"    // Session v16.2 - route the notification to the correct collection\n"
"    // based on providerType. Previously hardcoded to 'sitter', which meant\n"
"    // walker bookings either failed silently (wrong enum) or persisted with\n"
"    // a null recipientId.\n"
"    const notificationRecipientRole =\n"
"      providerType === 'walker' ? 'walker' : 'sitter';\n"
"    const notificationRecipientId =\n"
"      providerType === 'walker' ? providerId : sitterId;\n"
"    await createNotificationSafe({\n"
"      recipientRole: notificationRecipientRole,\n"
"      recipientId: notificationRecipientId,\n"
"      actorRole: 'owner',\n"
"      actorId: ownerId,\n"
"      type: 'booking_new',\n"
"      title: 'New booking request',\n"
"      body: trimmedDescription || 'You received a new booking request.',\n"
"      data: {\n"
"        bookingId: booking._id.toString(),\n"
"        ownerId: ownerId.toString(),\n"
"      },\n"
"    });"
)
if old_create not in bc_new:
    sys.exit('createBooking old not found')
bc_new = bc_new.replace(old_create, new_create, 1)
print('createBooking path: OK')

# Reject path
old_reject = (
"    booking.status = 'rejected';\n"
"    booking.rejectedAt = new Date();\n"
"    await booking.save();\n"
"    await booking.populate(['ownerId', 'sitterId']);\n"
"\n"
"    await createNotificationSafe({\n"
"      recipientRole: 'owner',\n"
"      recipientId: booking.ownerId?._id ? booking.ownerId._id.toString() : booking.ownerId.toString(),\n"
"      actorRole: 'sitter',\n"
"      actorId: booking.sitterId?._id ? booking.sitterId._id.toString() : booking.sitterId.toString(),\n"
"      type: 'booking_rejected',\n"
"      title: 'Booking rejected',\n"
"      body: 'Your booking request was rejected.',\n"
"      data: { bookingId: booking._id.toString() },\n"
"    });"
)
new_reject = (
"    booking.status = 'rejected';\n"
"    booking.rejectedAt = new Date();\n"
"    await booking.save();\n"
"    await booking.populate(['ownerId', 'sitterId', 'walkerId']);\n"
"\n"
"    await createNotificationSafe({\n"
"      recipientRole: 'owner',\n"
"      recipientId: booking.ownerId?._id ? booking.ownerId._id.toString() : booking.ownerId.toString(),\n"
"      // Session v16.2 - same walker/sitter routing as accept path above.\n"
"      actorRole: actorRoleForOwnerNotif,\n"
"      actorId: actorIdForOwnerNotif,\n"
"      type: 'booking_rejected',\n"
"      title: 'Booking rejected',\n"
"      body: 'Your booking request was rejected.',\n"
"      data: { bookingId: booking._id.toString() },\n"
"    });"
)
if old_reject not in bc_new:
    sys.exit('reject old not found')
bc_new = bc_new.replace(old_reject, new_reject, 1)
print('reject path: OK')

out_path = '/sessions/relaxed-jolly-pasteur/mnt/HopeTSIT_FINAL_FIXED/HopeTSIT_FINAL/backend/src/controllers/bookingController.js'
with open(out_path, 'w') as f:
    f.write(bc_new)
print('bookingController.js written,', len(bc_new), 'bytes')
