const Owner = require('../models/Owner');
const Pet = require('../models/Pet');
const { uploadMedia } = require('../services/cloudinary');
const { sanitizePet } = require('../utils/sanitize');

const normalizeMediaEntry = (entry) => {
  if (!entry || typeof entry !== 'object') {
    return null;
  }
  const normalized = {
    url: entry.url || '',
    publicId: entry.publicId || '',
  };
  if (entry.uploadedAt) {
    const timestamp = new Date(entry.uploadedAt);
    if (!Number.isNaN(timestamp.getTime())) {
      normalized.uploadedAt = timestamp;
    }
  }
  return normalized;
};

const normalizePetPayload = (payload = {}) => {
  const result = { ...payload };
  if (payload.avatar) {
    result.avatar = normalizeMediaEntry(payload.avatar);
  }
  if (Array.isArray(payload.photos)) {
    result.photos = payload.photos
      .map((photo) => {
        const normalized = normalizeMediaEntry(photo);
        if (!normalized) return null;
        return {
          url: normalized.url,
          publicId: normalized.publicId,
          uploadedAt: normalized.uploadedAt || new Date(),
        };
      })
      .filter(Boolean);
  }
  if (Array.isArray(payload.videos)) {
    result.videos = payload.videos
      .map((video) => {
        const normalized = normalizeMediaEntry(video);
        if (!normalized) return null;
        return {
          url: normalized.url,
          publicId: normalized.publicId,
          uploadedAt: normalized.uploadedAt || new Date(),
        };
      })
      .filter(Boolean);
  }
  if (payload.passportImage) {
    const passport = normalizeMediaEntry(payload.passportImage);
    if (passport) {
      result.passportImage = {
        url: passport.url,
        publicId: passport.publicId,
        uploadedAt: passport.uploadedAt || new Date(),
      };
    } else {
      result.passportImage = undefined;
    }
  }
  return result;
};

const createOrUpdatePet = async (req, res) => {
  try {
    const userId = req.user?.id;
    const userRole = req.user?.role;
    const { pet, petId } = req.body;

    if (!userId || userRole !== 'owner') {
      return res.status(403).json({ error: 'Only owners can manage pet profiles.' });
    }

    if (!pet) {
      return res.status(400).json({ error: 'Pet payload is required.' });
    }

    const owner = await Owner.findById(userId);

    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    const petData = normalizePetPayload(pet);

    const errors = {};
    if (!petData.petName || !petData.petName.trim()) {
      errors.petName = 'Pet name is required.';
    }
    if (!petData.category || !petData.category.trim()) {
      errors.category = 'Pet category is required.';
    }
    // Sprint 5 step 5 — vaccination is no longer required (new structured
    // vaccinations[] field replaces the free-text one; both remain optional).

    if (Object.keys(errors).length > 0) {
      return res.status(400).json({ errors });
    }

    let newPet;
    if (petId) {
      newPet = await Pet.findOneAndUpdate(
        { _id: petId, ownerId: owner._id },
        { ownerId: owner._id, ...petData },
        { new: true, runValidators: true }
      );
      if (!newPet) {
        return res.status(404).json({ error: 'Pet not found for this owner.' });
      }
    } else {
      newPet = await Pet.create({ ownerId: owner._id, ...petData });
    }

    res.status(201).json({ pet: newPet });
  } catch (error) {
    console.error('Create pet error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid owner id.' });
    }
    res.status(500).json({ error: 'Unable to create pet profile. Please try again later.' });
  }
};

const bufferToDataUri = (file) => `data:${file.mimetype};base64,${file.buffer.toString('base64')}`;

const SUPPORTED_MEDIA_TYPES = ['avatar', 'photo', 'passportImage', 'video'];

