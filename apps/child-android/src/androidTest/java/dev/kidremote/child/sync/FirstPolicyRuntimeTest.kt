package dev.kidremote.child.sync

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import dev.kidremote.child.ChildActivity
import dev.kidremote.child.IdentityStore
import dev.kidremote.child.accounting.ChildAccounting
import org.json.JSONObject
import org.json.JSONArray
import org.junit.Test
import java.io.File
import java.net.InetAddress
import java.net.ServerSocket
import java.time.Instant
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/** Owned emulator lifecycle + real loopback HTTP/Keystore/Room; server replies are fixtures.
 * No actual backend identity is transferred; the separate native backend test is not merged with this evidence. */
class FirstPolicyRuntimeTest {
 private val i get()=InstrumentationRegistry.getInstrumentation()
 private val c get()=i.targetContext
 private fun waitFor(code:String,ms:Long=30000,p:()->Boolean){val end=SystemClock.elapsedRealtime()+ms;while(!p()&&SystemClock.elapsedRealtime()<end)Thread.sleep(100);check(p()){code}}
 @Test fun bootstrapForegroundAndBackoff(){
  var stage="GUARD";val resumes=AtomicInteger();val out=JSONObject().put("scope","EMULATOR_LIFECYCLE_LOOPBACK_FIXTURE").put("physicalAcceptance",false)
  fun shell(s:String)=ParcelFileDescriptor.AutoCloseInputStream(i.uiAutomation.executeShellCommand(s)).bufferedReader().use{it.readText().trim()}
  check(shell("getprop ro.kernel.qemu")=="1"&&shell("getprop ro.boot.qemu.avd_name")=="kr006_e03b4820193b4132b1fcf7950eeed7fe")
  val app=c.applicationContext as Application
  val callbacks=object:Application.ActivityLifecycleCallbacks {
   override fun onActivityResumed(a:Activity){if(a is ChildActivity)resumes.incrementAndGet()}
   override fun onActivityCreated(a:Activity,b:Bundle?){}
   override fun onActivityStarted(a:Activity){}
   override fun onActivityPaused(a:Activity){}
   override fun onActivityStopped(a:Activity){}
   override fun onActivitySaveInstanceState(a:Activity,b:Bundle){}
   override fun onActivityDestroyed(a:Activity){}
  }
  var scenario:ActivityScenario<ChildActivity>?=null;var server:FirstPolicyServer?=null
  try {
   val mode=InstrumentationRegistry.getArguments().getString("first_policy_mode")!!
   check(mode in setOf("foreground","deadline"));out.put("mode",mode)
   val dir=c.noBackupFilesDir;check(!File(dir,"device-identity").exists()&&!File(dir,"accounting.db").exists())
   val synthetic=JSONObject().put("device_id",UUID.randomUUID().toString()).put("policy_epoch",UUID.randomUUID().toString())
    .put("credential",java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(ByteArray(32).also{java.security.SecureRandom().nextBytes(it)}))
   server=FirstPolicyServer(synthetic);SyncFaults.testEndpoint=server.endpoint
   IdentityStore(c).save(synthetic);app.registerActivityLifecycleCallbacks(callbacks)
   stage="BOOTSTRAP";scenario=ActivityScenario.launch(ChildActivity::class.java)
   waitFor("BOOTSTRAP_NOT_IDLE"){server.syncs.get()>0&&!RetryStore(c).read().getBoolean("pending")}
   Thread.sleep(700)
   check(!File(dir,"accounting.db").exists());val before=server.syncs.get();val resumeBefore=resumes.get()
   out.put("bootstrapResponses",before).put("initialAccountingAbsent",true)
   if(mode=="deadline"){
    RetryStore(c).save(RetryStore(c).read().put("pending",true).put("attempt",30).put("delay",45000).put("due",SystemClock.elapsedRealtime()+45000))
    SyncRecovery.request(c);out.put("controlledRetryDelayMs",45000)
   }
   server.configured.set(true);val start=SystemClock.elapsedRealtime();stage="TOP_LAUNCH"
   val launch=shell("am start -W -n ${c.packageName}/dev.kidremote.child.ChildActivity")
   out.put("topLaunchStatusOk",launch.contains("Status: ok")).put("topLaunchReused",launch.contains("not started")||launch.contains("delivered")||launch.contains("brought to the front"))
   fun initialized():Boolean=ChildAccounting(c).use{val r=it.read();!r.storageFailure&&r.ledger?.policy?.version==1L}
   stage="FIRST_WINDOW";while(!initialized()&&SystemClock.elapsedRealtime()-start<30000)Thread.sleep(100)
   val within=initialized();out.put("withinInitialWindow",within).put("resumeCallbacksAfterTopLaunch",resumes.get()-resumeBefore).put("responsesAfterTopLaunch",server.syncs.get()-before)
   if(mode=="foreground"&&!within){stage="RESUME_CONTROL";scenario.moveToState(Lifecycle.State.CREATED);scenario.moveToState(Lifecycle.State.RESUMED)}
   stage="CONVERGENCE";waitFor("FIRST_POLICY_NOT_INITIALIZED",60000){initialized()}
   waitFor("ACK_NOT_CONFIRMED"){ChildAccounting(c).use{it.read().ledger?.pendingAck==null}&&!RetryStore(c).read().getBoolean("pending")}
   val ledger=ChildAccounting(c).use{it.read().ledger!!}
   check(ledger.policy.epoch==synthetic.getString("policy_epoch")&&ledger.policy.version==1L&&!ledger.policy.manualLock)
   out.put("converged",true).put("localFixtureAckConfirmed",true).put("fixtureAckRequests",server.acks.get())
    .put("responseCount",server.syncs.get()).put("totalResumeCallbacks",resumes.get())
    .put("observedMsAfterFixtureCommit",SystemClock.elapsedRealtime()-start).put("status","PASS")
   i.sendStatus(0,Bundle().apply{putString("firstpolicy","FIXTURE_POLICY_ROOM_ACK_CONFIRMED")})
  }catch(e:Throwable){
   val line=e.stackTrace.firstOrNull{it.className==javaClass.name}?.lineNumber?:0
   out.put("status","FAIL").put("failureStage",stage).put("failureLine",line)
   throw AssertionError("FIRST_POLICY_FAILED_"+stage+"_LINE_"+line)
  }finally{
   File(c.noBackupFilesDir,"first-policy-result.json").writeText(out.toString())
   app.unregisterActivityLifecycleCallbacks(callbacks);scenario?.close();server?.close();SyncFaults.testEndpoint=null
  }
 }
}

