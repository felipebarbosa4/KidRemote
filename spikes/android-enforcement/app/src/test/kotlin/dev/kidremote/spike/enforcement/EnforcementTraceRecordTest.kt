package dev.kidremote.spike.enforcement

import org.junit.Assert.assertEquals
import org.junit.Test

class EnforcementTraceRecordTest {
    @Test
    fun traceContainsOnlyTypedSanitizedState() {
        val record = EnforcementTraceRecord(
            elapsedRealtimeMillis = 12_345,
            kind = "accessibility_event",
            trigger = "event",
            eventType = 32,
            identityClass = SurfaceIdentityClass.OWN_PACKAGE,
            disposition = SurfaceDisposition.ORDINARY_APP,
            nextDisposition = SurfaceDisposition.SAFE_SYSTEM,
            restrictionRequired = true,
            overlayAttached = true,
            adapterOutcome = AdapterOutcome.APPLIED,
            nextAdapterOutcome = AdapterOutcome.SAFE_SURFACE_AVAILABLE,
        )

        assertEquals(
            "t=12345 kind=accessibility_event trigger=event eventType=32 identity=OWN_PACKAGE " +
                "disposition=ORDINARY_APP nextDisposition=SAFE_SYSTEM restriction=true overlay=ATTACHED " +
                "adapter=APPLIED nextAdapter=SAFE_SURFACE_AVAILABLE revision=0",
            record.toLogLine(),
        )
    }
}
