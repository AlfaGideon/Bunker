const menuButton = document.querySelector('.menu-toggle');
const navigation = document.querySelector('#navigation');
menuButton.addEventListener('click', () => {
  const open = menuButton.getAttribute('aria-expanded') !== 'true';
  menuButton.setAttribute('aria-expanded', String(open));
  menuButton.setAttribute('aria-label', open ? 'Закрыть меню' : 'Открыть меню');
  navigation.classList.toggle('open', open);
});
navigation.addEventListener('click', event => {
  if (event.target.closest('a')) {
    navigation.classList.remove('open');
    menuButton.setAttribute('aria-expanded', 'false');
    menuButton.setAttribute('aria-label', 'Открыть меню');
  }
});
const track = document.querySelector('#gallery-track');
function scrollGallery(direction) {
  const card = track.querySelector('.shot');
  track.scrollBy({left: direction * (card.getBoundingClientRect().width + 18), behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth'});
}
document.querySelector('#gallery-prev').addEventListener('click', () => scrollGallery(-1));
document.querySelector('#gallery-next').addEventListener('click', () => scrollGallery(1));
// Optional best-effort update; static signed 0.20 link remains usable if GitHub
// rate-limits the API or the visitor has no connection.
fetch('https://api.github.com/repos/AlfaGideon/Bunker/releases/latest', {headers: {'Accept': 'application/vnd.github+json'}})
  .then(response => { if (!response.ok) throw new Error('unavailable'); return response.json(); })
  .then(release => {
    if (release.draft || release.prerelease || !/^android-[1-9]\d*$/.test(release.tag_name)) return;
    const code = Number(release.tag_name.slice(8));
    const name = `Bunker-Posledniy-Shlyuz-${code}.apk`;
    const expected = `https://github.com/AlfaGideon/Bunker/releases/download/android-${code}/${name}`;
    if (!Array.isArray(release.assets) || !release.assets.some(asset => asset.name === name && asset.browser_download_url === expected && asset.size > 0)) return;
    document.querySelectorAll('.apk-link').forEach(link => link.href = expected);
    document.querySelectorAll('.release-version').forEach(node => node.textContent = `0.${code}`);
  }).catch(() => {});