private class FirstPolicyServer(private val identity:JSONObject):AutoCloseable {
 val configured=AtomicBoolean(false);val syncs=AtomicInteger();val acks=AtomicInteger()
 private val socket=ServerSocket(0,4,InetAddress.getByName("127.0.0.1"))
 val endpoint="http://127.0.0.1:"+socket.localPort
 private val running=AtomicBoolean(true);private val snapshot=UUID.randomUUID().toString();private val operation=UUID.randomUUID().toString()
 private val thread=Thread {
  while(running.get())try{socket.accept().use{client->
   client.soTimeout=5000;val input=client.getInputStream().bufferedReader();val request=input.readLine()?:error("EMPTY_REQUEST")
   var size=0;while(true){val h=input.readLine()?:error("HEADERS_EOF");if(h.isEmpty())break;if(h.startsWith("Content-Length:",true))size=h.substringAfter(':').trim().toInt()}
   check(size in 1..65536);val chars=CharArray(size);var read=0;while(read<size){val n=input.read(chars,read,size-read);check(n>0);read+=n}
   val body=JSONObject(String(chars));val response=when(request.substringBefore(" HTTP")){
    "POST /device/sync"->{syncs.incrementAndGet();policy(body.getLong("after_version"))}
    "POST /device/ack"->{acks.incrementAndGet();JSONObject().put("code","ACKNOWLEDGED").put("report_sequence",body.getLong("report_sequence")).put("received_at",Instant.now().toString())}
    else->error("FIXTURE_ROUTE")
   }
   val bytes=response.toString().toByteArray(Charsets.UTF_8)
   client.getOutputStream().write(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: "+bytes.size+"\r\nConnection: close\r\n\r\n").toByteArray()+bytes)
  }}catch(_:Exception){/* Test records only convergence failure, never request or identity bytes. */}
 }.apply{isDaemon=true;start()}
 private fun policy(after:Long):JSONObject {
  val utc=Instant.now();val configuredNow=configured.get()
  val r=JSONObject().put("protocol_version",1).put("device_id",identity.getString("device_id")).put("policy_epoch",identity.getString("policy_epoch"))
   .put("kind",if(configuredNow)"CONFIGURED_SNAPSHOT" else "ENROLLMENT_BOOTSTRAP").put("version",if(configuredNow)1 else 0)
   .put("policy_configured",configuredNow).put("daily_limit_seconds",if(configuredNow)3600 else JSONObject.NULL).put("manual_lock",false).put("enforcement_available",false)
   .put("credential_lifecycle",JSONObject().put("generation",1).put("expires_at",utc.plusSeconds(86400).toString()).put("rotate_after",utc.plusSeconds(3600).toString()).put("rotation_due",false))
  if(configuredNow){
   val period="1:"+utc.atZone(java.time.ZoneId.of("Etc/UTC")).toLocalDate()
   val operations=JSONArray();if(after==0L)operations.put(JSONObject().put("operation_id",operation).put("version",1).put("kind","SET_DAILY_LIMIT").put("period_key",JSONObject.NULL).put("status","pending"))
   r.put("timezone_name","Etc/UTC").put("timezone_revision",1).put("server_utc",utc.toString()).put("period_key",period).put("bonus_seconds",0)
    .put("operations",operations).put("history_pruned",false).put("snapshot_id",snapshot).put("next_cursor",JSONObject.NULL)
  }
  return r
 }
 override fun close(){running.set(false);socket.close();thread.join(2000)}
}
