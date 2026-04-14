const attachOwnerFromToken = (req, res, next) => {
  if (!req.user?.id) {
    return res.status(401).json({ error: 'Authorization token is required.' });
  }

  if (req.user.role !== 'owner') {
    return res.status(403).json({ error: 'Only owners can access this resource.' });
  }

  req.ownerId = req.user.id;
  req.query = {
    ...req.query,
    ownerId: req.user.id,
  };

  return next();
};

const attachUserFromToken = (req, res, next) => {
  if (!req.user?.id) {
    return res.status(401).json({ error: 'Authorization token is required.' });
  }

  const role = req.user.role;
  const userId = req.user.id;

  if (!['owner', 'sitter'].includes(role)) {
    return res.status(403).json({ error: 'Invalid user role.' });
  }

  // Attach user ID to query based on role
  req.query = {
    ...req.query,
    [role === 'owner' ? 'ownerId' : 'sitterId']: userId,
  };

  return next();
};

module.exports = {
  attachOwnerFromToken,
  attachUserFromToken,
};


