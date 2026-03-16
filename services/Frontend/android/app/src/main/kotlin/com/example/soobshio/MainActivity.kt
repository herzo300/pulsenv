package com.soobshio.app

import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Bundle
import android.os.Debug
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private companion object {
        const val SECURITY_CHANNEL = "com.soobshio.security/runtime"
        private val ROOT_PATHS = listOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/system/app/Superuser.apk",
            "/system/bin/.ext/su",
            "/system/usr/we-need-root/su",
            "/system/xbin/daemonsu",
            "/su/bin/su",
            "/system/bin/magisk",
            "/sbin/magisk",
        )
        private val SUSPICIOUS_PACKAGES = listOf(
            "de.robv.android.xposed.installer",
            "io.github.vvb2060.magisk",
            "com.topjohnwu.magisk",
            "com.saurik.substrate",
            "re.frida.server",
            "com.devadvance.rootcloak",
        )
        private val SUSPICIOUS_MAP_TOKENS = listOf(
            "frida",
            "xposed",
            "substrate",
            "magisk",
            "zygisk",
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!BuildConfig.DEBUG) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SECURITY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSecurityState" -> result.success(buildSecurityState())
                else -> result.notImplemented()
            }
        }
    }

    private fun buildSecurityState(): Map<String, Any> {
        val debuggerAttached = Debug.isDebuggerConnected() || Debug.waitingForDebugger()
        val appDebuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        val adbEnabled = isAdbEnabled()
        val emulator = isProbablyEmulator()
        val rooted = isProbablyRooted()
        val suspiciousPackages = hasSuspiciousPackages()
        val hooked = hasSuspiciousMaps()

        return mapOf(
            "platform" to "android",
            "buildDebug" to BuildConfig.DEBUG,
            "debuggerAttached" to debuggerAttached,
            "appDebuggable" to appDebuggable,
            "adbEnabled" to adbEnabled,
            "emulator" to emulator,
            "rooted" to rooted,
            "suspiciousPackages" to suspiciousPackages,
            "hooked" to hooked,
            "secureFlagApplied" to !BuildConfig.DEBUG,
        )
    }

    private fun isAdbEnabled(): Boolean =
        runCatching {
            Settings.Global.getInt(contentResolver, Settings.Global.ADB_ENABLED, 0) == 1
        }.getOrDefault(false)

    private fun isProbablyRooted(): Boolean {
        if ((Build.TAGS ?: "").contains("test-keys")) {
            return true
        }
        return ROOT_PATHS.any { path -> File(path).exists() }
    }

    private fun hasSuspiciousPackages(): Boolean {
        val packageManager = applicationContext.packageManager
        return SUSPICIOUS_PACKAGES.any { packageName ->
            runCatching {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }.isSuccess
        }
    }

    private fun hasSuspiciousMaps(): Boolean {
        val mapsFile = File("/proc/self/maps")
        if (!mapsFile.exists()) {
            return false
        }
        return runCatching {
            val content = mapsFile.readText()
            SUSPICIOUS_MAP_TOKENS.any { token ->
                content.contains(token, ignoreCase = true)
            }
        }.getOrDefault(false)
    }

    private fun isProbablyEmulator(): Boolean {
        return Build.FINGERPRINT.startsWith("generic") ||
            Build.FINGERPRINT.lowercase().contains("emulator") ||
            Build.MODEL.contains("google_sdk") ||
            Build.MODEL.contains("Emulator") ||
            Build.MODEL.contains("Android SDK built for x86") ||
            Build.MANUFACTURER.contains("Genymotion") ||
            (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")) ||
            "google_sdk" == Build.PRODUCT
    }
}
