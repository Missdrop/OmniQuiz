// Validates APK identity, signing certificates and version before requesting OS-controlled installation.

package io.github.missdrop.omniquiz

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

/** Only verified downloads in our private update cache can reach the installer. */
class UpdateInstaller(private val activity: Activity) : MethodChannel.MethodCallHandler {
    @Suppress("DEPRECATION")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "abis" -> result.success(Build.SUPPORTED_ABIS.toList())
            "install" -> try {
                val root = File(activity.cacheDir, "updates").canonicalFile
                val file = File(requireNotNull(call.argument<String>("path"))).canonicalFile
                require(file.path.startsWith(root.path + File.separator) && file.isFile && file.extension == "apk")
                val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
                val candidate = requireNotNull(activity.packageManager.getPackageArchiveInfo(file.path, flags))
                val current = activity.packageManager.getPackageInfo(activity.packageName, flags)
                require(candidate.packageName == activity.packageName)
                require(signers(candidate) == signers(current) && signers(current).isNotEmpty())
                val candidateCode = if (Build.VERSION.SDK_INT >= 28) candidate.longVersionCode else candidate.versionCode.toLong()
                val currentCode = if (Build.VERSION.SDK_INT >= 28) current.longVersionCode else current.versionCode.toLong()
                require(candidateCode > currentCode)
                if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
                    activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:${activity.packageName}")))
                    result.success("permission")
                } else {
                    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
                    activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    })
                    result.success("installer")
                }
            } catch (_: Exception) {
                result.error("install_failed", "Could not open a compatible signed update.", null)
            }
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun signers(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
        return signatures.orEmpty().map {
            MessageDigest.getInstance("SHA-256").digest(it.toByteArray()).joinToString("") { byte -> "%02x".format(byte) }
        }.toSet()
    }
}
