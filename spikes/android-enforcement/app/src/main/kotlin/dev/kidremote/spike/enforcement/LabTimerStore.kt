package dev.kidremote.spike.enforcement

import android.content.Context
import android.os.SystemClock

class LabTimerStore(context: Context) {
    private val preferences = context.createDeviceProtectedStorageContext()
        .getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)

    @Synchronized
    fun load(): LabTimerState = LabTimerState(
        armed = preferences.getBoolean(KEY_ARMED, false),
        remainingMillis = preferences.getLong(KEY_REMAINING, 0),
        lastElapsedRealtimeMillis = preferences.getLong(KEY_LAST_ELAPSED, SystemClock.elapsedRealtime()),
        wasEligible = preferences.getBoolean(KEY_WAS_ELIGIBLE, false),
        accountingUncertain = preferences.getBoolean(KEY_UNCERTAIN, false),
        revision = preferences.getLong(KEY_REVISION, 0),
    )

    @Synchronized
    fun save(state: LabTimerState): Boolean = preferences.edit()
        .putBoolean(KEY_ARMED, state.armed)
        .putLong(KEY_REMAINING, state.remainingMillis)
        .putLong(KEY_LAST_ELAPSED, state.lastElapsedRealtimeMillis)
        .putBoolean(KEY_WAS_ELIGIBLE, state.wasEligible)
        .putBoolean(KEY_UNCERTAIN, state.accountingUncertain)
        .putLong(KEY_REVISION, state.revision)
        .commit()

    @Synchronized
    fun arm(durationMillis: Long, eligible: Boolean): LabTimerState {
        val revision = preferences.getLong(KEY_REVISION, 0) + 1
        return LabTimerReducer.arm(durationMillis, SystemClock.elapsedRealtime(), eligible, revision).also(::saveOrThrow)
    }

    @Synchronized
    fun clear(): LabTimerState {
        val state = LabTimerState(
            lastElapsedRealtimeMillis = SystemClock.elapsedRealtime(),
            revision = preferences.getLong(KEY_REVISION, 0) + 1,
        )
        saveOrThrow(state)
        setAdapterOutcome(AdapterOutcome.NOT_REQUIRED)
        return state
    }

    @Synchronized
    fun markClockUncertain(): LabTimerState {
        val state = LabTimerReducer.markClockUncertain(load(), SystemClock.elapsedRealtime())
            .copy(revision = preferences.getLong(KEY_REVISION, 0) + 1)
        saveOrThrow(state)
        return state
    }

    fun currentRevision(): Long = preferences.getLong(KEY_REVISION, 0)

    fun setAdapterOutcome(outcome: AdapterOutcome) {
        preferences.edit().putString(KEY_ADAPTER_OUTCOME, outcome.name).apply()
    }

    fun adapterOutcome(): AdapterOutcome = runCatching {
        AdapterOutcome.valueOf(preferences.getString(KEY_ADAPTER_OUTCOME, null) ?: AdapterOutcome.NOT_REQUIRED.name)
    }.getOrDefault(AdapterOutcome.OVERLAY_FAILED)

    fun setServiceHeartbeat(nowElapsedRealtimeMillis: Long) {
        preferences.edit().putLong(KEY_SERVICE_HEARTBEAT, nowElapsedRealtimeMillis).apply()
    }

    fun clearServiceHeartbeat() {
        preferences.edit().remove(KEY_SERVICE_HEARTBEAT).apply()
    }

    fun serviceHeartbeatFresh(nowElapsedRealtimeMillis: Long): Boolean = ServiceHeartbeat.isFresh(
        lastElapsedRealtimeMillis = preferences.getLong(KEY_SERVICE_HEARTBEAT, 0),
        nowElapsedRealtimeMillis = nowElapsedRealtimeMillis,
        maximumAgeMillis = SERVICE_HEARTBEAT_MAX_AGE_MILLIS,
    )

    @Synchronized
    fun recordLatencyOnce(revision: Long, latencyMillis: Long) {
        if (latencyMillis < 0 || preferences.getLong(KEY_RECORDED_REVISION, -1) == revision) return
        val retained = latencySamples().takeLast(MAX_RETAINED_SAMPLES - 1) + latencyMillis
        preferences.edit()
            .putLong(KEY_RECORDED_REVISION, revision)
            .putString(KEY_LATENCY_SAMPLES, retained.joinToString(","))
            .apply()
    }

    fun latencySamples(): List<Long> = preferences.getString(KEY_LATENCY_SAMPLES, "")
        .orEmpty()
        .split(',')
        .mapNotNull(String::toLongOrNull)
        .filter { it >= 0 }

    fun recordedLatencyRevision(): Long = preferences.getLong(KEY_RECORDED_REVISION, -1)

    fun clearLatencySamples() {
        preferences.edit()
            .remove(KEY_RECORDED_REVISION)
            .remove(KEY_LATENCY_SAMPLES)
            .apply()
    }

    private fun saveOrThrow(state: LabTimerState) {
        check(save(state)) { "Unable to persist lab timer state" }
    }

    private companion object {
        const val FILE_NAME = "enforcement_spike_state"
        const val KEY_ARMED = "armed"
        const val KEY_REMAINING = "remaining_millis"
        const val KEY_LAST_ELAPSED = "last_elapsed_realtime_millis"
        const val KEY_WAS_ELIGIBLE = "was_eligible"
        const val KEY_UNCERTAIN = "accounting_uncertain"
        const val KEY_REVISION = "revision"
        const val KEY_ADAPTER_OUTCOME = "adapter_outcome"
        const val KEY_SERVICE_HEARTBEAT = "service_heartbeat"
        const val KEY_RECORDED_REVISION = "recorded_revision"
        const val KEY_LATENCY_SAMPLES = "latency_samples"
        const val MAX_RETAINED_SAMPLES = 500
        const val SERVICE_HEARTBEAT_MAX_AGE_MILLIS = 3_000L
    }
}

enum class AdapterOutcome {
    NOT_REQUIRED,
    APPLIED,
    SAFE_SURFACE_AVAILABLE,
    UNKNOWN_SURFACE_FAIL_OPEN,
    OVERLAY_FAILED,
}
