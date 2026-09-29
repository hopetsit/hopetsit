// v599 (ZOE, 29/09/2026) — UNE conversation par paire de PERSONNES.
// Reproduit le cas de la prod : John (owner J1 = walker J1, sitter J2) et
// Daniel (owner D1, sitter D2, walker D3) avaient TROIS fils :
//   A) réservation  ownerId J1 / sitterId D2   (« Demande de suivi en direct »)
//   B) réservation  ownerId D1 / walkerId J1   (juillet)
//   F) ami          participants [D1, J1]      (les vocaux)
// → deux « Daniel C » dans la liste de John, et des messages invisibles pour
// Daniel depuis son profil propriétaire. Sans base : modèles en mémoire.

process.env.NODE_ENV = 'test';

const PEOPLE = {
  J1: { _id: 'J1', email: 'john@example.test' },
  J2: { _id: 'J2', email: 'john@example.test' },
  D1: { _id: 'D1', email: 'daniel@example.test' },
  D2: { _id: 'D2', email: 'daniel@example.test' },
  D3: { _id: 'D3', email: 'daniel@example.test' },
  L1: { _id: 'L1', email: 'lea@example.test' },
};
const ROLE_OF = { J1: ['Owner', 'Walker'], J2: ['Sitter'], D1: ['Owner'], D2: ['Sitter'], D3: ['Walker'], L1: ['Sitter'] };

const mockStores = { Conversation: [], Message: [] };

const mockEq = (a, b) => {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return String(a) === String(b);
};
const getPath = (doc, path) => {
  if (path === 'participants.userId') return (doc.participants || []).map((p) => p.userId);
  return doc[path];
};
const matchVal = (val, v) => {
  if (Array.isArray(val)) return val.some((x) => matchVal(x, v));
  if (v && typeof v === 'object' && !Array.isArray(v)) {
    return Object.entries(v).every(([op, arg]) => {
      if (op === '$in') return arg.some((x) => mockEq(val, x));
      if (op === '$nin') return !arg.some((x) => mockEq(val, x));
      if (op === '$ne') return !mockEq(val, arg);
      throw new Error(`opérateur non simulé : ${op}`);
    });
  }
  return mockEq(val, v);
};
const mockMatches = (doc, filter) =>
  Object.entries(filter || {}).every(([k, v]) => {
    if (k === '$or') return v.some((f) => mockMatches(doc, f));
    if (k === '$and') return v.every((f) => mockMatches(doc, f));
    if (k === 'mergedInto' && v === null) return doc.mergedInto == null;
    return matchVal(getPath(doc, k), v);
  });

const chain = (rows) => {
  let out = rows;
  const api = {
    select: () => api,
    populate: () => api,
    sort: (spec) => {
      const [[key, dir]] = Object.entries(spec);
      if (Array.isArray(out)) out = [...out].sort((a, b) => (new Date(a[key] || 0) - new Date(b[key] || 0)) * dir);
      return api;
    },
    lean: () => api,
    then: (res, rej) => Promise.resolve(out).then(res, rej),
  };
  return api;
};
const mockModel = (name) => ({
  find: jest.fn((filter) => chain(mockStores[name].filter((d) => mockMatches(d, filter)))),
  findById: jest.fn((id) => chain(mockStores[name].find((d) => String(d._id) === String(id)) || null)),
  findOne: jest.fn((filter) => chain(mockStores[name].find((d) => mockMatches(d, filter)) || null)),
  updateOne: jest.fn(async (filter, update) => {
    const doc = mockStores[name].find((d) => mockMatches(d, filter));
    if (!doc) return { modifiedCount: 0 };
    for (const [k, v] of Object.entries(update.$set || {})) doc[k] = v;
    for (const [k, v] of Object.entries(update.$inc || {})) {
      const m = /^participants\.(\d+)\.unreadCount$/.exec(k);
      if (m) doc.participants[Number(m[1])].unreadCount = (doc.participants[Number(m[1])].unreadCount || 0) + v;
      else doc[k] = (doc[k] || 0) + v;
    }
    return { modifiedCount: 1 };
  }),
  updateMany: jest.fn(async (filter, update) => {
    let n = 0;
    for (const doc of mockStores[name]) {
      if (!mockMatches(doc, filter)) continue;
      for (const [k, v] of Object.entries(update.$set || {})) doc[k] = v;
      n += 1;
    }
    return { modifiedCount: n };
  }),
});
const userModel = (model) => ({
  find: jest.fn((q) => {
    let rows = Object.values(PEOPLE).filter((d) => ROLE_OF[d._id].includes(model));
    if (q && q._id && q._id.$in) rows = rows.filter((d) => q._id.$in.map(String).includes(d._id));
    if (q && q.$or) rows = rows.filter((d) => q.$or.some((c) => (c.email ? c.email === d.email : false)));
    return chain(rows);
  }),
  findById: jest.fn((id) => {
    const d = PEOPLE[id];
    return { select: () => ({ lean: () => ({ catch: () => Promise.resolve(d && ROLE_OF[id].includes(model) ? d : null) }) }) };
  }),
});

