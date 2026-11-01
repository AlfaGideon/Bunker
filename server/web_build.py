"""Fetch, unpack and serve the published Godot web build.

The browser version is built in GitHub Actions and attached to a release as
``web-<version code>.zip``. The lobby container has no build tools, so it
downloads that archive once per container start and serves the files from a
temporary directory. ``WEB_BUILD_ZIP`` points at a local archive instead,
which is how the tests avoid the network.
"""
import asyncio
import re
import shutil
import zipfile
from pathlib import Path

from aiohttp import ClientSession, ClientTimeout, ClientError

REPO = 'AlfaGideon/Bunker'
RELEASES_API = 'https://api.github.com/repos/' + REPO + '/releases?per_page=10'
ASSET_NAME = re.compile(r'^web-([0-9]+)\.zip$')
MAX_ARCHIVE = 400 * 1024 * 1024

MIME = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.wasm': 'application/wasm',
    '.pck': 'application/octet-stream',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.css': 'text/css; charset=utf-8',
    '.txt': 'text/plain; charset=utf-8',
}


class WebBuildError(Exception):
    pass


class WebBuild:
    """One archive, one extraction directory, retried on demand."""

    def __init__(self, root: Path, source: str = '', version: str = ''):
        self.root = Path(root)
        self.source = source
        self.pinned_version = version
        self.site = self.root / 'site'
        self.lock = asyncio.Lock()
        self.ready = False
        self.version = version
        self.error = ''

    @property
    def index(self) -> Path:
        return self.site / 'index.html'

    async def ensure(self) -> bool:
        if self.ready and self.index.is_file():
            return True
        async with self.lock:
            if self.ready and self.index.is_file():
                return True
            try:
                archive = await self._archive()
                self._extract(archive)
                self.ready = self.index.is_file()
                if not self.ready:
                    raise WebBuildError('в архиве нет index.html')
                self.error = ''
            except (WebBuildError, ClientError, asyncio.TimeoutError, OSError, zipfile.BadZipFile) as exc:
                self.ready = False
                self.error = f'{type(exc).__name__}: {exc}'[:200]
            return self.ready

    async def _archive(self) -> Path:
        if self.source:
            return Path(self.source)
        url, version = await self._latest_url()
        self.version = self.pinned_version or version
        target = self.root / 'build.zip'
        timeout = ClientTimeout(total=600, connect=30, sock_read=120)
        async with ClientSession(timeout=timeout, headers={'User-Agent': 'Bunker-Web/1.0'}) as client:
            async with client.get(url, allow_redirects=True) as response:
                if response.status != 200:
                    raise WebBuildError(f'HTTP {response.status} для {url}')
                size = response.content_length
                if size is not None and size > MAX_ARCHIVE:
                    raise WebBuildError('архив слишком большой')
                written = 0
                self.root.mkdir(parents=True, exist_ok=True)
                with target.open('wb') as handle:
                    async for chunk in response.content.iter_chunked(1 << 16):
                        written += len(chunk)
                        if written > MAX_ARCHIVE:
                            raise WebBuildError('архив слишком большой')
                        handle.write(chunk)
        return target

    async def _latest_url(self) -> tuple[str, str]:
        timeout = ClientTimeout(total=30, connect=15)
        headers = {'User-Agent': 'Bunker-Web/1.0', 'Accept': 'application/vnd.github+json'}
        async with ClientSession(timeout=timeout, headers=headers) as client:
            async with client.get(RELEASES_API) as response:
                if response.status != 200:
                    raise WebBuildError(f'GitHub API: HTTP {response.status}')
                releases = await response.json()
        if not isinstance(releases, list):
            raise WebBuildError('GitHub API вернул не список')
        for release in releases:
            if not isinstance(release, dict) or release.get('draft'):
                continue
            for asset in release.get('assets', []):
                match = ASSET_NAME.match(str(asset.get('name', '')))
                if match and asset.get('browser_download_url'):
                    return str(asset['browser_download_url']), match.group(1)
        raise WebBuildError('в релизах нет web-<версия>.zip')

    def _extract(self, archive: Path) -> None:
        site_tmp = self.root / 'site-tmp'
        if site_tmp.exists():
            shutil.rmtree(site_tmp)
        site_tmp.mkdir(parents=True)
        with zipfile.ZipFile(archive) as bundle:
            for info in bundle.infolist():
                name = info.filename.replace('\\', '/')
                if name.startswith('/') or '..' in Path(name).parts:
                    raise WebBuildError('небезопасный путь в архиве')
                if info.is_dir():
                    continue
                destination = site_tmp / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                with bundle.open(info) as source, destination.open('wb') as target:
                    shutil.copyfileobj(source, target, 1 << 16)
        if self.site.exists():
            shutil.rmtree(self.site)
        site_tmp.rename(self.site)

    def resolve(self, name: str) -> Path | None:
        if not name:
            name = 'index.html'
        candidate = (self.site / name).resolve()
        try:
            candidate.relative_to(self.site.resolve())
        except ValueError:
            return None
        return candidate if candidate.is_file() else None
