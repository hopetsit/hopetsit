import json, urllib.request, pathlib
API="https://hopetsit-backend.onrender.com/api/v1"
def api(path, body=None, token=None, method=None):
    req=urllib.request.Request(API+path, data=json.dumps(body).encode() if body is not None else None, method=method or ("POST" if body is not None else "GET"))
    req.add_header("Content-Type","application/json")
    if token: req.add_header("Authorization","Bearer "+token)
    with urllib.request.urlopen(req, timeout=60) as r: return json.loads(r.read().decode())
lines=pathlib.Path.home().joinpath(".hopetsit_admin_credentials").read_text().split("\n")
tok=api("/auth/admin/login",{"email":lines[0].strip(),"password":lines[1].strip()})["token"]
ids={"6a5007267be16accb52ab9d8":"owner","6a5fa7e1e396344144529184":"sitter","6a3910a7bb3ed16baaf95874":"sitter","6a8777c6e11c90e1e6b62498":"sitter","6a87714ae11c90e1e6b6235b":"owner"}
for coll in ("owners","sitters","walkers"):
    try:
        data=api(f"/admin/{coll}",token=tok)
    except Exception as e:
        print(coll,"ERR",e); continue
    items=data if isinstance(data,list) else (data.get("items") or data.get("data") or data.get(coll) or [])
    for u in items:
        uid=str(u.get("_id") or u.get("id"))
        if uid in ids:
            toks=u.get("fcmTokens") or []
            print(coll, uid, (u.get("name") or "")[:20], (u.get("email") or "")[:40], "tokens=%d"%len(toks), "platform=",u.get("platform") or u.get("devicePlatform") or u.get("lastPlatform"), "appLocale=",u.get("appLocale"), "keys:", [k for k in u.keys() if 'device' in k.lower() or 'platform' in k.lower() or 'os' == k.lower()])