const uploadPetMedia = async (req, res) => {
  try {
    const userId = req.user?.id;
    const userRole = req.user?.role;
    const { petId } = req.query;
    const { folder } = req.body || {};

    if (!userId || userRole !== 'owner') {
      return res.status(403).json({ error: 'Only owners can upload pet media.' });
    }

    if (!petId) {
      return res.status(400).json({ error: 'petId query parameter is required.' });
    }

    if (!req.files || Object.keys(req.files).length === 0) {
      return res.status(400).json({ error: 'At least one file is required.' });
    }

    const pet = await Pet.findOne({ _id: petId, ownerId: userId });
    if (!pet) {
      return res.status(404).json({ error: 'Pet not found for this owner.' });
    }

    const uploadFolder = folder || `petsinsta/pets/${petId}`;
    const uploadedMedia = [];
    const fieldToMediaType = {
      avatar: 'avatar',
      photo: 'photo',
      passportImage: 'passportImage',
      video: 'video',
      file: 'photo', // default fallback
      media: 'photo', // default fallback
    };

    // Process each field
    for (const [fieldName, files] of Object.entries(req.files)) {
      const mediaType = fieldToMediaType[fieldName] || 'photo';
      const resourceType = mediaType === 'video' ? 'video' : 'image';

      for (const file of files) {
        const dataUri = bufferToDataUri(file);
        const uploadResult = await uploadMedia({
          file: dataUri,
          folder: uploadFolder,
          resourceType,
        });

        const mediaEntry = {
          url: uploadResult.url,
          publicId: uploadResult.publicId,
          uploadedAt: new Date(),
        };

        if (mediaType === 'avatar') {
          pet.avatar = mediaEntry;
        } else if (mediaType === 'passportImage') {
          pet.passportImage = mediaEntry;
        } else if (mediaType === 'photo') {
          pet.photos = Array.isArray(pet.photos) ? pet.photos : [];
          pet.photos.push(mediaEntry);
        } else if (mediaType === 'video') {
          pet.videos = Array.isArray(pet.videos) ? pet.videos : [];
          pet.videos.push(mediaEntry);
        }

        uploadedMedia.push({
          fieldName,
          mediaType,
          url: uploadResult.url,
          publicId: uploadResult.publicId,
          resourceType: uploadResult.resourceType,
          format: uploadResult.format,
          bytes: uploadResult.bytes,
          width: uploadResult.width,
          height: uploadResult.height,
          duration: uploadResult.duration,
          thumbnailUrl: uploadResult.thumbnailUrl,
          createdAt: uploadResult.createdAt,
        });
      }
    }

    await pet.save();

    res.status(201).json({
      message: 'Media uploaded successfully.',
      pet: sanitizePet(pet),
      media: uploadedMedia,
    });
  } catch (error) {
    console.error('Upload pet media error', error);
    if (error.message && error.message.includes('Cloudinary')) {
      return res.status(502).json({ error: 'Media service is unavailable. Please try again later.' });
    }
    res.status(500).json({ error: 'Unable to upload pet media. Please try again later.' });
  }
};

const listPets = async (req, res) => {
  try {
    const { ownerId } = req.query;
    const query = ownerId ? { ownerId } : {};
    const pets = await Pet.find(query).sort({ createdAt: -1 });
    res.json({ pets });
  } catch (error) {
    console.error('Fetch pets error', error);
    res.status(500).json({ error: 'Unable to fetch pets. Please try again later.' });
  }
};

const calculateAge = (dob) => {
  if (!dob || typeof dob !== 'string') return null;
  
  // Try to parse different date formats
  const dateStr = dob.trim();
  if (!dateStr) return null;
  
  // If it's already in a format like "4m" or "2y", return as is
  if (/^\d+[mMyY]$/.test(dateStr)) {
    return dateStr;
  }
  
  try {
    const birthDate = new Date(dateStr);
    if (isNaN(birthDate.getTime())) return null;
    
    const today = new Date();
    const years = today.getFullYear() - birthDate.getFullYear();
    const months = today.getMonth() - birthDate.getMonth();
    
    if (months < 0) {
      return `${years - 1}y`;
    } else if (years === 0) {
      return `${months}m`;
    } else {
      return `${years}y`;
    }
  } catch (e) {
    return null;
  }
};

const parseVaccinations = (vaccinationStr) => {
  if (!vaccinationStr || typeof vaccinationStr !== 'string') return [];
  
  // Split by comma, semicolon, or newline, then trim each item
  return vaccinationStr
    .split(/[,;\n]/)
    .map(v => v.trim())
    .filter(v => v.length > 0);
};