jest.mock('../src/models/Conversation', () => mockModel('Conversation'));
jest.mock('../src/models/Message', () => mockModel('Message'));
jest.mock('../src/models/Owner', () => userModel('Owner'));
jest.mock('../src/models/Sitter', () => userModel('Sitter'));
jest.mock('../src/models/Walker', () => userModel('Walker'));
jest.mock('../src/utils/logger', () => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() }));

const id599 = require('../src/utils/conversationIdentity599');

const JOHN = new Set(['J1', 'J2']);
const DANIEL = new Set(['D1', 'D2', 'D3']);

const seed = () => {
  mockStores.Conversation = [
    { _id: 'A', ownerId: 'J1', sitterId: 'D2', lastMessage: 'Tu vois les msg ???', lastMessageAt: '2026-09-28T22:44:00Z', ownerUnreadCount: 0, sitterUnreadCount: 4, mergedInto: null },
    { _id: 'B', ownerId: 'D1', walkerId: 'J1', lastMessage: '📍 Demande de suivi en direct', lastMessageAt: '2026-07-09T21:11:00Z', ownerUnreadCount: 2, sitterUnreadCount: 0, mergedInto: null },
    { _id: 'F', friendChat: true, participants: [{ userId: 'D1', userModel: 'Owner', unreadCount: 1 }, { userId: 'J1', userModel: 'Owner', unreadCount: 3 }], lastMessage: 'Regarde ton whatsapp', lastMessageAt: '2026-09-28T22:45:42Z', mergedInto: null },
    { _id: 'L', ownerId: 'D1', sitterId: 'L1', lastMessage: 'bonjour', lastMessageAt: '2026-07-19T10:49:00Z', ownerUnreadCount: 0, sitterUnreadCount: 0, mergedInto: null },
  ];
  mockStores.Message = [
    { _id: 'm1', conversationId: 'A', senderId: 'J1', senderRole: 'owner', body: 'Test' },
    { _id: 'm2', conversationId: 'A', senderId: 'J1', senderRole: 'owner', body: 'Tu vois les msg ???' },
    { _id: 'm3', conversationId: 'B', senderId: 'D1', senderRole: 'owner', body: 'superrr' },
    { _id: 'm4', conversationId: 'B', senderId: 'J1', senderRole: 'walker', body: 'youpi' },
    { _id: 'm5', conversationId: 'F', senderId: 'D1', senderRole: 'owner', body: '', type: 'voice' },
    { _id: 'm6', conversationId: 'F', senderId: 'J1', senderRole: 'owner', body: 'Regarde ton whatsapp' },
    { _id: 'm7', conversationId: 'L', senderId: 'L1', senderRole: 'sitter', body: 'bonjour' },
  ];
};

describe('sideOf — de quel côté suis-je (par personne)', () => {
  beforeEach(seed);
  test('Daniel connecté en PROPRIÉTAIRE est côté prestataire du fil A (il y est gardien)', () => {
    const s = id599.sideOf(mockStores.Conversation[0], DANIEL);
    expect(s.side).toBe('provider');
    expect(s.otherIds).toEqual(['J1']);
    expect(s.otherRole).toBe('owner');
  });
  test('John est côté propriétaire du fil A et côté prestataire du fil B', () => {
    expect(id599.sideOf(mockStores.Conversation[0], JOHN).side).toBe('owner');
    const b = id599.sideOf(mockStores.Conversation[1], JOHN);
    expect(b.side).toBe('provider');
    expect(b.otherRole).toBe('owner');
  });
  test('fil ami : participant, l\'autre = celui qui n\'est pas moi', () => {
    const s = id599.sideOf(mockStores.Conversation[2], DANIEL);
    expect(s.side).toBe('participant');
    expect(s.otherIds).toEqual(['J1']);
    expect(s.participantIndexes).toEqual([0]);
  });
  test('étranger au fil → aucun côté', () => {
    expect(id599.sideOf(mockStores.Conversation[0], new Set(['L1'])).side).toBeNull();
    expect(id599.isMemberByIdentity(mockStores.Conversation[0], ['L1'])).toBe(false);
    expect(id599.isMemberByIdentity(mockStores.Conversation[0], ['D3', 'D2'])).toBe(true);
  });
});

