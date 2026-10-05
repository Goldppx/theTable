from pathlib import Path
import xml.etree.ElementTree as ET

ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')
attr = '{http://schemas.android.com/apk/res/android}'
path = Path('android/app/src/main/AndroidManifest.xml')
tree = ET.parse(path)
root = tree.getroot()
for permission in ('INTERNET', 'ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION'):
    name = 'android.permission.' + permission
    if not any(item.get(attr + 'name') == name for item in root.findall('uses-permission')):
        ET.SubElement(root, 'uses-permission', {attr + 'name': name})
app = root.find('application')
app.set(attr + 'label', '应大通')
app.set(attr + 'allowBackup', 'false')
app.set(attr + 'icon', '@drawable/app_icon')
tree.write(path, encoding='utf-8', xml_declaration=True)
icon = Path('android/app/src/main/res/drawable/app_icon.xml')
icon.parent.mkdir(parents=True, exist_ok=True)
icon.write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#101418" android:pathData="M0,0h108v108h-108z" />
    <path android:fillColor="#A3C7FF" android:pathData="M28,30h52v49h-52z" />
    <path android:fillColor="#101418" android:pathData="M28,43h52v5h-52z M38,54h8v8h-8z M51,54h8v8h-8z M64,54h8v8h-8z M38,67h8v8h-8z M51,67h8v8h-8z" />
    <path android:strokeColor="#A3C7FF" android:strokeWidth="5" android:strokeLineCap="round" android:pathData="M39,25v12 M69,25v12" />
</vector>''', encoding='utf-8')
