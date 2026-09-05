package dev.kidremote.spike.enforcement

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import kotlin.math.ceil

class MainActivity : Activity() {
    private lateinit var store: LabTimerStore
    private lateinit var status: TextView
    private val handler = Handler(Looper.getMainLooper())
    private val refresh = object : Runnable {
        override fun run() {
            renderStatus()
            handler.postDelayed(this, 500)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = LabTimerStore(this)
        setContentView(buildContent())
    }

    override fun onResume() {
        super.onResume()
        handler.post(refresh)
    }

    override fun onPause() {
        handler.removeCallbacks(refresh)
        super.onPause()
    }

    private fun buildContent(): ScrollView {
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(24), dp(24), dp(32))
            setBackgroundColor(Color.rgb(246, 248, 247))
        }
        content.addView(text("KidRemote enforcement feasibility spike", 26f, Color.rgb(25, 40, 39)))
        content.addView(text(
            "TEST HARNESS ONLY — not a child-agent release and not evidence of Google Play approval.",
            14f,
            Color.rgb(151, 57, 42),
        ))
        content.addView(text(
            "Usage Access is used only to inspect aggregate screen-interactive and keyguard signals. " +
                "This spike does not retain or upload per-app history.",
            16f,
            Color.rgb(54, 69, 68),
        ))
        content.addView(text(
            "Accessibility is used only to display a screen-time block over known ordinary-app surfaces when the lab timer expires. " +
                "It does not read screen text or nodes, inspect content, record typing, take screenshots, or perform gestures. " +
                "Unknown and designated system/recovery surfaces fail open. Turning either access off degrades enforcement.",
            16f,
            Color.rgb(54, 69, 68),
        ))
        status = text("Loading health…", 16f, Color.rgb(25, 40, 39))
        content.addView(status)
        content.addView(button("Open Usage Access settings") {
            openSettings(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).setData(Uri.parse("package:$packageName")))
        })
        content.addView(button("I understand — open Accessibility settings") {
            openSettings(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        })
        content.addView(button("Arm 10-second lab timer") {
            store.arm(LAB_DURATION_MILLIS, DeviceSignals.eligibleForConsumption(this))
            Toast.makeText(this, "Lab timer armed", Toast.LENGTH_SHORT).show()
            renderStatus()
        })
        content.addView(button("Clear lab timer") {
            store.clear()
            renderStatus()
        })
        content.addView(button("Reset local timing samples") {
            store.clearLatencySamples()
            renderStatus()
        })
        return ScrollView(this).apply { addView(content) }
    }

    private fun renderStatus() {
        val state = store.load()
        val usage = DeviceSignals.hasUsageAccess(this)
        val accessibilityPermission = DeviceSignals.hasAccessibilityService(this)
        val serviceConnected = store.serviceHeartbeatFresh(SystemClock.elapsedRealtime())
        val adapter = store.adapterOutcome()
        val timing = LatencyStatistics.summarize(store.latencySamples())
        val health = PermissionHealthReducer.evaluate(
            usageAccess = usage,
            accessibility = accessibilityPermission,
            accountingUncertain = state.accountingUncertain,
            adapterFailed = (accessibilityPermission && !serviceConnected) || adapter == AdapterOutcome.OVERLAY_FAILED,
        )
        val probe = UsageEventProbe.sample(this)
        status.text = buildString {
            append("\nHealth: ").append(health.name.replace('_', ' '))
            append("\nUsage Access: ").append(if (usage) "enabled" else "required")
            append("\nAccessibility: ").append(if (accessibilityPermission) "enabled" else "required")
            append("; service: ").append(if (serviceConnected) "connected" else "unavailable")
            append("\nTimer: ").append(if (state.armed) "armed" else "not armed")
            append("\nRemaining: ").append(ceil(state.remainingMillis / 1000.0).toLong()).append(" s")
            append("\nRestriction required: ").append(state.restrictionRequired)
            append("\nAccounting uncertain: ").append(state.accountingUncertain)
            append("\nAdapter outcome: ").append(adapter.name.replace('_', ' '))
            append("\nExpiry→overlay samples: ").append(timing.samples)
            append("; p50 ").append(timing.p50Millis).append(" ms")
            append("; p95 ").append(timing.p95Millis).append(" ms")
            append("; max ").append(timing.maximumMillis).append(" ms")
            append("\nUsage signal probe: ").append(probe.eventCount).append(" signals; latest ").append(probe.latestSignal)
        }
    }

    private fun openSettings(intent: Intent) {
        try {
            startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            Toast.makeText(this, "This settings screen is unavailable on this device", Toast.LENGTH_LONG).show()
        }
    }

    private fun text(value: String, size: Float, colour: Int) = TextView(this).apply {
        text = value
        textSize = size
        setTextColor(colour)
        setPadding(0, 0, 0, dp(18))
    }

    private fun button(label: String, action: () -> Unit) = Button(this).apply {
        text = label
        isAllCaps = false
        setOnClickListener { action() }
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            bottomMargin = dp(10)
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private companion object {
        const val LAB_DURATION_MILLIS = 10_000L
    }
}