describe('pickCanonical — le fil gardé est le plus récent', () => {
  beforeEach(seed);
  test('F (22:45) gagne sur A (22:44) et B (juillet)', () => {
    const c = id599.pickCanonical(mockStores.Conversation.slice(0, 3));
    expect(c._id).toBe('F');
  });
  test('à date égale, la réservation passe avant le fil ami', () => {
    const t = '2026-09-28T22:45:42Z';
    const c = id599.pickCanonical([
      { _id: 'x', friendChat: true, lastMessageAt: t },
      { _id: 'y', ownerId: 'a', sitterId: 'b', lastMessageAt: t },
    ]);
    expect(c._id).toBe('y');
  });
});

describe('mergeDuplicatesFor — fusion sans perte de messages', () => {
  beforeEach(seed);
  test('John : A et B fusionnent dans F ; 4 messages déplacés ; non lus reportés', async () => {
    const r = await id599.mergeDuplicatesFor(JOHN);
    expect(r.merged).toBe(2);
    expect(r.moved).toBe(4);
    const byId = Object.fromEntries(mockStores.Conversation.map((c) => [c._id, c]));
    expect(byId.A.mergedInto).toBe('F');
    expect(byId.B.mergedInto).toBe('F');
    expect(byId.F.mergedInto).toBeNull();
    expect(byId.L.mergedInto).toBeNull(); // Léa n'est pas concernée
    // Tous les messages de la paire vivent dans F, aucun perdu.
    const inF = mockStores.Message.filter((m) => m.conversationId === 'F').map((m) => m._id).sort();
    expect(inF).toEqual(['m1', 'm2', 'm3', 'm4', 'm5', 'm6']);
    expect(mockStores.Message.find((m) => m._id === 'm7').conversationId).toBe('L');
    // Non lus : Daniel avait 4 (A, côté gardien) + 2 (B, côté propriétaire)
    // + 1 (F) = 7 ; John 0 (A) + 0 (B) + 3 (F) = 3.
    const daniel = byId.F.participants.find((p) => p.userId === 'D1');
    const john = byId.F.participants.find((p) => p.userId === 'J1');
    expect(daniel.unreadCount).toBe(7);
    expect(john.unreadCount).toBe(3);
  });
  test('idempotent : une 2e passe ne bouge plus rien', async () => {
    await id599.mergeDuplicatesFor(JOHN);
    const r2 = await id599.mergeDuplicatesFor(DANIEL);
    expect(r2.merged).toBe(0);
    expect(r2.moved).toBe(0);
  });
  test('un message posé ensuite dans un fil fusionné est ramené dans le canonique', async () => {
    await id599.mergeDuplicatesFor(JOHN);
    mockStores.Message.push({ _id: 'm8', conversationId: 'A', senderId: 'J1', senderRole: 'owner', body: 'après' });
    const r = await id599.mergeDuplicatesFor(JOHN);
    expect(r.moved).toBe(1);
    expect(mockStores.Message.find((m) => m._id === 'm8').conversationId).toBe('F');
  });
});

describe('resolveConversation / findConversationBetweenPersons', () => {
  beforeEach(seed);
  test('un ancien id mène au fil canonique', async () => {
    await id599.mergeDuplicatesFor(JOHN);
    const c = await id599.resolveConversation('A');
    expect(String(c._id)).toBe('F');
    expect(await id599.canonicalIdOf('B')).toBe('F');
    expect(await id599.canonicalIdOf('L')).toBe('L');
  });
  test('avant fusion : un fil existe déjà entre les deux personnes (réservation préférée)', async () => {
    const c = await id599.findConversationBetweenPersons(DANIEL, JOHN);
    expect(c).not.toBeNull();
    expect(['A', 'B']).toContain(c._id); // jamais un nouveau fil
    expect(await id599.findConversationBetweenPersons(JOHN, new Set(['L1']))).toBeNull();
  });
});

describe('personalizeMessage — « à moi » vu par le lecteur', () => {
  test('mon message envoyé depuis mon autre profil reste à moi (senderId = mon id courant)', () => {
    const m = id599.personalizeMessage({ id: 'm', senderId: 'D2', senderRole: 'sitter', body: 'x' }, DANIEL, 'D1');
    expect(m.mine).toBe(true);
    expect(m.senderId).toBe('D1');
  });
  test('le message de l\'autre n\'est pas à moi et garde son senderId', () => {
    const m = id599.personalizeMessage({ id: 'm', senderId: 'J1', senderRole: 'owner', body: 'x' }, DANIEL, 'D1');
    expect(m.mine).toBe(false);
    expect(m.senderId).toBe('J1');
  });
  test('un message système n\'est jamais à moi', () => {
    const m = id599.personalizeMessage({ id: 'm', senderId: 'D1', senderRole: 'system', body: 'x' }, DANIEL, 'D1');
    expect(m.mine).toBe(false);
  });
});
