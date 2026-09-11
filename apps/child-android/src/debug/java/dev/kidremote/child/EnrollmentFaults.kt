package dev.kidremote.child
/** Test-only in-process fault boundary; no exported control/intent or fake authorization. */
internal object EnrollmentFaults { var beforeIdentitySave:()->Unit = {} }
