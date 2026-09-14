package dev.kidremote.child.accounting
import org.junit.Assert.*
import org.junit.Test
import java.time.Instant
import java.util.zip.CRC32
import java.io.ByteArrayOutputStream
import java.io.DataOutputStream

class RecoveryTest {
    private val yes=Signals(true,false,true)
    private fun at(t:Long,boot:Long=7)=Sample(boot,t,t,yes)
    private fun base(lock:Boolean=false):Ledger {
        val p=Policy("epoch",7,"America/Toronto",3,"2026-09-13",3600,600,false)
        val s=Accounting.sample(Accounting.start(p,at(0),Instant.parse("2026-09-13T16:00:00Z").toEpochMilli()),at(1000))
        return s.copy(policy=s.policy.copy(manualLock=lock))
    }
    private fun gap()=Accounting.resume(base(),at(3000))
    private fun trusted(s:Ledger,utc:String="2026-09-14T04:00:00Z",sample:Sample=at(4000))=TrustedTime(s.policy.epoch,s.policy.zone,s.policy.zoneRevision,Instant.parse(utc).toEpochMilli(),sample)
    @Test fun completeSuffixClearsOnce(){val s=gap();val rs=listOf(Range(7,0,3000,yes));val n=Accounting.reconcile(s,rs,at(3000),true);assertEquals(3000,n.usedMs);assertEquals(0,n.recoveryThrough);assertEquals(Uncertainty.NONE,n.uncertainty);assertEquals(n,Accounting.reconcile(n,rs,at(3000),true))}
    @Test fun knownShorterEndpointCannotForgetGap(){val s=gap();val n=Accounting.reconcile(s,listOf(Range(7,0,1000,yes)),at(1000),true);assertEquals(s,n);assertTrue(n.restrictionRequired)}
    @Test fun partialGapDoesNotCommitPartialUsageOrPeriod(){
        val s=gap();val n=Accounting.reconcile(s,listOf(Range(7,1000,2000,yes)),at(3000),true);assertEquals(s,n)
        val midnight=Accounting.resume(base().copy(anchorUtc=Instant.parse("2026-09-14T03:59:58Z").toEpochMilli()),at(4000))
        assertEquals(midnight,Accounting.reconcile(midnight,listOf(Range(7,1000,3000,yes)),at(4000),true))
        val full=Accounting.reconcile(midnight,listOf(Range(7,1000,4000,yes)),at(4000),true)
        assertEquals("2026-09-14",full.date);assertEquals(2000,full.usedMs);assertEquals(2000,full.previousUsedMs);assertEquals(0,full.bonusSeconds)
    }
    @Test fun contradictionPreservesEntireState(){val s=gap();val n=Accounting.reconcile(s,listOf(Range(7,1000,3000,yes),Range(7,2000,3000,yes.copy(keyguard=true))),at(3000),true);assertEquals(s,n)}
    @Test fun unprovedOrUnboundedEvidenceCannotClear(){val s=gap();assertEquals(s,Accounting.reconcile(s,listOf(Range(7,0,3000,yes)),at(3000),false));val far=49*3600000L;val n=Accounting.reconcile(s,listOf(Range(7,0,far,yes)),at(far),true);assertEquals(s.usedMs,n.usedMs);assertTrue(n.restrictionRequired);assertEquals(s.date,n.date)}
    @Test fun sameTrustedPeriodRetainsGap(){val s=gap();val n=Accounting.recoverTrustedTime(s,trusted(s,"2026-09-13T20:00:00Z",at(4000)));assertEquals(s.copy(recoveryThrough=4000),n)}
    @Test fun newerPeriodClearsAndReanchors(){val s=gap();val n=Accounting.recoverTrustedTime(s,trusted(s));assertEquals("3:2026-09-14",n.periodKey);assertEquals(0,n.usedMs);assertEquals(0,n.bonusSeconds);assertEquals(s.policy,n.policy);assertEquals(s.usedMs,n.previousUsedMs);assertEquals(4000,n.anchorElapsed);assertEquals(trusted(s).utcMillis,n.anchorUtc);assertEquals(Uncertainty.NONE,n.uncertainty)}
    @Test fun manualLockPreserved(){val s=Accounting.resume(base(true),at(3000));val n=Accounting.recoverTrustedTime(s,trusted(s));assertTrue(n.policy.manualLock);assertEquals(3600,n.policy.dailyLimitSeconds);assertEquals(0,n.bonusSeconds);assertTrue(n.restrictionRequired)}
    @Test fun repeatedDeliveryCannotResetNewUse(){val s=gap();val input=trusted(s);val n=Accounting.sample(Accounting.recoverTrustedTime(s,input),at(5000));assertEquals(1000,n.usedMs);assertEquals(n,Accounting.recoverTrustedTime(n,input));assertEquals(n,Accounting.recoverTrustedTime(n,input.copy(at=at(6000))))}
    @Test fun skippedDatesAreOneAllowance(){val s=gap();val n=Accounting.recoverTrustedTime(s,trusted(s,"2026-09-30T04:00:00Z"));assertEquals("2026-09-30",n.date);assertEquals(3600000,n.remainingMs);assertEquals(s.date,n.previousDate)}
    @Test fun rebootNeedsLaterTrustedPeriodNotRangeReplay(){val s=base();val n=Accounting.resume(s,at(10,8));assertEquals(8,n.observedBoot);assertEquals(s.usedMs,n.usedMs);assertEquals(n,Accounting.reconcile(n,listOf(Range(8,0,100,yes)),at(100,8),true));val same=Accounting.recoverTrustedTime(n,trusted(n,"2026-09-13T20:00:00Z",at(100,8)));assertTrue(same.restrictionRequired);assertEquals(s.date,same.date);val next=Accounting.recoverTrustedTime(same,trusted(same,sample=at(200,8)));assertEquals(8,next.boot);assertEquals(200,next.cursor);assertEquals(0,next.usedMs)}
    @Test fun staleBootCannotReanchorAfterObservedReboot(){val s=Accounting.resume(base(),at(10,8));assertEquals(s,Accounting.recoverTrustedTime(s,trusted(s,sample=at(5000,7))))}
    @Test fun wallAndDeviceZoneEditsDoNotRecover(){val s=gap();val original=java.util.TimeZone.getDefault();try{for(zone in listOf("Pacific/Honolulu","Pacific/Kiritimati")){java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone(zone));for(offset in listOf(-86400000L,86400000L)){val clock=object{val rtc=s.anchorUtc+offset;fun sample()=at(4000)};assertNotEquals(s.anchorUtc,clock.rtc);val n=Accounting.sample(s,clock.sample());assertEquals(s.date,n.date);assertEquals(s.usedMs,n.usedMs);assertTrue(n.restrictionRequired)}}}finally{java.util.TimeZone.setDefault(original)}}
    @Test fun writableStorageAloneIsNotRecovery(){val s=gap().copy(uncertainty=Uncertainty.STORAGE);assertTrue(Accounting.resume(s,at(4000)).restrictionRequired);assertTrue(Accounting.recoverTrustedTime(s,trusted(s,"2026-09-13T20:00:00Z")).restrictionRequired);assertEquals(Uncertainty.NONE,Accounting.reconcile(s,listOf(Range(7,1000,3000,yes)),at(3000),true).uncertainty);assertEquals(Uncertainty.NONE,Accounting.recoverTrustedTime(s,trusted(s)).uncertainty)}
    @Test fun corruptedTrustedInputsFailClosed(){val s=gap();val good=trusted(s);for(bad in listOf(good.copy(epoch="foreign"),good.copy(zone="Etc/UTC"),good.copy(zoneRevision=99),good.copy(utcMillis=Long.MAX_VALUE),good.copy(at=at(-1)),good.copy(at=Sample(7,4000,5000,yes)))){val n=Accounting.recoverTrustedTime(s,bad);assertTrue(n.restrictionRequired);assertEquals(s.usedMs,n.usedMs);assertEquals(s.policy,n.policy);assertEquals(s.date,n.date)}}
    @Test fun recoveredCodecRoundtripAndCorruption(){val s=Accounting.recoverTrustedTime(gap(),trusted(gap()));assertEquals(s,LedgerCodec.decode(LedgerCodec.encode(s)));val bytes=LedgerCodec.encode(gap());bytes[bytes.size-10]=(bytes[bytes.size-10].toInt() xor 1).toByte();assertThrows(IllegalArgumentException::class.java){LedgerCodec.decode(bytes)}}
    private fun legacy(s:Ledger):ByteArray {val body=LedgerCodec.encode(s).dropLast(33).toByteArray();java.nio.ByteBuffer.wrap(body).putInt(1);return ByteArrayOutputStream().also{it.write(body);DataOutputStream(it).writeLong(CRC32().apply{update(body)}.value)}.toByteArray()}
    @Test fun legacyCodecRetainsPolicyButUnknownEndpointRequiresB(){assertEquals(base(),LedgerCodec.decode(legacy(base())));val s=LedgerCodec.decode(legacy(gap()));assertEquals(base().usedMs,s.usedMs);assertEquals(base().policy,s.policy);assertEquals(Uncertainty.CLOCK,s.uncertainty);assertEquals(s,Accounting.reconcile(s,listOf(Range(7,0,3000,yes)),at(3000),true));assertEquals(Uncertainty.NONE,Accounting.recoverTrustedTime(s,trusted(s)).uncertainty)}
    @Test fun intentCorruptionRejected(){val p=RecoveryIntent("epoch",2,7,3000,false);assertEquals(p,RecoveryIntent.decode(p.encode()));val b=p.encode();b[10]=(b[10].toInt() xor 1).toByte();assertThrows(IllegalArgumentException::class.java){RecoveryIntent.decode(b)}}
}
