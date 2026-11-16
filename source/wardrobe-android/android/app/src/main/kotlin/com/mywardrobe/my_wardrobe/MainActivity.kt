package com.mywardrobe.my_wardrobe

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 自动备份的落盘通道：
 *  - Android 10+ 走 MediaStore.Files（external_primary），RELATIVE_PATH = Documents/公主日记备份（公共目录，卸载不丢）；
 *    Downloads 集合只允许 Download/ 子目录，写 Documents 会被系统拒绝，所以统一用 Files 集合
 *  - Android 9 及以下走 WRITE_EXTERNAL_STORAGE 直接写公共 Documents
 * Dart 侧先把 .wrdx 生成在临时目录，再交给这里拷进去；删除旧备份也在这里做。
 */
class MainActivity : FlutterActivity() {
    private val channelName = "princess_diary/backup"
    // list/save/delete 三处共用；Files 集合才允许任意 RELATIVE_PATH（API 29+ 用 external_primary）
    private val backupCollection: Uri = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
    private val relPath = "Documents/公主日记备份"
    private val prefix = "gongzhuriji_"
    private val suffix = ".wrdx"

    private var pendingResult: MethodChannel.Result? = null
    private var pendingAction: (() -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "listBackups" -> result.success(listBackups())
                "saveBackup" -> {
                    val path = call.argument<String>("path")
                    val name = call.argument<String>("name")
                    if (path == null || name == null) {
                        result.error("bad_args", "path/name 不能为空", null)
                        return@setMethodCallHandler
                    }
                    withStoragePermission(result) { saveBackup(File(path), name, result) }
                }
                "deleteBackup" -> {
                    val name = call.argument<String>("name")
                    if (name == null) {
                        result.error("bad_args", "name 不能为空", null)
                        return@setMethodCallHandler
                    }
                    withStoragePermission(result) {
                        try {
                            deleteBackup(name)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("delete_failed", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Android 9 及以下需要写外部存储权限；先请求再执行。 */
    private fun withStoragePermission(result: MethodChannel.Result, action: () -> Unit) {
        if (Build.VERSION.SDK_INT >= 29 ||
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        ) {
            action()
            return
        }
        pendingResult = result
        pendingAction = action
        requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 21701)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 21701) return
        val action = pendingAction
        val result = pendingResult
        pendingAction = null
        pendingResult = null
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted && action != null) {
            action()
        } else {
            result?.error("permission_denied", "没有外部存储写入权限", null)
        }
    }

    private fun legacyDir(): File =
        File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS), "公主日记备份")

    private fun listBackups(): List<String> {
        val out = ArrayList<String>()
        if (Build.VERSION.SDK_INT >= 29) {
            val projection = arrayOf(MediaStore.MediaColumns.DISPLAY_NAME)
            val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ? AND ${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ?"
            val args = arrayOf("$relPath%", "$prefix%")
            contentResolver.query(backupCollection, projection, selection, args, null)?.use { c ->
                while (c.moveToNext()) {
                    val n = c.getString(0) ?: continue
                    if (n.startsWith(prefix) && n.endsWith(suffix)) out.add(n)
                }
            }
        } else {
            legacyDir().listFiles()?.forEach { f ->
                if (f.isFile && f.name.startsWith(prefix) && f.name.endsWith(suffix)) out.add(f.name)
            }
        }
        out.sort()
        return out
    }

    private fun saveBackup(src: File, name: String, result: MethodChannel.Result) {
        try {
            if (!src.exists()) throw IllegalStateException("临时备份文件不存在")
            if (Build.VERSION.SDK_INT >= 29) {
                val resolver = contentResolver
                // 同一分钟再次备份时文件名相同：先删掉同名旧文件，保证目录里只有一份
                deleteBackup(name)
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/octet-stream")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, relPath)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val uri: Uri = resolver.insert(backupCollection, values)
                    ?: throw IllegalStateException("MediaStore 无法创建文件")
                try {
                    resolver.openOutputStream(uri)?.use { out ->
                        src.inputStream().use { it.copyTo(out) }
                    } ?: throw IllegalStateException("无法写入文件")
                    val done = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
                    resolver.update(uri, done, null, null)
                } catch (e: Exception) {
                    resolver.delete(uri, null, null)
                    throw e
                }
                result.success(queryName(uri) ?: name)
            } else {
                val dir = legacyDir()
                if (!dir.exists() && !dir.mkdirs()) throw IllegalStateException("无法创建备份目录")
                var target = File(dir, name)
                // 同名文件直接覆盖（与 MediaStore 行为不同，去掉再拷）
                if (target.exists()) target.delete()
                src.copyTo(target, overwrite = true)
                result.success(name)
            }
        } catch (e: Exception) {
            result.error("save_failed", e.message, null)
        }
    }

    private fun queryName(uri: Uri): String? {
        contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) return c.getString(0)
        }
        return null
    }

    private fun deleteBackup(name: String) {
        if (Build.VERSION.SDK_INT >= 29) {
            val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ? AND ${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
            val args = arrayOf("$relPath%", name)
            contentResolver.delete(backupCollection, selection, args)
        } else {
            val f = File(legacyDir(), name)
            if (f.exists()) f.delete()
        }
    }
}
