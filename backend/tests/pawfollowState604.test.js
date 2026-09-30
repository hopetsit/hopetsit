// v604 (ZOE, 30/09/2026) — état RÉEL du suivi en direct d'une conversation,
// PAR SENS. Daniel : « En direct » restait affiché après l'arrêt, et le suivi
// mutuel (A suit B ET B suit A) se mélangeait.
const {
  sharerIdOf, followerIdOf, directionFor, effectiveStatus, directionalState, selectToStop,
} = require('../src/utils/pawfollowState604');

const NOW = Date.parse('2026-09-30T12:00:00Z');
let seq = 0;
const req = ({ from, fromRole, status = 'pending', respondedBy, createdAt, ...md } = {}) => {
  seq += 1;
  return {
    _id: `m${seq}`,
    type: 'pawfollow_request',
    senderId: from,
    senderRole: fromRole,
    createdAt: createdAt || new Date(NOW - (100 - seq) * 1000),
    metadata: {
      status, requesterId: from, requesterRole: fromRole,
      ...(respondedBy ? { respondedBy, respondedAt: new Date(NOW - 60000) } : {}),
      ...md,
    },
  };
};

// A = gardien (profils aS, aO), B = promeneur (profils bW, bO).
const A = ['aS', 'aO'];
const B = ['bW', 'bO'];

describe('qui partage, qui suit', () => {
  test('demande d\'un propriétaire : il SUIT, celui qui répond partage', () => {
    const m = req({ from: 'aO', fromRole: 'owner', status: 'accepted', respondedBy: 'bW' });
    expect(sharerIdOf(m)).toBe('bW');
    expect(followerIdOf(m)).toBe('aO');
  });
  test('demande d\'un gardien / promeneur : il PARTAGE sa position', () => {
    const m = req({ from: 'aS', fromRole: 'sitter', status: 'accepted', respondedBy: 'bW' });
    expect(sharerIdOf(m)).toBe('aS');
    expect(followerIdOf(m)).toBe('bW');
  });
  test('sens vu par chaque personne, sous n\'importe lequel de ses profils', () => {
    const m = req({ from: 'aS', fromRole: 'sitter', status: 'accepted', respondedBy: 'bW' });
    expect(directionFor(m, A)).toBe('outgoing');
    expect(directionFor(m, B)).toBe('incoming');
  });
  test('demande de propriétaire sans réponse : le demandeur est le suiveur', () => {
    const m = req({ from: 'aO', fromRole: 'owner' });
    expect(directionFor(m, A)).toBe('incoming');
    expect(directionFor(m, B)).toBe('outgoing');
  });
});

describe('statut effectif', () => {
  test('acceptée dont la garde est finie = terminée', () => {
    const m = req({ from: 'aS', fromRole: 'sitter', status: 'accepted', respondedBy: 'bW', endAt: new Date(NOW - 1000) });
    expect(effectiveStatus(m, NOW)).toBe('ended');
  });
  test('en attente expirée = expirée', () => {
    const m = req({ from: 'aS', fromRole: 'sitter', expiresAt: new Date(NOW - 1000) });
    expect(effectiveStatus(m, NOW)).toBe('expired');
  });
  test('terminée par un arrêt = terminée', () => {
    const m = req({ from: 'aS', fromRole: 'sitter', status: 'ended', respondedBy: 'bW' });
    expect(effectiveStatus(m, NOW)).toBe('ended');
  });
});