const getPetById = async (req, res) => {
  try {
    const { id } = req.params;

    if (!id) {
      return res.status(400).json({ error: 'Pet id is required.' });
    }

    const pet = await Pet.findById(id).populate('ownerId');

    if (!pet) {
      return res.status(404).json({ error: 'Pet not found.' });
    }

    // Get owner information (without card)
    const owner = pet.ownerId;
    const ownerData = owner ? {
      id: owner._id?.toString() || '',
      name: owner.name || '',
      email: owner.email || '',
      avatar: owner.avatar?.url || '',
    } : null;

    // Calculate age from date of birth
    const age = calculateAge(pet.dob);

    // Parse vaccinations
    const vaccinations = parseVaccinations(pet.vaccination);

    // Format pet response
    const petResponse = {
      id: pet._id.toString(),
      petName: pet.petName || '',
      breed: pet.breed || '',
      age: age || pet.dob || '',
      weight: pet.weight || '',
      height: pet.height || '',
      color: pet.colour || '',
      bio: pet.bio || '',
      category: pet.category || '',
      dob: pet.dob || '',
      passportNumber: pet.passportNumber || '',
      chipNumber: pet.chipNumber || '',
      medicationAllergies: pet.medicationAllergies || '',
      // Main pet image (avatar)
      avatar: {
        url: pet.avatar?.url || '',
        publicId: pet.avatar?.publicId || '',
      },
      // Pet gallery photos
      photos: Array.isArray(pet.photos)
        ? pet.photos.map((photo) => ({
            url: photo.url || '',
            publicId: photo.publicId || '',
            uploadedAt: photo.uploadedAt || null,
          }))
        : [],
      // Videos if any
      videos: Array.isArray(pet.videos)
        ? pet.videos.map((video) => ({
            url: video.url || '',
            publicId: video.publicId || '',
            uploadedAt: video.uploadedAt || null,
          }))
        : [],
      // Passport image
      passportImage: pet.passportImage
        ? {
            url: pet.passportImage.url || '',
            publicId: pet.passportImage.publicId || '',
            uploadedAt: pet.passportImage.uploadedAt || null,
          }
        : null,
      // Vaccinations array
      vaccinations: vaccinations,
      // Owner information
      owner: ownerData,
      createdAt: pet.createdAt,
      updatedAt: pet.updatedAt,
    };

    res.json({ pet: petResponse });
  } catch (error) {
    console.error('Get pet error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid pet id.' });
    }
    res.status(500).json({ error: 'Unable to fetch pet. Please try again later.' });
  }
};

const getMyPets = async (req, res) => {
  try {
    const ownerId = req.user?.id;
    const userRole = req.user?.role;

    if (!ownerId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'owner') {
      return res.status(403).json({ error: 'This endpoint is only accessible to owners.' });
    }

    const owner = await Owner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    const pets = await Pet.find({ ownerId: ownerId }).sort({ createdAt: -1 });

    const petsWithDetails = pets.map((pet) => {
      const age = calculateAge(pet.dob);
      const vaccinations = parseVaccinations(pet.vaccination);

      return {
        ...sanitizePet(pet),
        age: age || pet.dob || '',
        vaccinations: vaccinations,
      };
    });

    res.json({
      pets: petsWithDetails,
      count: pets.length,
    });
  } catch (error) {
    console.error('Get my pets error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid owner id.' });
    }
    res.status(500).json({ error: 'Unable to fetch pets. Please try again later.' });
  }
};

const getAllPets = async (req, res) => {
  try {
    const pets = await Pet.find({}).populate('ownerId', 'name email avatar').sort({ createdAt: -1 });

    const petsWithDetails = pets.map((pet) => {
      const age = calculateAge(pet.dob);
      const vaccinations = parseVaccinations(pet.vaccination);

      // Get owner information (without card)
      const owner = pet.ownerId;
      const ownerData = owner ? {
        id: owner._id?.toString() || '',
        name: owner.name || '',
        email: owner.email || '',
        avatar: owner.avatar?.url || '',
      } : null;

      return {
        ...sanitizePet(pet),
        age: age || pet.dob || '',
        vaccinations: vaccinations,
        owner: ownerData,
      };
    });

    res.json({
      pets: petsWithDetails,
      count: pets.length,
    });
  } catch (error) {
    console.error('Get all pets error', error);
    res.status(500).json({ error: 'Unable to fetch pets. Please try again later.' });
  }
};

