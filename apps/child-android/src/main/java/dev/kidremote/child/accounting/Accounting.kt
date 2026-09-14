package dev.kidremote.child.accounting

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** No Android, wall-clock subtraction, networking or package data in this reducer. */
data class Policy(val epoch:String,val version:Long,val zone:String,val zoneRevision:Long,
    val bonusDate:String,val dailyLimitSeconds:Long,val bonusSeconds:Long,val manualLock:Boolean) {
    fun validate() {
        require(epoch.isNotBlank()&&epoch.length<=64&&version>=0&&zoneRevision>=0)
        ZoneId.of(zone);LocalDate.parse(bonusDate)
        require(dailyLimitSeconds in 0..86400&&bonusSeconds in 0..86400&&dailyLimitSeconds+bonusSeconds<=86400)
    }
}
data class Signals(val interactive:Boolean,val keyguard:Boolean,val permitted:Boolean,val awake:Boolean=true) {
    val eligible get()=interactive&&!keyguard&&permitted&&awake
}
data class Sample(val boot:Long,val elapsed:Long,val uptime:Long,val signals:Signals)
data class Range(val boot:Long,val start:Long,val end:Long,val signals:Signals)
/** Trust is supplied by the local canonical-input boundary, never inferred from the device RTC. */
data class TrustedTime(val epoch:String,val zone:String,val zoneRevision:Long,val utcMillis:Long,val at:Sample)
enum class Uncertainty { NONE, HISTORY, CLOCK, STORAGE }
data class Ledger(val policy:Policy,val date:String,val usedMs:Long,val bonusSeconds:Long,
    val boot:Long,val cursor:Long,val uptime:Long,val anchorElapsed:Long,val anchorUtc:Long,
    val signals:Signals,val uncertainty:Uncertainty=Uncertainty.NONE,
    val previousDate:String?=null,val previousUsedMs:Long=0,val recoveryThrough:Long=0,val observedBoot:Long=boot,val reportSequence:Long=0,val pendingAck:String?=null) {
    val periodKey get()="${policy.zoneRevision}:$date"
    val remainingMs get()=maxOf(0,(policy.dailyLimitSeconds+bonusSeconds)*1000-usedMs)
    val restrictionRequired get()=policy.manualLock||remainingMs==0L||uncertainty!=Uncertainty.NONE||!signals.permitted
    fun validate() {
        policy.validate();LocalDate.parse(date);previousDate?.let{require(LocalDate.parse(it)<LocalDate.parse(date))}
        require(usedMs>=0&&previousUsedMs>=0&&bonusSeconds in 0..86400&&policy.dailyLimitSeconds+bonusSeconds<=86400)
        require(boot>=0&&cursor>=0&&uptime>=0&&uptime<=cursor&&anchorElapsed>=0&&anchorElapsed<=cursor)
        require(observedBoot>=boot&&recoveryThrough>=0&&(uncertainty!=Uncertainty.NONE||recoveryThrough==0L))
        require(reportSequence in 0..9007199254740991L&&(pendingAck==null||pendingAck.length in 1..2048&&reportSequence>0))
        Instant.ofEpochMilli(anchorUtc)
    }
}
object Accounting {
    fun start(policy:Policy,sample:Sample,trustedUtc:Long):Ledger {
        policy.validate();require(sample.boot>=0&&sample.elapsed>=0&&sample.uptime in 0..sample.elapsed)
        val date=date(trustedUtc,policy.zone)
        require(policy.bonusDate<=date) // Future-period credit is not silently installed.
        return Ledger(policy,date,0,if(policy.bonusDate==date)policy.bonusSeconds else 0,
            sample.boot,sample.elapsed,sample.uptime,sample.elapsed,trustedUtc,sample.signals).also{it.validate()}
    }
    private fun date(utc:Long,zone:String)=Instant.ofEpochMilli(utc).atZone(ZoneId.of(zone)).toLocalDate().toString()
    private fun utc(s:Ledger,elapsed:Long)=Math.addExact(s.anchorUtc,Math.subtractExact(elapsed,s.anchorElapsed))
    /** Remember the entire unresolved suffix. Clock discontinuity cannot be repaired by range replay. */
    fun uncertain(s:Ledger,now:Sample,reason:Uncertainty=Uncertainty.HISTORY):Ledger {
        val discontinuity=now.boot!=s.boot||now.elapsed<s.cursor||now.uptime<s.uptime||now.uptime>now.elapsed||now.boot<0
        if(discontinuity||s.uncertainty==Uncertainty.CLOCK)return s.copy(uncertainty=Uncertainty.CLOCK,observedBoot=maxOf(s.observedBoot,now.boot))
        return s.copy(uncertainty=if(s.uncertainty==Uncertainty.STORAGE)Uncertainty.STORAGE else reason,
            recoveryThrough=maxOf(s.recoveryThrough,now.elapsed))
    }
    fun resume(s:Ledger,now:Sample):Ledger {
        s.validate()
        return if(now.boot==s.boot&&now.elapsed==s.cursor&&now.uptime==s.uptime)s else uncertain(s,now)
    }
    /** Host must deliver every signal boundary while connected; sleep/gaps require reconciliation. */
    fun sample(s:Ledger,now:Sample):Ledger {
        s.validate()
        if(now.boot!=s.boot||now.elapsed<s.cursor||now.uptime<s.uptime||now.uptime>now.elapsed)return uncertain(s,now)
        if(s.uncertainty!=Uncertainty.NONE)return uncertain(s,now)
        val elapsed=now.elapsed-s.cursor;val awake=now.uptime-s.uptime
        if(awake!=elapsed)return uncertain(s,now) // never charge deep sleep blindly
        return integrate(s,Range(s.boot,s.cursor,now.elapsed,s.signals)).copy(uptime=now.uptime,signals=now.signals)
    }
    /** A: validate complete bounded coverage before changing any usage/period fields. */
    fun reconcile(s:Ledger,ranges:List<Range>,through:Sample,coverageProven:Boolean):Ledger {
        s.validate()
        if(through.boot!=s.boot)return uncertain(s,through)
        if(through.elapsed<s.cursor) return if(ranges.all{it.boot==s.boot&&it.start>=0&&it.end>=it.start&&it.end<=through.elapsed})s else uncertain(s,through)
        if(s.uncertainty==Uncertainty.CLOCK)return s
        if(through.uptime<s.uptime||through.uptime>through.elapsed)return uncertain(s,through)
        val failed=uncertain(s,through)
        if(!coverageProven||ranges.size>10000||through.elapsed-s.cursor>48*60*60*1000L||through.elapsed<s.recoveryThrough)return failed
        val sorted=ranges.sortedWith(compareBy<Range>{it.start}.thenBy{it.end})
        if(sorted.any{it.boot!=s.boot||it.start<0||it.end<it.start||it.end>through.elapsed})return failed
        for(i in sorted.indices)for(j in i+1 until sorted.size) {
            if(sorted[j].start>=sorted[i].end)break
            if(minOf(sorted[i].end,sorted[j].end)>maxOf(s.cursor,sorted[i].start,sorted[j].start)&&sorted[i].signals!=sorted[j].signals)return failed
        }
        var covered=s.cursor
        for(r in sorted) {
            if(r.end<=covered)continue
            if(r.start>covered)return failed
            covered=r.end
        }
        if(covered!=through.elapsed)return failed
        var next=s.copy(uncertainty=Uncertainty.NONE,recoveryThrough=0)
        for(r in sorted)if(r.end>next.cursor)next=integrate(next,r.copy(start=next.cursor))
        return next.copy(uptime=through.uptime,signals=through.signals)
    }
    /** B: only a strictly newer trusted household period retires unreconstructible old usage. */
    fun recoverTrustedTime(s:Ledger,input:TrustedTime):Ledger {
        s.validate()
        return try {
            val now=input.at
            require(input.epoch==s.policy.epoch&&input.zone==s.policy.zone&&input.zoneRevision==s.policy.zoneRevision)
            require(now.boot>=0&&now.elapsed>=0&&now.uptime in 0..now.elapsed)
            val day=date(input.utcMillis,s.policy.zone)
            require(day.length==10&&LocalDate.parse(day).year in 1..9999)
            // A well-formed old delivery is not a second reset or a new clock observation.
            if(day<=s.date) {
                if(now.boot<s.observedBoot||now.boot==s.boot&&now.elapsed<s.cursor)return s
                return if(s.uncertainty!=Uncertainty.NONE||now.boot!=s.boot)uncertain(s,now) else s
            }
            require(now.boot>=s.observedBoot&&input.utcMillis>=s.anchorUtc)
            if(now.boot==s.boot)require(now.elapsed>=maxOf(s.cursor,s.recoveryThrough)&&now.uptime>=s.uptime)
            val pending=if(now.boot!=s.boot)uncertain(s,now) else s
            if(pending.uncertainty==Uncertainty.NONE)return pending
            pending.copy(previousDate=s.date,previousUsedMs=s.usedMs,date=day,usedMs=0,bonusSeconds=0,
                boot=now.boot,cursor=now.elapsed,uptime=now.uptime,anchorElapsed=now.elapsed,anchorUtc=input.utcMillis,
                signals=now.signals,uncertainty=Uncertainty.NONE,recoveryThrough=0,observedBoot=now.boot).also{it.validate()}
        }catch(_:Exception){uncertain(s,input.at)}
    }
    private fun integrate(initial:Ledger,r:Range):Ledger {
        var s=initial;var at=r.start
        while(at<r.end) {
            val instant=Instant.ofEpochMilli(utc(s,at));val zone=ZoneId.of(s.policy.zone)
            val d=instant.atZone(zone).toLocalDate()
            if(d.toString()!=s.date) {
                if(d.toString()<s.date)return s.copy(uncertainty=Uncertainty.CLOCK)
                s=s.copy(previousDate=s.date,previousUsedMs=s.usedMs,date=d.toString(),usedMs=0,bonusSeconds=0)
            }
            val midnight=d.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli()
            val until=minOf(r.end,Math.addExact(s.anchorElapsed,Math.subtractExact(midnight,s.anchorUtc)))
            check(until>at)
            val counted=if(r.signals.eligible&&!s.policy.manualLock)minOf(until-at,s.remainingMs) else 0
            s=s.copy(usedMs=Math.addExact(s.usedMs,counted),cursor=until);at=until
        }
        // Midnight exactly at the endpoint also advances once (not on a later random tick).
        val endDate=date(utc(s,r.end),s.policy.zone)
        if(endDate>s.date)s=s.copy(previousDate=s.date,previousUsedMs=s.usedMs,date=endDate,usedMs=0,bonusSeconds=0)
        return s.copy(cursor=r.end)
    }
    fun snapshot(s:Ledger,input:Policy,now:Sample):Ledger {
        input.validate()
        require(input.epoch==s.policy.epoch&&input.zone==s.policy.zone&&input.zoneRevision==s.policy.zoneRevision)
        if(input.version<=s.policy.version)return s // no stale snapshot changes clock, coverage or use
        val settled=sample(s,now)
        require(input.bonusDate<=settled.date)
        return settled.copy(policy=input,bonusSeconds=if(input.bonusDate==settled.date)input.bonusSeconds else 0).also{it.validate()}
    }
}
