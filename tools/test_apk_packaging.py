"""Check that the APK keeps both existing ABIs and compresses native libraries."""
import sys
from zipfile import ZipFile, ZIP_DEFLATED

with ZipFile(sys.argv[1]) as apk:
    files = {entry.filename: entry for entry in apk.infolist()}
    dex = b''.join(apk.read(e) for e in apk.infolist() if e.filename.endswith('.dex'))
    if b'Lorg/bunker/prototype/InternetRadioPlayer;' not in dex:
        raise SystemExit('Native Android radio player missing from APK')
    for abi in ('arm64-v8a', 'x86_64'):
        path = f'lib/{abi}/libgodot_android.so'
        if path not in files:
            raise SystemExit(f'Missing existing architecture: {path}')
        entry = files[path]
        if entry.compress_type != ZIP_DEFLATED or entry.compress_size >= entry.file_size * 0.7:
            raise SystemExit(f'Native library not properly compressed: {path}')
        print(f'{path}: {entry.compress_size:,} compressed / {entry.file_size:,} bytes')
