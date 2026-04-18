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

  if (!['owner', 'sitter', 'walker'].includes(role)) {
    return res.status(403).json({ error: 'Invalid user role.' });
  }

  // Attach user ID to query based on role.
  // Walker is treated as a service provider like sitter for resources that
  // haven't been role-split yet — this keeps existing owner/sitter queries
  // working while letting walker hit the same middleware without a 403.
  const key = role === 'owner' ? 'ownerId' : (role === 'walker' ? 'walkerId' : 'sitterId');
  req.query = {
    ...req.query,
    [key]: userId,
  };

  return next();
};

module.exports = {
  attachOwnerFromToken,
  attachUserFromToken,
};


