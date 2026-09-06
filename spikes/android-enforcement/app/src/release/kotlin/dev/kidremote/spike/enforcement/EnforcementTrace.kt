package dev.kidremote.spike.enforcement

internal object EnforcementTrace {
    fun record(@Suppress("UNUSED_PARAMETER") record: EnforcementTraceRecord) = Unit

    @Suppress("UNUSED_PARAMETER")
    fun sample(now: Long, state: LabTimerState, disposition: SurfaceDisposition, attached: Boolean, eligible: Boolean) = Unit
}
