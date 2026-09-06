package dev.kidremote.spike.ordinary

import android.app.Activity
import android.os.Bundle
import android.os.SystemClock
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

object FixtureState {
    val instance = SystemClock.elapsedRealtime()
    var focused = false
    var resumed = false
    var taps = 0L
}

class FixtureActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val label = TextView(this).apply {
            text = "Disposable ordinary test surface\nNo data or permissions"
            textSize = 24f
            gravity = Gravity.CENTER
        }
        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            addView(label)
            addView(Button(this@FixtureActivity).apply {
                text = "Test ordinary use"
                setOnClickListener {
                    FixtureState.taps++
                    label.text = "Synthetic taps: ${FixtureState.taps}"
                }
            })
        })
    }

    override fun onResume() { super.onResume(); FixtureState.resumed = true }
    override fun onPause() { FixtureState.resumed = false; super.onPause() }
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        FixtureState.focused = hasFocus
    }
}
