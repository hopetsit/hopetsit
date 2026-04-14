# Backend test suite — follow-up TODOs

Sprint 8 step 7 shipped unit tests for the pure utilities (encryption, IBAN,
country/currency, Stripe country resolver, phone mask, referral codes, i18n
template). The following integration / controller suites still need to be
written — each requires `mongodb-memory-server` and HTTP fixtures.

- [ ] **Auth** — signup, login, JWT verify, suspended/banned block, multi-account same phone.
- [ ] **Booking state machine** — pending → accepted → agreed → paid → completed; refused transitions.
- [ ] **Stripe** — createPaymentIntent amount math, 20 % vs 15 % Top Sitter, currency fallback from sitter.country.
- [ ] **Reviews** — mutual owner↔sitter, block if booking not completed, admin hide/restore/delete, reply once only.
- [ ] **Loyalty** — credit on 3rd/6th/9th, Premium at 10, Top Sitter at 20+4.5★ via bookings + reviews.
- [ ] **Referrals** — unique code generation, first-booking credit to referrer.

Helpers to build first:
- `tests/fixtures/mongo.js` — boots MongoMemoryServer, disconnects after suite.
- `tests/fixtures/factories.js` — createOwner/createSitter/createBooking/completeBooking helpers.
- `tests/fixtures/app.js` — wraps the Express app with a seeded user + returns supertest agent.
