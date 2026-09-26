/**
 * Mesure d'audience du site (v576) — tests hors ligne, sans base ni réseau.
 *
 * Les helpers testés ici sont des fonctions pures exposées par le modèle
 * (statics) et par le routeur. Aucun appel Mongo n'est effectué : requérir un
 * modèle mongoose ne fait qu'enregistrer un schéma.
 */
const SiteEvent = require('../src/models/SiteEvent');
const siteEventRoutes = require('../src/routes/siteEventRoutes');

const { buildAnalytics, rateLimitAllow, rateLimitReset, RATE_MAX } = siteEventRoutes;

const UA_IPHONE =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';
const UA_DESKTOP =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0 Safari/537.36';
const UA_ANDROID =
  'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0 Mobile Safari/537.36';
const UA_IPAD =
  'Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/604.1';

const NOW = new Date('2026-09-20T10:00:00.000Z');

// ─────────────────────────────────────────────────────────────────────────────
describe('validation et troncature du corps envoyé par le site', () => {
  test('un pageview minimal est accepté et normalisé', () => {
    const doc = SiteEvent.buildEvent(
      { t: 'pageview', p: '/villes/paris', l: 'fr' },
      { ip: '1.2.3.4', userAgent: UA_IPHONE, now: NOW },
    );
    expect(doc).toMatchObject({
      type: 'pageview',
      path: '/villes/paris',
      lang: 'fr',
      device: 'mobile',
      source: 'direct',
      day: '2026-09-20',
      store: '',
      label: '',
    });
    expect(doc.visitor).toMatch(/^[0-9a-f]{16}$/);
  });

  test('un type inconnu est refusé', () => {
    for (const t of ['click', '', null, 'pageview ', 42, { t: 1 }]) {
      expect(SiteEvent.buildEvent({ t, p: '/' }, { userAgent: UA_DESKTOP })).toBeNull();
    }
  });

  test('la query string et le fragment ne sont jamais conservés', () => {
    const doc = SiteEvent.buildEvent(
      { t: 'pageview', p: '/pricing?utm_source=meta&email=daniel@example.com#top' },
      { ip: '1.2.3.4', userAgent: UA_DESKTOP, now: NOW },
    );
    expect(doc.path).toBe('/pricing');
    expect(JSON.stringify(doc)).not.toContain('daniel@example.com');
  });

  test('les chemins hors site sont refusés', () => {
    const cases = [
      'https://evil.example.com/steal',
      '//evil.example.com',
      'pricing',
      '',
      '/admin',
      '/admin/users',
      '/dashboard',
      '/chat/123',
    ];
    for (const p of cases) {
      expect(SiteEvent.buildEvent({ t: 'pageview', p }, { userAgent: UA_DESKTOP })).toBeNull();
    }
    // Une URL absolue du site est ramenée à son chemin.
    expect(SiteEvent.cleanPath('https://www.hopetsit.com/download?x=1')).toBe('/download');
  });

  test('les longueurs sont plafonnées (200 / 80 / 60 caractères)', () => {
    const doc = SiteEvent.buildEvent(
      {
        t: 'cta_click',
        p: `/${'a'.repeat(400)}`,
        us: 'm'.repeat(200),
        um: 'c'.repeat(200),
        uc: 'x'.repeat(200),
        lb: 'L'.repeat(200),
        r: `https://${'h'.repeat(300)}.example.com/page`,
      },
      { ip: '1.2.3.4', userAgent: UA_DESKTOP, now: NOW },
    );
    expect(doc.path.length).toBe(200);
    expect(doc.utmSource.length).toBe(80);
    expect(doc.utmMedium.length).toBe(80);
    expect(doc.utmCampaign.length).toBe(80);
    expect(doc.label.length).toBe(60);
    expect(doc.refHost.length).toBeLessThanOrEqual(100);
  });

  test('langue hors liste blanche → vide, langue du site → conservée', () => {
    expect(SiteEvent.cleanLang('fr')).toBe('fr');
    expect(SiteEvent.cleanLang('PL')).toBe('pl');
    expect(SiteEvent.cleanLang('fr-CA')).toBe('fr');
    expect(SiteEvent.cleanLang('zz')).toBe('');
    expect(SiteEvent.cleanLang('<script>')).toBe('');
  });

  test('du referrer on ne garde que le nom d’hôte, jamais l’URL', () => {
    expect(SiteEvent.hostOf('https://www.google.com/search?q=pet+sitter+paris')).toBe('google.com');
    expect(SiteEvent.hostOf('https://l.facebook.com/l.php?u=xxx')).toBe('l.facebook.com');
    expect(SiteEvent.hostOf('l.instagram.com')).toBe('l.instagram.com');
    expect(SiteEvent.hostOf('')).toBe('');
    expect(SiteEvent.hostOf('pas-un-hote')).toBe('');
    const doc = SiteEvent.buildEvent(
      { t: 'pageview', p: '/', r: 'https://www.google.com/search?q=secret' },
      { ip: '1.2.3.4', userAgent: UA_DESKTOP, now: NOW },
    );
    expect(doc.refHost).toBe('google.com');
    expect(JSON.stringify(doc)).not.toContain('secret');
  });

  test('store et label ne sont posés que sur le bon type d’événement', () => {
    const store = SiteEvent.buildEvent(
      { t: 'store_click', p: '/download', s: 'ios', lb: 'ignoré' },
      { ip: '1.2.3.4', userAgent: UA_IPHONE, now: NOW },
    );
    expect(store.store).toBe('ios');
    expect(store.label).toBe('');

    const cta = SiteEvent.buildEvent(
      { t: 'cta_click', p: '/', s: 'ios', lb: 'hero' },
      { ip: '1.2.3.4', userAgent: UA_DESKTOP, now: NOW },
    );
    expect(cta.store).toBe('');
    expect(cta.label).toBe('hero');

    // Valeur de store inconnue → 'other', jamais la valeur brute.
    const bogus = SiteEvent.buildEvent(
      { t: 'store_click', p: '/download', s: 'windows-phone' },
      { ip: '1.2.3.4', userAgent: UA_DESKTOP, now: NOW },
    );
    expect(bogus.store).toBe('other');
  });

  test('appareil déduit du user-agent', () => {
    expect(SiteEvent.deviceFromUserAgent(UA_IPHONE)).toBe('mobile');
    expect(SiteEvent.deviceFromUserAgent(UA_ANDROID)).toBe('mobile');
    expect(SiteEvent.deviceFromUserAgent(UA_IPAD)).toBe('tablet');
    expect(SiteEvent.deviceFromUserAgent(UA_DESKTOP)).toBe('desktop');
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('classement de la source', () => {
  const src = (o) => SiteEvent.classifySource(o);

  test('pub Meta via utm', () => {
    expect(src({ utmSource: 'meta', utmMedium: 'paid' })).toBe('meta_ads');
    expect(src({ utmSource: 'facebook', utmMedium: 'cpc' })).toBe('meta_ads');
    expect(src({ utmSource: 'instagram', utmMedium: 'paid_social' })).toBe('meta_ads');
    expect(src({ utmSource: 'fb', utmMedium: 'ppc' })).toBe('meta_ads');
    expect(src({ utmSource: 'ig', utmMedium: 'paid' })).toBe('meta_ads');
  });

  test('pub Meta via fbclid (le site envoie us:"fbclid")', () => {
    expect(src({ utmSource: 'fbclid' })).toBe('meta_ads');
    expect(src({ utmSource: 'fbclid', refHost: 'google.com' })).toBe('meta_ads');
  });

  test('pub Google', () => {
    expect(src({ utmSource: 'gclid' })).toBe('google_ads');
    expect(src({ utmSource: 'google', utmMedium: 'cpc' })).toBe('google_ads');
  });

  test('referrer Google → google (référencement naturel)', () => {
    expect(src({ refHost: 'google.com' })).toBe('google');
    expect(src({ refHost: 'www.google.fr' })).toBe('google');
  });

  test('réseaux sans utm → facebook / instagram', () => {
    expect(src({ refHost: 'facebook.com' })).toBe('facebook');
    expect(src({ refHost: 'l.facebook.com' })).toBe('facebook');
    expect(src({ refHost: 'instagram.com' })).toBe('instagram');
  });

  test('rien du tout → direct, le reste → other', () => {
    expect(src({})).toBe('direct');
    expect(src({ utmSource: '', utmMedium: '', refHost: '' })).toBe('direct');
    expect(src({ refHost: 'hopetsit.com' })).toBe('direct'); // navigation interne
    expect(src({ refHost: 'un-blog.example.com' })).toBe('other');
    expect(src({ utmSource: 'newsletter', utmMedium: 'email' })).toBe('other');
  });

  test('la source est toujours une valeur de la liste blanche', () => {
    const doc = SiteEvent.buildEvent(
      { t: 'pageview', p: '/', us: 'meta', um: 'paid', uc: 'dallas_sept' },
      { ip: '1.2.3.4', userAgent: UA_IPHONE, now: NOW },
    );
    expect(SiteEvent.SOURCES).toContain(doc.source);
    expect(doc.source).toBe('meta_ads');
    expect(doc.utmCampaign).toBe('dallas_sept');
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('rejet des robots', () => {
  test('les robots évidents sont reconnus', () => {
    const bots = [
      'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
      'facebookexternalhit/1.1',
      'Mozilla/5.0 (compatible; bingbot/2.0)',
      'Twitterbot/1.0',
      'HeadlessChrome/127.0.0.0',
      'curl/8.4.0',
      'python-requests/2.31.0',
      'AhrefsBot/7.0',
      'SemrushBot/7~bl',
      'Mozilla/5.0 (compatible; YandexBot/3.0)',
      'WhatsApp/2.23',
      '', // aucun user-agent = script, jamais un vrai navigateur
      '   ',
    ];
    for (const ua of bots) expect(SiteEvent.isBotUserAgent(ua)).toBe(true);
  });

  test('les vrais navigateurs passent', () => {
    for (const ua of [UA_IPHONE, UA_DESKTOP, UA_ANDROID, UA_IPAD]) {
      expect(SiteEvent.isBotUserAgent(ua)).toBe(false);
    }
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('empreinte visiteur (anonyme et non réversible)', () => {
  test('identique le même jour pour la même personne', () => {
    const a = SiteEvent.visitorFingerprint('88.120.4.7', UA_IPHONE, '2026-09-20');
    const b = SiteEvent.visitorFingerprint('88.120.4.7', UA_IPHONE, '2026-09-20');
    expect(a).toBe(b);
    expect(a).toMatch(/^[0-9a-f]{16}$/);
  });

  test('différente le lendemain (le sel change chaque jour)', () => {
    const j1 = SiteEvent.visitorFingerprint('88.120.4.7', UA_IPHONE, '2026-09-20');
    const j2 = SiteEvent.visitorFingerprint('88.120.4.7', UA_IPHONE, '2026-09-21');
    expect(j1).not.toBe(j2);
    expect(SiteEvent.dailySalt('2026-09-20')).not.toBe(SiteEvent.dailySalt('2026-09-21'));
  });

  test('différente pour deux personnes différentes le même jour', () => {
    const a = SiteEvent.visitorFingerprint('88.120.4.7', UA_IPHONE, '2026-09-20');
    const b = SiteEvent.visitorFingerprint('88.120.4.8', UA_IPHONE, '2026-09-20');
    const c = SiteEvent.visitorFingerprint('88.120.4.7', UA_DESKTOP, '2026-09-20');
    expect(new Set([a, b, c]).size).toBe(3);
  });

  test('ni l’IP ni le user-agent ne se retrouvent dans le document enregistré', () => {
    const ip = '88.120.4.7';
    const doc = SiteEvent.buildEvent(
      { t: 'pageview', p: '/villes/paris', l: 'fr', us: 'fbclid' },
      { ip, userAgent: UA_IPHONE, now: NOW },
    );
    const serialized = JSON.stringify(doc);
    expect(serialized).not.toContain(ip);
    expect(serialized).not.toContain('iPhone');
    expect(serialized).not.toContain('Mozilla');
    expect(Object.keys(doc).sort()).toEqual([
      'createdAt', 'day', 'device', 'label', 'lang', 'path', 'refHost',
      'source', 'store', 'type', 'utmCampaign', 'utmMedium', 'utmSource',
      'visitor',
    ]);
    // L'empreinte n'est pas l'IP hachée « en clair » : sans le sel du jour,
    // elle ne peut pas être recalculée.
    expect(doc.visitor).toBe(SiteEvent.visitorFingerprint(ip, UA_IPHONE, '2026-09-20'));
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('limitation de débit en mémoire', () => {
  beforeEach(() => rateLimitReset());

  test('60 événements par minute et par empreinte, puis rejet', () => {
    const t0 = 1_000_000;
    for (let i = 0; i < RATE_MAX; i += 1) {
      expect(rateLimitAllow('abc123', t0 + i)).toBe(true);
    }
    expect(rateLimitAllow('abc123', t0 + RATE_MAX)).toBe(false);
    expect(rateLimitAllow('abc123', t0 + RATE_MAX + 1)).toBe(false);
  });

  test('une autre empreinte n’est pas pénalisée', () => {
    const t0 = 2_000_000;
    for (let i = 0; i <= RATE_MAX; i += 1) rateLimitAllow('spam', t0 + i);
    expect(rateLimitAllow('spam', t0 + 100)).toBe(false);
    expect(rateLimitAllow('quelquun-dautre', t0 + 100)).toBe(true);
  });

  test('le compteur repart après la fenêtre d’une minute', () => {
    const t0 = 3_000_000;
    for (let i = 0; i <= RATE_MAX; i += 1) rateLimitAllow('abc', t0);
    expect(rateLimitAllow('abc', t0)).toBe(false);
    expect(rateLimitAllow('abc', t0 + 60_001)).toBe(true);
  });

  test('une empreinte vide est toujours refusée', () => {
    expect(rateLimitAllow('', Date.now())).toBe(false);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('agrégat admin', () => {
  const day = (n) => SiteEvent.shiftDay('2026-09-20', -n);
  const ev = (o) => ({
    type: 'pageview',
    path: '/',
    lang: 'fr',
    device: 'mobile',
    source: 'direct',
    utmCampaign: '',
    day: day(0),
    visitor: 'v1',
    ...o,
  });

  // 2 visiteurs venus de la pub Meta (dont 1 qui clique vers l'App Store),
  // 1 visiteur direct, + de l'historique sur la période précédente.
  const events = [
    ev({ visitor: 'meta1', source: 'meta_ads', path: '/villes/paris', utmCampaign: 'dallas' }),
    ev({ visitor: 'meta1', source: 'meta_ads', path: '/download', utmCampaign: 'dallas' }),
    ev({
      visitor: 'meta1',
      type: 'store_click',
      source: 'meta_ads',
      path: '/download',
      utmCampaign: 'dallas',
    }),
    ev({ visitor: 'meta2', source: 'meta_ads', path: '/villes/paris', utmCampaign: 'dallas', day: day(2) }),
    ev({ visitor: 'direct1', source: 'direct', path: '/', device: 'desktop', lang: 'en' }),
    // Période précédente (J-7 à J-13) : 1 visiteur, 1 page vue.
    ev({ visitor: 'vieux', source: 'direct', path: '/', day: day(9) }),
  ];

  const out = buildAnalytics(events, { days: 7, now: NOW });

  test('période et totaux', () => {
    expect(out.days).toBe(7);
    expect(out.from).toBe('2026-09-14');
    expect(out.to).toBe('2026-09-20');
    expect(out.previousFrom).toBe('2026-09-07');
    expect(out.previousTo).toBe('2026-09-13');
    expect(out.totals).toMatchObject({ pageviews: 4, storeClicks: 1, visitors: 3 });
    expect(out.previous).toMatchObject({ pageviews: 1, visitors: 1 });
  });

  test('comparaison avec la période précédente', () => {
    expect(out.change.pageviews).toBe(300); // 1 → 4
    expect(out.change.visitors).toBe(200); // 1 → 3
    expect(out.change.storeClicks).toBe(100); // 0 → 1
  });

  test('par jour : un point par jour de la période, même vide', () => {
    expect(out.byDay).toHaveLength(7);
    expect(out.byDay[0].day).toBe('2026-09-14');
    expect(out.byDay[6].day).toBe('2026-09-20');
    const today = out.byDay[6];
    expect(today).toMatchObject({ pageviews: 3, visitors: 2, storeClicks: 1 });
  });

  test('par source : LA ligne que Daniel regarde (visiteurs → clics store)', () => {
    const meta = out.bySource.find((s) => s.source === 'meta_ads');
    expect(meta).toMatchObject({
      visitors: 2,
      pageviews: 3,
      storeClicks: 1,
      storeClickRate: 50, // 1 clic store pour 2 visiteurs
    });
    const direct = out.bySource.find((s) => s.source === 'direct');
    expect(direct).toMatchObject({ visitors: 1, pageviews: 1, storeClicks: 0, storeClickRate: 0 });
    expect(out.bySource[0].source).toBe('meta_ads'); // trié par visiteurs
  });

  test('top pages, campagnes, appareils et langues', () => {
    expect(out.topPages.length).toBeLessThanOrEqual(15);
    const paris = out.topPages.find((p) => p.path === '/villes/paris');
    expect(paris).toMatchObject({ pageviews: 2, visitors: 2, storeClicks: 0 });
    const dl = out.topPages.find((p) => p.path === '/download');
    expect(dl).toMatchObject({ pageviews: 1, storeClicks: 1, visitors: 1, storeClickRate: 100 });

    expect(out.byCampaign[0]).toMatchObject({ campaign: 'dallas', visitors: 2, storeClicks: 1 });

    const mobile = out.byDevice.find((d) => d.device === 'mobile');
    expect(mobile).toMatchObject({ visitors: 2, pageviews: 3 });
    const fr = out.byLang.find((l) => l.lang === 'fr');
    expect(fr.visitors).toBe(2);
  });

  test('aucun ensemble interne ne fuit dans la réponse JSON', () => {
    const serialized = JSON.stringify(out);
    expect(serialized).not.toContain('_visitors');
    for (const row of [...out.bySource, ...out.topPages, ...out.byDay]) {
      expect(row._visitors).toBeUndefined();
      expect(typeof row.visitors).toBe('number');
    }
  });

  test('par bouton : chaque libellé compté séparément, avec la part venue de la pub', () => {
    const clics = buildAnalytics([
      ev({ visitor: 'a', type: 'cta_click', label: 'signup_web', path: '/garde-animaux/paris', utmCampaign: 'paris_owners' }),
      ev({ visitor: 'b', type: 'cta_click', label: 'face_sitter', path: '/garde-animaux/paris', utmCampaign: 'paris_owners' }),
      ev({ visitor: 'b', type: 'cta_click', label: 'face_sitter', path: '/garde-animaux/paris' }),
      ev({ visitor: 'c', type: 'store_click', path: '/download' }),
      ev({ visitor: 'd', path: '/garde-animaux/paris' }),
    ], { days: 7, now: NOW }).byCta;
    expect(clics[0]).toEqual({ path: '/garde-animaux/paris', label: 'face_sitter', clicks: 2, fromAds: 1, visitors: 1 });
    expect(clics.find((c) => c.label === 'signup_web')).toMatchObject({ clicks: 1, fromAds: 1 });
    expect(clics.find((c) => c.label === 'store')).toMatchObject({ path: '/download', clicks: 1, fromAds: 0 });
    expect(clics).toHaveLength(3); // les pages vues n'y entrent pas
    expect(JSON.stringify(clics)).not.toContain('_v');
  });

  test('sans aucun événement, la réponse garde la même forme', () => {
    const empty = buildAnalytics([], { days: 30, now: NOW });
    expect(empty.days).toBe(30);
    expect(empty.byDay).toHaveLength(30);
    expect(empty.totals).toMatchObject({ pageviews: 0, visitors: 0, storeClicks: 0, storeClickRate: 0 });
    expect(empty.bySource).toEqual([]);
    expect(empty.topPages).toEqual([]);
    expect(empty.byCta).toEqual([]);
    expect(empty.change).toMatchObject({ pageviews: 0, visitors: 0, storeClicks: 0 });
  });
});
