# HopeTSIT — Kit Logo Final

Version finale — patte de chien classique avec 4 ongles (orange · bleu · vert · orange) et œil caméra central pour la PawMap.

## Structure

```
hopetsit-logos/
├── web/
│   ├── logo-orange.svg          → Logo principal fond orange 1024x1024
│   ├── logo-white-mode.svg      → White mode fond #FAFAFA, bouclier sable
│   ├── logo-dark-mode.svg       → Dark mode fond #111111, bouclier #2A2A2A
│   ├── logo-monochrome-black.svg → Monochrome noir pour impression
│   └── wordmark.svg             → Wordmark horizontal Hope + TSIT
│
├── apple/
│   ├── apple-icon-original.svg  → App icon iOS 1024x1024 fond #EF4324
│   ├── apple-icon-dark.svg      → App icon dark mode iOS 18
│   └── apple-icon-white.svg     → App icon white mode iOS 18
│
└── android/
    ├── ic_launcher.svg          → Icône complète 1024x1024
    ├── ic_launcher_foreground.svg → Layer foreground adaptive icon 108x108
    ├── ic_launcher_background.svg → Layer background orange 108x108
    └── ic_notification.svg      → Icône notification monochrome blanc 96x96
```

## Couleurs

| Élément     | Couleur      | Hex      |
|-------------|--------------|----------|
| Primary     | Rouge-orange | #EF4324  |
| Owner       | Rouge-orange | #EF4324  |
| Sitter      | Bleu         | #1A73E8  |
| Walker      | Vert         | #008000  |
| Paume       | Noir         | #1A1A1A  |
| Fond sombre | Noir         | #0D0D0D  |

## Composition du logo

- **Bouclier blanc** — sécurité et confiance
- **4 ongles tricolores** (orange, bleu, vert, orange) — les 3 rôles de l'app encadrés
- **Grand coussinet central noir** — la patte de chien emblématique
- **Œil caméra au centre** — surveillance bienveillante, référence PawMap

## Usage Apple iOS 18

Soumettre les 3 variantes sur App Store Connect :
- `apple-icon-original.svg` → Icône par défaut
- `apple-icon-dark.svg` → Thème sombre système
- `apple-icon-white.svg` → Thème clair (Tinted) système

## Usage Android

Pour adaptive icons :
- `ic_launcher_foreground.svg` → Layer foreground
- `ic_launcher_background.svg` → Layer background orange plein

Pour notifications push : utiliser `ic_notification.svg` (Android exige du monochrome blanc sur transparent pour les notifications).

## Conversion PNG

Pour exporter en PNG aux tailles nécessaires :
- Web : 512, 1024, 2048 px
- iOS : 20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024 px
- Android : 48, 72, 96, 144, 192, 512 px

Utiliser un outil comme rsvg-convert, Inkscape, ou Figma pour l'export PNG depuis les SVG.
