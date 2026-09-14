package dev.kidremote.child.sync
import android.os.Process
import androidx.room.Room
import androidx.test.platform.app.InstrumentationRegistry
import dev.kidremote.accounting.storage.LedgerDatabase
import dev.kidremote.child.IdentityStore
import dev.kidremote.child.DeviceRemoved
import dev.kidremote.child.accounting.*
import java.io.File
import java.security.MessageDigest
import org.json.JSONObject
import org.json.JSONArray
import org.junit.Test

/** Real gateway/Auth/DB identity handoff; controlled monotonic signals, actual Room/Keystore/HTTP. */
class SyncRuntimeTest {
 private val context get()=InstrumentationRegistry.getInstrumentation().targetContext
 private val folder get()=context.noBackupFilesDir
 private val yes=Signals(true,false,true)
 private fun at(t:Long=1000)=Sample(7,t,t,yes)
 private fun ck(v:Boolean){if(!v)throw AssertionError("SYNC_ASSERTION")}
 private fun result(code:String){InstrumentationRegistry.getInstrumentation().sendStatus(0,android.os.Bundle().apply{putString("kr009",code)})}
 private fun safe(action:()->Unit){try{action()}catch(e:Throwable){val line=e.stackTrace.firstOrNull{it.className.startsWith("dev.kidremote.child.sync.")&&it.methodName!="ck"}?.lineNumber?:0;result("SYNC_FAILURE_LINE_"+maxOf(0,line));throw AssertionError("SYNC_RUNTIME_FAILED")}}
 private fun raw():Ledger {val db=Room.databaseBuilder(context,LedgerDatabase::class.java,File(folder,"accounting.db").absolutePath).addMigrations(LedgerDatabase.MIGRATION_1_2).build();try{return LedgerCodec.decode(db.ledger().read()!!.payload)}finally{db.close()}}
 private fun sync()=DeviceSync(context,{at()}).use{it.sync()}
 private fun digest()=MessageDigest.getInstance("SHA-256").digest(IdentityStore(context).file.readBytes()).joinToString(""){"%02x".format(it)}
 private fun mark(){File(folder,"sync-pid").writeText(Process.myPid().toString())}
 @Test fun prepareIdentityAndUsage()=safe {
  val f=File(folder,"sync-handoff");val id=JSONObject(f.readText());IdentityStore(context).save(id);ck(f.delete())
  DeviceSync(context,{at(0)}).use{val r=it.sync();ck(!r.storageFailure&&r.ledger!!.policy.version==1L)}
  ChildAccounting(context).use{val r=it.reconcile(listOf(Range(7,0,1000,yes)),at(),true);ck(r.ledger!!.usedMs==1000L)}
  File(folder,"sync-identity-digest").writeText(digest());mark();result("REAL_IDENTITY_HTTP_SNAPSHOT_ROOM_ACK_INITIALIZED_NONZERO_USE")
 }
 @Test fun lockPersisted()=safe {
  val r=sync();ck(r.ledger!!.policy.version==2L&&r.ledger.policy.manualLock&&r.ledger.usedMs==1000L&&r.restrictionRequired)
  ck(raw().pendingAck==null&&digest()==File(folder,"sync-identity-digest").readText());result("LOCK_PERSISTED_ACKNOWLEDGED_NO_ENFORCEMENT_CLAIM")
 }
 @Test fun zeroUnlockAndReordered()=safe {
  val r=sync();ck(r.ledger!!.policy.version==4L&&!r.ledger.policy.manualLock&&r.ledger.usedMs==1000L&&r.ledger.remainingMs==0L&&r.restrictionRequired)
  sync();ck(raw().usedMs==1000L)
  SyncFaults.transformSyncResponse={text->JSONObject(text).put("version",3).put("daily_limit_seconds",3600).put("operations",JSONArray()).toString()}
  try{sync();ck(raw().policy.version==4L&&raw().usedMs==1000L&&raw().remainingMs==0L)}finally{SyncFaults.transformSyncResponse=null}
  result("UNLOCK_ZERO_LOWER_LIMIT_DUPLICATE_OLDER_SNAPSHOT_NO_ROLLBACK")
 }
 @Test fun malformedSnapshotRetainsPolicy()=safe {
  val old=raw()
  val edits=listOf<(JSONObject)->JSONObject>(
   {it.put("protocol_version",2)},{it.put("device_id","90000000-0000-4000-8000-000000000099")},
   {it.put("policy_epoch","90000000-0000-4000-8000-000000000099")},{it.put("daily_limit_seconds","3600")},
   {it.put("bonus_seconds",-1)},{it.put("unexpected",true)})
  for(edit in edits){SyncFaults.transformSyncResponse={edit(JSONObject(it)).toString()};try{ck(runCatching{sync()}.isFailure);ck(raw()==old)}finally{SyncFaults.transformSyncResponse=null}}
  SyncFaults.transformSyncResponse={it.dropLast(1)+",\"protocol_version\":1}"}
  try{ck(runCatching{sync()}.isFailure);ck(raw()==old)}finally{SyncFaults.transformSyncResponse=null}
  result("REAL_HTTP_MUTATED_BEFORE_VALIDATION_SCHEMA_NUMBERS_DUPLICATES_RETAIN_POLICY")
 }
 @Test fun killAfterGrantPersistence() {
  SyncFaults.afterPersist={
   val s=raw();ck(s.policy.version==5L&&s.bonusSeconds==600L&&s.usedMs==1000L&&s.pendingAck!=null)
   File(folder,"sync-crash").outputStream().use{it.write("KR009_EXPECTED_KILL_AFTER_PERSIST".toByteArray());it.fd.sync()};mark();result("KR009_EXPECTED_KILL_AFTER_PERSIST");Process.killProcess(Process.myPid());error("KILL_FAILED")
  }
  sync();error("EXPECTED_KILL_MISSING")
 }
 @Test fun restartResendsPendingAck()=safe {
  ck(Process.myPid()!=File(folder,"sync-pid").readText().toInt());ck(raw().pendingAck!=null)
  DeviceSync(context,{at()}).use{it.retryAck()};ck(raw().pendingAck==null&&raw().bonusSeconds==600L&&raw().usedMs==1000L)
  sync();ck(raw().bonusSeconds==600L&&raw().usedMs==1000L);result("PROCESS_RESTART_RESENDS_DURABLE_ACK_NO_GRANT_REPLAY")
 }
 @Test fun loseAckResponse()=safe {
  SyncFaults.afterAckResponse={throw java.io.IOException("INJECTED_ACK_RESPONSE_LOSS")}
  try{ck(runCatching{sync()}.isFailure)}finally{SyncFaults.afterAckResponse=null}
  val s=raw();ck(s.policy.version==6L&&s.bonusSeconds==2400L&&s.pendingAck!=null&&s.usedMs==1000L);mark()
  result("REAL_COMMITTED_ACK_HTTP_RESPONSE_WITHHELD_PENDING_RETAINED")
 }
 @Test fun retryLostAckAfterRestart()=safe {
  ck(Process.myPid()!=File(folder,"sync-pid").readText().toInt());val old=raw()
  DeviceSync(context,{at()}).use{it.retryAck()};val s=raw();ck(s.pendingAck==null&&s.reportSequence==old.reportSequence&&s.bonusSeconds==old.bonusSeconds&&s.usedMs==old.usedMs)
  result("LOST_ACK_RETRY_IDENTICAL_SEQUENCE_AFTER_PROCESS_RESTART")
 }
 @Test fun offlinePreservesLedger()=safe {
  val old=raw();ck(runCatching{sync()}.isFailure);ck(raw()==old&&digest()==File(folder,"sync-identity-digest").readText());result("GATEWAY_OUTAGE_RETAINS_LEDGER_IDENTITY_NO_PENDING_ERASURE")
 }
 @Test fun explicitRestartConverges()=safe {
  val r=sync();ck(r.ledger!!.policy.version==7L&&r.ledger.policy.manualLock&&r.ledger.bonusSeconds==2400L&&r.ledger.usedMs==1000L);result("EXPLICIT_SYNC_AFTER_OUTAGE_RESTART_WITHOUT_PUSH_CONVERGED")
 }
 @Test fun yesterdayGrantNotCredited()=safe {
  val r=sync();ck(r.ledger!!.policy.version==8L&&r.ledger.bonusSeconds==2400L&&r.ledger.usedMs==1000L);result("YESTERDAY_GRANT_NO_TODAY_CREDIT")
 }
 @Test fun expiredRetainsLedger()=safe {
  val old=raw();ck(runCatching{sync()}.exceptionOrNull() is SecurityException);ck(raw()==old&&digest()==File(folder,"sync-identity-digest").readText());result("EXPIRED_AUTH_RETAINS_DOWNLOADED_POLICY_ACCOUNTING")
 }
 @Test fun revokedRetainsUntilExplicitRemoval()=safe {
  val old=raw();ck(runCatching{sync()}.exceptionOrNull() is DeviceRemoved);ck(raw()==old&&IdentityStore(context).read()!!.has("removal"));result("VALIDATED_REVOCATION_PRESERVES_LEDGER_UNTIL_EXPLICIT_CLEAR")
 }
}
