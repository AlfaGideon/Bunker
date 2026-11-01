"""The lobby serves the browser build that GitHub Actions publishes."""
import io
import os
import tempfile
import unittest
import zipfile
from pathlib import Path

from aiohttp.test_utils import TestClient, TestServer

from app import create_app
from web_build import WebBuild, WebBuildError


def make_archive(directory: Path, extra: dict | None = None) -> Path:
    target = directory / 'web-40.zip'
    with zipfile.ZipFile(target, 'w') as bundle:
        bundle.writestr('index.html', '<!doctype html><script src="index.js"></script><canvas id="canvas"></canvas>')
        bundle.writestr('index.js', 'const engine = new Engine();')
        bundle.writestr('index.wasm', b'\x00asm')
        bundle.writestr('index.pck', b'PCK\x00')
        for name, payload in (extra or {}).items():
            bundle.writestr(name, payload)
    return target


class WebBuildTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name)
        self.archive = make_archive(root)
        os.environ['WEB_BUILD_ZIP'] = str(self.archive)
        os.environ['WEB_ROOT'] = str(root / 'cache')
        self.client = TestClient(TestServer(create_app()))
        await self.client.start_server()

    async def asyncTearDown(self):
        await self.client.close()
        os.environ.pop('WEB_BUILD_ZIP', None)
        os.environ.pop('WEB_ROOT', None)
        self.directory.cleanup()

    async def test_build_is_unpacked_and_served(self):
        response = await self.client.get('/play')
        self.assertEqual(response.status, 200)
        self.assertEqual(response.content_type, 'text/html')
        body = await response.text()
        self.assertIn('canvas', body)
        for name, kind in (('index.wasm', 'application/wasm'), ('index.pck', 'application/octet-stream')):
            response = await self.client.get('/play/' + name)
            self.assertEqual(response.status, 200, name)
            self.assertEqual(response.headers['Content-Type'], kind)
        status = await (await self.client.get('/play-status')).json()
        self.assertTrue(status['ready'])
        self.assertEqual(status['version'], '')

    async def test_unknown_file_is_missing(self):
        self.assertEqual((await self.client.get('/play')).status, 200)
        self.assertEqual((await self.client.get('/play/absent.js')).status, 404)
        self.assertEqual((await self.client.get('/play/../app.py')).status, 404)

    async def test_page_is_not_served_before_the_build_arrives(self):
        build = WebBuild(Path(self.directory.name) / 'empty', source=str(Path(self.directory.name) / 'absent.zip'))
        self.assertFalse(await build.ensure())
        self.assertIn('FileNotFoundError', build.error)


class ArchiveSafetyTest(unittest.IsolatedAsyncioTestCase):
    async def test_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = make_archive(root, extra={'../escape.txt': 'x'})
            build = WebBuild(root / 'cache', source=str(archive))
            with self.assertRaises(WebBuildError):
                build._extract(archive)
            self.assertFalse((root / 'escape.txt').exists())
            self.assertFalse(build.ready)

    async def test_missing_index_is_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / 'web-40.zip'
            with zipfile.ZipFile(archive, 'w') as bundle:
                bundle.writestr('index.js', 'x')
            build = WebBuild(root / 'cache', source=str(archive))
            self.assertFalse(await build.ensure())
            self.assertIn('index.html', build.error)


class InvitePageTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.client = TestClient(TestServer(create_app()))
        await self.client.start_server()

    async def asyncTearDown(self):
        await self.client.close()

    async def test_invitation_offers_the_browser(self):
        response = await self.client.get('/invite/' + 'a' * 16)
        body = await response.text()
        self.assertEqual(response.status, 200)
        self.assertIn('Играть в браузере', body)
        self.assertIn('/play?room=', body)
        self.assertIn('Открыть в приложении', body)

    async def test_root_links_the_browser_build(self):
        body = await (await self.client.get('/')).text()
        self.assertIn('/play', body)


if __name__ == '__main__':
    unittest.main()
