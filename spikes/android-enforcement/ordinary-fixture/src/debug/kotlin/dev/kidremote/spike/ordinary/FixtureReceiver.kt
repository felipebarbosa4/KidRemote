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
            response.put("elapsed", SystemClock.elapsedRealtime())
                .put("instance", FixtureState.instance)
                .put("focused", FixtureState.focused)
                .put("resumed", FixtureState.resumed)
                .put("taps", FixtureState.taps)
        }
        resultCode = if (response.has("error")) 1 else 0
        resultData = "KR003:" + Base64.encodeToString(response.toString().toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
    }
}
