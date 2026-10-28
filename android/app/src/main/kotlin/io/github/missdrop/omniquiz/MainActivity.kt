// Registers native update/export channels and releases pending results when the engine detaches.

package io.github.missdrop.omniquiz

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var backupExporter: BackupExporter? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Native handlers are activity-scoped: a recreated engine must not reuse
        // a pending picker result or a callback bound to the previous activity.
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "io.github.missdrop.omniquiz/updates").setMethodCallHandler(UpdateInstaller(this))
        backupExporter = BackupExporter(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "io.github.missdrop.omniquiz/backup").setMethodCallHandler(backupExporter)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (backupExporter?.onActivityResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Detach the messenger before completing/cancelling retained export work.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "io.github.missdrop.omniquiz/updates").setMethodCallHandler(null)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "io.github.missdrop.omniquiz/backup").setMethodCallHandler(null)
        backupExporter?.dispose()
        backupExporter = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
