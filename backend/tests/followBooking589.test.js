// v589 — suivre la balade d'une prestation en cours + « qui suit mon direct ».
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const f = require('../src/utils/followers589');
const { activeServiceFilter } = require('../src/utils/bookingLive589');

describe('qui suit mon direct', () => {
  beforeEach(() => f._resetForTests());
  test('compte les personnes, pas les appels ; retrait ; expiration 3 min', () => {
    const t0 = 1_000_000;
    expect(f.touch('A', 'B', true, t0)).toBe(1);
    expect(f.touch('A', 'B', true, t0 + 1000)).toBe(1);
    expect(f.touch('A', 'C', true, t0 + 2000)).toBe(2);
    expect(f.touch('A', 'B', false, t0 + 3000)).toBe(1);
    expect(f.count('A', t0 + 2000 + f.TTL_MS + 1)).toBe(0);
  });
  test('on ne se suit pas soi-même ; clé de personne stable', () => {
    expect(f.touch('A', 'A', true)).toBe(0);
    expect(f.personKey(['z9', 'a1', 'm5'])).toBe('a1');
    expect(f.personKey([])).toBe('');
  });
});

test('prestation en cours : récupérée < 24 h, pas rendue, pas annulée', () => {
  const now = new Date('2026-09-26T12:00:00Z');
  const q = activeServiceFilter(now);
  expect(q.status.$nin).toEqual(expect.arrayContaining(['cancelled', 'refunded']));
  const or = q.$and[0].$or;
  expect(or[0]['handover.pickupProviderAt'].$gte.toISOString()).toBe('2026-09-25T12:00:00.000Z');
  expect(q.$and[1]).toEqual({ 'handover.returnProviderAt': null });
  expect(q.$and[2]).toEqual({ serviceEndedAt: null });
});

// ── Intégration : le direct du promeneur part vers le propriétaire NON ami ──
const mockGroupOf = (id) => {
  const g = ['wW', 'wO'].includes(String(id)) ? ['wW', 'wO'] : [String(id)];
  return { ids: g, set: new Set(g), docs: g.map((x) => ({ id: x, model: x.endsWith('W') ? 'Walker' : 'Owner' })) };
};
const mockChain = (result) => {
  const c = { select: () => c, limit: () => c, sort: () => c, lean: () => Promise.resolve(result),
    then: (ok, ko) => Promise.resolve(result).then(ok, ko), catch: () => c };
  return c;
};
let mockBookings = [];
jest.mock('../src/models/Booking', () => ({ find: jest.fn(() => mockChain(mockBookings)) }));
const mockModel = () => ({
  find: jest.fn(() => mockChain([])),
  findById: jest.fn(() => mockChain({ preferences: {} })),
  updateOne: jest.fn(() => Promise.resolve({})),
});
jest.mock('../src/models/Owner', () => mockModel());
jest.mock('../src/models/Sitter', () => mockModel());
jest.mock('../src/models/Walker', () => mockModel());
jest.mock('../src/models/Friendship', () => ({ find: jest.fn(() => mockChain([])) }));
jest.mock('../src/models/UserSubscription', () => ({
  find: jest.fn(() => mockChain([])),
  hasActivePawFollow: jest.fn(() => Promise.resolve(false)),
  isInSameFamily: jest.fn(() => Promise.resolve(false)),
  listFamilyMembers: jest.fn(() => Promise.resolve([])),
}));
jest.mock('../src/sockets/emitter', () => ({
  userRoom: (role, id) => `user:${role}:${id}`,
  emitToUser: jest.fn(),
  emitToWalk: jest.fn(),
}));
jest.mock('../src/utils/identityGroup', () => ({ identityGroup: jest.fn((id) => Promise.resolve(mockGroupOf(id))) }));
jest.mock('../src/utils/personScope', () => ({
  personIds: jest.fn((id) => Promise.resolve(mockGroupOf(id).ids)),
  personIndex: jest.fn((ids) => Promise.resolve(new Map(ids.map((i) => [String(i), mockGroupOf(i)])))),
}));
let mockVis = 'all';
jest.mock('../src/utils/mapVisibility', () => ({
  ...jest.requireActual('../src/utils/mapVisibility'),
  personMapVisibility: jest.fn(() => Promise.resolve(mockVis)),
}));

const mapSocket = require('../src/sockets/mapSocket');

test('prestation en cours : le propriétaire (non ami) reçoit le direct sous l\'id de la réservation', async () => {
  mockVis = 'all';
  mockBookings = [{ _id: 'b1', ownerId: 'oX', walkerId: 'wW', sitterId: null }];
  const ls = await mapSocket.listPositionListeners('wO', 'owner');
  const toOwner = ls.filter((l) => l.userId === 'oX');
  expect(toOwner.length).toBeGreaterThan(0);
  expect(toOwner[0].viewAsId).toBe('wW');
  expect(ls.personIds).toEqual(['wW', 'wO']);
});

test('« Masqué » : seul le propriétaire en cours de prestation reçoit ; sans prestation, personne', async () => {
  mockVis = 'hidden';
  mockBookings = [{ _id: 'b1', ownerId: 'oX', walkerId: 'wW', sitterId: null }];
  const ls = await mapSocket.listPositionListeners('wW', 'walker');
  expect(ls.map((l) => l.userId)).toEqual(['oX']);
  mockBookings = [];
  expect(await mapSocket.listPositionListeners('wW', 'walker')).toEqual([]);
});
