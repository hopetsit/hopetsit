// v587 (point 8 de Daniel) — le LIEU du service, de l'annonce à la réservation.
//
//   garde (multi-jours, à domicile, garderie de jour) : chez moi / chez le gardien
//   promenade : récupérer chez moi / point de rendez-vous (+ adresse ou quartier)
//   visites : chez moi, fixé par le serveur
//
// Chaîne testée sur une VRAIE base Mongo en mémoire avec les vrais gestionnaires
// createPost / createPostWithMedia / updatePost / getRequestPosts, puis la
// recopie annonce → candidature → réservation (copyServiceLocation, utilisée
// telle quelle par createApplication et respondToApplication).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/services/translationService', () => ({
  translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })),
}));
jest.mock('../src/services/notificationService', () => ({ createNotificationSafe: jest.fn(async () => null) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => null) }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn() }) }));
jest.mock('../src/services/cloudinary', () => ({
  uploadMedia: jest.fn(async () => ({ url: 'https://example.test/p.jpg', secure_url: 'https://example.test/p.jpg', public_id: 'p', publicId: 'p' })),
}));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const {
  resolveServiceLocation,
  copyServiceLocation,
  serviceFamily,
} = require('../src/utils/serviceLocation587');

let mongo;
let Post;
let Owner;
let Application;
let Booking;
let postController;
let ownerId;

const mockRes = () => {
  const res = {};
  res.status = jest.fn(() => res);
  res.json = jest.fn((b) => { res.body = b; return res; });
  return res;
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Post = require('../src/models/Post');
  Owner = require('../src/models/Owner');
  Application = require('../src/models/Application');
  Booking = require('../src/models/Booking');
  postController = require('../src/controllers/postController');
  // Propriétaire de test en zone fictive (océan, lat −35 / lng −30).
  const r = await Owner.collection.insertOne({
    name: 'Test Lieu 587', email: 'lieu587@example.test', language: 'fr',
    location: { type: 'Point', coordinates: [-30, -35], city: 'Zone test' },
  });
  ownerId = r.insertedId.toString();
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

const publish = async (body) => {
  const res = mockRes();
  await postController.createPost({ user: { id: ownerId, role: 'owner' }, body: {
    body: 'Annonce de test 587', location: { city: 'Zone test', lat: -35, lng: -30 }, ...body,
  } }, res);
  return res;
};

describe('resolveServiceLocation — règle par service', () => {
  test('familles', () => {
    expect(serviceFamily(['dog_walking'])).toBe('walk');
    expect(serviceFamily(['home_visit'])).toBe('visit');
    expect(serviceFamily(['day_care'])).toBe('sitting');
    expect(serviceFamily([])).toBeNull();
  });
  test('garde : chez moi / chez le gardien ; repli sur houseSittingVenue', () => {
    expect(resolveServiceLocation({ serviceTypes: ['day_care'], serviceLocation: 'at_sitter' }))
      .toEqual({ serviceLocation: 'at_sitter', meetingPoint: '' });
    expect(resolveServiceLocation({ serviceTypes: ['house_sitting'], houseSittingVenue: 'sitters_home' }))
      .toEqual({ serviceLocation: 'at_sitter', meetingPoint: '' });
    expect(resolveServiceLocation({ serviceTypes: ['pet_sitting'], serviceLocation: 'pickup' })).toEqual({});
  });
  test('promenade : pickup / meeting_point + adresse', () => {
    expect(resolveServiceLocation({ serviceTypes: ['dog_walking'], serviceLocation: 'meeting_point', meetingPoint: '  Parc  Monceau ' }))
      .toEqual({ serviceLocation: 'meeting_point', meetingPoint: 'Parc Monceau' });
    expect(resolveServiceLocation({ serviceTypes: ['dog_walking'], serviceLocation: 'pickup', meetingPoint: 'x' }))
      .toEqual({ serviceLocation: 'pickup', meetingPoint: '' });
    expect(resolveServiceLocation({ serviceTypes: ['dog_walking'], serviceLocation: 'at_sitter' })).toEqual({});
  });
  test('visites : toujours chez le propriétaire', () => {
    expect(resolveServiceLocation({ serviceTypes: ['home_visit'], serviceLocation: 'at_sitter' }))
      .toEqual({ serviceLocation: 'at_owner', meetingPoint: '' });
  });
});

describe('createPost → base → feed prestataire (vrais gestionnaires)', () => {
  const cases = [
    ['pet_sitting', { serviceLocation: 'at_sitter' }, 'at_sitter', ''],
    ['house_sitting', { houseSittingVenue: 'owners_home' }, 'at_owner', ''],
    ['day_care', { serviceLocation: 'at_sitter' }, 'at_sitter', ''],
    ['dog_walking', { serviceLocation: 'meeting_point', meetingPoint: 'Place de la Nation' }, 'meeting_point', 'Place de la Nation'],
    ['dog_walking', { serviceLocation: 'pickup' }, 'pickup', ''],
    ['home_visit', {}, 'at_owner', ''],
  ];
  test.each(cases)('%s %j → %s', async (svc, extra, expected, mp) => {
    const res = await publish({ serviceTypes: [svc], ...extra });
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.body.post.serviceLocation).toBe(expected);
    expect(res.body.post.meetingPoint || '').toBe(mp);
    const stored = await Post.findById(res.body.post.id).lean();
    expect(stored.serviceLocation).toBe(expected);
    expect(stored.meetingPoint || '').toBe(mp);
  });

  test('ancienne app sans le champ : comportement inchangé (défaut at_owner)', async () => {
    const res = await publish({ serviceTypes: ['day_care'] });
    expect(res.body.post.serviceLocation).toBe('at_owner');
  });

  test('avec photo (with-media, multipart) : le lieu n\'est plus perdu', async () => {
    const res = mockRes();
    await postController.createPostWithMedia({
      user: { id: ownerId, role: 'owner' },
      body: {
        body: 'Annonce photo 587', serviceTypes: 'dog_walking', startDate: '2026-10-01T09:00:00.000Z',
        endDate: '2026-10-01T10:00:00.000Z', serviceLocation: 'meeting_point', meetingPoint: 'Gare de Lyon',
        location: JSON.stringify({ city: 'Zone test', lat: -35, lng: -30 }),
      },
      files: { images: [{ fieldname: 'images', originalname: 'p.jpg', mimetype: 'image/jpeg', buffer: Buffer.from('x') }] },
    }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.body.post.serviceLocation).toBe('meeting_point');
    expect(res.body.post.meetingPoint).toBe('Gare de Lyon');
  });

  test('le feed promeneur porte le lieu et le point de rendez-vous', async () => {
    const res = mockRes();
    await postController.getRequestPosts({ user: { id: new mongoose.Types.ObjectId().toString(), role: 'walker' }, query: {} }, res);
    const posts = (res.body && res.body.posts) || [];
    const walk = posts.find((p) => p.serviceLocation === 'meeting_point');
    expect(walk).toBeTruthy();
    expect(walk.meetingPoint).toBeTruthy();
  });

  test('modifier l\'annonce : pickup → meeting_point', async () => {
    const created = await publish({ serviceTypes: ['dog_walking'], serviceLocation: 'pickup' });
    const res = mockRes();
    await postController.updatePost({
      user: { id: ownerId, role: 'owner' },
      params: { id: created.body.post.id },
      body: { serviceLocation: 'meeting_point', meetingPoint: 'Parc des Buttes' },
    }, res);
    const stored = await Post.findById(created.body.post.id).lean();
    expect(stored.serviceLocation).toBe('meeting_point');
    expect(stored.meetingPoint).toBe('Parc des Buttes');
  });
});

