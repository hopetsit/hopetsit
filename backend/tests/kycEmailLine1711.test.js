// 17/11/2026 (BOB, « tout pour la première vente ») — ligne « identité offerte » dans les e-mails déjà envoyés
// aux gardiens et promeneurs sans badge. Aucun e-mail en plus.
const { kycLineFor1711, buildNotificationEmailHtml } = require('../src/services/emailService');

const ON = {};

describe('kycLineFor1711 — qui voit la ligne', () => {
  test('gardien et promeneur sans badge : oui, dans leur langue (anglais par défaut)', () => {
    expect(kycLineFor1711('sitter', { kycStatus: 'none' }, 'fr', ON)).toMatch(/^Vérifie ton identité gratuitement/);
    expect(kycLineFor1711('walker', {}, 'en', ON)).toMatch(/^Verify your identity for free/);
    expect(kycLineFor1711('sitter', { kycStatus: 'pending_verification' }, 'xx', ON)).toMatch(/^Verify your identity for free/);
    for (const l of ['fr', 'en', 'es', 'de', 'it', 'pt', 'pl', 'ko', 'ja']) {
      expect(kycLineFor1711('sitter', { kycStatus: 'none' }, l, ON).length).toBeGreaterThan(40);
    }
  });
  test('jamais : propriétaire, déjà vérifié (KYC ou validation manuelle), destinataire inconnu', () => {
    expect(kycLineFor1711('owner', { kycStatus: 'none' }, 'fr', ON)).toBe('');
    expect(kycLineFor1711('sitter', { kycStatus: 'verified' }, 'fr', ON)).toBe('');
    expect(kycLineFor1711('walker', { identityVerification: { status: 'verified' } }, 'fr', ON)).toBe('');
    expect(kycLineFor1711('sitter', null, 'fr', ON)).toBe('');
  });
  test('coupe-circuits : la ligne seule, ou l\'offre gratuite éteinte (on ne promet pas « gratuit » à 3 €)', () => {
    expect(kycLineFor1711('sitter', { kycStatus: 'none' }, 'fr', { KYC_EMAIL_LINE_1711: 'off' })).toBe('');
    expect(kycLineFor1711('sitter', { kycStatus: 'none' }, 'fr', { KYC_FREE_1711: 'off' })).toBe('');
  });
});

describe('buildNotificationEmailHtml — rendu de la ligne', () => {
  const inner = '<p>Bonjour</p>';
  test('sans ligne : e-mail identique à avant (aucun bloc ajouté)', () => {
    const html = buildNotificationEmailHtml(inner, { locale: 'fr' });
    expect(html).not.toContain('🪪');
    expect(html).toBe(buildNotificationEmailHtml(inner, { locale: 'fr', kycLine: '' }));
  });
  test('avec ligne : un seul bloc, texte échappé, avant la ligne « app »', () => {
    const html = buildNotificationEmailHtml(inner, { locale: 'fr', kycLine: 'Vérifie <b>ton</b> identité' });
    expect(html.split('🪪').length - 1).toBe(1);
    expect(html).toContain('Vérifie &lt;b&gt;ton&lt;/b&gt; identité');
    expect(html.indexOf('🪪')).toBeLessThan(html.indexOf('📲'));
  });
});
