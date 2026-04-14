const VisitReport = require('../models/VisitReport');
const Booking = require('../models/Booking');
const { uploadMedia } = require('../services/cloudinary');
const { sendNotification } = require('./../services/notificationSender');
const logger = require('../utils/logger');

const bufferToDataUri = (file) =>
  `data:${file.mimetype};base64,${file.buffer.toString('base64')}`;

const submitVisitReport = async (req, res) => {
  try {
    const { id: bookingId } = req.params;
    const booking = await Booking.findById(bookingId).select('ownerId sitterId paymentStatus');
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    if (String(booking.sitterId) !== req.user.id) {
      return res.status(403).json({ error: 'Only the assigned sitter can submit a visit report.' });
    }
    if (booking.paymentStatus !== 'paid') {
      return res.status(400).json({ error: 'Booking must be paid.' });
    }

    const { notes = '', mood = 'calm', activities } = req.body || {};
    const parsedActivities = Array.isArray(activities)
      ? activities
      : typeof activities === 'string' && activities.trim()
      ? activities.split(',').map((a) => a.trim()).filter(Boolean)
      : [];

    const files = req.files || [];
    if (files.length > 10) {
      return res.status(400).json({ error: 'Max 10 photos.' });
    }

    const photos = [];
    for (const f of files) {
      try {
        const up = await uploadMedia({
          file: bufferToDataUri(f),
          folder: 'visit_reports',
          resourceType: 'image',
        });
        photos.push(up.url);
      } catch (e) {
        logger.warn('visit-report photo upload failed', e.message);
      }
    }

    const report = await VisitReport.create({
      bookingId: booking._id,
      sitterId: booking.sitterId,
      ownerId: booking.ownerId,
      notes: String(notes || '').trim(),
      mood: ['happy', 'calm', 'anxious'].includes(mood) ? mood : 'calm',
      activities: parsedActivities,
      photos,
      submittedAt: new Date(),
    });

    // Notify the owner.
    sendNotification({
      userId: String(booking.ownerId),
      role: 'owner',
      type: 'VISIT_REPORT',
      data: {
        bookingId: booking._id.toString(),
        reportId: report._id.toString(),
        photoCount: photos.length,
        mood: report.mood,
      },
      actor: { role: 'sitter', id: req.user.id },
    }).catch(() => {});

    res.status(201).json({ report });
  } catch (e) {
    logger.error('submitVisitReport error', e);
    res.status(500).json({ error: 'Unable to submit visit report.' });
  }
};

const getVisitReport = async (req, res) => {
  try {
    const { id: bookingId } = req.params;
    const booking = await Booking.findById(bookingId).select('ownerId sitterId');
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    const uid = req.user.id;
    if (String(booking.ownerId) !== uid && String(booking.sitterId) !== uid) {
      return res.status(403).json({ error: 'Not a participant.' });
    }
    const report = await VisitReport.findOne({ bookingId })
      .sort({ submittedAt: -1 })
      .lean();
    res.json({ report: report || null });
  } catch (e) {
    logger.error('getVisitReport error', e);
    res.status(500).json({ error: 'Unable to fetch visit report.' });
  }
};

module.exports = { submitVisitReport, getVisitReport };
