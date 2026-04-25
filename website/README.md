# HoPetSit — Public Website

Marketing site + login/dashboard for **hopetsit.com**, built with Next.js 14
(App Router) + TypeScript + Tailwind. Connects to the existing Render backend
for authentication. Supports 6 languages (EN default · FR · ES · DE · IT · PT).

## Stack

- **Next.js 14** (App Router)
- **TypeScript** strict
- **Tailwind CSS** with the HoPetSit brand palette (orange / blue / green)
- **next/font** Inter typography
- **Vercel** deployment (free tier — auto-HTTPS, CDN, custom domain)

## Pages

| Route | Purpose |
| --- | --- |
| `/` | Hero + 3 roles + trust grid + CTA |
| `/how-it-works` | 4-step explainer |
| `/pricing` | Owner free, provider 20% (15% Top) |
| `/pawmap` | 9 categories across 29 EU countries |
| `/faq` | 5 frequent questions |
| `/contact` | Contact form (POST `/api/v1/contact`) |
| `/download` | Android APK + Play/App Store soon |
| `/login` | POST `/api/v1/auth/login` |
| `/signup` | POST `/api/v1/auth/signup` (3 roles) |
| `/dashboard` | Logged-in landing — links into the app |
| `/terms` | Terms of Service |
| `/privacy` | Privacy policy (GDPR + UK GDPR + PDPO) |
| `/refund` | Refund policy (Airwallex requirement) |
| `/imprint` | Legal notice (HK company info) |

## Local development

```bash
cd website
npm install
npm run dev
# → http://localhost:3000
```

## Environment variables

Copy `.env.local.example` → `.env.local` if you need to override the API base.

```bash
NEXT_PUBLIC_API_BASE=https://hopetsit-backend.onrender.com/api/v1
```

By default the website hits the production Render backend.

## Deploy to Vercel (custom domain hopetsit.com)

1. Push this folder to a GitHub repo (or use the existing HoPetSit repo with a
   subfolder). On Vercel: **Add new Project → Import** → set Root Directory
   to `website`.
2. Vercel auto-detects Next.js. Click **Deploy**. You get a URL like
   `hopetsit-website.vercel.app`.
3. **Settings → Domains → Add `hopetsit.com`** + `www.hopetsit.com`.
4. Vercel shows the DNS records to add. On Wix DNS panel:
   - **A record** `@` → `76.76.21.21` (TTL 1h)
   - **CNAME** `www` → `cname.vercel-dns.com` (TTL 1h)
   - Leave the existing **MX records** untouched (your `contact@hopetsit.com`
     mailbox keeps working).
5. Propagation 5–30 min. Vercel issues an HTTPS certificate automatically.

## Before you submit Airwallex Payments product

Open `src/app/imprint/page.tsx` and replace the `[TO COMPLETE]` placeholders:

- Hong Kong **CR Number**
- Hong Kong **Business Registration Number**
- **Registered office address** in Hong Kong

These are required in the legal notice for Airwallex compliance review.

## File map

```
website/
├── src/app/                Next.js App Router pages
│   ├── layout.tsx          Root layout (Header + Footer + LanguageProvider)
│   ├── page.tsx            Home
│   ├── how-it-works/...
│   ├── pricing/...
│   ├── pawmap/...
│   ├── faq/...
│   ├── contact/...
│   ├── download/...
│   ├── login/...
│   ├── signup/...
│   ├── dashboard/...
│   ├── terms/...
│   ├── privacy/...
│   ├── refund/...
│   └── imprint/...
├── src/components/         Header, Footer, Logo, LangSwitcher, LegalPage
├── src/lib/
│   ├── api.ts              Backend client (login/signup/contact)
│   └── i18n/
│       ├── translations.ts EN · FR · ES · DE · IT · PT bundle
│       └── LanguageProvider.tsx  Context + useT() hook
└── public/                 favicon and static assets
```

## License

© HoPetSit Limited. All rights reserved.
