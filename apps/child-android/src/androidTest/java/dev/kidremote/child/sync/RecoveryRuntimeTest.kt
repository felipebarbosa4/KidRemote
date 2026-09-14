package dev.kidremote.child.sync

import android.os.Process
import androidx.room.Room
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.core.app.ActivityScenario
import androidx.work.*
import dev.kidremote.accounting.storage.LedgerDatabase
import dev.kidremote.child.ChildActivity
import dev.kidremote.child.accounting.*
import java.io.File
import java.util.concurrent.TimeUnit
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Test

/** Real HTTP/Room/WorkManager; dispatch/clock fault fixtures do not measure OS latency. */
class RecoveryRuntimeTest {
 private val c get()=InstrumentationRegistry.getInstrumentation().targetContext
 private val folder get()=c.noBackupFilesDir
 private fun ck(v:Boolean){if(!v)throw AssertionError("RECOVERY_ASSERTION")}
 private fun raw():Ledger{val db=Room.databaseBuilder(c,LedgerDatabase::class.java,File(folder,"accounting.db").absolutePath).addMigrations(LedgerDatabase.MIGRATION_1_2).build();try{return LedgerCodec.decode(db.ledger().read()!!.payload)}finally{db.close()}}
 private fun result(code:String){InstrumentationRegistry.getInstrumentation().sendStatus(0,android.os.Bundle().apply{putString("kr009",code)})}
 private fun safe(action:()->Unit){try{action()}catch(e:Throwable){val line=e.stackTrace.firstOrNull{it.className==javaClass.name&&it.methodName!="ck"}?.lineNumber?:0;result("RECOVERY_FAILURE_LINE_"+maxOf(0,line));throw AssertionError("RECOVERY_RUNTIME_FAILED")}}
 private fun until(condition:()->Boolean){val end=System.nanoTime()+TimeUnit.SECONDS.toNanos(30);while(!condition()){ck(System.nanoTime()<end);Thread.sleep(50)}}
 private fun freshIntent(){val s=RetryStore(c).read().put("pending",true).put("stopped",false).put("attempt",0).put("delay",0).put("due",0);RetryStore(c).save(s)}
 @Test fun killAfterPageCheckpoint(){
  SyncFaults.afterPage={page->if(page==0){ck(raw().policy.version==8L);ck(File(folder,"sync-page-progress").exists());ck(RetryStore(c).read().getBoolean("pending"));ck(WorkManager.getInstance(c).getWorkInfosForUniqueWork("child-sync-recovery").get().isNotEmpty())
   File(folder,"sync-crash").outputStream().use{it.write("KR009_EXPECTED_KILL_AFTER_PAGE".toByteArray());it.fd.sync()};result("KR009_EXPECTED_KILL_AFTER_PAGE");Process.killProcess(Process.myPid())}}
  SyncRecovery.request(c,true);Thread.sleep(90000);error("EXPECTED_KILL_MISSING")
 }
 @Test fun restartThroughWorkManager()=safe {
  ck(raw().policy.version==8L&&RetryStore(c).read().getBoolean("pending"));ck(WorkManager.getInstance(c).getWorkInfosForUniqueWork("child-sync-recovery").get().isNotEmpty())
  // Explicit zero-delay dispatch uses real WorkManager DB/executor; persisted production recovery work is independently asserted.
  val work=OneTimeWorkRequestBuilder<SyncWorker>().build();WorkManager.getInstance(c).enqueue(work).result.get()
  until{WorkManager.getInstance(c).getWorkInfoById(work.id).get()?.state?.isFinished==true}
  ck(WorkManager.getInstance(c).getWorkInfoById(work.id).get()!!.state==WorkInfo.State.SUCCEEDED)
  ck(raw().policy.version==113L&&raw().usedMs==1000L&&raw().bonusSeconds==2400L&&raw().pendingAck==null)
  ck(!RetryStore(c).read().getBoolean("pending"));result("REAL_WORKMANAGER_RESTART_FULL_PAGES_NO_POLICY_ROLLBACK_OR_BONUS_REPLAY")
 }
 @Test fun expiredSequenceRestarts()=safe {
  var held=false;SyncFaults.afterPage={page->if(page==0&&!held){held=true;File(folder,"page-ready").writeText("READY");until{File(folder,"page-release").exists()}}}
  try{DeviceSync(c).use{it.sync()};ck(held&&raw().policy.version==218L&&raw().usedMs==1000L&&raw().bonusSeconds==2400L)}finally{SyncFaults.afterPage=null}
  result("REAL_EXPIRED_CURSOR_HTTP_410_FULL_RESTART_CONVERGED")
 }
 @Test fun resumeDiscoversState()=safe {
  ck(File(folder,"sync-test-control").delete())
  try{ActivityScenario.launch(ChildActivity::class.java).use{until{raw().policy.version==219L&&raw().pendingAck==null}}}finally{File(folder,"sync-test-control").writeText("")}
  ck(raw().usedMs==1000L);result("ACTUAL_ACTIVITY_RESUME_DISCOVERS_STATE_NO_PUSH")
 }
 @Test fun coalescedTriggers()=safe {
  freshIntent();val entered=CountDownLatch(1);val release=CountDownLatch(1);val pages=AtomicInteger()
  SyncFaults.afterPage={if(pages.incrementAndGet()==1){entered.countDown();ck(release.await(30,TimeUnit.SECONDS))}}
  try{SyncRecovery.request(c);ck(entered.await(30,TimeUnit.SECONDS));repeat(32){SyncRecovery.request(c)};release.countDown();until{pages.get()>=2&&!RetryStore(c).read().getBoolean("pending")};Thread.sleep(300);ck(pages.get()==2)}finally{release.countDown();SyncFaults.afterPage=null}
  ck(raw().usedMs==1000L);result("32_CONCURRENT_TRIGGERS_ONE_ACTIVE_ONE_FOLLOWUP")
 }
 @Test fun outagePersistsRetry()=safe {
  SyncRecovery.request(c,true);until{RetryStore(c).read().getInt("attempt")>0}
  ck(RetryStore(c).read().getBoolean("pending")&&!RetryStore(c).read().getBoolean("stopped"));ck(raw().policy.version==219L&&raw().usedMs==1000L);result("REAL_GATEWAY_OUTAGE_DURABLE_RETRY_INTENT_NO_POLICY_ERASURE")
 }
 @Test fun networkRecoveryConverges()=safe {
  ck(RetryStore(c).read().getBoolean("pending"))
  val connectivity=c.getSystemService(android.net.ConnectivityManager::class.java)
  until{connectivity.activeNetwork==null}
  val s=RetryStore(c).read().put("due",0).put("delay",0);RetryStore(c).save(s)
  val callback=NetworkRecovery(c);connectivity.registerDefaultNetworkCallback(callback)
  try{File(folder,"network-ready").writeText("READY");until{raw().policy.version==220L&&raw().pendingAck==null&&!RetryStore(c).read().getBoolean("pending")}}finally{connectivity.unregisterNetworkCallback(callback)}
  ck(raw().usedMs==1000L);result("REAL_EMULATOR_NETWORK_RETURN_CALLBACK_CONVERGED_CONTROLLED_DUE")
 }
 @Test fun workerDiscoversWithoutIntent()=safe {
  ck(!RetryStore(c).read().getBoolean("pending"));val work=OneTimeWorkRequestBuilder<SyncWorker>().build();WorkManager.getInstance(c).enqueue(work).result.get()
  until{WorkManager.getInstance(c).getWorkInfoById(work.id).get()?.state?.isFinished==true}
  ck(WorkManager.getInstance(c).getWorkInfoById(work.id).get()!!.state==WorkInfo.State.SUCCEEDED&&raw().policy.version==221L&&raw().usedMs==1000L&&raw().pendingAck==null)
  result("REAL_RECOVERY_WORK_DISCOVERS_NEW_STATE_WITHOUT_LOCAL_INTENT_OR_PUSH")
 }
 @Test fun scheduledLostAckRetry()=safe {
  var withheld=false;SyncFaults.afterAckResponse={withheld=true;throw java.io.IOException("LOST_ACK")}
  try{SyncRecovery.request(c,true);until{withheld&&RetryStore(c).read().getInt("attempt")>0}}finally{SyncFaults.afterAckResponse=null}
  ck(raw().pendingAck!=null);val bonus=raw().bonusSeconds
  val s=RetryStore(c).read().put("due",0).put("delay",0);RetryStore(c).save(s);SyncRecovery.request(c)
  until{raw().pendingAck==null&&!RetryStore(c).read().getBoolean("pending")};ck(raw().bonusSeconds==bonus&&raw().usedMs==1000L);result("SCHEDULED_RETRY_AFTER_REAL_ACK_RESPONSE_LOSS_NO_DUPLICATE_EFFECT")
 }
 @Test fun httpRetryAndAuthStop()=safe {
  val old=raw()
  for(code in listOf(429,503,401,403,200)){
   val socket=java.net.ServerSocket(0,1,java.net.InetAddress.getByName("127.0.0.1"));val count=AtomicInteger();val server=Thread{
    try{socket.accept().use{client->val input=client.getInputStream().bufferedReader();var length=0;while(true){val line=input.readLine()?:break;if(line.isEmpty())break;if(line.startsWith("Content-Length:",true))length=line.substringAfter(':').trim().toInt()};repeat(length){input.read()};count.incrementAndGet();val body=if(code==200)"x".repeat(65537)else "{\"code\":\"CREDENTIAL_REVOKED\"}";client.getOutputStream().write("HTTP/1.1 $code Test\r\nContent-Type: application/json\r\nRetry-After: 60\r\nContent-Length: ${body.length}\r\nConnection: close\r\n\r\n$body".toByteArray())}}catch(_:Exception){}
   };server.start();SyncFaults.testEndpoint="http://127.0.0.1:"+socket.localPort
   try{SyncRecovery.request(c,true);until{val s=RetryStore(c).read();s.getInt("attempt")>0||s.getBoolean("stopped")};val s=RetryStore(c).read();ck(count.get()==1)
    if(code in listOf(429,503)){ck(s.getBoolean("pending")&&s.getLong("delay")>=60000)}else{ck(s.getBoolean("stopped")&&!s.getBoolean("pending"));repeat(10){SyncRecovery.request(c)};ck(SyncRecovery.run(c));ck(count.get()==1)}
    ck(raw()==old)
   }finally{SyncFaults.testEndpoint=null;socket.close();server.join(2000)}
  }
  result("REAL_LOOPBACK_RETRY_AFTER_AUTH_STOP_OVERSIZE_REJECTION")
 }
 @Test fun corruptedRetryStops()=safe {
  val file=File(folder,"sync-retry");val old=file.readBytes();val ledger=raw();val expected=RetryStore(c).read().toString();ck(file.renameTo(File(file.path+".bak")));ck(RetryStore(c).read().toString()==expected&&file.exists());file.writeText("broken")
  try{ck(runCatching{SyncRecovery.request(c)}.isFailure);ck(raw()==ledger)}finally{file.writeBytes(old)}
  result("ATOMICFILE_BACKUP_RECOVERS_CORRUPT_INTENT_FAILS_CLOSED")
 }
}
