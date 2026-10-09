import hashlib
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as original, zipfile.ZipFile(sys.argv[2]) as patched:
    for name in original.namelist():
        if name.startswith(('assets/', 'lib/')):
            assert original.read(name) == patched.read(name), name + ' unexpectedly changed'
    assert len([n for n in patched.namelist() if n.endswith('.dex')]) >= 3
    assert patched.testzip() is None
print('All original assets, Hermes bytecode and native libraries preserved byte-for-byte')
print('APK SHA256:', hashlib.sha256(open(sys.argv[2], 'rb').read()).hexdigest())
