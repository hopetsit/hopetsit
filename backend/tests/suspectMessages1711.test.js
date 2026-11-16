// 17/11/2026 (BOB, ordre de Daniel) — alerte « messages suspects » de l'admin.
const { detectSuspect, groupSuspects, reasonText, PREFILTER_SOURCE } = require('../src/utils/suspectMessages1711');

describe('detectSuspect', () => {
  test('cas réel du 13/11 : une propriétaire demande Telegram → niveau fort', () => {
    const a = detectSuspect('You’re on telegram', 'owner');
    expect(a).toMatchObject({ level: 'fort', reasons: ['hors_app'], apps: ['Telegram'] });
    const b = detectSuspect('No,Telegram will be preferable', 'owner');
    expect(b.level).toBe('fort');
  });
  test('un gardien qui cite ses messageries → niveau moyen', () => {
    const h = detectSuspect('I have WhatsApp, facebook, instagram and Snapchat.', 'sitter');
    expect(h.level).toBe('moyen');
    expect(h.apps).toEqual(['WhatsApp', 'Snapchat', 'Instagram', 'Facebook / Messenger']);
  });
  test('paiement hors app → fort, quel que soit le rôle', () => {
    expect(detectSuspect('I will send you a check by mail, then you send back the rest', 'owner').level).toBe('fort');
    expect(detectSuspect('Tu peux me payer par PayPal ou en espèces', 'sitter')).toMatchObject({ level: 'fort', payments: ['PayPal', 'Espèces'] });
    expect(detectSuspect('buy a gift card for me', 'owner').payments).toEqual(['Carte cadeau']);
  });
  test('coordonnées masquées seules : jamais une alerte', () => {
    expect(detectSuspect('You can call me at [MASQUÉ] when you get some time.', 'sitter')).toBeNull();
    const h = detectSuspect('écris-moi sur whatsapp [MASQUÉ]', 'sitter');
    expect(h.reasons).toEqual(['hors_app', 'coordonnees']);
  });
  test('messages normaux : rien', () => {
    for (const t of [
      'Bonjour ! Je suis disponible pour ton animal 🐾',
      'Bonjour Madame je pourrais le prendre en garde votre chien, je souhaiterais savoir la race svp',
      'Where do you stay now', 'I do long term sits', '', null,
      'Je vous enverrai des photos et des nouvelles chaque jour',
      'Le signal GPS était faible pendant la promenade', 'Il adore jouer avec les instants de calme',
    ]) expect(detectSuspect(t, 'owner')).toBeNull();
  });
  test('la présélection en base attrape tout ce que la détection attrape', () => {
    const re = new RegExp(PREFILTER_SOURCE, 'i');
    for (const t of ['You’re on telegram', 'par paypal', 'cash app me', 'on WhatsApp', 'wire transfer']) {
      expect(re.test(t)).toBe(true);
      expect(detectSuspect(t)).not.toBeNull();
    }
    expect(re.test('Bonjour, je suis disponible')).toBe(false);
  });
  test('phrase pour l\'admin', () => {
    expect(reasonText(detectSuspect('telegram or paypal [MASQUÉ]', 'owner')))
      .toBe("demande de passer sur Telegram · paiement hors de l'app (PayPal) · coordonnées envoyées");
  });
});

describe('groupSuspects', () => {
  const C1 = 'a'.repeat(24); const C2 = 'b'.repeat(24); const O = 'c'.repeat(24); const S = 'd'.repeat(24);
  const msgs = [
    { conversationId: C1, senderRole: 'owner', senderId: O, body: 'You’re on telegram', createdAt: '2026-11-13T20:58:00Z' },
    { conversationId: C1, senderRole: 'owner', senderId: O, body: 'Am here for you to petsit my baby', createdAt: '2026-11-13T21:00:00Z' },
    { conversationId: C1, senderRole: 'sitter', senderId: S, body: 'I have WhatsApp, facebook', createdAt: '2026-11-14T05:26:00Z' },
    { conversationId: C2, senderRole: 'owner', senderId: O, body: 'No,Telegram will be preferable', createdAt: '2026-11-13T21:01:00Z' },
    { conversationId: C2, senderRole: 'owner', senderId: O, body: 'telegram please', createdAt: '2026-11-13T21:05:00Z' },
  ];
  const g = groupSuspects(msgs);
  test('une ligne par expéditeur et par conversation, forts d\'abord', () => {
    expect(g.map((x) => [x.conversationId[0], x.senderRole, x.level, x.count])).toEqual([
      ['b', 'owner', 'fort', 2], ['a', 'owner', 'fort', 1], ['a', 'sitter', 'moyen', 1],
    ]);
  });
  test('extrait = dernier message suspect, dates et clé', () => {
    expect(g[0].excerpt).toBe('telegram please');
    expect(g[0].firstAt).toBe('2026-11-13T21:01:00.000Z');
    expect(g[0].lastAt).toBe('2026-11-13T21:05:00.000Z');
    expect(g[0].key).toBe(`${C2}:owner:${O}`);
    expect(g[0].reason).toBe('demande de passer sur Telegram');
  });
  test('liste vide', () => { expect(groupSuspects([])).toEqual([]); expect(groupSuspects(null)).toEqual([]); });
});
