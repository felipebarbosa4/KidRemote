package dev.kidremote.child
/** Test-only in-process fault boundary; no exported control/intent or fake authorization. */
internal object EnrollmentFaults {
    var beforeIdentitySave:()->Unit = {}
    // Test-only in-memory stage counts. Never accepts images, payloads or exceptions.
    val cameraCounts=java.util.concurrent.atomic.AtomicIntegerArray(8)
    fun cameraStage(stage:Int){cameraCounts.incrementAndGet(stage)}
}
