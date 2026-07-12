---
name: python3-store-alias-hook-error
description: The per-edit check-sql-files.py hook error was a sandboxed python3 Store alias; fixed in PATH
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

The CockroachDB plugin (`plugin_01J1ZUJcofzWJxiajSBsZ8US`, desktop "knowledge-work-plugins" marketplace) has a PostToolUse hook on Write|Edit|MultiEdit that runs `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check-sql-files.py"`. It failed on EVERY edit with `can't open file ... [Errno 2]` even though the file existed.

**Root cause:** `python3` resolved to the 0-byte Windows Store App Execution Alias at `%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe` (user PATH pos 22). That stub launches the real python in a sandboxed AppContainer where `AppData\Roaming\Claude\...` is virtualized/invisible → python's `os.path.exists` returns False for the script. PowerShell `Test-Path` saw it fine. The real python is `C:\Users\Usuario\AppData\Local\Python\pythoncore-3.14-64\python.exe` (had no `python3.exe`).

**Fix applied (this session):** copied `python.exe` → `python3.exe` in the pythoncore dir, and prepended that dir to the **user** PATH (ahead of WindowsApps). Verified the hook then runs `exit=0`. Effect is durable but only for processes started AFTER the change — the running desktop app keeps the old env, so the cosmetic error persists until the app is **restarted**. Edits always applied regardless; the error was never blocking.

**How to apply:** if the error reappears, check `python3` resolution (`(Get-Command python3).Source`) — it must NOT be the WindowsApps stub. The CockroachDB plugin is irrelevant to HopeTSIT (no SQL); cleanest permanent removal is to uninstall it from the desktop app's plugin manager. Note `.dart`/`.yaml`/`.html`/`.md` edits aren't even in the script's SQL_EXTENSIONS set, so the check is a no-op for our usual files anyway.
