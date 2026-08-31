package com.example.bgm_app

import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.Display
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Proxy
import java.net.ProxySelector
import java.util.WeakHashMap

class MainActivity : FlutterActivity() {
    private val surfaceCallbacks = WeakHashMap<SurfaceView, SurfaceHolder.Callback>()
    private val surfaceFrameRates = WeakHashMap<SurfaceView, Float>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.decorView.post(::requestHighestRefreshRate)
    }

    override fun onResume() {
        super.onResume()
        window.decorView.post(::requestHighestRefreshRate)
    }

    override fun onDestroy() {
        surfaceCallbacks.forEach { (view, callback) ->
            view.holder.removeCallback(callback)
        }
        surfaceCallbacks.clear()
        surfaceFrameRates.clear()
        super.onDestroy()
    }

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

    @Suppress("DEPRECATION")
    private fun activityDisplay(): Display? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            windowManager.defaultDisplay
        }

    @Suppress("DEPRECATION")
    private fun requestHighestRefreshRate() {
        val targetDisplay = activityDisplay() ?: return
        val configuredRate = Settings.Secure.getFloat(
            contentResolver,
            "user_refresh_rate",
            Float.NaN,
        ).takeIf { it.isFinite() && it > 0f } ?: Settings.System.getFloat(
            contentResolver,
            "peak_refresh_rate",
            Float.NaN,
        ).takeIf { it.isFinite() && it > 0f }
        val bestMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val currentMode = targetDisplay.mode
            targetDisplay.supportedModes
                .asSequence()
                .filter {
                    it.physicalWidth == currentMode.physicalWidth &&
                        it.physicalHeight == currentMode.physicalHeight &&
                        (configuredRate == null || it.refreshRate <= configuredRate + 0.5f)
                }
                .maxByOrNull { it.refreshRate }
        } else {
            null
        }
        val targetRate = bestMode?.refreshRate
            ?: targetDisplay.supportedRefreshRates.maxOrNull()
            ?: targetDisplay.refreshRate

        val attributes = window.attributes
        var requestChanged = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && bestMode != null) {
            if (attributes.preferredDisplayModeId != bestMode.modeId) {
                attributes.preferredDisplayModeId = bestMode.modeId
                requestChanged = true
            }
        } else {
            if (attributes.preferredRefreshRate != targetRate) {
                attributes.preferredRefreshRate = targetRate
                requestChanged = true
            }
        }
        if (requestChanged) {
            window.attributes = attributes
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            window.setFrameRateBoostOnTouchEnabled(true)
            window.setFrameRatePowerSavingsBalanced(false)
        }
        requestChanged = requestFrameRateForSurfaces(
            window.decorView,
            targetRate,
        ) || requestChanged
        if (requestChanged) {
            Log.i(
                "aBangumiFrameRate",
                "request=${targetRate}Hz mode=${bestMode?.modeId} user=${configuredRate ?: "auto"}",
            )
        }
    }

    private fun requestFrameRateForSurfaces(view: View, targetRate: Float): Boolean {
        var changed = false
        if (view is SurfaceView) {
            registerSurfaceFrameRateCallback(view)
            changed = applySurfaceFrameRate(view, targetRate)
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                changed = requestFrameRateForSurfaces(
                    view.getChildAt(index),
                    targetRate,
                ) || changed
            }
        }
        return changed
    }

    private fun registerSurfaceFrameRateCallback(view: SurfaceView) {
        if (surfaceCallbacks.containsKey(view)) return
        val callback = object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                requestHighestRefreshRate()
            }

            override fun surfaceChanged(
                holder: SurfaceHolder,
                format: Int,
                width: Int,
                height: Int,
            ) {
                requestHighestRefreshRate()
            }

            override fun surfaceDestroyed(holder: SurfaceHolder) {
                surfaceFrameRates.remove(view)
            }
        }
        surfaceCallbacks[view] = callback
        view.holder.addCallback(callback)
    }

    private fun applySurfaceFrameRate(view: SurfaceView, targetRate: Float): Boolean {
        if (surfaceFrameRates[view] == targetRate) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            view.requestedFrameRate = targetRate
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            surfaceFrameRates[view] = targetRate
            return true
        }
        val surface = view.holder.surface
        if (!surface.isValid) return false
        val compatibility = if (Build.VERSION.SDK_INT >= 36) {
            Surface.FRAME_RATE_COMPATIBILITY_AT_LEAST
        } else {
            Surface.FRAME_RATE_COMPATIBILITY_DEFAULT
        }
        surface.setFrameRate(targetRate, compatibility)
        surfaceFrameRates[view] = targetRate
        return true
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
