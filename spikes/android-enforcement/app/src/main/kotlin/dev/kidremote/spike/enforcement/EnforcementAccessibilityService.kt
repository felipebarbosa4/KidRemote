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
    private var adapterOutcome = AdapterOutcome.NOT_REQUIRED

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
        adapterOutcome = store.adapterOutcome()
        store.setServiceHeartbeat(persistedAtElapsed)
        registerScreenSignals()
        trace(kind = "service_connected", trigger = "lifecycle")
        handler.post(tick)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Only the transient package identity is used to distinguish a known ordinary app from a safe/unknown surface.
        // No AccessibilityNodeInfo, text, content, history, screenshots, gestures, or package timeline is accessed.
        val observation = SurfacePolicy.observe(event?.packageName, packageName)
        val resolvedDisposition = SurfaceEventResolver.resolve(
            currentDisposition = surfaceDisposition,
            observation = observation,
            restrictionRequired = state.restrictionRequired,
            overlayAttached = overlay != null,
        )
        trace(
            kind = "accessibility_event",
            trigger = "event",
            eventType = event?.eventType ?: NO_EVENT_TYPE,
            identityClass = observation.identityClass,
            nextDisposition = resolvedDisposition,
        )
        if (resolvedDisposition != observation.disposition) {
            trace(
                kind = "surface_preserved",
                trigger = "overlay_own_event",
                eventType = event?.eventType ?: NO_EVENT_TYPE,
                identityClass = observation.identityClass,
                nextDisposition = resolvedDisposition,
            )
        }
        if (surfaceDisposition != resolvedDisposition) {
            trace(
                kind = "surface_transition",
                trigger = "event",
                eventType = event?.eventType ?: NO_EVENT_TYPE,
                identityClass = observation.identityClass,
                nextDisposition = resolvedDisposition,
            )
        }
        surfaceDisposition = resolvedDisposition
        sampleAndApply(trigger = "accessibility_event")
    }

    override fun onInterrupt() {
        hideOverlay()
        if (::store.isInitialized) {
            store.clearServiceHeartbeat()
            setAdapterOutcome(AdapterOutcome.OVERLAY_FAILED, "service_interrupt")
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        if (receiverRegistered) unregisterReceiver(screenReceiver)
        hideOverlay()
        if (::store.isInitialized) store.clearServiceHeartbeat()
        super.onDestroy()
    }

    private fun sampleAndApply(trigger: String = "timer_or_screen_signal") {
        if (!::store.isInitialized) return
        if (store.currentRevision() != state.revision) state = store.load()
        val now = SystemClock.elapsedRealtime()
        val previousRestriction = state.restrictionRequired
        if (!previousRestriction && state.wasEligible && now - state.lastElapsedRealtimeMillis >= state.remainingMillis) {
            pendingExpiryElapsed = state.lastElapsedRealtimeMillis + state.remainingMillis
        }
        val eligible = DeviceSignals.eligibleForConsumption(this)
        state = LabTimerReducer.sample(state, now, eligible)
        if (now - persistedAtElapsed >= PERSIST_MILLIS || previousRestriction != state.restrictionRequired) {
            if (!store.save(state)) {
                state = state.copy(accountingUncertain = true, wasEligible = false)
            }
            persistedAtElapsed = now
            store.setServiceHeartbeat(now)
        }
        applyRestriction(state.restrictionRequired, trigger)
        EnforcementTrace.sample(now, state, surfaceDisposition, overlay != null, eligible)
    }

    private fun applyRestriction(required: Boolean, trigger: String) {
        if (!required) {
            hideOverlay("restriction_not_required")
            setAdapterOutcome(AdapterOutcome.NOT_REQUIRED, trigger)
            return
        }
        when (surfaceDisposition) {
            SurfaceDisposition.SAFE_SYSTEM -> {
                hideOverlay("safe_surface")
                setAdapterOutcome(AdapterOutcome.SAFE_SURFACE_AVAILABLE, trigger)
            }
            SurfaceDisposition.UNKNOWN_FAIL_OPEN -> {
                hideOverlay("unknown_surface")
                setAdapterOutcome(AdapterOutcome.UNKNOWN_SURFACE_FAIL_OPEN, trigger)
            }
            SurfaceDisposition.ORDINARY_APP -> showOverlay(trigger)
        }
    }

    private fun showOverlay(trigger: String) {
        if (overlay != null) {
            setAdapterOutcome(AdapterOutcome.APPLIED, trigger)
            return
        }
        trace(kind = "overlay_show_requested", trigger = trigger)
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
            trace(kind = "overlay_attached", trigger = trigger)
            setAdapterOutcome(AdapterOutcome.APPLIED, trigger)
            pendingExpiryElapsed?.let { expiry ->
                store.recordLatencyOnce(state.revision, SystemClock.elapsedRealtime() - expiry)
                pendingExpiryElapsed = null
            }
        } catch (_: RuntimeException) {
            overlay = null
            trace(kind = "overlay_attach_failed", trigger = trigger)
            setAdapterOutcome(AdapterOutcome.OVERLAY_FAILED, trigger)
        }
    }

    private fun hideOverlay(reason: String = "lifecycle") {
        overlay?.let { view ->
            trace(kind = "overlay_hide_requested", trigger = reason)
            val result = runCatching { windowManager.removeView(view) }
            trace(
                kind = if (result.isSuccess) "overlay_removed" else "overlay_remove_failed",
                trigger = reason,
            )
        }
        overlay = null
    }

    private fun setAdapterOutcome(next: AdapterOutcome, trigger: String) {
        if (adapterOutcome == next) return
        trace(kind = "adapter_transition", trigger = trigger, nextAdapterOutcome = next)
        adapterOutcome = next
        store.setAdapterOutcome(next)
    }

    private fun trace(
        kind: String,
        trigger: String,
        eventType: Int = NO_EVENT_TYPE,
        identityClass: SurfaceIdentityClass? = null,
        nextDisposition: SurfaceDisposition = surfaceDisposition,
        nextAdapterOutcome: AdapterOutcome = adapterOutcome,
    ) {
        EnforcementTrace.record(
            EnforcementTraceRecord(
                elapsedRealtimeMillis = SystemClock.elapsedRealtime(),
                revision = state.revision,
                kind = kind,
                trigger = trigger,
                eventType = eventType,
                identityClass = identityClass,
                disposition = surfaceDisposition,
                nextDisposition = nextDisposition,
                restrictionRequired = state.restrictionRequired,
                overlayAttached = overlay != null,
                adapterOutcome = adapterOutcome,
                nextAdapterOutcome = nextAdapterOutcome,
            ),
        )
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
        const val NO_EVENT_TYPE = -1
    }
}
