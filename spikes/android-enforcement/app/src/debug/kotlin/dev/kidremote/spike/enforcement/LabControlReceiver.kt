package dev.kidremote.spike.enforcement

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject

class LabControlReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val request = intent.getLongExtra("request", -1)
        val cursor = intent.getLongExtra("after", 0)
        val operation = LabOperation.parse(intent.getStringExtra("operation"))
        val response = if (request < 0 || cursor < 0 || operation == null) {
            JSONObject().put("error", "INVALID_REQUEST")
        } else {
            try {
                val store = LabTimerStore(context)
                when (operation) {
                    LabOperation.SNAPSHOT -> Unit
                    LabOperation.CLEAR -> store.clear()
                    LabOperation.ARM -> store.arm(10_000, DeviceSignals.eligibleForConsumption(context))
                    LabOperation.RESET_METRICS -> store.clearLatencySamples()
                }
                snapshot(context, store, cursor)
            } catch (_: RuntimeException) {
                JSONObject().put("error", "CONTROL_FAILED")
            }
        }
        response.put("schema", 2).put("request", request)
        resultCode = if (response.has("error")) 1 else 0
        resultData = "KR003:" + Base64.encodeToString(response.toString().toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
    }

    private fun snapshot(context: Context, store: LabTimerStore, cursor: Long): JSONObject {
        val now = SystemClock.elapsedRealtime()
        val state = store.load()
        val samples = store.latencySamples()
        val summary = LatencyStatistics.summarize(samples)
        val version = context.packageManager.getPackageInfo(context.packageName, 0)
        val events = LabProbe.journal.after(cursor)
        return JSONObject()
            .put("elapsed", now)
            .put("versionCode", version.longVersionCode)
            .put("versionName", version.versionName)
            .put("api", Build.VERSION.SDK_INT)
            .put("revision", state.revision)
            .put("remaining", state.remainingMillis)
            .put("armed", state.armed)
            .put("restriction", state.restrictionRequired)
            .put("uncertain", state.accountingUncertain)
            .put("usage", DeviceSignals.hasUsageAccess(context))
            .put("accessibility", DeviceSignals.hasAccessibilityService(context))
            .put("heartbeat", store.serviceHeartbeatFresh(now))
            .put("eligible", DeviceSignals.eligibleForConsumption(context))
            .put("adapter", store.adapterOutcome().name)
            .put("sampledAt", LabProbe.sampledAt)
            .put("sampledRevision", LabProbe.sampledRevision)
            .put("disposition", LabProbe.disposition.name)
            .put("attached", LabProbe.attached)
            .put("windowVisibility", LabProbe.windowVisibility)
            .put("windowFocused", LabProbe.windowFocused)
            .put("viewAttached", LabProbe.viewAttached)
            .put("eligibilityLost", LabProbe.eligibilityLost)
            .put("firstAttachedAt", LabProbe.firstAttachedAt)
            .put("removals", LabProbe.removals)
            .put("recordedRevision", store.recordedLatencyRevision())
            .put("samples", JSONArray(samples))
            .put("sampleCount", summary.samples)
            .put("p50", summary.p50Millis)
            .put("p95", summary.p95Millis)
            .put("max", summary.maximumMillis)
            .put("traceHead", LabProbe.journal.sequence)
            .put("traceLost", LabProbe.journal.lostAfter(cursor))
            .put("events", JSONArray(events.map { JSONObject().put("sequence", it.sequence).put("line", it.line) }))
    }
}
