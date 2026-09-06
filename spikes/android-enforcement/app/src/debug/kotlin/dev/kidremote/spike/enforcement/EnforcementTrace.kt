package dev.kidremote.spike.enforcement

import android.util.Log

internal object EnforcementTrace {
    private const val TRACE_TAG = "KidRemoteKR003"

    fun record(record: EnforcementTraceRecord) {
        LabProbe.record(record)
        Log.i(TRACE_TAG, record.toLogLine())
    }

    fun sample(now: Long, state: LabTimerState, disposition: SurfaceDisposition, attached: Boolean, eligible: Boolean) {
        LabProbe.sample(now, state, disposition, attached, eligible)
    }
}
