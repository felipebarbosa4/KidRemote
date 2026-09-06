package dev.kidremote.spike.enforcement

data class EnforcementTraceRecord(
    val elapsedRealtimeMillis: Long,
    val kind: String,
    val trigger: String,
    val eventType: Int,
    val identityClass: SurfaceIdentityClass?,
    val disposition: SurfaceDisposition,
    val nextDisposition: SurfaceDisposition,
    val restrictionRequired: Boolean,
    val overlayAttached: Boolean,
    val adapterOutcome: AdapterOutcome,
    val nextAdapterOutcome: AdapterOutcome,
) {
    fun toLogLine(): String = buildString {
        append("t=").append(elapsedRealtimeMillis)
        append(" kind=").append(kind)
        append(" trigger=").append(trigger)
        append(" eventType=").append(eventType)
        append(" identity=").append(identityClass?.name ?: "NONE")
        append(" disposition=").append(disposition.name)
        append(" nextDisposition=").append(nextDisposition.name)
        append(" restriction=").append(restrictionRequired)
        append(" overlay=").append(if (overlayAttached) "ATTACHED" else "DETACHED")
        append(" adapter=").append(adapterOutcome.name)
        append(" nextAdapter=").append(nextAdapterOutcome.name)
    }
}
