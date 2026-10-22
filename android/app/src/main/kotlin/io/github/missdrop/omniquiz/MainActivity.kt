package io.github.missdrop.omniquiz

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var backupExporter: BackupExporter? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "io.github.missdrop.omniquiz/updates").setMethodCallHandler(null)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "io.github.missdrop.omniquiz/backup").setMethodCallHandler(null)
        backupExporter?.dispose()
        backupExporter = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
