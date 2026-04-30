@echo off
REM ─────────────────────────────────────────────────────────────────────
REM  HoPetSit — Build APK release v23.1 (B9 + B3+B5)
REM  Double-clique sur ce fichier pour builder l'APK et le copier
REM  automatiquement dans C:\Users\Usuario\Downloads\
REM ─────────────────────────────────────────────────────────────────────

setlocal enabledelayedexpansion

set FRONTEND_DIR=%~dp0frontend
set DOWNLOADS_DIR=%USERPROFILE%\Downloads
set APK_NAME=hopetsit-v23.1-b9-b3b5-test.apk

echo.
echo ============================================================
echo   HoPetSit APK Builder — v23.1 (B9 saved cards + B3+B5 multi-candidats)
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
echo [4/4] Copie de l'APK dans Downloads ...
copy /Y "%APK_SRC%" "%DOWNLOADS_DIR%\%APK_NAME%"
if errorlevel 1 (
    echo [ERREUR] Copie a echoue.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   SUCCES !
echo ============================================================
echo   APK pret :
echo     %DOWNLOADS_DIR%\%APK_NAME%
echo.
for %%A in ("%DOWNLOADS_DIR%\%APK_NAME%") do echo   Taille : %%~zA octets
echo ============================================================
echo.

pause
endlocal
