package dev.kidremote.spike.enforcement

import org.junit.Assert.assertEquals
import org.junit.Test

class SurfacePolicyTest {
    private val ownPackage = "dev.kidremote.spike.enforcement"

    @Test
    fun ownAndKnownSystemSurfacesRemainAvailable() {
        assertEquals(SurfaceDisposition.SAFE_SYSTEM, SurfacePolicy.classify(ownPackage, ownPackage))
        assertEquals(SurfaceDisposition.SAFE_SYSTEM, SurfacePolicy.classify("com.android.settings", ownPackage))
        assertEquals(SurfaceDisposition.SAFE_SYSTEM, SurfacePolicy.classify("com.android.systemui", ownPackage))
        assertEquals(SurfaceDisposition.SAFE_SYSTEM, SurfacePolicy.classify("com.google.android.dialer", ownPackage))
    }

    @Test
    fun ownAndKnownSystemIdentitiesRemainDistinctForSanitizedTracing() {
        assertEquals(
            SurfaceObservation(SurfaceIdentityClass.OWN_PACKAGE, SurfaceDisposition.SAFE_SYSTEM),
            SurfacePolicy.observe(ownPackage, ownPackage),
        )
        assertEquals(
            SurfaceObservation(SurfaceIdentityClass.KNOWN_SAFE_SYSTEM, SurfaceDisposition.SAFE_SYSTEM),
            SurfacePolicy.observe("com.android.settings", ownPackage),
        )
    }

    @Test
    fun ordinaryAppIsCandidateForOverlay() {
        assertEquals(SurfaceDisposition.ORDINARY_APP, SurfacePolicy.classify("example.ordinary.app", ownPackage))
    }

    @Test
    fun missingPackageIdentityFailsOpen() {
        assertEquals(SurfaceDisposition.UNKNOWN_FAIL_OPEN, SurfacePolicy.classify(null, ownPackage))
        assertEquals(SurfaceDisposition.UNKNOWN_FAIL_OPEN, SurfacePolicy.classify("", ownPackage))
        assertEquals(
            SurfaceObservation(SurfaceIdentityClass.MISSING, SurfaceDisposition.UNKNOWN_FAIL_OPEN),
            SurfacePolicy.observe(null, ownPackage),
        )
    }
}
