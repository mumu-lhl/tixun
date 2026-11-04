package org.tixun.tixun

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var pendingSave: MethodChannel.Result? = null
    private var pendingSource: File? = null
    private val writer = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.tixun/backup_files")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveBackup") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingSave != null) {
                    result.error("BUSY", "另一个文件保存操作尚未完成。", null)
                    return@setMethodCallHandler
                }
                try {
                    val source = File(call.argument<String>("source") ?: "").canonicalFile
                    val cache = cacheDir.canonicalFile
                    if (!source.path.startsWith(cache.path + File.separator) ||
                        !source.isFile || !source.name.endsWith(".tixun-backup")) {
                        result.error("INVALID_FILE", "备份暂存文件无效。", null)
                        return@setMethodCallHandler
                    }
                    val name = call.argument<String>("name") ?: "tixun.tixun-backup"
                    pendingSave = result
                    pendingSource = source
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/zip"
                        putExtra(Intent.EXTRA_TITLE, File(name).name)
                    }
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, SAVE_BACKUP)
                } catch (_: Exception) {
                    pendingSave = null
                    pendingSource = null
                    result.error("SAVE_FAILED", "无法打开系统文件保存窗口。", null)
                }
            }
    }

    @Deprecated("Android forwards the document-picker result through this activity API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_BACKUP) return
        val result = pendingSave ?: return
        val source = pendingSource
        pendingSave = null
        pendingSource = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || source == null) {
            result.success(false)
            return
        }
        writer.execute {
            try {
                contentResolver.openOutputStream(uri, "wt").use { output ->
                    requireNotNull(output)
                    source.inputStream().use { input -> input.copyTo(output, 64 * 1024) }
                }
                runOnUiThread { result.success(true) }
            } catch (_: Exception) {
                runOnUiThread { result.error("WRITE_FAILED", "备份保存失败，请检查存储空间并重试。", null) }
            }
        }
    }

    override fun onDestroy() {
        pendingSave?.error("INTERRUPTED", "文件保存已中断，请重新导出。", null)
        pendingSave = null
        writer.shutdown()
        super.onDestroy()
    }

    companion object { private const val SAVE_BACKUP = 4182 }
}
