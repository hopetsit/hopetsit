// v602 (PAM, 29/09) — une notification de suivi en direct ouvre LA demande
// (la conversation où vit la carte Accepter / Refuser), jamais l'écran Amis.
const { buildAppRoute } = require('../src/utils/emailLinkBuilder');

const conv = '64b7f0c2a1b2c3d4e5f60718';

describe('routes des notifications de suivi en direct (602)', () => {
  test('demande reçue → la conversation', () => {
    expect(buildAppRoute('live_tracking_request_received', { conversationId: conv })).toBe(`/chat/${conv}`);
  });
  test('demande reçue sans conversation → liste des conversations, pas les Amis', () => {
    expect(buildAppRoute('live_tracking_request_received', { bookingId: conv })).toBe('/chat');
  });
  test('acceptée → la conversation (carte « Voir sur la carte »)', () => {
    expect(buildAppRoute('live_tracking_accepted', { conversationId: conv })).toBe(`/chat/${conv}`);
    expect(buildAppRoute('live_tracking_accepted', {})).toBe('/friends/live');
  });
  test('refusée → la conversation', () => {
    expect(buildAppRoute('live_tracking_refused', { conversationId: conv })).toBe(`/chat/${conv}`);
    expect(buildAppRoute('live_tracking_refused', {})).toBe('/chat');
  });
  test('balade démarrée / terminée → la balade (inchangé)', () => {
    expect(buildAppRoute('walk_started', { bookingId: conv })).toBe(`/walk/${conv}`);
    expect(buildAppRoute('walk_finished', { bookingId: conv })).toBe(`/walk/${conv}`);
  });
  test('autres types Amis inchangés', () => {
    expect(buildAppRoute('friend_request_received', {})).toBe('/friends/requests');
    expect(buildAppRoute('live_still_active', {})).toBe('/friends/live');
  });
});
