// Registers native update/export channels and releases pending results when the engine detaches.

package io.github.missdrop.omniquiz

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var backupExporter: BackupExporter? = null
    private var authBrowserChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Native handlers are activity-scoped: a recreated engine must not reuse
        // a pending picker result or a callback bound to the previous activity.
        super.configureFlutterEngine(flutterEngine)
        authBrowserChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "io.github.missdrop.omniquiz/auth_browser").also {
            it.setMethodCallHandler(AuthBrowser(this))
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "io.github.missdrop.omniquiz/updates").setMethodCallHandler(UpdateInstaller(this))
        backupExporter = BackupExporter(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "io.github.missdrop.omniquiz/backup").setMethodCallHandler(backupExporter)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == AuthBrowser.REQUEST_CODE) {
            authBrowserChannel?.invokeMethod("closed", null)
            return
        }
        if (backupExporter?.onActivityResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Detach the messenger before completing/cancelling retained export work.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "io.github.missdrop.omniquiz/updates").setMethodCallHandler(null)
        authBrowserChannel?.setMethodCallHandler(null)
        authBrowserChannel = null
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "io.github.missdrop.omniquiz/backup").setMethodCallHandler(null)
        backupExporter?.dispose()
        backupExporter = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
