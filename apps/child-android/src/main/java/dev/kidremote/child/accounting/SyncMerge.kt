package dev.kidremote.child.accounting

import java.time.Instant
import java.time.ZoneId

/** Canonical inputs only; no network clock source and no change to approved A/B recovery. */
object SyncMerge {
    fun accept(old:Ledger,input:Policy,now:Sample,utc:Long):Ledger {
        input.validate();require(input.epoch==old.policy.epoch&&input.zone==old.policy.zone&&input.zoneRevision==old.policy.zoneRevision)
        val settled=Accounting.sample(old,now)
        if(input.version<old.policy.version)return settled
        if(input.version==old.policy.version) {
            require(input.dailyLimitSeconds==old.policy.dailyLimitSeconds&&input.manualLock==old.policy.manualLock)
            require(if(input.bonusDate==old.policy.bonusDate)input.bonusSeconds==old.policy.bonusSeconds else input.bonusDate>old.policy.bonusDate&&input.bonusSeconds==0L)
        }
        require(Instant.ofEpochMilli(utc).atZone(ZoneId.of(input.zone)).toLocalDate().toString()==input.bonusDate)
        val dated=if(input.bonusDate>settled.date)Accounting.recoverTrustedTime(Accounting.uncertain(settled,now),TrustedTime(input.epoch,input.zone,input.zoneRevision,utc,now)) else settled
        return if(input.version>dated.policy.version)Accounting.snapshot(dated,input,now) else dated
    }
}
