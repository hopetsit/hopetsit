---
name: norton-mitm-gradle-truststore
description: Norton intercepte le HTTPS sur le PC de Daniel → Gradle PKIX fail ; fix = trustStoreType=Windows-ROOT dans ~/.gradle/gradle.properties
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

**Norton Antivirus fait du SSL/TLS scanning (MITM) sur le PC de Daniel** : tous les sites
renvoient un certificat émis par « CN=Norton Web/Mail Shield Root ». Windows lui fait
confiance (donc curl.exe/Chrome OK), mais la **JVM de Gradle utilise son propre cacerts**
→ `PKIX path building failed` dès qu'un build Flutter doit télécharger une dépendance
(vu le 12/07/2026 : kotlin-gradle-plugin requis par in_app_purchase_android, apparu avec
le patch iOS v506).

**Why:** builds précédents passaient car tout était en cache Gradle ; toute NOUVELLE
dépendance refait surface le problème. Le sandbox n'y est pour rien (échec identique hors
sandbox).

**How to apply:** `C:\Users\Usuario\.gradle\gradle.properties` doit contenir
`systemProp.javax.net.ssl.trustStoreType=Windows-ROOT` (fait le 12/07/2026, persistant).
Si ça re-casse : vérifier que la ligne est toujours là, `gradlew.bat --stop` dans
frontend/android, relancer le build. Même famille que [[python3-store-alias-hook-error]]
(curl --ssl-no-revoke, NODE_TLS_REJECT_UNAUTHORIZED=0, python unverified context).
