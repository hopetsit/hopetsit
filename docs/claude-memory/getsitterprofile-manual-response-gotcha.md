---
name: getsitterprofile-manual-response-gotcha
description: "getSitterProfile builds its JSON by hand (not sanitizeUser), so new Sitter fields silently disappear from the API unless added there too"
metadata: 
  node_type: memory
  type: project
  originSessionId: e5b5c8c0-64b1-4791-83d5-983edf5b98ab
---

`backend/src/controllers/sitterController.js` → `getSitterProfile` builds its
response object **by hand** (an explicit `{ id, name, rating, ... }` literal),
NOT via `sanitizeUser`. So any new field on the Sitter model is silently absent
from `GET /sitters/:id` until you add it to that literal too.

This caused the v296 "Top Sitter stuck at 0/20" bug: `completedServicesCount` /
`averageRating` / `isTopSitter` existed on the model and were recomputed
correctly, but the hand-built response never returned them, so `TopSitterCard`
always read 0. Fixed by adding the 3 fields + a self-heal `recomputeSitterStatus(id)`
on read.

**Why:** contrast with `getWalkerProfile` (walkerController) which uses
`sanitizeUser(walker)` → `sanitizeDoc` spreads ALL fields, so new Walker fields
appear automatically. The two provider endpoints are NOT symmetric.

**How to apply:** when adding a Sitter field that the app/website must read,
edit the `sitterProfile` literal in `getSitterProfile` (and check any other
hand-built response). Same class of bug as the Mongoose strict-mode `$set`
field-drop (Post.status). Related: [[backend-strict-mode-drops-unknown-fields]] if present.
