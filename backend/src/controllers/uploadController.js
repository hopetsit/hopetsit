const { uploadMedia } = require('../services/cloudinary');
const logger = require('../utils/logger');

const DEFAULT_FOLDER = 'petsinsta';

const uploadToCloudinary = async (req, res) => {
  try {
    const { file, folder = DEFAULT_FOLDER, resourceType = 'auto' } = req.body || {};

    if (!file) {
      return res.status(400).json({ error: 'file is required.' });
    }

    const result = await uploadMedia({ file, folder, resourceType });

    res.status(201).json(result);
  } catch (error) {
    logger.error('Cloudinary upload error', error);
    res.status(500).json({ error: 'Unable to upload media. Please try again later.' });
  }
};

const bufferToDataUri = (file) => `data:${file.mimetype};base64,${file.buffer.toString('base64')}`;

const uploadFormDataToCloudinary = async (req, res) => {
  try {
    const { folder = DEFAULT_FOLDER, resourceType = 'auto' } = req.body || {};
    if (!req.file) {
      return res.status(400).json({ error: 'file is required.' });
    }

    const dataUri = bufferToDataUri(req.file);

    const result = await uploadMedia({ file: dataUri, folder, resourceType });

    res.status(201).json(result);
  } catch (error) {
    logger.error('Cloudinary form-data upload error', error);
    res.status(500).json({ error: 'Unable to upload media. Please try again later.' });
  }
};

module.exports = {
  uploadToCloudinary,
  uploadFormDataToCloudinary,
};

