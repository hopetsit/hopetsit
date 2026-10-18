// 619 (BOB, 19/10/2026) — photos : plafond à l'envoi et adresse de livraison
// allégée (l'ancien compte Cloudinary a été coupé pour dépassement du quota).
process.env.CLOUDINARY_CLOUD_NAME = 'cloudtest';
process.env.CLOUDINARY_API_KEY = 'cle-de-test';
process.env.CLOUDINARY_API_SECRET = 'secret-de-test';
const cld = require('../src/services/cloudinary');

describe('619 — livraison des photos allégée', () => {
  test('image : largeur plafonnée, qualité et format automatiques, bon cloud', () => {
    const u = cld.deliveryUrl({ resource_type: 'image', public_id: 'petsinsta/sitters/abc', version: 1792000000, format: 'jpg', secure_url: 'https://res.cloudinary.com/cloudtest/image/upload/v1792000000/petsinsta/sitters/abc.jpg' });
    expect(u).toMatch(/^https:\/\/res\.cloudinary\.com\/cloudtest\/image\/upload\//);
    expect(u).toContain('c_limit');
    expect(u).toContain(`w_${cld.MAX_DELIVERY_PX}`);
    expect(u).toContain(`h_${cld.MAX_DELIVERY_PX}`);
    expect(u).toContain('q_auto');
    expect(u).toContain('f_auto');
    expect(u).toContain('/v1792000000/petsinsta/sitters/abc.jpg');
  });
  test('vidéo ou résultat incomplet : adresse d\'origine, jamais de transformation', () => {
    const v = { resource_type: 'video', public_id: 'petsinsta/chat/vid', secure_url: 'https://res.cloudinary.com/cloudtest/video/upload/v1/petsinsta/chat/vid.mp4' };
    expect(cld.deliveryUrl(v)).toBe(v.secure_url);
    expect(cld.deliveryUrl(null)).toBe('');
    expect(cld.deliveryUrl({ resource_type: 'image', secure_url: 'https://x/y.jpg' })).toBe('https://x/y.jpg');
  });
  test('plafonds : 2 000 px à l\'envoi, 1 600 px à l\'affichage', () => {
    expect(cld.MAX_UPLOAD_PX).toBe(2000);
    expect(cld.MAX_DELIVERY_PX).toBe(1600);
  });
});
