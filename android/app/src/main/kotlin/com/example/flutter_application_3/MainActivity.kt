package com.example.flutter_application_3

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.simpeg.pdam/android_device_settings"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getNotificationDiagnostic" -> {
                        result.success(getNotificationDiagnostic())
                    }
                    "openNotificationSettings" -> {
                        result.success(openAppNotificationSettings())
                    }
                    "openBatteryOptimizationSettings" -> {
                        result.success(openBatterySettings())
                    }
                    "openOemAutostartSettings" -> {
                        result.success(openOemBackgroundSettings())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getNotificationDiagnostic(): Map<String, Any> {
        val notificationsEnabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val ignoringBattery = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && powerManager != null) {
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }

        var urgentChannelImportance = NotificationManagerCompat.IMPORTANCE_UNSPECIFIED
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            val ch = nm?.getNotificationChannel("simpeg_urgent_channel")
            if (ch != null) {
                urgentChannelImportance = ch.importance
            }
        }

        return mapOf(
            "notificationsEnabled" to notificationsEnabled,
            "ignoringBatteryOptimizations" to ignoringBattery,
            "sdkInt" to Build.VERSION.SDK_INT,
            "manufacturer" to (Build.MANUFACTURER ?: "").lowercase(),
            "model" to (Build.MODEL ?: ""),
            "urgentChannelImportance" to urgentChannelImportance
        )
    }

    private fun openAppNotificationSettings(): Boolean {
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Throwable) {
            openAppDetailsSettings()
        }
    }

    private fun openBatterySettings(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val candidates = listOf(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
            )
            for (intent in candidates) {
                if (tryStartIntent(intent)) return true
            }
        }
        return openAppDetailsSettings()
    }

    private fun openOemBackgroundSettings(): Boolean {
        val manufacturer = (Build.MANUFACTURER ?: "").lowercase()
        val oemIntents = mutableListOf<Intent>()

        if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco")) {
            oemIntents.add(
                Intent().setComponent(
                    ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                )
            )
            oemIntents.add(
                Intent("miui.intent.action.OP_AUTO_START").addCategory(Intent.CATEGORY_DEFAULT)
            )
            oemIntents.add(
                Intent().setComponent(
                    ComponentName("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity")
                ).putExtra("package_name", packageName).putExtra("package_label", "SIMPEG Mobile")
            )
        } else if (manufacturer.contains("oppo") || manufacturer.contains("realme") || manufacturer.contains("oneplus")) {
            oemIntents.add(
                Intent().setComponent(
                    ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                )
            )
            oemIntents.add(
                Intent().setComponent(
                    ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")
                )
            )
            oemIntents.add(
                Intent().setComponent(
                    ComponentName("com.oplus.battery", "com.oplus.powermanager.fuelgaue.PowerUsageModelActivity")
                )
            )
        } else if (manufacturer.contains("vivo") || manufacturer.contains("iqoo")) {
            oemIntents.add(
                Intent().setComponent(
                    ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")
                )
            )
            oemIntents.add(
                Intent().setComponent(
                    ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                )
            )
        } else if (manufacturer.contains("huawei") || manufacturer.contains("honor")) {
            oemIntents.add(
                Intent().setComponent(
                    ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
                )
            )
            oemIntents.add(
                Intent().setComponent(
                    ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")
                )
            )
        } else if (manufacturer.contains("samsung")) {
            oemIntents.add(
                Intent().setComponent(
                    ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity")
                )
            )
            oemIntents.add(
                Intent().setComponent(
                    ComponentName("com.samsung.android.sm", "com.samsung.android.sm.battery.ui.BatteryActivity")
                )
            )
        } else if (manufacturer.contains("asus")) {
            oemIntents.add(
                Intent().setComponent(
                    ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.autostart.AutoStartActivity")
                )
            )
        } else if (manufacturer.contains("infinix") || manufacturer.contains("tecno") || manufacturer.contains("itel")) {
            oemIntents.add(
                Intent().setComponent(
                    ComponentName("com.transsion.phonemaster", "com.cyin.himgr.autostart.AutoStartActivity")
                )
            )
        }

        for (intent in oemIntents) {
            if (tryStartIntent(intent)) return true
        }
        return openAppDetailsSettings()
    }

    private fun openAppDetailsSettings(): Boolean {
        return tryStartIntent(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        )
    }

    private fun tryStartIntent(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val resolved = packageManager.resolveActivity(intent, 0)
            if (resolved != null) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (_: Throwable) {
            false
        }
    }
}
