package dev.kidremote.child.accounting
internal object AccountingFaults {
    @Volatile var beforeRecoveryCommit:(()->Unit)?=null
    @Volatile var afterRecoveryCommit:(()->Unit)?=null
    fun beforeRecoveryCommit(){beforeRecoveryCommit?.invoke()}
    fun afterRecoveryCommit(){afterRecoveryCommit?.invoke()}
}
