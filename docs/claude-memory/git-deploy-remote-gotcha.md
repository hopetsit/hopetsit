---
name: git-deploy-remote-gotcha
description: "Deploys go through `origin` (hopetsit/hopetsit) — NOT the `dadaciao` remote; local work must be committed+pushed or Render keeps serving old code"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

The repo at `HopeTSIT_FINAL/` has TWO remotes:
- **`origin` = https://github.com/hopetsit/hopetsit.git — THE deploy remote.** Render (hopetsit-backend.onrender.com, auto-deploy) and Vercel (hopetsit.com, serves `website/public/HoPetSit.apk`) both build from `origin/main`. `branch.main.remote=origin`.
- `dadaciao` = https://github.com/dadaciao84-ai/hopetsit.git — STALE (tip stuck at v23.1.202/203, May 23, diverged at v197). Pushing there is rejected non-fast-forward and deploys nothing.

**Why:** in June 2026 Daniel "redeployed" Render repeatedly and kept getting v336 — the cause was that sessions v337–v344 edited files locally without ever committing; Render rebuilt the same old origin/main commit. Lost a whole cycle on it.

**How to apply:** after any backend/website change that must go live: `git add -A && git commit && git push origin main` (NOT dadaciao). Verify with https://hopetsit-backend.onrender.com/__build (must match `ADMIN_BUILD` in backend/src/app.js). Render build takes ~3–8 min after push. The ~92MB APK in website/public triggers a GitHub size warning — expected, under the 100MB hard limit. See [[payment-escrow-mechanism]] for why stale deploys are dangerous (money fixes only protect once deployed).
