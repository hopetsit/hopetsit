# Marketing automatisé HoPetSit

Ce dossier est alimenté chaque **dimanche 7 h (Paris)** par la routine cloud
« HoPetSit — Marketing dimanche (Paris d'abord) » (id `trig_01BpzyjaJz7SPDgPFCdjinQM`,
gestion : https://claude.ai/code/routines). L'agent clone ce dépôt, écrit,
vérifie (`npx tsc --noEmit`) et pousse sur `main` → Vercel déploie.

## Priorités (décision du fondateur)
1. **Paris / France** — obtenir les premiers clients : recruter des pet sitters
   parisiens (semaines impaires), puis parler aux propriétaires (semaines paires).
2. USA, Pologne (Varsovie), Corée (Séoul) — un article chacun le premier
   dimanche du mois.

## Ce que produit chaque run
- `website/src/app/blog/<slug>/page.tsx` — l'article (même structure que
  `devenir-pet-sitter-combien-ca-rapporte`), ajouté en tête de `POSTS`
  (`blog/page.tsx`) et au `sitemap.ts`.
- `social/<AAAA>-W<ss>.md` — 3 posts FR (Facebook groupes Paris, Instagram,
  story) + 1 PL + 1 EN, prêts à copier-coller.
- `reports/<AAAA>-W<ss>.md` — récap 10 lignes : publié, prochains sujets,
  actions humaines utiles.

## Pages SEO « devenir pet sitter à <ville> »
Générées depuis `website/src/lib/recruit-cities.ts` : une ligne = une page.
- FR : `/devenir-petsitter/paris-1` … `paris-20`, communes limitrophes, grandes villes
- EN : `/become-a-pet-sitter/<city>` · PL : `/zostan-opiekunem/<miasto>` · KO : `/pet-sitter-korea/<city>`

## Règles pour l'agent (et pour tout humain)
- Ne jamais toucher `frontend/`, `backend/`, `admin_dashboard.html`, ni un secret.
- Ne jamais modifier ou supprimer un article existant ; jamais de slug en double.
- Fourchettes de prix uniquement celles des pages existantes ; aucune
  affirmation juridique ou fiscale précise.
- Pas de Markdown gras dans les textes de posts (affiché tel quel sur Instagram/Facebook).

## Ce qui reste humain
- Publier les posts de `social/` dans les groupes Facebook / Instagram
  (ou brancher le jeton Meta : voir `~/hopetsit-social/MODE_EMPLOI.md`).
- Google Ads (l'interface refuse toute automatisation).
- Demander des avis 5 étoiles aux prestataires.