describe('annonce → candidature → réservation', () => {
  test('copyServiceLocation recopie lieu + point de rendez-vous', async () => {
    const p = await Post.create({ ownerId, body: 'x', postType: 'request', serviceTypes: ['dog_walking'], serviceLocation: 'meeting_point', meetingPoint: 'Parc Monceau' });
    const src = await Post.findById(p._id).select('serviceLocation meetingPoint').lean();
    const app = copyServiceLocation(src, {});
    expect(app).toEqual({ serviceLocation: 'meeting_point', meetingPoint: 'Parc Monceau' });
    const booking = copyServiceLocation(app, {});
    expect(booking).toEqual(app);
  });

  test('les schémas Candidature et Réservation acceptent et gardent le champ', () => {
    for (const M of [Application, Booking]) {
      for (const loc of ['at_owner', 'at_sitter', 'both', 'pickup', 'meeting_point']) {
        const d = new M({ serviceLocation: loc, meetingPoint: 'Parc' });
        const err = d.validateSync();
        expect(err?.errors?.serviceLocation).toBeUndefined();
        expect(d.serviceLocation).toBe(loc);
      }
      const bad = new M({ serviceLocation: 'nowhere' }).validateSync();
      expect(bad.errors.serviceLocation).toBeDefined();
      expect(new M({}).serviceLocation).toBeNull();
    }
  });

  test('createApplication et respondToApplication branchent la recopie', () => {
    const src = require('fs').readFileSync(require.resolve('../src/controllers/applicationController'), 'utf8');
    expect(src).toMatch(/copyServiceLocation\(srcPost, locationFromPost\)/);
    expect(src).toMatch(/\.\.\.locationFromPost/);
    expect(src).toMatch(/\.\.\.copyServiceLocation\(application, \{\}\)/);
  });
});
