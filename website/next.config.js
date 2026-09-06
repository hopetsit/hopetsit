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
  // v23.1.267 — SEO/marketing : les chemins FR partagés (pubs, anciens liens)
  // n'existaient pas comme routes (le site est mono-URL avec switch de langue
  // client) → 404. On les redirige vers leur équivalent EN (308 permanent).
  async redirects() {
    return [
      // v551 — l'APK (93 Mo) qui vivait dans public/ est retiré : il était
      // recopié dans CHAQUE déploiement Vercel et a rempli à lui seul les
      // 10 Go de stockage inclus (aucune page du site ne le référençait, et
      // il datait de la v401). Le lien direct est redirigé vers la page de
      // téléchargement officielle pour ne casser aucun partage passé.
      { source: '/HoPetSit.apk', destination: '/download', permanent: true },
      { source: '/tarifs', destination: '/pricing', permanent: true },
      { source: '/comment-ca-marche', destination: '/how-it-works', permanent: true },
      { source: '/telecharger', destination: '/download', permanent: true },
      { source: '/confidentialite', destination: '/privacy', permanent: true },
      { source: '/mentions-legales', destination: '/imprint', permanent: true },
    ];
  },

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
