@echo off
REM ─────────────────────────────────────────────────────────────────────
REM  HoPetSit — PawMap seed depuis OpenStreetMap (Overpass API).
REM  Lance UNE FOIS pour peupler la collection mappois avec des POI
REM  reels (vetos, parcs, animaleries, plages, points d'eau, etc.).
REM
REM  Couvre 11 pays europeens : FR BE CH LU DE IT ES PT NL AT GB
REM  Categories : vet, shop, groomer, park, beach, water, trainer,
REM               hotel, restaurant.
REM
REM  Pre-requis :
REM   1. backend\.env doit contenir MONGODB_URI=mongodb+srv://...
REM      (recupere-la depuis Render -> Environment).
REM   2. Connexion Internet pour Overpass API.
REM
REM  Duree : 10-30 min selon nombre de pays + categories.
REM  Safe a re-lancer : upsert sur osmId, pas de doublons.
REM ─────────────────────────────────────────────────────────────────────

setlocal

set BACKEND_DIR=%~dp0backend

echo.
echo ============================================================
echo   HoPetSit PawMap Seed (OpenStreetMap -> Mongo)
echo ============================================================
echo.

cd /d "%BACKEND_DIR%"
if errorlevel 1 (
    echo [ERREUR] Dossier backend introuvable : %BACKEND_DIR%
    pause
    exit /b 1
)

if not exist ".env" (
    echo [ERREUR] Fichier backend\.env manquant.
    echo Recupere MONGODB_URI depuis Render -^> Environment et cree .env.
    pause
    exit /b 1
)

echo Choisis l'option :
echo   1. France uniquement (rapide, ^~5 min)
echo   2. Tous les pays europeens (long, 30-60 min)
echo   3. Dry-run France (compte sans ecrire)
echo.
set /p choice="Ton choix [1/2/3] : "

if "%choice%"=="1" (
    node src/scripts/seedOsmEurope.js --country FR
) else if "%choice%"=="2" (
    node src/scripts/seedOsmEurope.js
) else if "%choice%"=="3" (
    node src/scripts/seedOsmEurope.js --country FR --dry-run
) else (
    echo Choix invalide. Lance le script et tape 1, 2 ou 3.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   SEED TERMINE — verifie sur https://hopetsit.com/map
echo ============================================================
pause
endlocal