const updatePetProfile = async (req, res) => {
  try {
    const ownerId = req.user?.id;
    const userRole = req.user?.role;
    const { id } = req.params;
    const petData = req.body;

    if (!ownerId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'owner') {
      return res.status(403).json({ error: 'Only owners can edit pet profiles.' });
    }

    if (!id) {
      return res.status(400).json({ error: 'Pet id is required.' });
    }

    const owner = await Owner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    // Check if pet exists and belongs to the owner
    const existingPet = await Pet.findOne({ _id: id, ownerId: ownerId });
    if (!existingPet) {
      return res.status(404).json({ error: 'Pet not found or you do not have permission to edit this pet.' });
    }

    // Normalize the pet payload
    const normalizedData = normalizePetPayload(petData);

    // Build update object with only provided fields
    const updateData = {};
    
    if (normalizedData.petName !== undefined) {
      updateData.petName = normalizedData.petName.trim();
    }
    if (normalizedData.breed !== undefined) {
      updateData.breed = normalizedData.breed.trim();
    }
    if (normalizedData.dob !== undefined) {
      updateData.dob = normalizedData.dob.trim();
    }
    if (normalizedData.weight !== undefined) {
      updateData.weight = normalizedData.weight.trim();
    }
    if (normalizedData.height !== undefined) {
      updateData.height = normalizedData.height.trim();
    }
    if (normalizedData.passportNumber !== undefined) {
      updateData.passportNumber = normalizedData.passportNumber.trim();
    }
    if (normalizedData.chipNumber !== undefined) {
      updateData.chipNumber = normalizedData.chipNumber.trim();
    }
    if (normalizedData.medicationAllergies !== undefined) {
      updateData.medicationAllergies = normalizedData.medicationAllergies.trim();
    }
    if (normalizedData.category !== undefined) {
      updateData.category = normalizedData.category.trim();
    }
    if (normalizedData.vaccination !== undefined) {
      updateData.vaccination = normalizedData.vaccination.trim();
    }
    if (normalizedData.bio !== undefined) {
      updateData.bio = normalizedData.bio.trim();
    }
    if (normalizedData.colour !== undefined) {
      updateData.colour = normalizedData.colour.trim();
    }
    if (normalizedData.profileView !== undefined) {
      updateData.profileView = normalizedData.profileView.trim();
    }
    // Note: Media fields (avatar, photos, videos, passportImage) should be updated via updatePetMedia endpoint

    // Validate required fields if they're being updated
    if (updateData.petName !== undefined && !updateData.petName) {
      return res.status(400).json({ error: 'Pet name cannot be empty.' });
    }
    if (updateData.category !== undefined && !updateData.category) {
      return res.status(400).json({ error: 'Pet category cannot be empty.' });
    }
    if (updateData.vaccination !== undefined && !updateData.vaccination) {
      return res.status(400).json({ error: 'Vaccination details cannot be empty.' });
    }

    // Update the pet
    const updatedPet = await Pet.findOneAndUpdate(
      { _id: id, ownerId: ownerId },
      { $set: updateData },
      { new: true, runValidators: true }
    );

    if (!updatedPet) {
      return res.status(404).json({ error: 'Pet not found or you do not have permission to edit this pet.' });
    }

    // Format response with calculated age and parsed vaccinations
    const age = calculateAge(updatedPet.dob);
    const vaccinations = parseVaccinations(updatedPet.vaccination);

    const petResponse = {
      ...sanitizePet(updatedPet),
      age: age || updatedPet.dob || '',
      vaccinations: vaccinations,
    };

    res.json({
      message: 'Pet profile updated successfully.',
      pet: petResponse,
    });
  } catch (error) {
    console.error('Update pet profile error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid pet id or owner id.' });
    }
    if (error.name === 'ValidationError') {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Unable to update pet profile. Please try again later.' });
  }
};

