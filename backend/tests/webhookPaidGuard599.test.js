// v599 — FLO : un payment_intent.failed/cancelled tardif n'écrase jamais une réservation payée.
process.env.NODE_ENV = 'test';
const { failedEventStatus } = require('../src/utils/webhookPaidGuard599');
test('réservation déjà payée : événement ignoré', () => {
  expect(failedEventStatus({ paymentStatus: 'paid', status: 'paid' }, 'payment_intent.failed')).toBeNull();
  expect(failedEventStatus({ paymentStatus: 'paid', status: 'paid' }, 'payment_intent.cancelled')).toBeNull();
  expect(failedEventStatus({ paymentStatus: 'pending', status: 'paid' }, 'payment_intent.cancelled')).toBeNull();
});
test('réservation non payée : failed → failed, cancelled → cancelled', () => {
  expect(failedEventStatus({ paymentStatus: 'pending', status: 'accepted' }, 'payment_intent.failed')).toBe('failed');
  expect(failedEventStatus({ paymentStatus: 'pending', status: 'agreed' }, 'payment_intent.cancelled')).toBe('cancelled');
});
test('événement inconnu ou réservation absente : rien', () => {
  expect(failedEventStatus({ paymentStatus: 'pending' }, 'payment_intent.succeeded')).toBeNull();
  expect(failedEventStatus(null, 'payment_intent.failed')).toBeNull();
});
