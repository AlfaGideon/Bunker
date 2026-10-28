"""Prevent publishing stale version metadata or credentials with source."""
import configparser
from pathlib import Path
import re
c = configparser.ConfigParser(interpolation=None)
c.read('export_presets.cfg')
options = c['preset.0.options']
script = Path('game/scripts/app_updates.gd').read_text()
code = int(re.search(r'const VERSION_CODE := (\d+)', script)[1])
name = re.search(r'const VERSION_NAME := "([^"]+)"', script)[1]
assert options.getint('version/code') == code
assert options['version/name'].strip('"') == name
assert options['permissions/internet'] == 'true'
assert options['package/unique_name'] == '"org.bunker.prototype"'
print('Release version, package ID and Internet permission verified')
