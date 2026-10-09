#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tools dist
curl -fsSL https://github.com/NCIST-IT/UEM-Connect-board/releases/download/v1.1.1/uem-connect.apk -o build/original.apk
curl -fsSL https://github.com/iBotPeaches/Apktool/releases/download/v2.12.1/apktool_2.12.1.jar -o build/tools/apktool.jar
curl -fsSL https://storage.googleapis.com/r8-releases/raw/8.3.37/r8.jar -o build/tools/r8.jar
java -jar build/tools/apktool.jar d -f build/original.apk -o build/decoded
python3 scripts/patch.py build/original.apk build/decoded build/generated
mkdir -p build/classes build/dex
javac --release 8 -classpath "$ANDROID_HOME/platforms/android-35/android.jar" -d build/classes build/generated/DynamicBundle.java
jar cf build/native.jar -C build/classes .
java -cp build/tools/r8.jar com.android.tools.r8.D8 --lib "$ANDROID_HOME/platforms/android-35/android.jar" --min-api 24 --output build/dex build/native.jar
python3 - <<'PY'
import zipfile
with zipfile.ZipFile('build/original.apk') as source, zipfile.ZipFile('build/native.apk','w') as out:
    out.writestr('AndroidManifest.xml', source.read('AndroidManifest.xml'))
    out.write('build/dex/classes.dex','classes.dex')
PY
java -jar build/tools/apktool.jar d -r -f build/native.apk -o build/native-decoded
cp -r build/native-decoded/smali/cn/edu/ncist/it/uemconnect/patch build/decoded/smali/cn/edu/ncist/it/uemconnect/
java -jar build/tools/apktool.jar b build/decoded -o build/unsigned.apk
"$ANDROID_HOME/build-tools/35.0.0/zipalign" -P 16 -f 4 build/unsigned.apk build/aligned.apk
if [ ! -f build/preview.jks ]; then
    keytool -genkeypair -keystore build/preview.jks -alias preview -storepass android -keypass android -keyalg RSA -keysize 2048 -validity 3650 -dname 'CN=UEM Dynamic Color Preview'
fi
"$ANDROID_HOME/build-tools/35.0.0/apksigner" sign --ks build/preview.jks --ks-key-alias preview --ks-pass pass:android --key-pass pass:android --out dist/uem-connect-1.1.1-dynamic.1-arm64.apk build/aligned.apk
"$ANDROID_HOME/build-tools/35.0.0/apksigner" verify --verbose dist/uem-connect-1.1.1-dynamic.1-arm64.apk
"$ANDROID_HOME/build-tools/35.0.0/zipalign" -P 16 -c 4 dist/uem-connect-1.1.1-dynamic.1-arm64.apk
python3 scripts/verify_apk.py build/original.apk dist/uem-connect-1.1.1-dynamic.1-arm64.apk
(cd dist && sha256sum *.apk > SHA256SUMS)
