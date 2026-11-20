// 20/11/2026 (BOB) — photo trop lourde : réponse 413 claire au lieu de 500 + alerte Sentry.
const express = require('express');
const multer = require('multer');
const request = require('supertest');
const { uploadErrorResponse } = require('../src/utils/uploadError2011');

describe('uploadErrorResponse — fonction pure', () => {
  const tropLourd = new multer.MulterError('LIMIT_FILE_SIZE', 'avatar');

  test('photo trop lourde : 413 + code, en français', () => {
    const r = uploadErrorResponse(tropLourd, 'fr-FR,fr;q=0.9');
    expect(r.status).toBe(413);
    expect(r.body.code).toBe('FILE_TOO_LARGE');
    expect(r.body.error).toMatch(/trop lourde/);
  });
  test('autre langue ou en-tête absent : anglais', () => {
    expect(uploadErrorResponse(tropLourd, 'en-US').body.error).toMatch(/too large/);
    expect(uploadErrorResponse(tropLourd, undefined).body.error).toMatch(/too large/);
    expect(uploadErrorResponse(tropLourd, 'de-DE').body.error).toMatch(/too large/);
  });
  test('trop de fichiers / champ inattendu : 400', () => {
    expect(uploadErrorResponse(new multer.MulterError('LIMIT_FILE_COUNT'), 'fr')).toMatchObject({ status: 400, body: { code: 'TOO_MANY_FILES' } });
    expect(uploadErrorResponse(new multer.MulterError('LIMIT_UNEXPECTED_FILE', 'x'), 'fr')).toMatchObject({ status: 400, body: { code: 'UNEXPECTED_FILE' } });
  });
  test('code multer inconnu : 400 générique, jamais 500', () => {
    expect(uploadErrorResponse(new multer.MulterError('LIMIT_PART_COUNT'), 'fr')).toMatchObject({ status: 400, body: { code: 'UPLOAD_REJECTED' } });
  });
  test('une vraie panne n\'est PAS avalée', () => {
    expect(uploadErrorResponse(new Error('base indisponible'), 'fr')).toBeNull();
    expect(uploadErrorResponse(null, 'fr')).toBeNull();
    expect(uploadErrorResponse({ name: 'TypeError', code: 'LIMIT_FILE_SIZE' }, 'fr')).toBeNull();
  });
});

describe('parcours réel : multer + gestionnaire d\'erreurs', () => {
  const alertes = [];
  const app = express();
  const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 1024 } });
  app.put('/photo', upload.single('avatar'), (req, res) => res.json({ ok: true, size: req.file.size }));
  app.get('/panne', () => { throw new Error('panne'); });
  // Même ordre que dans src/app.js : le refus d'envoi d'abord, l'alerte ensuite.
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    const refus = uploadErrorResponse(err, req.headers['accept-language']);
    if (refus) { res.status(refus.status).json(refus.body); return; }
    alertes.push(err.message);
    res.status(500).json({ error: 'Internal server error' });
  });

  beforeEach(() => { alertes.length = 0; });

  test('fichier au-dessus de la limite : 413, message clair, aucune alerte', async () => {
    const res = await request(app).put('/photo').set('Accept-Language', 'fr-FR')
      .attach('avatar', Buffer.alloc(5000, 1), 'photo.jpg');
    expect(res.status).toBe(413);
    expect(res.body).toEqual({ error: expect.stringMatching(/trop lourde/), code: 'FILE_TOO_LARGE' });
    expect(alertes).toEqual([]);
  });
  test('fichier sous la limite : passe comme avant', async () => {
    const res = await request(app).put('/photo').attach('avatar', Buffer.alloc(500, 1), 'photo.jpg');
    expect(res.status).toBe(200);
    expect(res.body.size).toBe(500);
  });
  test('une vraie panne reste un 500 avec alerte', async () => {
    const res = await request(app).get('/panne');
    expect(res.status).toBe(500);
    expect(alertes).toEqual(['panne']);
  });
});

describe('src/app.js branche bien le refus avant l\'alerte Sentry', () => {
  test('ordre dans le gestionnaire global', () => {
    const src = require('fs').readFileSync(require('path').join(__dirname, '../src/app.js'), 'utf8');
    const iRefus = src.indexOf("require('./utils/uploadError2011')");
    const iSentry = src.indexOf('sentry.captureException(err, {');
    expect(iRefus).toBeGreaterThan(0);
    expect(iSentry).toBeGreaterThan(iRefus);
  });
});
