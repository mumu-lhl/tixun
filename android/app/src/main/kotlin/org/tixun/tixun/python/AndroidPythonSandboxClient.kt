package org.tixun.tixun.python

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.ServiceConnection
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.UUID
import java.util.concurrent.Executors

/** Only bounded pipes cross the app/isolated UID boundary, never app directory FDs. */
class AndroidPythonSandboxClient(private val activity: Activity) {
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newCachedThreadPool()
    private var active: Request? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "execute" -> {
                if (active != null) { result.error("BUSY", "Python is running", null); return }
                val payload = call.argument<String>("payload") ?: ""
                val id = call.argument<String>("requestId") ?: ""
                val timeout = call.argument<Int>("timeoutSeconds") ?: 0
                if (payload.toByteArray().size > LIMIT || id.isEmpty() || timeout !in 1..120) {
                    result.error("INVALID_ARGUMENT", "Invalid Python request", null); return
                }
                val request = Request(id, payload, result)
                active = request
                request.start(timeout)
            }
            "cancel" -> {
                if (call.argument<String>("requestId") == active?.id) {
                    active?.finish(null, "Python execution cancelled")
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun close() {
        active?.finish(null, "Python activity closed")
        io.shutdownNow()
    }

    private inner class Request(
        val id: String,
        private val payload: String,
        private val result: MethodChannel.Result,
    ) : ServiceConnection {
        private var bound = false
        private var finished = false
        private var connected = false
        private var service: IPythonSandboxService? = null
        private val descriptors = mutableListOf<ParcelFileDescriptor>()
        private val timeout = Runnable { finish(null, "Python execution timed out; isolated process stopped", "SANDBOX_TIMEOUT") }

        fun start(seconds: Int) {
            main.postDelayed(timeout, seconds * 1000L)
            try {
                bound = activity.bindIsolatedService(
                    Intent(activity, PythonSandboxService::class.java),
                    android.content.Context.BIND_AUTO_CREATE,
                    "python_" + UUID.randomUUID().toString().replace("-", ""),
                    activity.mainExecutor, this,
                )
                if (!bound) finish(null, "Cannot bind isolated Python service")
            } catch (error: Exception) { finish(null, error.message ?: "Cannot start sandbox") }
        }

        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            // A service restart must never replay code after a crash. The
            // original pipe reader reports EOF or the watchdog stops the run.
            if (finished || connected) return
            connected = true
            try {
                service = IPythonSandboxService.Stub.asInterface(binder)
                val input = ParcelFileDescriptor.createPipe()
                val output = ParcelFileDescriptor.createPipe()
                descriptors.addAll(input)
                descriptors.addAll(output)
                service!!.run(input[0], output[1])
                input[0].close()
                output[1].close()
                io.execute {
                    try {
                        ParcelFileDescriptor.AutoCloseOutputStream(input[1]).use {
                            it.write(payload.toByteArray(Charsets.UTF_8))
                        }
                    } catch (error: Exception) {
                        main.post { finish(null, error.message ?: "Sandbox input failed") }
                    }
                }
                io.execute {
                    try {
                        val bytes = ByteArrayOutputStream()
                        ParcelFileDescriptor.AutoCloseInputStream(output[0]).use { stream ->
                            val buffer = ByteArray(65536)
                            while (true) {
                                val count = stream.read(buffer)
                                if (count < 0) break
                                check(bytes.size() + count <= LIMIT) { "Sandbox output exceeds limit" }
                                bytes.write(buffer, 0, count)
                            }
                        }
                        val response = bytes.toString("UTF-8")
                        main.post {
                            if (response.isEmpty()) finish(null, "Isolated Python process exited without a result")
                            else finish(response, null)
                        }
                    } catch (error: Exception) {
                        main.post { finish(null, error.message ?: "Sandbox output failed") }
                    }
                }
            } catch (error: Exception) { finish(null, error.message ?: "Sandbox IPC failed") }
        }

        // EOF on the result pipe, not Binder death, determines completion: the
        // service exits immediately after writing and these events can race.
        override fun onServiceDisconnected(name: ComponentName) {}
        override fun onNullBinding(name: ComponentName) { finish(null, "Sandbox binding rejected") }
        override fun onBindingDied(name: ComponentName) { finish(null, "Sandbox binding died") }

        fun finish(response: String?, error: String?, code: String = "SANDBOX_FAILED") {
            if (finished) return
            finished = true
            main.removeCallbacks(timeout)
            try { service?.stop() } catch (_: Exception) {}
            if (bound) { activity.unbindService(this); bound = false }
            descriptors.forEach { try { it.close() } catch (_: Exception) {} }
            active = null
            if (response != null) result.success(response)
            else result.error(code, error, null)
        }
    }

    companion object { private const val LIMIT = 16 * 1024 * 1024 }
}
