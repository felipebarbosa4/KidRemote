package dev.kidremote.spike.enforcement

// Main-thread debug observation only; never participates in enforcement decisions.
internal object LabProbe {
    val journal = TraceJournal()
    var sampledAt = -1L
        private set
    var sampledRevision = -1L
        private set
    var disposition = SurfaceDisposition.UNKNOWN_FAIL_OPEN
        private set
    var attached = false
        private set
    var eligibilityLost = false
        private set
    var firstAttachedAt = -1L
        private set
    var removals = 0
        private set

    fun record(record: EnforcementTraceRecord) {
        journal.append(record.toLogLine())
        if (record.revision == sampledRevision && record.kind == "overlay_hide_requested" && firstAttachedAt >= 0) removals++
    }

    fun sample(now: Long, state: LabTimerState, surface: SurfaceDisposition, overlay: Boolean, eligible: Boolean) {
        if (sampledRevision != state.revision) {
            sampledRevision = state.revision
            eligibilityLost = false
            firstAttachedAt = -1
            removals = 0
        }
        sampledAt = now
        disposition = surface
        attached = overlay
        if (state.armed && !eligible) eligibilityLost = true
        if (state.restrictionRequired && overlay && firstAttachedAt < 0) firstAttachedAt = now
    }
}

internal class TraceJournal(private val capacity: Int = 512) {
    data class Entry(val sequence: Long, val line: String)
    private val entries = ArrayDeque<Entry>()
    var sequence = 0L
        private set

    fun append(line: String) {
        entries.addLast(Entry(++sequence, line))
        if (entries.size > capacity) entries.removeFirst()
    }

    fun after(cursor: Long): List<Entry> = entries.filter { it.sequence > cursor }.take(32)
    fun lostAfter(cursor: Long): Boolean = cursor < (entries.firstOrNull()?.sequence ?: 1L) - 1
}

internal enum class LabOperation {
    SNAPSHOT, CLEAR, ARM, RESET_METRICS;

    companion object {
        fun parse(value: String?): LabOperation? = entries.firstOrNull { it.name == value }
    }
}
