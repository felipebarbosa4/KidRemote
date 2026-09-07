package dev.kidremote.spike.ordinary

import android.app.Activity
import android.os.Bundle
import android.os.SystemClock
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

object FixtureState {
    val instance = SystemClock.elapsedRealtime()
    private var focused = false
    private var resumed = false
    private var taps = 0L
    private var focusGains = 0L
    private var focusLosses = 0L
    private var lastFocusChangeElapsed = -1L
    private var probeX = -1
    private var probeY = -1

    @Synchronized
    fun setResumed(value: Boolean) { resumed = value }

    @Synchronized
    fun setFocused(value: Boolean) {
        if (focused == value) return
        focused = value
        if (value) focusGains++ else focusLosses++
        lastFocusChangeElapsed = SystemClock.elapsedRealtime()
    }

    @Synchronized
    fun recordTap(): Long = ++taps

    @Synchronized
    fun setProbeLocation(x: Int, y: Int) {
        probeX = x
        probeY = y
    }

    @Synchronized
    fun snapshot(): FixtureSnapshot = FixtureSnapshot(
        instance = instance,
        focused = focused,
        resumed = resumed,
        taps = taps,
        focusGains = focusGains,
        focusLosses = focusLosses,
        lastFocusChangeElapsed = lastFocusChangeElapsed,
        probeX = probeX,
        probeY = probeY,
    )
}

data class FixtureSnapshot(
    val instance: Long,
    val focused: Boolean,
    val resumed: Boolean,
    val taps: Long,
    val focusGains: Long,
    val focusLosses: Long,
    val lastFocusChangeElapsed: Long,
    val probeX: Int,
    val probeY: Int,
)

class FixtureActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val label = TextView(this).apply {
            text = "Disposable ordinary test surface\nNo data or permissions"
            textSize = 24f
            gravity = Gravity.CENTER
        }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            addView(label, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f,
            ))
        }
        val probe = Button(this).apply {
            text = "Test ordinary use"
            setOnClickListener {
                label.text = "Synthetic taps: ${FixtureState.recordTap()}"
            }
        }
        root.addView(probe, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply { setMargins(48, 24, 48, 96) })
        setContentView(root)
        probe.addOnLayoutChangeListener { view, _, _, _, _, _, _, _, _ ->
            val position = IntArray(2)
            view.getLocationOnScreen(position)
            FixtureState.setProbeLocation(
                position[0] + view.width / 2,
                position[1] + view.height / 2,
            )
        }
    }

    override fun onResume() { super.onResume(); FixtureState.setResumed(true) }
    override fun onPause() { FixtureState.setResumed(false); super.onPause() }
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        FixtureState.setFocused(hasFocus)
    }
}
