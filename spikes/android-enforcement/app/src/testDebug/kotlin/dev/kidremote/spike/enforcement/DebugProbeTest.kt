package dev.kidremote.spike.enforcement

import org.junit.Assert.*
import org.junit.Test

class DebugProbeTest {
    @Test fun ownedWindowDiagnosticsDoNotOverrideAdapterState() {
        LabProbe.sample(100, LabTimerState(armed = true, revision = 300), SurfaceDisposition.ORDINARY_APP,
            true, true, visibility = 4, focused = false, attachedToWindow = true)
        assertTrue(LabProbe.attached)
        assertEquals(SurfaceDisposition.ORDINARY_APP, LabProbe.disposition)
        assertEquals(4, LabProbe.windowVisibility)
        assertFalse(LabProbe.windowFocused)
        assertTrue(LabProbe.viewAttached)
    }

    @Test fun probeLatchesEligibilityLossUntilANewRevision() {
        val state = LabTimerState(armed = true, remainingMillis = 10_000, revision = 100)
        LabProbe.sample(10, state, SurfaceDisposition.ORDINARY_APP, false, true)
        LabProbe.sample(20, state, SurfaceDisposition.ORDINARY_APP, false, false)
        LabProbe.sample(30, state, SurfaceDisposition.ORDINARY_APP, false, true)
        assertTrue(LabProbe.eligibilityLost)
        LabProbe.sample(40, state.copy(revision = 101), SurfaceDisposition.ORDINARY_APP, false, true)
        assertFalse(LabProbe.eligibilityLost)
    }

    @Test fun probeRetainsRemovalEvidenceWithinExpiryThenResetsOnClear() {
        val state = LabTimerState(armed = true, revision = 200)
        LabProbe.sample(50, state, SurfaceDisposition.ORDINARY_APP, true, true)
        LabProbe.record(EnforcementTraceRecord(
            elapsedRealtimeMillis = 60, kind = "overlay_hide_requested", trigger = "safe_surface",
            eventType = -1, identityClass = null, disposition = SurfaceDisposition.SAFE_SYSTEM,
            nextDisposition = SurfaceDisposition.SAFE_SYSTEM, restrictionRequired = true, overlayAttached = true,
            adapterOutcome = AdapterOutcome.APPLIED, nextAdapterOutcome = AdapterOutcome.SAFE_SURFACE_AVAILABLE,
            revision = state.revision,
        ))
        LabProbe.sample(70, state, SurfaceDisposition.ORDINARY_APP, true, true)
        assertEquals(1, LabProbe.removals)
        assertEquals(50L, LabProbe.firstAttachedAt)
        LabProbe.sample(80, LabTimerState(revision = 201), SurfaceDisposition.ORDINARY_APP, false, true)
        assertEquals(0, LabProbe.removals)
        assertEquals(-1L, LabProbe.firstAttachedAt)
    }

    @Test fun operationsRejectFreeFormCommands() {
        assertNull(LabOperation.parse("arm 999999"))
        assertNull(LabOperation.parse(null))
        assertEquals(LabOperation.ARM, LabOperation.parse("ARM"))
    }

    @Test fun journalDetectsOverrunAndPaginatesWithoutDuplicating() {
        val journal = TraceJournal(40)
        repeat(50) { journal.append("synthetic") }
        assertTrue(journal.lostAfter(0))
        assertFalse(journal.lostAfter(10))
        val first = journal.after(10)
        assertEquals(32, first.size)
        assertEquals(11L, first.first().sequence)
        assertEquals(8, journal.after(first.last().sequence).size)
        assertTrue(journal.after(50).isEmpty())
    }
}
