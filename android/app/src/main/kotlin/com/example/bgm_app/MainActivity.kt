package com.example.bgm_app

import android.net.Uri
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
                    ?.firstOrNull { it.type() == Proxy.Type.HTTP || it.type() == Proxy.Type.SOCKS }
                val address = proxy?.address() as? java.net.InetSocketAddress
                result.success(
                    if (address == null) "DIRECT"
                    else "${if (proxy?.type() == Proxy.Type.SOCKS) "SOCKS5" else "PROXY"} ${address.hostString}:${address.port}"
                )
            }
    }

    private fun Uri.toJavaUri(): java.net.URI = java.net.URI(toString())
}
