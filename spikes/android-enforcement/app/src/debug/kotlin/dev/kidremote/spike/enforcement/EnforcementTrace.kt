package dev.kidremote.spike.enforcement

import android.util.Log

internal object EnforcementTrace {
    private const val TRACE_TAG = "KidRemoteKR003"

    fun record(record: EnforcementTraceRecord) {
        Log.i(TRACE_TAG, record.toLogLine())
    }
}
