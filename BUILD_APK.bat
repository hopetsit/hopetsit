@echo off
REM ─────────────────────────────────────────────────────────────────────
REM  HoPetSit — Build APK release v23.1 (B9 + B3+B5)
REM  Double-clique sur ce fichier pour builder l'APK et le copier
REM  automatiquement dans C:\Users\Usuario\Downloads\
REM ─────────────────────────────────────────────────────────────────────

setlocal enabledelayedexpansion

set FRONTEND_DIR=%~dp0frontend
set WEBSITE_PUBLIC_DIR=%~dp0website\public
set DOWNLOADS_DIR=%USERPROFILE%\Downloads
REM v23.1 part 146 — renommage pour reflechir la version courante.
set APK_NAME=hopetsit-v23.1.146-test.apk

echo.
echo ============================================================
echo   HoPetSit APK Builder — v23.1.146 (deep link fix + bridge OTT)
echo ============================================================
echo.

cd /d "%FRONTEND_DIR%"
if errorlevel 1 (
    echo [ERREUR] Dossier frontend introuvable : %FRONTEND_DIR%
    pause
    exit /b 1
)

echo [1/4] flutter pub get ...
call flutter pub get
if errorlevel 1 (
    echo.
    echo [ERREUR] flutter pub get a echoue.
    pause
    exit /b 1
)

echo.
echo [2/4] flutter clean ...
call flutter clean
if errorlevel 1 (
    echo [WARN] flutter clean a echoue, on continue quand meme.
)

echo.
echo [3/4] flutter build apk --release (5-15 min) ...
call flutter build apk --release
if errorlevel 1 (
    echo.
    echo [ERREUR] Le build a echoue. Lis les erreurs ci-dessus.
    pause
    exit /b 1
)

set APK_SRC=%FRONTEND_DIR%\build\app\outputs\flutter-apk\app-release.apk
if not exist "%APK_SRC%" (
    echo.
    echo [ERREUR] APK non trouve a l'emplacement attendu :
    echo   %APK_SRC%
    pause
    exit /b 1
)

echo.
echo [4/5] Copie de l'APK dans Downloads ...
copy /Y "%APK_SRC%" "%DOWNLOADS_DIR%\%APK_NAME%"
if errorlevel 1 (
    echo [ERREUR] Copie vers Downloads a echoue.
    pause
    exit /b 1
)

REM v23.1 part 146 — copie l'APK dans website/public pour que le bouton
REM "Telecharger APK Android" sur hopetsit.com/download serve toujours
REM la derniere version. Le fichier est versionne en git Vercel, donc
REM le prochain `git push` deploiera l'APK automatiquement.
echo.
echo [5/5] Copie de l'APK dans website/public/HoPetSit.apk ...
if not exist "%WEBSITE_PUBLIC_DIR%" (
    echo [WARN] %WEBSITE_PUBLIC_DIR% introuvable, on skip la copie site.
) else (
    copy /Y "%APK_SRC%" "%WEBSITE_PUBLIC_DIR%\HoPetSit.apk"
    if errorlevel 1 (
        echo [WARN] Copie vers website/public a echoue, mais l'APK est OK dans Downloads.
    ) else (
        echo [OK] APK copie vers website/public/HoPetSit.apk
    )
)

echo.
echo ============================================================
echo   SUCCES !
echo ============================================================
echo   APK pret :
echo     %DOWNLOADS_DIR%\%APK_NAME%
echo     %WEBSITE_PUBLIC_DIR%\HoPetSit.apk
echo.
for %%A in ("%DOWNLOADS_DIR%\%APK_NAME%") do echo   Taille : %%~zA octets
echo ============================================================
echo   Pour publier sur le site :
echo     1. cd website
echo     2. git add public/HoPetSit.apk
echo     3. git commit -m "release: APK v23.1.146"
echo     4. git push  ^(Vercel deploiera auto^)
echo ============================================================
echo.

pause
endlocal
