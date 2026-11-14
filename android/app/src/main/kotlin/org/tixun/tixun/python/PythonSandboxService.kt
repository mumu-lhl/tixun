package org.tixun.tixun.python

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.os.Process

/** The only process allowed to initialize CPython. No app UID or permissions. */
class PythonSandboxService : Service() {
    private var started = false
    private val binder = object : IPythonSandboxService.Stub() {
        @Synchronized override fun run(input: ParcelFileDescriptor, output: ParcelFileDescriptor) {
            if (started) { input.close(); output.close(); return }
            started = true
            Thread({
                try {
                    System.loadLibrary("tixun_python_sandbox")
                    val archives = listOf("stdlib.zip", "sitepackages.zip", "extract.zip", "app.zip")
                        .map { asset ->
                            val bytes = assets.open(asset).use { it.readBytes() }
                            val fd = PythonSandboxNative.archive(bytes)
                            check(fd >= 0) { "Cannot create isolated runtime archive" }
                            fd
                        }.toIntArray()
                    val abi = if (Process.is64Bit()) {
                        if (android.os.Build.SUPPORTED_64_BIT_ABIS[0] == "x86_64") "x86_64" else "arm64-v8a"
                    } else "armeabi-v7a"
                    val prefix = applicationInfo.sourceDir + "!/lib/" + abi + "/"
                    val status = PythonSandboxNative.run(prefix, archives, input.fd, output.fd)
                    if (status != 0) java.io.FileOutputStream(output.fileDescriptor).write("Native Python status $status".toByteArray())
                } catch (error: Throwable) {
                    java.io.FileOutputStream(output.fileDescriptor).write(("Isolated runtime failed: " + error.toString()).toByteArray())
                } finally {
                    input.close()
                    output.close()
                    Process.killProcess(Process.myPid())
                }
            }, "isolated-python").start()
        }

        override fun stop() { Process.killProcess(Process.myPid()) }
    }

    override fun onBind(intent: Intent): IBinder = binder
}

internal object PythonSandboxNative {
    external fun archive(bytes: ByteArray): Int
    external fun run(prefix: String, archives: IntArray, input: Int, output: Int): Int
}
