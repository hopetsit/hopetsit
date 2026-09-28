// v599 (29/09/2026) — qui peut répondre à une demande de suivi en direct.
// Daniel : son frère (propriétaire) lui a envoyé une demande depuis le chat,
// impossible de l'accepter. Avant, le destinataire était désigné par son
// RÔLE ; entre deux propriétaires amis, ou quand le destinataire ouvre le
// chat sous un autre de ses profils, personne ne pouvait répondre.
const { respondDecision, participantIds } = require('../src/utils/pawfollowRespond599');

const msg = ({ metadata, ...over } = {}) => ({
  type: 'pawfollow_request',
  senderId: 'frereO',
  metadata: { status: 'pending', requesterId: 'frereO', requesterRole: 'owner', responderRole: 'owner', ...(metadata || {}) },
  ...over,
});

describe('respondDecision — la personne compte, pas le rôle', () => {
  const amis = { friendChat: true, participants: [{ userId: 'frereO', userModel: 'Owner' }, { userId: 'danielO', userModel: 'Owner' }] };
  const garde = { ownerId: 'frereO', sitterId: 'danielS' };

  test('deux propriétaires amis : Daniel (propriétaire) peut accepter', () => {
    expect(respondDecision({ message: msg(), conversation: amis, myIds: ['danielO', 'danielS', 'danielW'] })).toEqual({ ok: true });
  });

  test('le frère ne répond pas à sa propre demande, sous aucun de ses profils', () => {
    const d = respondDecision({ message: msg(), conversation: amis, myIds: ['frereO', 'frereS'] });
    expect(d.ok).toBe(false);
    expect(d.code).toBe('OWN_REQUEST');
    expect(d.status).toBe(403);
  });

  test('conversation de garde : Daniel connecté en PROPRIÉTAIRE répond quand même (autre profil de la même personne)', () => {
    const m = msg({ metadata: { responderRole: 'sitter' } });
    expect(respondDecision({ message: m, conversation: garde, myIds: ['danielO', 'danielS'] })).toEqual({ ok: true });
  });

  test('un inconnu de la conversation est refusé', () => {
    const d = respondDecision({ message: msg(), conversation: amis, myIds: ['autre'] });
    expect(d).toMatchObject({ ok: false, status: 403, code: 'NOT_PARTICIPANT' });
  });

  test('demande déjà traitée : 409', () => {
    const m = msg({ metadata: { status: 'accepted' } });
    expect(respondDecision({ message: m, conversation: amis, myIds: ['danielO'] })).toMatchObject({ ok: false, status: 409, code: 'ALREADY_RESPONDED' });
  });

  test('pas une demande de suivi : 400', () => {
    expect(respondDecision({ message: { type: 'text' }, conversation: amis, myIds: ['danielO'] })).toMatchObject({ ok: false, status: 400 });
  });

  test('participantIds lit les deux formes de conversation (ids peuplés ou bruts)', () => {
    expect(participantIds({ friendChat: true, participants: [{ userId: { _id: 'a' } }, { userId: 'b' }] })).toEqual(['a', 'b']);
    expect(participantIds({ ownerId: { _id: 'o' }, walkerId: 'w' })).toEqual(['o', 'w']);
    expect(participantIds(null)).toEqual([]);
  });
});
