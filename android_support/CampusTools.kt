package __PACKAGE__

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.core.app.NotificationCompat
import androidx.work.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.net.URL
import java.security.KeyStore
import java.util.TimeZone
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

object CampusTools {
    private val executor = Executors.newSingleThreadExecutor()
    private fun prefs(c: Context) = c.getSharedPreferences("campus_notifications", Context.MODE_PRIVATE)
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (!store.containsAlias("campus_api")) KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder("campus_api", KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build()); generateKey()
        }
        return store.getKey("campus_api", null) as SecretKey
    }
    private fun save(c: Context, value: JSONObject) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        val bytes = cipher.doFinal(value.toString().toByteArray(Charsets.UTF_8))
        prefs(c).edit().putString("config", Base64.encodeToString(cipher.iv + bytes, Base64.NO_WRAP)).apply()
    }
    fun config(c: Context): JSONObject {
        val encoded = prefs(c).getString("config", null) ?: return JSONObject()
        val bytes = Base64.decode(encoded, Base64.NO_WRAP)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12))) }
        return JSONObject(String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8))
    }
    private fun validUrl(s: String): Boolean { val u = Uri.parse(s); return u.scheme == "https" && !u.host.isNullOrEmpty() && u.userInfo == null }
    fun register(activity: FlutterActivity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "the_table/tools").setMethodCallHandler { call, result ->
            try {
                val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                when (call.method) {
                    "timezone" -> result.success(TimeZone.getDefault().id)
                    "apps" -> {
                        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                        val apps = activity.packageManager.queryIntentActivities(intent, 0).map { mapOf("name" to it.loadLabel(activity.packageManager).toString(), "package" to it.activityInfo.packageName) }.distinctBy { it["package"] }.sortedBy { it["name"] }
                        result.success(apps)
                    }
                    "open" -> {
                        val target = args["target"] as? String ?: ""
                        val intent = if (args["kind"] == "package") activity.packageManager.getLaunchIntentForPackage(target) ?: throw IllegalArgumentException("未安装该应用，请检查包名")
                        else { require(validUrl(target) || Uri.parse(target).scheme == "weixin") { "链接格式无效" }; Intent(Intent.ACTION_VIEW, Uri.parse(target)) }
                        activity.startActivity(intent); result.success(null)
                    }
                    "map" -> {
                        val lat = (args["lat"] as Number).toDouble(); val lon = (args["lon"] as Number).toDouble(); val name = Uri.encode(args["name"] as? String ?: "目的地")
                        require(lat in -90.0..90.0 && lon in -180.0..180.0)
                        val url = when (args["provider"]) {
                            "amap" -> "androidamap://viewMap?sourceApplication=theTable&poiname=$name&lat=$lat&lon=$lon&dev=1"
                            "baidu" -> "baidumap://map/marker?location=$lat,$lon&title=$name&coord_type=wgs84&src=theTable"
                            else -> "geo:$lat,$lon?q=$lat,$lon($name)"
                        }
                        activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))); result.success(null)
                    }
                    "apiConfig" -> {
                        val value = JSONObject(args); if (value.optBoolean("enabled")) require(validUrl(value.optString("url"))) { "API 必须使用 HTTPS" }
                        save(activity, value)
                        val manager = WorkManager.getInstance(activity)
                        if (value.optBoolean("enabled")) {
                            val work = PeriodicWorkRequestBuilder<CampusApiWorker>(15, TimeUnit.MINUTES).setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()).build()
                            manager.enqueueUniquePeriodicWork("campus_api", ExistingPeriodicWorkPolicy.UPDATE, work)
                        } else manager.cancelUniqueWork("campus_api")
                        result.success(null)
                    }
                    "apiMessage" -> { if (config(activity).optBoolean("enabled")) message(activity, JSONObject(args)); result.success(null) }
                    "apiCheck" -> executor.execute {
                        try { check(activity); activity.runOnUiThread { result.success(null) } }
                        catch (_: Exception) { activity.runOnUiThread { result.error("API_UNAVAILABLE", "API 检查失败，请检查地址、令牌和 JSON 响应", null) } }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("ACTION_FAILED", if (e is android.content.ActivityNotFoundException) "没有可以打开该入口的应用" else e.message, null) }
        }
    }
    @Synchronized fun message(c: Context, item: JSONObject) {
        val id = item.optString("id"); val title = item.optString("title"); val body = item.optString("body")
        require(id.isNotBlank() && title.isNotBlank() && id.length <= 200 && title.length <= 200 && body.length <= 10000) { "消息需要 id、title、body" }
        val seen = JSONArray(prefs(c).getString("seen", "[]")); val ids = (0 until seen.length()).map { seen.getString(it) }.toMutableList()
        if (id in ids) return
        val manager = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("api_messages", "校园 API 消息", NotificationManager.IMPORTANCE_HIGH))
        val icon = c.resources.getIdentifier("notification_icon", "drawable", c.packageName)
        val builder = NotificationCompat.Builder(c, "api_messages").setSmallIcon(icon).setContentTitle(title).setContentText(body).setStyle(NotificationCompat.BigTextStyle().bigText(body)).setAutoCancel(true)
        val url = item.optString("url")
        val intent = if (validUrl(url)) Intent(Intent.ACTION_VIEW, Uri.parse(url)) else c.packageManager.getLaunchIntentForPackage(c.packageName)
        if (intent != null) builder.setContentIntent(PendingIntent.getActivity(c, id.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        manager.notify(100000 + (id.hashCode() and 0x3fffffff), builder.build())
        ids.add(id); prefs(c).edit().putString("seen", JSONArray(ids.takeLast(200)).toString()).apply()
    }
    fun check(c: Context) {
        val cfg = config(c); if (!cfg.optBoolean("enabled")) return
        val url = cfg.optString("url"); require(validUrl(url))
        val connection = URL(url).openConnection() as javax.net.ssl.HttpsURLConnection
        try {
            connection.connectTimeout = 15000; connection.readTimeout = 20000; connection.instanceFollowRedirects = false
            connection.setRequestProperty("Accept", "application/json")
            if (cfg.optString("token").isNotEmpty()) connection.setRequestProperty("Authorization", "Bearer " + cfg.optString("token"))
            require(connection.responseCode == 200)
            val bytes = connection.inputStream.use { it.readBytesLimited(1024 * 1024) }
            val json = org.json.JSONTokener(String(bytes, Charsets.UTF_8)).nextValue()
            val items = when (json) { is JSONArray -> json; is JSONObject -> if (json.has("messages")) json.getJSONArray("messages") else JSONArray().put(json); else -> throw IllegalArgumentException() }
            require(items.length() <= 200)
            val current = config(c)
            if (!current.optBoolean("enabled") || current.optString("url") != url) return
            for (i in 0 until items.length()) message(c, items.getJSONObject(i))
        } finally { connection.disconnect() }
    }
    private fun java.io.InputStream.readBytesLimited(limit: Int): ByteArray {
        val out = java.io.ByteArrayOutputStream(); val buffer = ByteArray(8192)
        while (true) { val size = read(buffer); if (size < 0) break; require(out.size() + size <= limit); out.write(buffer, 0, size) }
        return out.toByteArray()
    }
}
class CampusApiWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result = try { CampusTools.check(applicationContext); Result.success() } catch (_: Exception) { Result.retry() }
}
