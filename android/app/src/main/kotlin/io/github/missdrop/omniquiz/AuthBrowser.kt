package io.github.missdrop.omniquiz

import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** A system-browser sheet keeps the calling activity visible while waiting for loopback OAuth.
 * No WebView, background service, battery exemption or persistent authorization data is used.
 */
class AuthBrowser(private val activity: MainActivity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "open" -> {
                    val uri = Uri.parse(call.argument<String>("url") ?: error("Missing URL"))
                    require((uri.scheme == "https" && uri.host == "auth.openai.com") ||
                        (uri.scheme == "http" && uri.host == "127.0.0.1"))
                    val height = (activity.resources.displayMetrics.heightPixels * 0.85).toInt()
                    val tab = CustomTabsIntent.Builder()
                        .setInitialActivityHeightPx(height, CustomTabsIntent.ACTIVITY_HEIGHT_FIXED)
                        .setShareState(CustomTabsIntent.SHARE_STATE_OFF)
                        .build()
                    // Required for partial Custom Tabs when there is no bound browser session.
                    activity.startActivityForResult(tab.intent.setData(uri), REQUEST_CODE, tab.startAnimationBundle)
                    result.success(true)
                }
                "close" -> {
                    // Reuse the existing Flutter activity and remove its browser sheet from the task.
                    activity.startActivity(Intent(activity, MainActivity::class.java).addFlags(
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            result.error("auth_browser", "Could not open or close the sign-in browser", null)
        }
    }

    companion object { const val REQUEST_CODE = 0x4a11 }
}
