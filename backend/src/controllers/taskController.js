const Task = require('../models/Task');
const Owner = require('../models/Owner');
const { sanitizeDoc } = require('../utils/sanitize');
const logger = require('../utils/logger');

const createTask = async (req, res) => {
  try {
    const ownerId = req.user?.id;
    const { title, description } = req.body || {};

    if (!ownerId) {
      return res.status(403).json({ error: 'Owner context missing.' });
    }

    if (!title || !title.trim()) {
      return res.status(400).json({ error: 'Task title is required.' });
    }

    if (!description || !description.trim()) {
      return res.status(400).json({ error: 'Task description is required.' });
    }

    const owner = await Owner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    const task = await Task.create({
      ownerId,
      title: title.trim(),
      description: description.trim(),
    });

    res.status(201).json({ task: sanitizeDoc(task) });
  } catch (error) {
    logger.error('Create task error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid owner id.' });
    }
    res.status(500).json({ error: 'Unable to create task. Please try again later.' });
  }
};

const getTasks = async (req, res) => {
  try {
    const ownerId = req.user?.id;

    if (!ownerId) {
      return res.status(401).json({ error: 'Authentication required. Please provide a valid token.' });
    }

    const owner = await Owner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ error: 'Owner not found.' });
    }

    const tasks = await Task.find({ ownerId: ownerId }).sort({ createdAt: -1 });

    res.json({
      tasks: tasks.map((task) => sanitizeDoc(task)),
      count: tasks.length,
    });
  } catch (error) {
    logger.error('Get tasks error', error);
    if (error.name === 'CastError') {
      return res.status(400).json({ error: 'Invalid owner id.' });
    }
    res.status(500).json({ error: 'Unable to fetch tasks. Please try again later.' });
  }
};

module.exports = {
  createTask,
  getTasks,
};

