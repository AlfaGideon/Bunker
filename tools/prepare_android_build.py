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
print('Android build prepared with TTS engine visibility:', identifier)
