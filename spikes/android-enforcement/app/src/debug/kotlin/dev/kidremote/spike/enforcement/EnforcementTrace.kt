package dev.kidremote.spike.enforcement

import android.util.Log
import android.view.View

internal object EnforcementTrace {
    private const val TRACE_TAG = "KidRemoteKR003"

    fun record(record: EnforcementTraceRecord) {
        LabProbe.record(record)
        Log.i(TRACE_TAG, record.toLogLine())
    }

    fun sample(now: Long, state: LabTimerState, disposition: SurfaceDisposition, overlay: View?, eligible: Boolean) {
        LabProbe.sample(now, state, disposition, overlay != null, eligible,
            overlay?.windowVisibility ?: -1, overlay?.hasWindowFocus() == true, overlay?.isAttachedToWindow == true)
    }
}
