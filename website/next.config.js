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
};

module.exports = nextConfig;
