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

# Preserve HttpOnly/Secure cookie attributes when native CAS opens a WebView.
activity = next(Path('android/app/src/main/kotlin').rglob('MainActivity.kt'))
package_line = next(line for line in activity.read_text().splitlines() if line.startswith('package '))
activity.write_text(package_line + '''

import android.net.Uri
import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "the_table/campus_session")
            .setMethodCallHandler { call, result ->
                val manager = CookieManager.getInstance()
                when (call.method) {
                    "clearCookies" -> manager.removeAllCookies { manager.flush(); result.success(null) }
                    "setCookies" -> {
                        val records = call.arguments as? List<*>
                        val allowed = setOf("auth.ncist.edu.cn", "my1.ncist.edu.cn", "jw.cidp.edu.cn", "gms.ncist.edu.cn")
                        val parsed = records?.mapNotNull { record ->
                            val item = record as? Map<*, *>
                            val url = item?.get("uri") as? String
                            val cookie = item?.get("cookie") as? String
                            if (url != null && cookie != null && Uri.parse(url).scheme == "https" && Uri.parse(url).host in allowed) Pair(url, cookie) else null
                        }
                        if (parsed == null || parsed.size != records?.size) {
                            result.error("INVALID_SESSION", "Invalid school cookie records", null)
                        } else {
                            manager.setAcceptCookie(true)
                            manager.removeAllCookies {
                                if (parsed.isEmpty()) { manager.flush(); result.success(null) }
                                else {
                                    var remaining = parsed.size
                                    var accepted = true
                                    parsed.forEach { (url, cookie) ->
                                        manager.setCookie(url, cookie) { success ->
                                            accepted = accepted && success
                                            remaining -= 1
                                            if (remaining == 0) {
                                                manager.flush()
                                                if (accepted) result.success(null) else result.error("COOKIE_REJECTED", "Cookie rejected", null)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
''', encoding='utf-8')

activity.write_text(activity.read_text().replace('super.configureFlutterEngine(flutterEngine)', 'super.configureFlutterEngine(flutterEngine)\n        CampusTools.register(this, flutterEngine)'))
(activity.parent / 'CampusTools.kt').write_text(Path('android_support/CampusTools.kt').read_text().replace('__PACKAGE__', package_line.removeprefix('package ').strip()))
for permission in ('POST_NOTIFICATIONS', 'SCHEDULE_EXACT_ALARM', 'RECEIVE_BOOT_COMPLETED'):
    name = 'android.permission.' + permission
    if not any(item.get(attr + 'name') == name for item in root.findall('uses-permission')):
        ET.SubElement(root, 'uses-permission', {attr + 'name': name})
# Replace only tool queries so repeated local generation keeps the manifest valid.
queries = root.find('queries')
if queries is None:
    queries = ET.SubElement(root, 'queries')
for item in list(queries):
    action = item.find('action')
    data = item.find('data')
    category = item.find('category')
    if (action is not None and action.get(attr + 'name') == 'android.intent.action.MAIN' and category is not None and category.get(attr + 'name') == 'android.intent.category.LAUNCHER') or (data is not None and data.get(attr + 'scheme') in ('https', 'weixin', 'androidamap', 'baidumap', 'geo')):
        queries.remove(item)
intent = ET.SubElement(queries, 'intent')
ET.SubElement(intent, 'action', {attr + 'name': 'android.intent.action.MAIN'})
ET.SubElement(intent, 'category', {attr + 'name': 'android.intent.category.LAUNCHER'})
for scheme in ('https', 'weixin', 'androidamap', 'baidumap', 'geo'):
    intent = ET.SubElement(queries, 'intent')
    ET.SubElement(intent, 'action', {attr + 'name': 'android.intent.action.VIEW'})
    ET.SubElement(intent, 'data', {attr + 'scheme': scheme})
for item in list(app.findall('receiver')):
    if item.get(attr + 'name') in ('com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver', 'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver'):
        app.remove(item)
ET.SubElement(app, 'receiver', {attr + 'name': 'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver', attr + 'exported': 'false'})
receiver = ET.SubElement(app, 'receiver', {attr + 'name': 'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver', attr + 'exported': 'false'})
intent = ET.SubElement(receiver, 'intent-filter')
for action in ('BOOT_COMPLETED', 'MY_PACKAGE_REPLACED', 'QUICKBOOT_POWERON'):
    ET.SubElement(intent, 'action', {attr + 'name': 'android.intent.action.' + action})
tree.write(path, encoding='utf-8', xml_declaration=True)
(icon.parent / 'notification_icon.xml').write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24"><path android:fillColor="#FFFFFFFF" android:pathData="M4,4h16v17h-16z M7,1h2v6h-2z M15,1h2v6h-2z" /></vector>''')
gradle = Path('android/app/build.gradle.kts')
text = gradle.read_text()
if 'isCoreLibraryDesugaringEnabled' not in text:
    text = text.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true')
if 'com.android.tools:desugar_jdk_libs' not in text:
    text += '\ndependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }\n'
if 'androidx.work:work-runtime' not in text:
    text += '\ndependencies { implementation("androidx.work:work-runtime-ktx:2.10.1") }\n'
gradle.write_text(text)

# Compatibility build: install native libraries as standalone files instead of
# mapping libflutter.so directly from base.apk. Keep the official engine intact.
text = gradle.read_text()
if 'useLegacyPackaging' not in text:
    text = text.replace('android {', 'android {\n    packaging {\n        jniLibs { useLegacyPackaging = true }\n    }', 1)
else:
    text = text.replace('useLegacyPackaging = false', 'useLegacyPackaging = true')
gradle.write_text(text)
