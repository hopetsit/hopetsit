/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'res.cloudinary.com' },
      { protocol: 'https', hostname: 'hopetsit-backend.onrender.com' },
    ],
  },
  // v20.1 — toutes les pages publiques sont rendues côté client/static.
  // Le backend HoPetSit (Render) reste l'unique source de vérité pour
  // l'auth/booking/data; le site web sert de vitrine + login/dashboard.

  // v23.1 part 146 — headers forcés pour les fichiers `.well-known`.
  // Apple exige que `apple-app-site-association` soit servi avec
  //   Content-Type: application/json
  // SANS extension .json dans l'URL. Vercel/Next sinon devine MIME via
  // l'extension → octet-stream → iOS rejette → Universal Links morts.
  // Android `assetlinks.json` accepte tout content-type JSON mais on le
  // pin aussi par cohérence.
  async headers() {
    return [
      {
        source: '/.well-known/apple-app-site-association',
        headers: [
          { key: 'Content-Type', value: 'application/json' },
          { key: 'Cache-Control', value: 'public, max-age=3600' },
        ],
      },
      {
        source: '/.well-known/assetlinks.json',
        headers: [
          { key: 'Content-Type', value: 'application/json' },
          { key: 'Cache-Control', value: 'public, max-age=3600' },
        ],
      },
    ];
  },
};

module.exports = nextConfig;
