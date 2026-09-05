package dev.kidremote.spike.enforcement

import kotlin.math.max

data class LabTimerState(
    val armed: Boolean = false,
    val remainingMillis: Long = 0,
    val lastElapsedRealtimeMillis: Long = 0,
    val wasEligible: Boolean = false,
    val accountingUncertain: Boolean = false,
    val revision: Long = 0,
) {
    val restrictionRequired: Boolean
        get() = armed && (remainingMillis == 0L || accountingUncertain)
}

object LabTimerReducer {
    fun arm(durationMillis: Long, nowElapsedRealtimeMillis: Long, eligible: Boolean, revision: Long): LabTimerState {
        require(durationMillis > 0)
        require(nowElapsedRealtimeMillis >= 0)
        return LabTimerState(
            armed = true,
            remainingMillis = durationMillis,
            lastElapsedRealtimeMillis = nowElapsedRealtimeMillis,
            wasEligible = eligible,
            revision = revision,
        )
    }

    fun sample(previous: LabTimerState, nowElapsedRealtimeMillis: Long, eligible: Boolean): LabTimerState {
        require(nowElapsedRealtimeMillis >= 0)
        if (!previous.armed) {
            return previous.copy(lastElapsedRealtimeMillis = nowElapsedRealtimeMillis, wasEligible = false)
        }

        if (nowElapsedRealtimeMillis < previous.lastElapsedRealtimeMillis) {
            return previous.copy(
                lastElapsedRealtimeMillis = nowElapsedRealtimeMillis,
                wasEligible = false,
                accountingUncertain = true,
            )
        }

        val elapsed = nowElapsedRealtimeMillis - previous.lastElapsedRealtimeMillis
        val consumed = if (previous.wasEligible && !previous.restrictionRequired) elapsed else 0L
        val remaining = max(0L, previous.remainingMillis - consumed)
        return previous.copy(
            remainingMillis = remaining,
            lastElapsedRealtimeMillis = nowElapsedRealtimeMillis,
            wasEligible = eligible && remaining > 0 && !previous.accountingUncertain,
        )
    }

    fun markClockUncertain(previous: LabTimerState, nowElapsedRealtimeMillis: Long): LabTimerState =
        previous.copy(
            lastElapsedRealtimeMillis = nowElapsedRealtimeMillis,
            wasEligible = false,
            accountingUncertain = previous.armed,
        )
}

enum class PermissionHealth {
    HEALTHY,
    PERMISSION_REQUIRED,
    ENFORCEMENT_DEGRADED,
}

object PermissionHealthReducer {
    fun evaluate(usageAccess: Boolean, accessibility: Boolean, accountingUncertain: Boolean, adapterFailed: Boolean): PermissionHealth =
        when {
            !usageAccess || !accessibility -> PermissionHealth.PERMISSION_REQUIRED
            accountingUncertain || adapterFailed -> PermissionHealth.ENFORCEMENT_DEGRADED
            else -> PermissionHealth.HEALTHY
        }
}

object ServiceHeartbeat {
    fun isFresh(lastElapsedRealtimeMillis: Long, nowElapsedRealtimeMillis: Long, maximumAgeMillis: Long): Boolean =
        lastElapsedRealtimeMillis > 0 &&
            nowElapsedRealtimeMillis >= lastElapsedRealtimeMillis &&
            nowElapsedRealtimeMillis - lastElapsedRealtimeMillis <= maximumAgeMillis
}

enum class SurfaceDisposition {
    SAFE_SYSTEM,
    ORDINARY_APP,
    UNKNOWN_FAIL_OPEN,
}

object SurfacePolicy {
    private val safeSystemPackages = setOf(
        "android",
        "com.android.dialer",
        "com.android.permissioncontroller",
        "com.android.settings",
        "com.android.systemui",
        "com.android.telecom",
        "com.google.android.dialer",
        "com.google.android.permissioncontroller",
        "com.samsung.android.dialer",
    )

    fun classify(observedPackage: CharSequence?, ownPackage: String): SurfaceDisposition {
        val packageName = observedPackage?.toString()?.takeIf { it.isNotBlank() }
            ?: return SurfaceDisposition.UNKNOWN_FAIL_OPEN
        return if (packageName == ownPackage || packageName in safeSystemPackages) {
            SurfaceDisposition.SAFE_SYSTEM
        } else {
            SurfaceDisposition.ORDINARY_APP
        }
    }
}

data class LatencySummary(
    val samples: Int,
    val p50Millis: Long,
    val p95Millis: Long,
    val maximumMillis: Long,
)

object LatencyStatistics {
    fun summarize(values: List<Long>): LatencySummary {
        if (values.isEmpty()) return LatencySummary(0, 0, 0, 0)
        require(values.all { it >= 0 })
        val sorted = values.sorted()
        return LatencySummary(
            samples = sorted.size,
            p50Millis = percentileNearestRank(sorted, 50),
            p95Millis = percentileNearestRank(sorted, 95),
            maximumMillis = sorted.last(),
        )
    }

    private fun percentileNearestRank(sorted: List<Long>, percentile: Int): Long {
        val rank = ((percentile * sorted.size) + 99) / 100
        return sorted[(rank - 1).coerceIn(sorted.indices)]
    }
}
