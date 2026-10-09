#!/usr/bin/env python3
"""Apply a version-pinned theme loader patch; fail closed on upstream drift."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('apk', type=Path)
parser.add_argument('decoded', type=Path)
parser.add_argument('generated', type=Path)
args = parser.parse_args()
palette = json.loads((ROOT / 'palette.json').read_text())
assert hashlib.sha256(args.apk.read_bytes()).hexdigest() == palette['source_sha256'], 'Source APK changed'
with zipfile.ZipFile(args.apk) as z:
    bundle = z.read('assets/index.android.bundle')
assert hashlib.sha256(bundle).hexdigest() == palette['bundle_sha256']
assert hashlib.sha1(bundle[:-20]).digest() == bundle[-20:]
for color in palette['colors']:
    assert bundle[color['offset']:color['offset'] + 7].decode() == color['original']

source = (ROOT / 'native/cn/edu/ncist/it/uemconnect/patch/DynamicBundle.java').read_text()
source = source.replace('/* OFFSETS */', ', '.join(str(c['offset']) for c in palette['colors']))
for token, key in [('ORIGINAL', 'original'), ('RESOURCES', 'resource')]:
    source = source.replace('/* ' + token + ' */', ', '.join(json.dumps(c[key]) for c in palette['colors']))
source = source.replace('/* BUNDLE_SHA256 */', palette['bundle_sha256'])
args.generated.mkdir(parents=True, exist_ok=True)
(args.generated / 'DynamicBundle.java').write_text(source)

path = args.decoded / 'smali_classes2/com/facebook/react/bridge/JSBundleLoader$Companion.smali'
text = path.read_text()
pattern = r'(\.method public final createAssetLoader\(Landroid/content/Context;Ljava/lang/String;Z\)Lcom/facebook/react/bridge/JSBundleLoader;\n    \.locals 1\n)'
assert len(re.findall(pattern, text)) == 1, 'Unexpected upstream asset loader'
hook = '''
    invoke-static {p1, p2}, Lcn/edu/ncist/it/uemconnect/patch/DynamicBundle;->prepare(Landroid/content/Context;Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    if-eqz v0, :uem_original_asset
    invoke-virtual {p0, v0, p2, p3}, Lcom/facebook/react/bridge/JSBundleLoader$Companion;->createFileLoader(Ljava/lang/String;Ljava/lang/String;Z)Lcom/facebook/react/bridge/JSBundleLoader;
    move-result-object v0
    return-object v0
    :uem_original_asset
'''
text = re.sub(pattern, lambda m: m[1] + hook, text)
path.write_text(text)
yml = args.decoded / 'apktool.yml'
text = yml.read_text().replace('versionCode: 13', 'versionCode: 14').replace('versionName: 1.1.1', 'versionName: 1.1.1-dynamic.1')
yml.write_text(text)
print('Verified upstream APK and Hermes checksum; installed dynamic theme loader hook')
