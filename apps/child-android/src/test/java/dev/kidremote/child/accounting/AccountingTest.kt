package dev.kidremote.child.accounting
import org.junit.Assert.*
import org.junit.Test
import java.time.Instant
import java.time.ZoneId

class AccountingTest {
    private val yes=Signals(true,false,true)
    private fun at(t:Long,signals:Signals=yes,boot:Long=7,uptime:Long=t)=Sample(boot,t,uptime,signals)
    private fun policy(date:String="2026-09-13",zone:String="Etc/UTC",limit:Long=3600,bonus:Long=0,lock:Boolean=false,version:Long=1)=Policy("epoch",version,zone,1,date,limit,bonus,lock)
    private fun start(p:Policy=policy(),utc:String="2026-09-13T12:00:00Z")=Accounting.start(p,at(0),Instant.parse(utc).toEpochMilli())
    private fun ranges(vararg r:Range)=r.toList()
    @Test fun eligibleExactlyOnce(){val s=start();val n=Accounting.sample(s,at(60000));assertEquals(60000,n.usedMs);assertEquals(n,Accounting.sample(n,at(60000)))}
    @Test fun exclusions(){for(signal in listOf(yes.copy(interactive=false),yes.copy(keyguard=true),yes.copy(permitted=false),yes.copy(awake=false))){val s=start().copy(signals=signal);assertEquals(0,Accounting.sample(s,at(60000,signal)).usedMs)}}
    @Test fun sleepDoesNotBecomeUse(){val n=Accounting.sample(start(),at(60000,uptime=10));assertEquals(0,n.usedMs);assertEquals(Uncertainty.HISTORY,n.uncertainty);assertTrue(n.restrictionRequired)}
    @Test fun settlePreviousSignal(){var s=start();s=Accounting.sample(s,at(1000,yes.copy(keyguard=true)));s=Accounting.sample(s,at(3000));s=Accounting.sample(s,at(4000));assertEquals(2000,s.usedMs)}
    @Test fun uncoveredSuffix(){val s=Accounting.sample(start(),at(1000));val n=Accounting.reconcile(s,ranges(Range(7,0,2000,yes)),at(2000),true);assertEquals(2000,n.usedMs);assertEquals(n,Accounting.reconcile(n,ranges(Range(7,0,2000,yes)),at(2000),true))}
    @Test fun reorderedDuplicateRanges(){val n=Accounting.reconcile(start(),ranges(Range(7,1000,2000,yes),Range(7,0,1500,yes),Range(7,0,1500,yes)),at(2000),true);assertEquals(2000,n.usedMs)}
    @Test fun oldCoveredBatchCannotRegress(){val s=Accounting.sample(start(),at(2000));assertEquals(s,Accounting.reconcile(s,ranges(Range(7,0,1000,yes)),at(1000),true))}
    @Test fun strongUncertaintySurvivesResume(){for(u in listOf(Uncertainty.CLOCK,Uncertainty.STORAGE)){val s=start().copy(uncertainty=u);assertEquals(s,Accounting.resume(s,at(1000)))}}
    @Test fun conflictingOverlap(){val n=Accounting.reconcile(start(),ranges(Range(7,0,2000,yes),Range(7,1000,2000,yes.copy(keyguard=true))),at(2000),true);assertEquals(Uncertainty.HISTORY,n.uncertainty);assertEquals(0,n.usedMs)}
    @Test fun knownPrefixOnly(){val n=Accounting.reconcile(start(),ranges(Range(7,0,1000,yes),Range(7,2000,3000,yes)),at(3000),true);assertEquals(1000,n.usedMs);assertEquals(1000,n.cursor);assertTrue(n.restrictionRequired)}
    @Test fun missingHistory(){val s=Accounting.sample(start(),at(1000));val n=Accounting.reconcile(s,emptyList(),at(5000),false);assertEquals(1000,n.usedMs);assertEquals(1000,n.cursor);assertEquals(Uncertainty.HISTORY,n.uncertainty)}
    @Test fun historySignalsAndSuffix(){val s=Accounting.sample(start(),at(500));val rs=History.ranges(7,0,4000,yes,listOf(SignalEvent(1000,SignalKind.NON_INTERACTIVE),SignalEvent(3000,SignalKind.INTERACTIVE)));assertEquals(2000,Accounting.reconcile(s,rs,at(4000),true).usedMs)}
    @Test fun invalidHistoryOrder(){assertThrows(IllegalArgumentException::class.java){History.ranges(7,0,4000,yes,listOf(SignalEvent(2000,SignalKind.INTERACTIVE),SignalEvent(1000,SignalKind.NON_INTERACTIVE)))}}
    @Test fun midnightSplit(){val s=start(utc="2026-09-13T23:59:59Z");val n=Accounting.sample(s,at(2000));assertEquals("1:2026-09-14",n.periodKey);assertEquals(1000,n.usedMs);assertEquals(1000,n.previousUsedMs)}
    @Test fun exactMidnight(){val n=Accounting.sample(start(utc="2026-09-13T23:59:59Z"),at(1000));assertEquals("2026-09-14",n.date);assertEquals(0,n.usedMs);assertEquals(1000,n.previousUsedMs)}
    @Test fun dstDays(){for((day,hours) in listOf("2026-03-08" to 23,"2026-11-01" to 25)){val z=ZoneId.of("America/Toronto");val begin=java.time.LocalDate.parse(day).atStartOfDay(z);val duration=begin.plusDays(1).toInstant().toEpochMilli()-begin.toInstant().toEpochMilli();assertEquals(hours*3600000L,duration);val s=Accounting.start(policy(day,z.id,86400),at(0,yes.copy(interactive=false)),begin.toInstant().toEpochMilli());val n=Accounting.sample(s,at(duration,yes.copy(interactive=false)));assertEquals(begin.plusDays(1).toLocalDate().toString(),n.date);assertEquals(0,n.usedMs);assertEquals(0,n.bonusSeconds)}}
    @Test fun limitRetainsUse(){val s=Accounting.sample(start(),at(3000000));val low=Accounting.snapshot(s,policy(limit=1800,version=2),at(3000000));assertEquals(3000000,low.usedMs);assertEquals(0,low.remainingMs);val high=Accounting.snapshot(low,policy(limit=3600,version=3),at(3000000));assertEquals(600000,high.remainingMs)}
    @Test fun manualLockAndBonusMidnight(){val s=start(policy(bonus=600,lock=true),"2026-09-13T23:59:59Z");val n=Accounting.sample(s,at(2000));assertTrue(n.policy.manualLock);assertEquals(0,n.usedMs);assertEquals(0,n.bonusSeconds)}
    @Test fun bonusAbsoluteNotDelta(){val s=start();val p=policy(bonus=600,version=2);val n=Accounting.snapshot(s,p,at(0));assertEquals(600,n.bonusSeconds);assertEquals(n,Accounting.snapshot(n,p,at(100)));assertEquals(600,Accounting.snapshot(n,p.copy(version=3),at(0)).bonusSeconds)}
    @Test fun staleCannotUnlock(){val s=start(policy(lock=true,version=3));assertEquals(s,Accounting.snapshot(s,policy(lock=false,version=2),at(999)));assertEquals(s,Accounting.snapshot(s,policy(lock=false,version=3),at(999)))}
    @Test fun yesterdayBonusExpiresButLockApplies(){val s=start(utc="2026-09-13T23:59:59Z");val n=Accounting.snapshot(s,policy(bonus=600,lock=true,version=2),at(2000));assertEquals(0,n.bonusSeconds);assertTrue(n.policy.manualLock)}
    @Test fun epochAndHouseholdZoneCannotChange(){val s=start();assertThrows(IllegalArgumentException::class.java){Accounting.snapshot(s,s.policy.copy(epoch="other",version=2),at(0))};assertThrows(IllegalArgumentException::class.java){Accounting.snapshot(s,s.policy.copy(zone="Asia/Tokyo",version=2),at(0))}}
    @Test fun rebootNoCrossBootOrFreshDay(){val s=Accounting.sample(start(),at(10000));val n=Accounting.resume(s,at(100,boot=8));assertEquals(10000,n.usedMs);assertEquals(s.date,n.date);assertEquals(Uncertainty.CLOCK,n.uncertainty);assertEquals(n,Accounting.sample(n,at(1000,boot=8)))}
    @Test fun monotonicRegression(){val s=Accounting.sample(start(),at(1000));assertEquals(Uncertainty.CLOCK,Accounting.sample(s,at(999)).uncertainty)}
    @Test fun deviceClockAndTimezoneCannotMint(){val s=start();val zone=java.util.TimeZone.getDefault();try{for(tz in listOf("Pacific/Kiritimati","Pacific/Honolulu")){java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone(tz));for(wallEdit in listOf(-86400000,86400000)){val fakeClock=object { val wallUtc=Instant.parse("2026-09-13T12:00:00Z").toEpochMilli()+wallEdit; fun monotonicSample()=at(1000) };assertNotEquals(s.anchorUtc,fakeClock.wallUtc);val n=Accounting.sample(s,fakeClock.monotonicSample());assertEquals("2026-09-13",n.date);assertEquals(1000,n.usedMs)}}}finally{java.util.TimeZone.setDefault(zone)}}
    @Test fun expiredDoesNotConsumeFurther(){val s=start(policy(limit=1));val n=Accounting.sample(s,at(10000));assertEquals(1000,n.usedMs);assertTrue(n.restrictionRequired)}
    @Test fun codecAndCorruption(){val s=Accounting.sample(start(),at(1000));assertEquals(s,LedgerCodec.decode(LedgerCodec.encode(s)));val bytes=LedgerCodec.encode(s);bytes[15]=(bytes[15].toInt() xor 1).toByte();assertThrows(IllegalArgumentException::class.java){LedgerCodec.decode(bytes)}}
    @Test fun invalidNumericPolicy(){for(p in listOf(policy(limit=-1),policy(limit=86400,bonus=600),policy(version=-1))){assertThrows(IllegalArgumentException::class.java){start(p)}}}
}
