package dev.kidremote.spike.ordinary

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.util.Base64
import org.json.JSONObject

class FixtureReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val request = intent.getLongExtra("request", -1)
        val response = JSONObject().put("schema", 1).put("request", request)
        if (request < 0) {
            response.put("error", "INVALID_REQUEST")
        } else {
            val snapshot = FixtureState.snapshot()
            response.put("elapsed", SystemClock.elapsedRealtime())
                .put("instance", snapshot.instance)
                .put("focused", snapshot.focused)
                .put("resumed", snapshot.resumed)
                .put("taps", snapshot.taps)
                .put("focusGains", snapshot.focusGains)
                .put("focusLosses", snapshot.focusLosses)
                .put("lastFocusChange", snapshot.lastFocusChangeElapsed)
                .put("probeReady", snapshot.probeX > 0 && snapshot.probeY > 0)
                .put("probeX", snapshot.probeX)
                .put("probeY", snapshot.probeY)
        }
        response.put("schema", 2)
        resultCode = if (response.has("error")) 1 else 0
        resultData = "KR003:" + Base64.encodeToString(response.toString().toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
    }
}
