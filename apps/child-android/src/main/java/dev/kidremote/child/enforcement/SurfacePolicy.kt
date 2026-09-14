package dev.kidremote.child.enforcement

// KR-003 candidate semantics copied unchanged under OD-49; no laboratory state.
enum class SurfaceDisposition {
    SAFE_SYSTEM,
    ORDINARY_APP,
    UNKNOWN_FAIL_OPEN,
}

enum class SurfaceIdentityClass {
    MISSING,
    OWN_PACKAGE,
    KNOWN_SAFE_SYSTEM,
    ORDINARY_APP,
}

data class SurfaceObservation(
    val identityClass: SurfaceIdentityClass,
    val disposition: SurfaceDisposition,
)

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

    fun observe(observedPackage: CharSequence?, ownPackage: String): SurfaceObservation {
        val packageName = observedPackage?.toString()?.takeIf { it.isNotBlank() }
            ?: return SurfaceObservation(SurfaceIdentityClass.MISSING, SurfaceDisposition.UNKNOWN_FAIL_OPEN)
        return when {
            packageName == ownPackage -> SurfaceObservation(
                SurfaceIdentityClass.OWN_PACKAGE,
                SurfaceDisposition.SAFE_SYSTEM,
            )
            packageName in safeSystemPackages -> SurfaceObservation(
                SurfaceIdentityClass.KNOWN_SAFE_SYSTEM,
                SurfaceDisposition.SAFE_SYSTEM,
            )
            else -> SurfaceObservation(SurfaceIdentityClass.ORDINARY_APP, SurfaceDisposition.ORDINARY_APP)
        }
    }

    fun classify(observedPackage: CharSequence?, ownPackage: String): SurfaceDisposition =
        observe(observedPackage, ownPackage).disposition
}

object SurfaceEventResolver {
    fun resolve(
        currentDisposition: SurfaceDisposition,
        observation: SurfaceObservation,
        restrictionRequired: Boolean,
        overlayAttached: Boolean,
    ): SurfaceDisposition = if (
        restrictionRequired &&
        overlayAttached &&
        currentDisposition == SurfaceDisposition.ORDINARY_APP &&
        observation.identityClass == SurfaceIdentityClass.OWN_PACKAGE
    ) {
        currentDisposition
    } else {
        observation.disposition
    }
}

