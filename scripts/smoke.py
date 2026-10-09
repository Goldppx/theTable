"""Verify native theme loading, real rendered colors and startup on Android."""
import json
from pathlib import Path
import re
import subprocess
import time

PACKAGE = 'cn.edu.ncist.it.uemconnect'
OUT = Path('build/smoke')
OUT.mkdir(parents=True, exist_ok=True)

def adb(*args):
    return subprocess.check_output(['adb', *args], text=True)

activity = adb('shell', 'cmd', 'package', 'resolve-activity', '--brief', PACKAGE).strip().splitlines()[-1]
assert '/' in activity, activity
colors = []
for name, seed in [('green','008800'), ('purple','880088')]:
    settings = json.dumps({'android.theme.customization.color_source': 'preset',
        'android.theme.customization.system_palette': seed,
        'android.theme.customization.accent_color': seed}, separators=(',', ':'))
    adb('shell', 'settings', 'put', 'secure', 'theme_customization_overlay_packages', "'" + settings + "'")
    time.sleep(12)
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('logcat', '-c')
    adb('shell', 'am', 'start', '-W', '-n', activity)
    time.sleep(15)
    logs = adb('logcat', '-d')
    (OUT / f'{name}.log').write_text(logs)
    primary = re.findall(r'primary_light=(#[0-9A-F]{6})', logs)
    assert primary, 'Dynamic theme loader did not run: inspect smoke log'
    assert 'System palette applied to 18 theme constants' in logs
    assert 'Keeping upstream theme' not in logs
    assert 'FATAL EXCEPTION' not in logs and 'Fatal signal' not in logs
    assert adb('shell', 'pidof', PACKAGE).strip(), 'App stopped'
    colors.append(primary[-1])
    screenshot = subprocess.check_output(['adb', 'exec-out', 'screencap', '-p'])
    (OUT / f'{name}.png').write_bytes(screenshot)
assert len(set(colors)) == 2, f'System palette did not change: {colors}'
(OUT / 'result.json').write_text(json.dumps({'primary_colors': colors, 'startup': 'passed'}, indent=2))
print('Cold-start and system palette change passed:', colors)