describe('suivi MUTUEL : deux sens indépendants', () => {
  // A partage vers B (A demande), B partage vers A (B demande).
  const aToB = () => req({ from: 'aS', fromRole: 'sitter', status: 'accepted', respondedBy: 'bW' });
  const bToA = () => req({ from: 'bW', fromRole: 'walker', status: 'accepted', respondedBy: 'aS' });

  test('les deux diffusent : chacun voit son sens sortant ET entrant en direct', () => {
    const msgs = [aToB(), bToA()];
    const live = () => true;
    const sa = directionalState({ messages: msgs, viewerIds: A, liveOf: live, now: NOW });
    const sb = directionalState({ messages: msgs, viewerIds: B, liveOf: live, now: NOW });
    expect(sa.outgoing).toMatchObject({ status: 'accepted', following: true, live: true, sharerId: 'aS' });
    expect(sa.incoming).toMatchObject({ status: 'accepted', following: true, live: true, sharerId: 'bW' });
    expect(sb.outgoing).toMatchObject({ live: true, sharerId: 'bW' });
    expect(sb.incoming).toMatchObject({ live: true, sharerId: 'aS' });
  });

  test('B arrête SON direct : seul le sens B→A tombe, A reste en direct pour B', () => {
    const msgs = [aToB(), bToA()];
    const liveOf = (id) => id === 'aS';
    const sa = directionalState({ messages: msgs, viewerIds: A, liveOf, now: NOW });
    const sb = directionalState({ messages: msgs, viewerIds: B, liveOf, now: NOW });
    expect(sa.incoming).toMatchObject({ following: true, live: false });
    expect(sa.outgoing).toMatchObject({ following: true, live: true });
    expect(sb.incoming).toMatchObject({ following: true, live: true });
    expect(sb.outgoing).toMatchObject({ following: true, live: false });
  });

  test('« arrêter de suivre » de A ne vise que le sens B→A', () => {
    const x = aToB();
    const y = bToA();
    const picked = selectToStop([x, y], A, { scope: 'following', now: NOW });
    expect(picked.map((m) => m._id)).toEqual([y._id]);
  });

  test('« arrêter le partage » de A ne vise que le sens A→B ; « tout » vise les deux', () => {
    const x = aToB();
    const y = bToA();
    expect(selectToStop([x, y], A, { scope: 'sharing', now: NOW }).map((m) => m._id)).toEqual([x._id]);
    expect(selectToStop([x, y], A, { scope: 'all', now: NOW })).toHaveLength(2);
  });

  test('un sens terminé n\'écrase pas l\'autre sens accepté', () => {
    const x = aToB();
    const y = req({ from: 'bW', fromRole: 'walker', status: 'ended', respondedBy: 'aS', endedAt: new Date(NOW), endReason: 'follow_stopped' });
    const sb = directionalState({ messages: [x, y], viewerIds: B, liveOf: () => true, now: NOW });
    expect(sb.incoming).toMatchObject({ status: 'accepted', live: true });
    expect(sb.outgoing).toMatchObject({ status: 'ended', following: false, live: false, endReason: 'follow_stopped' });
  });
});

describe('un seul sens, direct arrêté', () => {
  test('demande terminée après l\'arrêt : plus jamais « en direct », même si une session traîne', () => {
    const m = req({ from: 'aO', fromRole: 'owner', status: 'ended', respondedBy: 'bW', endedAt: new Date(NOW), endReason: 'live_stopped' });
    const sa = directionalState({ messages: [m], viewerIds: A, liveOf: () => true, now: NOW });
    expect(sa.incoming).toMatchObject({ status: 'ended', following: false, live: false, endReason: 'live_stopped' });
    expect(sa.outgoing.status).toBe('none');
  });

  test('acceptée mais partageur muet : suivi en cours, pas en direct', () => {
    const m = req({ from: 'aO', fromRole: 'owner', status: 'accepted', respondedBy: 'bW' });
    const sa = directionalState({ messages: [m], viewerIds: A, liveOf: () => false, now: NOW });
    expect(sa.incoming).toMatchObject({ following: true, live: false });
  });

  test('une vieille acceptée + une nouvelle en attente : la vieille acceptée pilote le sens', () => {
    const old = req({ from: 'aO', fromRole: 'owner', status: 'accepted', respondedBy: 'bW' });
    const pend = req({ from: 'aO', fromRole: 'owner' });
    const sa = directionalState({ messages: [pend, old], viewerIds: A, liveOf: () => true, now: NOW });
    expect(sa.incoming).toMatchObject({ status: 'accepted', live: true, messageId: old._id });
  });

  test('conversation sans demande : deux sens vides', () => {
    const s = directionalState({ messages: [], viewerIds: A, now: NOW });
    expect(s.outgoing.status).toBe('none');
    expect(s.incoming.status).toBe('none');
  });
});
