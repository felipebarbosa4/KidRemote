package dev.kidremote.child.enforcement

import dev.kidremote.child.accounting.Ledger

/** A report is bound to the desired transition, never to an API return value. */
data class EnforcementTarget(val epoch:String,val version:Long,val period:String,val required:Boolean) {
    companion object { fun from(s:Ledger)=EnforcementTarget(s.policy.epoch,s.policy.version,s.periodKey,s.restrictionRequired) }
}
data class EnforcementObservation(val target:EnforcementTarget?,val attached:Boolean,val health:String) {
    fun matches(s:Ledger)=target==EnforcementTarget.from(s)
    fun applied(s:Ledger)=matches(s)&&s.restrictionRequired&&attached&&health=="RESTRICTED_OBSERVED"
}
interface EnforcementAdapter {
    fun request(target:EnforcementTarget?,ready:Boolean)
    fun observe():EnforcementObservation
}
