package dev.kidremote.child.accounting
import java.time.Instant
import org.junit.Assert.*
import org.junit.Test
class SyncMergeTest {
 private val utc=Instant.parse("2026-09-13T12:00:00Z").toEpochMilli()
 private val yes=Signals(true,false,true)
 private fun at(t:Long)=Sample(7,t,t,yes)
 private fun old()=Accounting.sample(Accounting.start(Policy("epoch",1,"Etc/UTC",1,"2026-09-13",3600,0,false),at(0),utc),at(1000))
 @Test fun lockSettlesBeforePolicy(){val s=old();val n=SyncMerge.accept(s,s.policy.copy(version=2,manualLock=true),at(2000),utc+2000);assertEquals(2000,n.usedMs);assertTrue(n.policy.manualLock)}
 @Test fun unlockDoesNotClearExpiry(){val s=old().copy(usedMs=3600000,policy=old().policy.copy(manualLock=true));val n=SyncMerge.accept(s,s.policy.copy(version=2,manualLock=false),at(1000),utc);assertEquals(0,n.remainingMs);assertTrue(n.restrictionRequired)}
 @Test fun absoluteBonusRestartDoesNotReplay(){val s=old();val p=s.policy.copy(version=2,bonusSeconds=600);val n=SyncMerge.accept(s,p,at(1000),utc);val restored=LedgerCodec.decode(LedgerCodec.encode(n));assertEquals(n,SyncMerge.accept(restored,p,at(1000),utc));assertEquals(600,n.bonusSeconds)}
 @Test fun lowerLimitRetainsUse(){val s=old().copy(usedMs=3000000);val n=SyncMerge.accept(s,s.policy.copy(version=2,dailyLimitSeconds=1800),at(1000),utc);assertEquals(s.usedMs,n.usedMs);assertEquals(0,n.remainingMs)}
 @Test fun staleSnapshotCannotUnlock(){val s=old().copy(policy=old().policy.copy(version=3,manualLock=true));val n=SyncMerge.accept(s,s.policy.copy(version=2,manualLock=false),at(1000),utc);assertEquals(s,n)}
 @Test fun sameVersionChangedPayloadFails(){val s=old();assertThrows(IllegalArgumentException::class.java){SyncMerge.accept(s,s.policy.copy(bonusSeconds=600),at(1000),utc)}}
 @Test fun yesterdayBonusCannotCarry(){val s=old().copy(policy=old().policy.copy(bonusSeconds=600),bonusSeconds=600,uncertainty=Uncertainty.HISTORY,recoveryThrough=3000);val next=utc+86400000;val n=SyncMerge.accept(s,s.policy.copy(version=2,bonusDate="2026-09-14",bonusSeconds=0),at(4000),next);assertEquals("2026-09-14",n.date);assertEquals(0,n.bonusSeconds);assertEquals(0,n.usedMs)}
 @Test fun samePeriodSyncCannotForgiveGap(){val s=Accounting.resume(old(),at(3000));val n=SyncMerge.accept(s,s.policy.copy(version=2,bonusSeconds=1800),at(4000),utc+4000);assertEquals(s.usedMs,n.usedMs);assertTrue(n.restrictionRequired);assertEquals(Uncertainty.HISTORY,n.uncertainty)}
 @Test fun wrongEpochDenied(){val s=old();assertThrows(IllegalArgumentException::class.java){SyncMerge.accept(s,s.policy.copy(epoch="foreign",version=2),at(1000),utc)}}
 @Test fun pendingReceiptCodecSurvives(){
  val s=old().copy(reportSequence=8,pendingAck="minimal-fixture");assertEquals(s,LedgerCodec.decode(LedgerCodec.encode(s)))
  val body=LedgerCodec.encode(old()).dropLast(17).toByteArray();java.nio.ByteBuffer.wrap(body).putInt(2)
  val legacy=java.io.ByteArrayOutputStream().also{it.write(body);java.io.DataOutputStream(it).writeLong(java.util.zip.CRC32().apply{update(body)}.value)}.toByteArray()
  assertEquals(old(),LedgerCodec.decode(legacy))
 }
}
