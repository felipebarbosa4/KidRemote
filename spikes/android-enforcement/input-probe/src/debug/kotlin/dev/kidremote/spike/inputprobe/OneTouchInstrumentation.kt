package dev.kidremote.spike.inputprobe

import android.app.Activity
import android.app.Instrumentation
import android.app.UiAutomation
import android.os.Bundle
import android.os.SystemClock
import android.view.InputDevice
import android.view.MotionEvent

/** Disposable, self-targeted instrumentation; no dependency on fixture or candidate code. */
class OneTouchInstrumentation : Instrumentation() {
    private var x = -1
    private var y = -1
    private var request = -1L

    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        x = arguments?.getString("x")?.toIntOrNull() ?: -1
        y = arguments?.getString("y")?.toIntOrNull() ?: -1
        request = arguments?.getString("request")?.toLongOrNull() ?: -1L
        start()
    }

    override fun onStart() {
        var stage = "ARGUMENTS"
        var outcome = "INVALID_ARGUMENTS"
        var downAccepted = false
        var upAccepted = false
        var automation: UiAutomation? = null
        try {
            if (x !in 0..16383 || y !in 0..16383 || request <= 0) return
            stage = "CONNECT"
            automation = getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
            val bridge = automation
            if (bridge == null) { outcome = "CONNECT_UNAVAILABLE"; return }
            stage = "CONFIGURE"
            // API 29 cannot opt out of the automation accessibility connection. Subscribe to no events.
            val info = bridge.serviceInfo
            info.eventTypes = 0
            info.flags = 0
            bridge.serviceInfo = info
            val downTime = SystemClock.uptimeMillis()
            stage = "DOWN"
            try {
                downAccepted = inject(bridge, downTime, MotionEvent.ACTION_DOWN)
            } catch (_: SecurityException) { outcome = "SECURITY_EXCEPTION" }
            catch (_: Exception) { outcome = "OTHER" }
            val downFailed = outcome == "SECURITY_EXCEPTION" || outcome == "OTHER"
            try {
                // Release even when DOWN was rejected; preserve its primary failure if UP also fails.
                if (!downFailed) stage = "UP"
                upAccepted = inject(bridge, downTime, MotionEvent.ACTION_UP)
            } catch (_: SecurityException) { if (!downFailed) outcome = "SECURITY_EXCEPTION" }
            catch (_: Exception) { if (!downFailed) outcome = "OTHER" }
            if (outcome != "SECURITY_EXCEPTION" && outcome != "OTHER") {
                stage = "UP"
                outcome = if (downAccepted && upAccepted) "INJECTED" else "INPUT_REJECTED"
                stage = "COMPLETE"
            }
        } catch (_: SecurityException) {
            outcome = "SECURITY_EXCEPTION"
        } catch (_: Exception) {
            outcome = "OTHER"
        } finally {
            val result = Bundle().apply {
                putString("kr003_probe", "v1,$request,$stage,$outcome,$downAccepted,$upAccepted,FRAMEWORK_FINISH")
            }
            // Public finish owns UiAutomation disconnection; no hidden API or reflective cleanup.
            finish(if (outcome == "INJECTED") Activity.RESULT_OK else Activity.RESULT_CANCELED, result)
        }
    }

    private fun inject(bridge: UiAutomation, downTime: Long, action: Int): Boolean {
        val event = MotionEvent.obtain(downTime, SystemClock.uptimeMillis(), action, x.toFloat(), y.toFloat(), 0)
        event.setSource(InputDevice.SOURCE_TOUCHSCREEN)
        return try { bridge.injectInputEvent(event, true) } finally { event.recycle() }
    }
}