const updatePetMedia = async (req, res) => {
  try {
    const ownerId = req.user?.id;
    const userRole = req.user?.role;
    const { id } = req.params;
    const { action, mediaType, publicId, folder } = req.body || {};

    if (!ownerId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    if (userRole !== 'owner') {
      return res.status(403).json({ error: 'Only owners can update pet media.' });
    }

    if (!id) {
      return res.status(400).json({ error: 'Pet id is required.' });
    }

    const owner = await Owner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    // Check if pet exists and belongs to the owner
    const pet = await Pet.findOne({ _id: id, ownerId: ownerId });
    if (!pet) {
      return res.status(404).json({ error: 'Pet not found or you do not have permission to edit this pet.' });
    }

    // Validate file types
    const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime', 'video/x-msvideo'];
    
    const uploadFolder = folder || `petsinsta/pets/${id}`;
    const uploadedMedia = [];
    const fieldToMediaType = {
      avatar: 'avatar',
      photo: 'photo',
      photos: 'photo',
      passportImage: 'passportImage',
      video: 'video',
      videos: 'video',
      file: 'photo', // default fallback
      media: 'photo', // default fallback
    };

    // Handle file uploads
    if (req.files && Object.keys(req.files).length > 0) {
      // Process each field
      for (const [fieldName, files] of Object.entries(req.files)) {
        const detectedMediaType = fieldToMediaType[fieldName] || 'photo';
        const resourceType = detectedMediaType === 'video' ? 'video' : 'image';

        for (const file of files) {
          // Validate file type
          if (!allowedMimeTypes.includes(file.mimetype)) {
            return res.status(400).json({ 
              error: `Invalid file type for ${file.originalname}. Only JPEG, PNG, WebP images and MP4, MOV, AVI videos are allowed.` 
            });
          }

          const dataUri = bufferToDataUri(file);
          const uploadResult = await uploadMedia({
            file: dataUri,
            folder: uploadFolder,
            resourceType,
          });

          const mediaEntry = {
            url: uploadResult.url,
            publicId: uploadResult.publicId,
            uploadedAt: new Date(),
          };

          // Delete old media from Cloudinary if replacing
          if (detectedMediaType === 'avatar' && pet.avatar?.publicId) {
            try {
              const cloudinary = require('cloudinary').v2;
              await cloudinary.uploader.destroy(pet.avatar.publicId);
            } catch (deleteError) {
              console.error('Error deleting old avatar:', deleteError);
            }
            pet.avatar = mediaEntry;
          } else if (detectedMediaType === 'passportImage' && pet.passportImage?.publicId) {
            try {
              const cloudinary = require('cloudinary').v2;
              await cloudinary.uploader.destroy(pet.passportImage.publicId);
            } catch (deleteError) {
              console.error('Error deleting old passport image:', deleteError);
            }
            pet.passportImage = mediaEntry;
          } else if (detectedMediaType === 'photo') {
            pet.photos = Array.isArray(pet.photos) ? pet.photos : [];
            pet.photos.push(mediaEntry);
          } else if (detectedMediaType === 'video') {
            pet.videos = Array.isArray(pet.videos) ? pet.videos : [];
            pet.videos.push(mediaEntry);
          }

          uploadedMedia.push({
            fieldName,
            mediaType: detectedMediaType,
            url: uploadResult.url,
            publicId: uploadResult.publicId,
            resourceType: uploadResult.resourceType,
            format: uploadResult.format,
            bytes: uploadResult.bytes,
            width: uploadResult.width,
            height: uploadResult.height,
            duration: uploadResult.duration,
            thumbnailUrl: uploadResult.thumbnailUrl,
            createdAt: uploadResult.createdAt,
          });
        }
      }
    }

    // Handle deletion if action is 'delete'
    if (action === 'delete' && mediaType && publicId) {
      try {
        const cloudinary = require('cloudinary').v2;
        await cloudinary.uploader.destroy(publicId);

        if (mediaType === 'avatar') {
          pet.avatar = { url: '', publicId: '' };
        } else if (mediaType === 'passportImage') {
          pet.passportImage = { url: '', publicId: '', uploadedAt: null };
        } else if (mediaType === 'photo') {
          pet.photos = Array.isArray(pet.photos) 
            ? pet.photos.filter(photo => photo.publicId !== publicId)
            : [];
        } else if (mediaType === 'video') {
          pet.videos = Array.isArray(pet.videos)
            ? pet.videos.filter(video => video.publicId !== publicId)
            : [];
        }
      } catch (deleteError) {
        console.error('Error deleting media from Cloudinary:', deleteError);
        // Continue even if deletion fails
      }
    }

    await pet.save();

    // Format response with calculated age and parsed vaccinations
    const age = calculateAge(pet.dob);
    const vaccinations = parseVaccinations(pet.vaccination);

    const petResponse = {
      ...sanitizePet(pet),
      age: age || pet.dob || '',
      vaccinations: vaccinations,
    };

    res.json({
      message: uploadedMedia.length > 0 
        ? 'Pet media updated successfully.' 
        : action === 'delete' 
          ? 'Media deleted successfully.' 
          : 'Pet media updated successfully.',
      pet: petResponse,
      uploadedMedia: uploadedMedia.length > 0 ? uploadedMedia : undefined,
    });
  } catch (error) {
    console.error('Update pet media error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid pet id or owner id.' });
    }
    if (error.message && error.message.includes('Cloudinary')) {
      return res.status(502).json({ error: 'Media service is unavailable. Please try again later.' });
    }
    res.status(500).json({ error: 'Unable to update pet media. Please try again later.' });
  }
};

module.exports = {
  createOrUpdatePet,
  listPets,
  getPetById,
  uploadPetMedia,
  getMyPets,
  getAllPets,
  updatePetProfile,
  updatePetMedia,
};

