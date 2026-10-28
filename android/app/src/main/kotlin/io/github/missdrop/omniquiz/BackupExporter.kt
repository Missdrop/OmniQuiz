// Exports a bounded cache archive through SAF; worker I/O returns its result on the UI thread.

package io.github.missdrop.omniquiz

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Saves an existing archive through SAF without passing its bytes over Flutter. */
class BackupExporter(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object { const val REQUEST_CODE = 48121 }
    private var pending: MethodChannel.Result? = null
    private var source: File? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "exportBackup") { result.notImplemented(); return }
        if (pending != null) { result.error("busy", "An export is already open.", null); return }
        try {
            val file = File(requireNotNull(call.argument<String>("path"))).canonicalFile
            require(file.path.startsWith(activity.cacheDir.canonicalPath + File.separator))
            require(file.isFile && file.name == "OmniQuiz-backup.zip")
            source = file
            pending = result
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/zip"
                putExtra(Intent.EXTRA_TITLE, file.name)
            }
            activity.startActivityForResult(intent, REQUEST_CODE)
        } catch (_: Exception) {
            pending = null; source = null
            result.error("export_failed", "Could not open the backup save dialog.", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        if (pending == null) return true
        val file = source
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || file == null) {
            finish(null); return true
        }
        worker.execute {
            try {
                activity.contentResolver.openOutputStream(uri, "wt").use { output ->
                    requireNotNull(output)
                    file.inputStream().use { input -> input.copyTo(output, 64 * 1024) }
                }
                main.post { finish(true) }
            } catch (_: Exception) {
                main.post { finish(false) }
            }
        }
        return true
    }

    private fun finish(success: Boolean?) {
        val result = pending ?: return
        pending = null; source = null
        if (success == false) result.error("export_failed", "Could not save the backup.", null)
        else result.success(success)
    }

    fun dispose() {
        finish(false)
        worker.shutdown()
    }
}
