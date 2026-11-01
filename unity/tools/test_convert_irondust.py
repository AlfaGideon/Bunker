#!/usr/bin/env python3
import hashlib
import tempfile
import unittest
from pathlib import Path
from convert_irondust import convert

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'unity/source-assets/irondust/Meshes.fbx'
ASSETS = ROOT / 'unity/BunkerUnity/Assets/Resources/Irondust/Models'

class ConversionTest(unittest.TestCase):
    def test_converted_meshes_match_repository(self):
        with tempfile.TemporaryDirectory() as temp:
            dest = Path(temp)
            convert(SOURCE, dest)
            generated = sorted(p.name for p in dest.glob('*.obj'))
            self.assertEqual(generated, sorted(p.name for p in ASSETS.glob('*.obj')))
            for name in generated:
                self.assertEqual(hashlib.sha256((dest/name).read_bytes()).digest(),
                                 hashlib.sha256((ASSETS/name).read_bytes()).digest(), name)
    def test_rejects_other_format(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / 'bad.fbx'
            source.write_text('FBXVersion: 7400')
            with self.assertRaises(ValueError):
                convert(source, Path(temp)/'out')

if __name__ == '__main__':
    unittest.main()
