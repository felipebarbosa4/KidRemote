package dev.kidremote.spike.enforcement

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class EnforcementAccessibilityService : AccessibilityService() {
    private lateinit var store: LabTimerStore
    private lateinit var windowManager: WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private var state = LabTimerState()
    private var persistedAtElapsed = 0L
    private var surfaceDisposition = SurfaceDisposition.UNKNOWN_FAIL_OPEN
    private var overlay: View? = null
    private var pendingExpiryElapsed: Long? = null
    private var receiverRegistered = false

    private val tick = object : Runnable {
        override fun run() {
            sampleAndApply()
            handler.postDelayed(this, TICK_MILLIS)
        }
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            sampleAndApply()
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        store = LabTimerStore(this)
        windowManager = getSystemService(WindowManager::class.java)
        state = store.load()
        persistedAtElapsed = SystemClock.elapsedRealtime()
        store.setServiceHeartbeat(persistedAtElapsed)
        registerScreenSignals()
        handler.post(tick)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Only the transient package identity is used to distinguish a known ordinary app from a safe/unknown surface.
        // No AccessibilityNodeInfo, text, content, history, screenshots, gestures, or package timeline is accessed.
        surfaceDisposition = SurfacePolicy.classify(event?.packageName, packageName)
        sampleAndApply()
    }

    override fun onInterrupt() {
        hideOverlay()
        if (::store.isInitialized) {
            store.clearServiceHeartbeat()
            store.setAdapterOutcome(AdapterOutcome.OVERLAY_FAILED)
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        if (receiverRegistered) unregisterReceiver(screenReceiver)
        hideOverlay()
        if (::store.isInitialized) store.clearServiceHeartbeat()
        super.onDestroy()
    }

    private fun sampleAndApply() {
        if (!::store.isInitialized) return
        if (store.currentRevision() != state.revision) state = store.load()
        val now = SystemClock.elapsedRealtime()
        val previousRestriction = state.restrictionRequired
        if (!previousRestriction && state.wasEligible && now - state.lastElapsedRealtimeMillis >= state.remainingMillis) {
            pendingExpiryElapsed = state.lastElapsedRealtimeMillis + state.remainingMillis
        }
        state = LabTimerReducer.sample(state, now, DeviceSignals.eligibleForConsumption(this))
        if (now - persistedAtElapsed >= PERSIST_MILLIS || previousRestriction != state.restrictionRequired) {
            if (!store.save(state)) {
                state = state.copy(accountingUncertain = true, wasEligible = false)
            }
            persistedAtElapsed = now
            store.setServiceHeartbeat(now)
        }
        applyRestriction(state.restrictionRequired)
    }

    private fun applyRestriction(required: Boolean) {
        if (!required) {
            hideOverlay()
            store.setAdapterOutcome(AdapterOutcome.NOT_REQUIRED)
            return
        }
        when (surfaceDisposition) {
            SurfaceDisposition.SAFE_SYSTEM -> {
                hideOverlay()
                store.setAdapterOutcome(AdapterOutcome.SAFE_SURFACE_AVAILABLE)
            }
            SurfaceDisposition.UNKNOWN_FAIL_OPEN -> {
                hideOverlay()
                store.setAdapterOutcome(AdapterOutcome.UNKNOWN_SURFACE_FAIL_OPEN)
            }
            SurfaceDisposition.ORDINARY_APP -> showOverlay()
        }
    }

    private fun showOverlay() {
        if (overlay != null) {
            store.setAdapterOutcome(AdapterOutcome.APPLIED)
            return
        }
        val view = buildOverlay()
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            android.graphics.PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.CENTER }
        try {
            windowManager.addView(view, params)
            overlay = view
            store.setAdapterOutcome(AdapterOutcome.APPLIED)
            pendingExpiryElapsed?.let { expiry ->
                store.recordLatencyOnce(state.revision, SystemClock.elapsedRealtime() - expiry)
                pendingExpiryElapsed = null
            }
        } catch (_: RuntimeException) {
            overlay = null
            store.setAdapterOutcome(AdapterOutcome.OVERLAY_FAILED)
        }
    }

    private fun hideOverlay() {
        overlay?.let { view -> runCatching { windowManager.removeView(view) } }
        overlay = null
    }

    private fun buildOverlay(): View = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER
        setPadding(dp(32), dp(32), dp(32), dp(32))
        setBackgroundColor(Color.rgb(246, 248, 247))
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
        addView(TextView(context).apply {
            text = "Screen time is up. Ask a parent for more time."
            textSize = 26f
            setTextColor(Color.rgb(25, 40, 39))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(24))
        }, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        addView(TextView(context).apply {
            text = "This test overlay leaves designated system, permission, and emergency surfaces available."
            textSize = 16f
            setTextColor(Color.rgb(54, 69, 68))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(24))
        }, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        addView(Button(context).apply {
            text = "Open device settings"
            isAllCaps = false
            setOnClickListener {
                startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
        })
    }

    private fun registerScreenSignals() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(screenReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private companion object {
        const val TICK_MILLIS = 250L
        const val PERSIST_MILLIS = 1_000L
    }
}
