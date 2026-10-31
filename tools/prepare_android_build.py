"""Install Godot's matching Gradle template and expose Android's TTS engines.

Android 11+ requires a manifest query for the TTS service. Keep the source
zip as the source of truth; do not commit the generated Gradle project.
"""
from pathlib import Path
from zipfile import ZipFile
import os
import re
import subprocess

version = subprocess.check_output(['godot', '--version'], text=True).strip().split('.')[0:4]
identifier = '.'.join(version)
template = Path.home() / '.local/share/godot/export_templates' / identifier / 'android_source.zip'
if not template.is_file():
    raise SystemExit(f'Godot Android source template not found: {template}')
root = Path('android')
build = root / 'build'
build.mkdir(parents=True, exist_ok=True)
with ZipFile(template) as z:
    for entry in z.infolist():
        dest = (build / entry.filename).resolve()
        if not dest.is_relative_to(build.resolve()):
            raise SystemExit('Unsafe template path')
        z.extract(entry, build)
        if not entry.is_dir():
            os.chmod(dest, (entry.external_attr >> 16) & 0o777 or 0o644)
(root / '.build_version').write_text(identifier + '\n')
(build / '.gdignore').write_text('')
manifest = build / 'AndroidManifest.xml'
text = manifest.read_text()
query = '<queries><intent><action android:name="android.intent.action.TTS_SERVICE" /></intent></queries>'
if 'android.intent.action.TTS_SERVICE' not in text:
    text, count = re.subn(r'(<manifest\b[^>]*>)', r'\1\n    ' + query, text, count=1)
    if count != 1:
        raise SystemExit('Cannot insert TTS service query into Godot manifest')
    manifest.write_text(text)
java = build / 'src/org/bunker/prototype/InternetRadioPlayer.java'
java.parent.mkdir(parents=True, exist_ok=True)
java.write_bytes(Path('android_src/InternetRadioPlayer.java').read_bytes())
invite_java = build / 'src/org/bunker/prototype/LobbyInvite.java'
invite_java.write_bytes(Path('android_src/LobbyInvite.java').read_bytes())
# Register a custom scheme. The landing page requires a second tap after install.
text = manifest.read_text()
if 'bunkerinvite' not in text:
    invite_filter = '''<intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="bunkerinvite" android:host="join" />
            </intent-filter>'''
    text, count = re.subn(r'(</activity>)', lambda m: invite_filter + '\n        ' + m.group(1), text, count=1)
    if count != 1:
        raise SystemExit('Cannot register lobby deep link in manifest')
    manifest.write_text(text)
activity = build / 'src/com/godot/game/GodotApp.java'
activity_text = activity.read_text()
if 'LobbyInvite.capture' not in activity_text:
    activity_text, count = re.subn(r'(public void onCreate\(Bundle savedInstanceState\) \{)', r'\1\n        org.bunker.prototype.LobbyInvite.capture(getIntent());', activity_text, count=1)
    if count != 1:
        raise SystemExit('Cannot install invitation handler in Android activity')
    marker = '\n\t@Override\n\tpublic void onResume()'
    if marker not in activity_text:
        raise SystemExit('Cannot find Android activity onResume')
    activity_text = activity_text.replace(marker, "\n\t@Override\n\tpublic void onNewIntent(android.content.Intent intent) {\n\t\tsuper.onNewIntent(intent);\n\t\torg.bunker.prototype.LobbyInvite.capture(intent);\n\t}\n" + marker, 1)
    activity.write_text(activity_text)
print('Android build prepared with TTS engine visibility:', identifier)
