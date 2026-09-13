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
enum class Uncertainty { NONE, HISTORY, CLOCK, STORAGE }
data class Ledger(val policy:Policy,val date:String,val usedMs:Long,val bonusSeconds:Long,
    val boot:Long,val cursor:Long,val uptime:Long,val anchorElapsed:Long,val anchorUtc:Long,
    val signals:Signals,val uncertainty:Uncertainty=Uncertainty.NONE,
    val previousDate:String?=null,val previousUsedMs:Long=0) {
    val periodKey get()="${policy.zoneRevision}:$date"
    val remainingMs get()=maxOf(0,(policy.dailyLimitSeconds+bonusSeconds)*1000-usedMs)
    val restrictionRequired get()=policy.manualLock||remainingMs==0L||uncertainty!=Uncertainty.NONE||!signals.permitted
    fun validate() {
        policy.validate();LocalDate.parse(date);previousDate?.let{require(LocalDate.parse(it)<LocalDate.parse(date))}
        require(usedMs>=0&&previousUsedMs>=0&&bonusSeconds in 0..86400&&policy.dailyLimitSeconds+bonusSeconds<=86400)
        require(boot>=0&&cursor>=0&&uptime>=0&&uptime<=cursor&&anchorElapsed>=0&&anchorElapsed<=cursor)
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
    fun resume(s:Ledger,now:Sample):Ledger {
        s.validate()
        if(now.boot!=s.boot||now.elapsed<s.cursor||now.uptime<s.uptime)return s.copy(uncertainty=Uncertainty.CLOCK)
        return if(now.elapsed==s.cursor||s.uncertainty in listOf(Uncertainty.CLOCK,Uncertainty.STORAGE))s else s.copy(uncertainty=Uncertainty.HISTORY)
    }
    /** Host must deliver every signal boundary while connected; sleep/gaps require reconciliation. */
    fun sample(s:Ledger,now:Sample):Ledger {
        s.validate()
        if(now.boot!=s.boot||now.elapsed<s.cursor||now.uptime<s.uptime)return s.copy(uncertainty=Uncertainty.CLOCK)
        if(s.uncertainty!=Uncertainty.NONE)return s
        val elapsed=now.elapsed-s.cursor;val awake=now.uptime-s.uptime
        if(awake!=elapsed)return s.copy(uncertainty=Uncertainty.HISTORY) // never charge deep sleep blindly
        return integrate(s,Range(s.boot,s.cursor,now.elapsed,s.signals)).copy(uptime=now.uptime,signals=now.signals)
    }
    /** Coverage/proven permission are caller evidence, not inferred from absence of UsageEvents. */
    fun reconcile(s:Ledger,ranges:List<Range>,through:Sample,coverageProven:Boolean):Ledger {
        s.validate()
        if(through.boot!=s.boot)return s.copy(uncertainty=Uncertainty.CLOCK)
        if(through.elapsed<s.cursor) return if(ranges.all{it.boot==s.boot&&it.start>=0&&it.end>=it.start&&it.end<=through.elapsed})s else s.copy(uncertainty=Uncertainty.HISTORY)
        if(s.uncertainty in listOf(Uncertainty.CLOCK,Uncertainty.STORAGE))return s
        if(!coverageProven||ranges.size>10000)return s.copy(uncertainty=Uncertainty.HISTORY)
        val sorted=ranges.sortedWith(compareBy<Range>{it.start}.thenBy{it.end})
        if(sorted.any{it.boot!=s.boot||it.start<0||it.end<it.start||it.end>through.elapsed})return s.copy(uncertainty=Uncertainty.HISTORY)
        // Conflicting overlapping suffixes are not resolved by arrival order.
        for(i in sorted.indices)for(j in i+1 until sorted.size) {
            if(sorted[j].start>=sorted[i].end)break
            if(minOf(sorted[i].end,sorted[j].end)>maxOf(s.cursor,sorted[i].start,sorted[j].start)&&sorted[i].signals!=sorted[j].signals)
                return s.copy(uncertainty=Uncertainty.HISTORY)
        }
        var next=s.copy(uncertainty=Uncertainty.NONE)
        for(r in sorted) {
            if(r.end<=next.cursor)continue
            if(r.start>next.cursor)return next.copy(uncertainty=Uncertainty.HISTORY)
            next=integrate(next,r.copy(start=next.cursor))
        }
        if(next.cursor!=through.elapsed)return next.copy(uncertainty=Uncertainty.HISTORY)
        if(through.uptime<s.uptime||through.uptime>through.elapsed)return next.copy(uncertainty=Uncertainty.CLOCK)
        return next.copy(uptime=through.uptime,signals=through.signals)
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
