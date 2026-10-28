"""Generate a PRIVATE Android signing bundle. Never run in public CI or commit output.
Requires: pip install cryptography. Output must be outside tracked source.
"""
import base64
import datetime
import json
import os
from pathlib import Path
import secrets
import zipfile
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID

root = Path(__file__).resolve().parent.parent / '.cache/private-signing'
root.mkdir(parents=True, exist_ok=True, mode=0o700)
output = root / 'bunker-signing-secrets.zip'
if output.exists():
    raise SystemExit('Bundle already exists. Keep the original key; refusing to replace it.')
password = secrets.token_urlsafe(36)
alias = 'bunker-release'
key = rsa.generate_private_key(public_exponent=65537, key_size=3072)
name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'Bunker Android Release')])
now = datetime.datetime.now(datetime.timezone.utc)
certificate = (x509.CertificateBuilder().subject_name(name).issuer_name(name)
    .public_key(key.public_key()).serial_number(x509.random_serial_number())
    .not_valid_before(now - datetime.timedelta(days=1))
    .not_valid_after(now + datetime.timedelta(days=10000))
    .sign(key, hashes.SHA256()))
store = pkcs12.serialize_key_and_certificates(alias.encode(), key, certificate, None,
    serialization.BestAvailableEncryption(password.encode()))
values = {'BUNKER_KEYSTORE_BASE64': base64.b64encode(store).decode(),
          'BUNKER_KEYSTORE_PASSWORD': password, 'BUNKER_KEY_ALIAS': alias}
with zipfile.ZipFile(output, 'x', compression=zipfile.ZIP_DEFLATED) as archive:
    archive.writestr('bunker-signing.p12', store)
    for field, value in values.items():
        archive.writestr(field + '.txt', value)
    archive.writestr('certificate-sha256.txt', certificate.fingerprint(hashes.SHA256()).hex())
    archive.writestr('README.txt', 'PRIVATE. Keep an offline backup. Do not commit or share.\n'
        'GitHub repository > Settings > Secrets and variables > Actions > New repository secret.\n'
        'Create three secrets named after the three BUNKER_*.txt files; paste each file content as its value.\n'
        'The .p12 file is your encrypted signing-key backup. Do not upload it as a public artifact.\n'
        'Never regenerate this key for ordinary updates. No GitHub token is needed in the app.\n')
os.chmod(output, 0o600)
# Verify the bundle can be decrypted before handing it to its owner.
loaded_key, loaded_certificate, _ = pkcs12.load_key_and_certificates(store, password.encode())
assert loaded_key and loaded_certificate.fingerprint(hashes.SHA256()) == certificate.fingerprint(hashes.SHA256())
print('Private signing bundle created; no secret values printed.')
