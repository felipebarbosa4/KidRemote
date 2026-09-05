package dev.kidremote.spike.enforcement

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.os.Process
import android.os.PowerManager
import android.view.accessibility.AccessibilityManager

object DeviceSignals {
    fun eligibleForConsumption(context: Context): Boolean {
        val power = context.getSystemService(PowerManager::class.java)
        val keyguard = context.getSystemService(KeyguardManager::class.java)
        return power.isInteractive && !keyguard.isKeyguardLocked
    }

    fun hasUsageAccess(context: Context): Boolean {
        val appOps = context.getSystemService(AppOpsManager::class.java)
        val mode = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun hasAccessibilityService(context: Context): Boolean {
        val manager = context.getSystemService(AccessibilityManager::class.java)
        val expected = ComponentName(context, EnforcementAccessibilityService::class.java)
        return manager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK).any { info ->
            val serviceInfo = info.resolveInfo.serviceInfo
            ComponentName(serviceInfo.packageName, serviceInfo.name) == expected
        }
    }
}

data class UsageProbeResult(
    val eventCount: Int,
    val latestSignal: String,
)

object UsageEventProbe {
    private val eligibleTypes = setOf(
        UsageEvents.Event.SCREEN_INTERACTIVE,
        UsageEvents.Event.SCREEN_NON_INTERACTIVE,
        UsageEvents.Event.KEYGUARD_SHOWN,
        UsageEvents.Event.KEYGUARD_HIDDEN,
    )

    fun sample(context: Context, nowWallMillis: Long = System.currentTimeMillis()): UsageProbeResult {
        if (!DeviceSignals.hasUsageAccess(context)) return UsageProbeResult(0, "permission required")
        val usage = context.getSystemService(UsageStatsManager::class.java)
        val events = usage.queryEvents(nowWallMillis - PROBE_WINDOW_MILLIS, nowWallMillis)
        val event = UsageEvents.Event()
        var count = 0
        var latest = "none in probe window"
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType in eligibleTypes) {
                count += 1
                latest = eventName(event.eventType)
            }
        }
        return UsageProbeResult(count, latest)
    }

    private fun eventName(type: Int): String = when (type) {
        UsageEvents.Event.SCREEN_INTERACTIVE -> "screen interactive"
        UsageEvents.Event.SCREEN_NON_INTERACTIVE -> "screen non-interactive"
        UsageEvents.Event.KEYGUARD_SHOWN -> "keyguard shown"
        UsageEvents.Event.KEYGUARD_HIDDEN -> "keyguard hidden"
        else -> "other"
    }

    private const val PROBE_WINDOW_MILLIS = 15 * 60 * 1000L
}
