"""CI-only configuration. Read GitHub Secrets; never print their values."""
import base64
import json
import os
from pathlib import Path

home = Path.home()
folder = home / '.android'
folder.mkdir(exist_ok=True)
encoded = os.environ.get('BUNKER_KEYSTORE_BASE64', '')
password = os.environ.get('BUNKER_KEYSTORE_PASSWORD', '')
alias = os.environ.get('BUNKER_KEY_ALIAS', '')
release = os.environ.get('BUNKER_RELEASE', '') == '1'
if any([encoded, password, alias]) and not all([encoded, password, alias]):
    raise SystemExit('Incomplete signing secrets: configure all three BUNKER_* values.')
if release and not encoded:
    raise SystemExit('Release blocked: permanent signing secrets are missing. No temporary-key fallback.')
if encoded:
    store = folder / 'bunker.keystore'
    store.write_bytes(base64.b64decode(encoded, validate=True))
    store.chmod(0o600)
else:
    # Legacy CI preview only. Never publish this as an update.
    store = folder / 'debug.keystore'
    password, alias = 'android', 'androiddebugkey'
    import subprocess
    subprocess.run(['keytool', '-genkeypair', '-noprompt', '-keystore', str(store),
        '-storepass', password, '-alias', alias, '-keypass', password,
        '-dname', 'CN=Android Debug,O=Android,C=US', '-keyalg', 'RSA',
        '-keysize', '2048', '-validity', '10000'], check=True, capture_output=True)
    print('::warning::Temporary-key preview: not eligible for in-place release updates. Configure signing secrets.')
settings = home / '.config/godot/editor_settings-4.5.tres'
settings.parent.mkdir(parents=True, exist_ok=True)
fields = {'export/android/android_sdk_path': os.environ['ANDROID_HOME'],
          'export/android/java_sdk_path': os.environ['JAVA_HOME'],
          'export/android/debug_keystore': str(store),
          'export/android/debug_keystore_user': alias,
          'export/android/debug_keystore_pass': password}
settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' +
    ''.join(f'{k} = {json.dumps(v)}\n' for k, v in fields.items()))
settings.chmod(0o600)
if release:
    # Ephemeral runner checkout only; no secret is committed or uploaded.
    preset = Path('export_presets.cfg')
    data = preset.read_text().replace('[preset.0.options]', '[preset.0.options]\n' +
        ''.join(f'{k}={json.dumps(v)}\n' for k, v in {
          'keystore/release': str(store), 'keystore/release_user': alias,
          'keystore/release_password': password}.items()))
    preset.write_text(data)
print('Android signing configured without exposing credentials.')
