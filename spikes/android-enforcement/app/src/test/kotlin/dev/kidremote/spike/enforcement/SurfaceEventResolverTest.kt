package dev.kidremote.spike.enforcement

import org.junit.Assert.assertEquals
import org.junit.Test

class SurfaceEventResolverTest {
    @Test
    fun ownOverlayEventPreservesUnderlyingOrdinarySurfaceDuringRestriction() {
        val resolved = SurfaceEventResolver.resolve(
            currentDisposition = SurfaceDisposition.ORDINARY_APP,
            observation = SurfaceObservation(SurfaceIdentityClass.OWN_PACKAGE, SurfaceDisposition.SAFE_SYSTEM),
            restrictionRequired = true,
            overlayAttached = true,
        )

        assertEquals(SurfaceDisposition.ORDINARY_APP, resolved)
    }

    @Test
    fun genuineSafeSystemEventReleasesUnderlyingOrdinarySurface() {
        val resolved = SurfaceEventResolver.resolve(
            currentDisposition = SurfaceDisposition.ORDINARY_APP,
            observation = SurfaceObservation(SurfaceIdentityClass.KNOWN_SAFE_SYSTEM, SurfaceDisposition.SAFE_SYSTEM),
            restrictionRequired = true,
            overlayAttached = true,
        )

        assertEquals(SurfaceDisposition.SAFE_SYSTEM, resolved)
    }

    @Test
    fun ownActivityWithoutAttachedOverlayRemainsSafe() {
        val resolved = SurfaceEventResolver.resolve(
            currentDisposition = SurfaceDisposition.ORDINARY_APP,
            observation = SurfaceObservation(SurfaceIdentityClass.OWN_PACKAGE, SurfaceDisposition.SAFE_SYSTEM),
            restrictionRequired = true,
            overlayAttached = false,
        )

        assertEquals(SurfaceDisposition.SAFE_SYSTEM, resolved)
    }

    @Test
    fun missingIdentityRetainsFailOpenDisposition() {
        val resolved = SurfaceEventResolver.resolve(
            currentDisposition = SurfaceDisposition.ORDINARY_APP,
            observation = SurfaceObservation(SurfaceIdentityClass.MISSING, SurfaceDisposition.UNKNOWN_FAIL_OPEN),
            restrictionRequired = true,
            overlayAttached = true,
        )

        assertEquals(SurfaceDisposition.UNKNOWN_FAIL_OPEN, resolved)
    }
}
