#!/usr/bin/env python3
"""Ajoute à un projet Flutter fraîchement créé tout ce qu'il faut côté Gradle
pour les modules natifs (WorkManager, DataStore, Glance, scanner QR).

Usage (depuis le dossier du projet) :   python patch_gradle.py
Peut être relancé sans danger (ne duplique rien).
"""
import re
import sys
from pathlib import Path

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
settings = root / "android" / "settings.gradle.kts"
app = root / "android" / "app" / "build.gradle.kts"
for f in (settings, app):
    if not f.exists():
        sys.exit(f"Fichier introuvable : {f}\n(le script gère les fichiers .kts ; voir README pour la version manuelle)")

# ---- 1) settings.gradle.kts : plugin Compose (même version que Kotlin)
s = settings.read_text(encoding="utf-8")
if "org.jetbrains.kotlin.plugin.compose" not in s:
    m = re.search(r'id\("org\.jetbrains\.kotlin\.android"\)\s+version\s+"([^"]+)"', s)
    if not m:
        sys.exit("Version de Kotlin introuvable dans settings.gradle.kts : voir README (section Gradle manuelle).")
    kotlin = m.group(1)
    line = m.group(0)
    s = s.replace(
        m.group(0) + " apply false",
        m.group(0) + ' apply false\n    id("org.jetbrains.kotlin.plugin.compose") version "%s" apply false' % kotlin,
        1,
    )
    if "plugin.compose" not in s:
        sys.exit("Format inattendu dans settings.gradle.kts : voir README (section Gradle manuelle).")
    settings.write_text(s, encoding="utf-8")
    print(f"settings.gradle.kts : plugin Compose {kotlin} ajouté")
else:
    print("settings.gradle.kts : déjà patché")

# ---- 2) app/build.gradle.kts
a = app.read_text(encoding="utf-8")
changed = False

if "org.jetbrains.kotlin.plugin.compose" not in a:
    a = a.replace('id("com.android.application")', 'id("com.android.application")\n    id("org.jetbrains.kotlin.plugin.compose")', 1)
    changed = True

# minSdk 26 (comme les TP) : Glance, DataStore et WorkManager sont à l'aise dessus
new_min = re.sub(r"minSdk\s*=\s*[^\n]+", "minSdk = maxOf(flutter.minSdkVersion, 26)", a, count=1)
if new_min != a:
    a = new_min
    changed = True

DEPS = [
    'implementation("androidx.core:core-ktx:1.15.0")',
    'implementation("androidx.work:work-runtime-ktx:2.10.0")',
    'implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")',
    'implementation("androidx.datastore:datastore-preferences:1.1.1")',
    'implementation("androidx.glance:glance-appwidget:1.1.1")',
    'implementation("com.google.android.gms:play-services-code-scanner:16.1.0")',
]
missing = [d for d in DEPS if d.split('"')[1].split(":")[1] not in a]
if missing:
    block = "\n".join("    " + d for d in missing)
    if re.search(r"dependencies\s*\{", a):
        a = re.sub(r"dependencies\s*\{", "dependencies {\n" + block, a, count=1)
    else:
        a = a.rstrip() + "\n\ndependencies {\n" + block + "\n}\n"
    changed = True

if changed:
    app.write_text(a, encoding="utf-8")
    print("app/build.gradle.kts : mis à jour")
else:
    print("app/build.gradle.kts : déjà patché")
print("Terminé.")
