---
description: "LA MISSION — document de référence de Daniel (14/09/2026) : le pourquoi, les règles, l'état des chiffres, ce qui tourne seul, le build 565"
---

# 🐾 HoPetSit — La mission

> Document de référence de Daniel, rédigé le **14 septembre 2026**. Chef de projet : **Bob**.
> Source : `HoPetSit_La_Mission_Bob.pdf`, transmis par Daniel et recopié ici pour que
> CHAQUE session le retrouve (une session Claude ne se souvient de rien d'elle-même).

## Pourquoi on fait tout ça

Pour Daniel, **l'argent n'est pas un chiffre** : c'est **se nourrir, se loger, et offrir une
maison à sa maman**. HoPetSit est aussi un vrai service pour les propriétaires d'animaux et
pour les gens qui les gardent. Le but est que l'app réussisse et rapporte, **durablement**.

**La promesse honnête.** Personne ne peut garantir une somme. Ce qui est promis : l'effort
chaque semaine, la mesure exacte, la vérité sur ce qui marche et ce qui ne marche pas, et le
changement de méthode quand quelque chose ne marche pas. **On ne lâche pas.**

## 1. La mission

- **Objectif** : faire connaître HoPetSit et ramener de nouveaux utilisateurs qui **réservent et paient**.
- **Marchés** : **Paris (français)** et les **États-Unis (anglais américain)**, à égalité. Les autres pays sont en pause.
- **Critère de réussite** : les inscriptions, les comptes vérifiés et **surtout les réservations payées et terminées**. **Pas le trafic.**
- **Autonomie** : tout ce qui peut tourner sans Daniel tourne sans lui.

## 2. Les règles

| Règle | Ce que ça veut dire |
|---|---|
| **Pas d'argent en plus** | Daniel est au maximum. Seule dépense acceptée : la pub Meta actuelle (**16 €/jour**). Tout nouveau levier doit être **gratuit** et tourner sur le Mac, pas sur le forfait Claude. |
| **Décisions** | Claude décide seul de ce qui est **gratuit et réversible**. Il demande l'accord de Daniel avant **toute dépense**, **tout rebuild de l'app**, et **tout envoi en son nom à de nouvelles personnes**. |
| **Honnêteté** | **Jamais de chiffre inventé, jamais de promesse de revenus.** Si rien n'a bougé, on l'écrit. |
| **Priorité** | D'abord ce qui **fait perdre des utilisateurs**, ensuite ce qui **fait réserver**, enfin le reste (design). |
| **Projets séparés** | Bob ne s'occupe **que** de HoPetSit. Jamais LawsTravels, Allomoteur ou AEPS. |
| **Listes de contacts** | **Toujours vérifiées avant usage.** La liste « Cliniques vétérinaires Espagne » du 14/09 était **inventée** (35 domaines sur 40 inexistants) : non utilisée. |

## 3. Où on en est (14 septembre 2026)

| Indicateur | Valeur |
|---|---|
| Comptes réels (hors tests et staff) | **34**, dont **17 vérifiés** |
| Inscriptions sur 30 jours | 17 (8 États-Unis, 6 France, 3 autres) |
| Réservations | **9 au total, 2 payées, 0 terminée** |
| Revenus | **8 € de commission**, 26,95 € de boutique |
| Pub Meta (premiers jours) | Paris 0,06 €/clic, Dallas 0,20 €/clic |
| App | Android 564 en ligne · iOS 1.17 (564) en vérification chez Apple |

**Découverte clé** : la moitié des inscrits se perdaient à la **vérification de l'e-mail**
(e-mail en anglais seulement, code valable 10 minutes, rien à cliquer). **Corrigé le 14/09
sans rebuild** : e-mail dans la langue du compte, bouton « Activer mon compte », code valable
24 heures, et les 13 comptes bloqués relancés.

## 4. Ce qui tourne tout seul

| Quand | Quoi | Détail |
|---|---|---|
| Tous les jours 9 h 15 | **Vigie** | Corrige les e-mails mal tapés (ex. `iclous.com` → `icloud.com`), renvoie une fois le code aux inscrits bloqués, liste les comptes non vérifiés. |
| Toutes les heures | **E-mails de cycle de vie** | Bienvenue, profil incomplet, premier client, relance, en 9 langues. |
| Tous les jours | **Pub Meta** | 3 campagnes : Dallas propriétaires 7 €/j, Paris propriétaires 5 €/j, Dallas pet-sitters 4 €/j. |
| Lundi 8 h | **Bob, chef de projet** | Rapport par e-mail : inscriptions, vérifications, réservations, pub, vigie, décisions à prendre. |
| Lundi 10 h 05 / 16 h 05 | **Partenaires** | Affiches gratuites aux commerces animaliers : petite couronne de Paris, puis Dallas en anglais. |
| Dimanche 14 h | **Articles** | 1 article Paris en français + 1 article sur une ville américaine (Dallas, New York, Los Angeles, Houston, Miami, Chicago, Austin, San Francisco). |
| Dimanche 14 h 30 + mercredi | **Réseaux sociaux** | Publication automatique Facebook et Instagram. |
| En continu | **Site** | Plus de 650 pages référencées, dont 120 villes américaines (banlieue de Dallas en priorité). |

## 5. Ce que Daniel fait lui-même (15 minutes par semaine)

1. Chaque dimanche après 14 h 30 : copier les textes prêts de la semaine dans 2 ou 3 groupes Facebook de Paris et de Dallas, sur Nextdoor et Reddit.
2. Demander un avis 5 étoiles sur l'App Store et Google Play aux utilisateurs les plus actifs.
3. Répondre aux commerces qui écrivent sur hopetsit@gmail.com, ou transférer.
4. Lire le rapport de Bob le lundi et répondre dans le chat avec ses choix.
5. Prévenir quand Apple valide la version 1.17.

**Sécurité, un jour calme** : révoquer les jetons Meta passés dans le chat (Business Suite →
Utilisateurs système → aepsinfos → Révoquer les tokens) et changer le mot de passe admin HoPetSit.

## 6. Le prochain build (565) — à faire en une fois après le 18 septembre

Le forfait de Daniel était à 91 %. On attend la remise à zéro du **18/09**, puis Daniel écrit
« **go build 565** ».

> ⚠️ **La liste ci-dessous est l'instantané du PDF au 14/09 (24 points).** La liste **qui fait
> foi** est la section « 📋 PROCHAIN BUILD (v562 app, build 565) » de `CLAUDE.md` à la racine :
> Daniel l'a complétée le 14/09 (25 points). En cas de divergence, **CLAUDE.md gagne**.

**Fiabilité (on perd des utilisateurs)**
1. Les 3 profils (propriétaire, sitter, promeneur) fonctionnent et restent synchronisés ; e-mail, téléphone et ville bien enregistrés.
2. Pouvoir changer son e-mail dans l'app après inscription, avec nouveau code de vérification.
3. Notifications Android et surtout **Apple (ne marchent pas)**.
4. Tous les e-mails traduits dans la langue du compte.
5. Synchronisation PawMap ↔ reste de l'app : demandes d'amis et de service partout, et « Demande déjà envoyée · en attente ».
6. Point vert « en ligne » (app et web).
7. Suivi en direct on/off fiable.
8. Partage en direct qui s'arrête tout seul en moins de 2 h : suivi robuste en arrière-plan, « vu il y a X min », arrêt seulement par l'utilisateur ou à la durée choisie.
9. Préfixe du téléphone selon le pays ; partage d'adresse.
10. Envoi de photos et vidéos dans le chat (**ne marche pas**).
11. Bandeau d'accueil « découvre la PawMap » qui ouvre l'historique au lieu de la PawMap.
12. Vieux pop-up « Suivre en direct sur la PawMap » à supprimer.
13. Paiements, notifications et wallet : vérification complète.

**Ce qui fait réserver**

14. Adresse et téléphone : pas obligatoires à l'inscription, mais obligatoires au bon moment (le sitter pour publier son profil, le propriétaire pour réserver) ; barre « profil complété à X % ».
15. Validation de la récupération et du rendu de l'animal : rappel 30 min avant, « Animal récupéré » / « Animal rendu » avec photo et GPS, confirmation d'un tap, automatique après 2 h, **paiement libéré au rendu**.
16. Verrou des coordonnées à partir de **700 utilisateurs**, débloqué par un pet-sitting payé ou un abonnement.
17. Page Réservations modernisée.
18. Chat : message vocal, réponse à un message précis (comme WhatsApp), design modernisé, contrôle de ces fonctions dans l'admin.

**PawMap et confort**

19. Rail gauche, petite et grande carte : bouton rose « Amis en direct » (voir qui est en direct, ouvrir son profil, le suivre) ; petit bouton chat avec les amis sur la mini carte.
20. Les barres ne se masquent plus quand on bouge la carte ; bouton retour en bas à gauche quand le menu du bas disparaît.
21. « Autour de moi » : uniquement les lieux dédiés aux animaux ou pet-friendly.
22. Couleur du rôle des membres visible plus tôt, sans zoomer autant.
23. Profil › Préférences › Notifications : choisir les notifications et le son (aboiement, miaulement, cui-cui), vibreur ou silencieux.
24. Admin : clic sur les compteurs du tableau de bord pour voir les profils.

## 7. Les recommandations données

| Sujet | Recommandation |
|---|---|
| **Modèle de paiement** | Le garder : 20 % de commission (standard du secteur), **paiement bloqué jusqu'à la fin du service** (la vraie force de l'app), abonnements en plus. Ce qui compte, ce sont les **réservations terminées**. |
| **Verrou à 700 utilisateurs** | Le garder : échange libre au début pour créer la confiance, verrou ensuite pour protéger la commission. À condition qu'il se déclenche **côté serveur** et que l'app explique comment débloquer. |
| **Adresse et téléphone** | Ne pas les imposer à l'inscription ; les demander au moment où ils servent. |
| **Pub** | Garder les 16 €/jour Meta ; **couper une campagne qui dépasse 3 € par inscription après 7 jours** et remettre le budget sur celle qui marche. |
| **Nouveaux pays** | **Pas avant** que Paris et les États-Unis produisent des réservations. |

## 8. Calendrier

- Chaque **lundi 8 h** : rapport de Bob.
- Chaque **lundi** : affiches partenaires (Paris 10 h, Dallas 16 h).
- Chaque **dimanche 14 h** : 2 articles, puis réseaux sociaux à 14 h 30.
- **Dès validation Apple** : déclarer la version iOS 564 dans l'admin.
- **À partir du 18 septembre** : « go build 565 », publication iOS et Android.

---

**Fichiers de travail** : `~/hopetsit-social` (vigie.py, bob_hebdo.py, BOB_PROMPT.md, ads/,
partenaires) · journal complet : `CLAUDE.md` à la racine du dépôt
(`~/Projects/HopeTSIT_v221/CLAUDE.md` sur le Mac).
