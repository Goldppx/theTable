"""Cold-start the installed APK on an Android emulator; retain device evidence."""
from pathlib import Path
import subprocess
import time

PACKAGE = 'cn.edu.ncist.it.the_table'
OUT = Path('build/startup-smoke')
OUT.mkdir(parents=True, exist_ok=True)

def adb(*args):
    result = subprocess.run(['adb', *args], capture_output=True, timeout=60)
    if result.returncode:
        raise RuntimeError(f'adb {args[0]} failed: {result.stderr.decode(errors="replace")}')
    return result.stdout

for attempt in range(1, 4):
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('logcat', '-c')
    launched = adb('shell', 'am', 'start', '-W', '-n', PACKAGE + '/.MainActivity')
    time.sleep(15)
    log = adb('logcat', '-d', '-v', 'threadtime')
    (OUT / f'launch-{attempt}.txt').write_bytes(launched + b'\n' + log)
    result = subprocess.run(['adb', 'shell', 'pidof', PACKAGE], capture_output=True, timeout=10)
    if result.returncode or not result.stdout.strip():
        raise RuntimeError(f'Application exited after cold start {attempt}; inspect build/startup-smoke logs')
    if b'Fatal signal' in log and PACKAGE.encode() in log:
        raise RuntimeError(f'Native crash during cold start {attempt}')
    (OUT / f'launch-{attempt}.png').write_bytes(adb('exec-out', 'screencap', '-p'))
print('Three Android cold starts passed; device logs and screenshots saved.')
