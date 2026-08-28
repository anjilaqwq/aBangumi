package com.example.bgm_app

import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Proxy
import java.net.ProxySelector

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "abgm/proxy")
            .setMethodCallHandler { call, result ->
                if (call.method != "getProxy") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val proxy = ProxySelector.getDefault()
                    ?.select(Uri.parse("https://api.bgm.tv").toJavaUri())
                    ?.firstOrNull { it.type() == Proxy.Type.HTTP }
                val address = proxy?.address() as? java.net.InetSocketAddress
                result.success(
                    when {
                        address != null -> "PROXY ${address.hostString}:${address.port}"
                        isEmulator() -> "PROXY 10.0.2.2:2080"
                        else -> "DIRECT"
                    }
                )
            }
    }

    private fun isEmulator(): Boolean {
        return Build.FINGERPRINT.startsWith("generic") ||
            Build.FINGERPRINT.startsWith("unknown") ||
            Build.MODEL.contains("google_sdk") ||
            Build.MODEL.contains("Emulator") ||
            Build.MODEL.contains("Android SDK built for x86") ||
            Build.MANUFACTURER.contains("Genymotion") ||
            (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")) ||
            Build.PRODUCT == "google_sdk"
    }

    private fun Uri.toJavaUri(): java.net.URI = java.net.URI(toString())
}
