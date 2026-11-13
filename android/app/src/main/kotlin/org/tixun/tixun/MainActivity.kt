package org.tixun.tixun

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.core.content.FileProvider
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
                val isBackup = call.method == "saveBackup"
                val isUsage = call.method == "saveUsage"
                if (!isBackup && !isUsage) {
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
                    val validExtension = if (isBackup) {
                        source.name.endsWith(".tixun-backup")
                    } else {
                        source.extension in setOf("csv", "jsonl")
                    }
                    if (!source.path.startsWith(cache.path + File.separator) ||
                        !source.isFile || !validExtension) {
                        result.error("INVALID_FILE", "导出暂存文件无效。", null)
                        return@setMethodCallHandler
                    }
                    val name = call.argument<String>("name") ?:
                        if (isBackup) "tixun.tixun-backup" else source.name
                    pendingSave = result
                    pendingSource = source
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = if (isBackup) {
                            "application/zip"
                        } else if (source.extension == "csv") {
                            "text/csv"
                        } else {
                            "application/json"
                        }
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.tixun/app_update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        try {
                            val file = File(call.argument<String>("path") ?: "").canonicalFile
                            val cache = cacheDir.canonicalFile
                            if (!file.path.startsWith(cache.path + File.separator) ||
                                !file.isFile || !file.name.endsWith(".apk")) {
                                result.error("INVALID_FILE", "安装包文件无效。", null)
                                return@setMethodCallHandler
                            }
                            if (!packageManager.canRequestPackageInstalls()) {
                                result.error("INSTALL_NOT_ALLOWED", "未允许安装未知应用。", null)
                                return@setMethodCallHandler
                            }
                            val uri = FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.fileprovider",
                                file,
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.error("INSTALL_FAILED", "无法打开安装界面。", null)
                        }
                    }
                    "openInstallSettings" -> {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName"),
                            ).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.error("SETTINGS_FAILED", "无法打开安装未知应用设置。", null)
                        }
                    }
                    else -> result.notImplemented()
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
