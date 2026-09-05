package dev.kidremote.spike.enforcement

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LabTimerTest {
    @Test
    fun eligibleMonotonicIntervalConsumesExactlyOnce() {
        val armed = LabTimerReducer.arm(10_000, 1_000, eligible = true, revision = 1)
        val sampled = LabTimerReducer.sample(armed, 3_500, eligible = true)

        assertEquals(7_500, sampled.remainingMillis)
        assertFalse(sampled.restrictionRequired)
    }

    @Test
    fun screenOffIntervalDoesNotConsume() {
        val armed = LabTimerReducer.arm(10_000, 1_000, eligible = false, revision = 1)
        val sampled = LabTimerReducer.sample(armed, 9_000, eligible = false)

        assertEquals(10_000, sampled.remainingMillis)
    }

    @Test
    fun transitionToScreenOffSettlesPriorEligibleInterval() {
        val armed = LabTimerReducer.arm(10_000, 1_000, eligible = true, revision = 1)
        val screenOff = LabTimerReducer.sample(armed, 4_000, eligible = false)
        val later = LabTimerReducer.sample(screenOff, 12_000, eligible = false)

        assertEquals(7_000, later.remainingMillis)
    }

    @Test
    fun zeroRequiresRestrictionAndStopsFurtherConsumption() {
        val armed = LabTimerReducer.arm(2_000, 10_000, eligible = true, revision = 1)
        val expired = LabTimerReducer.sample(armed, 12_500, eligible = true)
        val later = LabTimerReducer.sample(expired, 20_000, eligible = true)

        assertEquals(0, expired.remainingMillis)
        assertTrue(expired.restrictionRequired)
        assertEquals(expired.remainingMillis, later.remainingMillis)
        assertFalse(later.wasEligible)
    }

    @Test
    fun sameBootProcessGapUsesPersistedMonotonicAnchor() {
        val persisted = LabTimerReducer.arm(20_000, 3_000, eligible = true, revision = 4)
        val restored = LabTimerReducer.sample(persisted, 8_000, eligible = true)

        assertEquals(15_000, restored.remainingMillis)
        assertFalse(restored.accountingUncertain)
    }

    @Test
    fun rebootLikeMonotonicRollbackPreservesBalanceAndFailsRestricted() {
        val persisted = LabTimerReducer.arm(20_000, 50_000, eligible = true, revision = 4)
        val restored = LabTimerReducer.sample(persisted, 2_000, eligible = true)

        assertEquals(20_000, restored.remainingMillis)
        assertTrue(restored.accountingUncertain)
        assertTrue(restored.restrictionRequired)
        assertFalse(restored.wasEligible)
    }

    @Test
    fun permissionHealthNeverReportsHealthyWhenRequiredAccessIsMissing() {
        assertEquals(PermissionHealth.PERMISSION_REQUIRED, PermissionHealthReducer.evaluate(false, true, false, false))
        assertEquals(PermissionHealth.PERMISSION_REQUIRED, PermissionHealthReducer.evaluate(true, false, false, false))
        assertEquals(PermissionHealth.ENFORCEMENT_DEGRADED, PermissionHealthReducer.evaluate(true, true, true, false))
        assertEquals(PermissionHealth.ENFORCEMENT_DEGRADED, PermissionHealthReducer.evaluate(true, true, false, true))
        assertEquals(PermissionHealth.HEALTHY, PermissionHealthReducer.evaluate(true, true, false, false))
    }

    @Test
    fun latencySummaryUsesNearestRankAndMaximum() {
        val summary = LatencyStatistics.summarize((1L..100L).toList())

        assertEquals(100, summary.samples)
        assertEquals(50, summary.p50Millis)
        assertEquals(95, summary.p95Millis)
        assertEquals(100, summary.maximumMillis)
    }

    @Test
    fun serviceHeartbeatRejectsMissingStaleAndPriorBootValues() {
        assertFalse(ServiceHeartbeat.isFresh(0, 10_000, 3_000))
        assertTrue(ServiceHeartbeat.isFresh(8_000, 10_000, 3_000))
        assertFalse(ServiceHeartbeat.isFresh(6_999, 10_000, 3_000))
        assertFalse(ServiceHeartbeat.isFresh(50_000, 2_000, 3_000))
    }
}
