// v604 (PAM) — « Arrêter de suivre » depuis la PawMap : un seul sens.
const { conversationsFollowing } = require('../src/utils/followStop604');
const pf = require('../src/utils/pawfollowState604');

const A = 'a'.repeat(24);
const B = 'b'.repeat(24);

// Demande « je partage ma position » envoyée par un prestataire : le
// partageur est le demandeur.
const shares = (sharer, other, conv) => ({
  _id: `${sharer}-${conv}`,
  type: 'pawfollow_request',
  conversationId: conv,
  senderId: sharer,
  metadata: { status: 'accepted', requesterId: sharer, requesterRole: 'walker', respondedBy: other },
});

describe('followStop604.conversationsFollowing', () => {
  test('suivi mutuel : A arrête de suivre B → seule la demande où B partage', () => {
    const msgs = [shares(B, A, 'c1'), shares(A, B, 'c1')];
    // A ne suit plus B : conversations où B partage.
    expect(conversationsFollowing(msgs, { targetIds: [B], sharerIdOf: pf.sharerIdOf })).toEqual(['c1']);
    // Et la règle de ZOE ne termine alors que le sens entrant de A.
    const stop = pf.selectToStop(msgs, [A], { scope: 'following' });
    expect(stop.map((m) => m._id)).toEqual([`${B}-c1`]);
  });

  test('aucune demande où la cible partage → rien', () => {
    const msgs = [shares(A, B, 'c1')];
    expect(conversationsFollowing(msgs, { targetIds: [B], sharerIdOf: pf.sharerIdOf })).toEqual([]);
  });

  test('plusieurs demandes dans la même conversation → une seule fois', () => {
    const msgs = [shares(B, A, 'c1'), { ...shares(B, A, 'c1'), _id: 'x' }, shares(B, A, 'c2')];
    expect(conversationsFollowing(msgs, { targetIds: [B], sharerIdOf: pf.sharerIdOf })).toEqual(['c1', 'c2']);
  });
});
