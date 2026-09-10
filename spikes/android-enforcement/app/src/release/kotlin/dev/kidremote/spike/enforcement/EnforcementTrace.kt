package dev.kidremote.spike.enforcement

import android.view.View

internal object EnforcementTrace {
    fun record(@Suppress("UNUSED_PARAMETER") record: EnforcementTraceRecord) = Unit

    @Suppress("UNUSED_PARAMETER")
    fun sample(now: Long, state: LabTimerState, disposition: SurfaceDisposition, overlay: View?, eligible: Boolean) = Unit
}
