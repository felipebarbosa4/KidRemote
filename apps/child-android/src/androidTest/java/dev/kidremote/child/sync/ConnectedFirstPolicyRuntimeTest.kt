package dev.kidremote.child.sync

import android.os.ParcelFileDescriptor
import android.os.SystemClock
import androidx.lifecycle.ViewModelProvider
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import dev.kidremote.child.ChildActivity
import dev.kidremote.child.EnrollmentApi
import dev.kidremote.child.EnrollmentModel
import dev.kidremote.child.IdentityStore
import dev.kidremote.child.accounting.ChildAccounting
import org.json.JSONObject
import org.junit.Test
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/** Entire synthetic enrollment originates in the owned emulator against a NEW host lease.
 * No host-to-device credential file, camera scan, permission change or enforcement claim. */
class ConnectedFirstPolicyRuntimeTest {
 private val i get()=InstrumentationRegistry.getInstrumentation()
 private val c get()=i.targetContext
 private fun shell(s:String)=ParcelFileDescriptor.AutoCloseInputStream(i.getUiAutomation(android.app.UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES).executeShellCommand(s)).bufferedReader().use{it.readText().trim()}
 private fun waitFor(code:String,ms:Long=30000,p:()->Boolean){val end=SystemClock.elapsedRealtime()+ms;while(!p()&&SystemClock.elapsedRealtime()<end)Thread.sleep(100);check(p()){code}}
 private fun http(port:Int,path:String,body:JSONObject?=null,token:String?=null):JSONObject {
  check(port in setOf(47361,47362,47365)&&path.startsWith('/')&&!path.contains(".."))
  val connection=URL("http://10.0.2.2:$port$path").openConnection() as HttpURLConnection
  try{connection.connectTimeout=5000;connection.readTimeout=10000;connection.instanceFollowRedirects=false;connection.useCaches=false
   if(token!=null)connection.setRequestProperty("Authorization","Bearer $token")
   if(body!=null){connection.requestMethod="POST";connection.doOutput=true;connection.setRequestProperty("Content-Type","application/json");connection.outputStream.use{it.write(body.toString().toByteArray())}}
   check(connection.responseCode==200)
   val bytes=connection.inputStream.use{input->val output=java.io.ByteArrayOutputStream();val buffer=ByteArray(4096);while(true){val n=input.read(buffer);if(n<0)break;check(output.size()+n<=65536);output.write(buffer,0,n)};output.toByteArray()}
   return JSONObject(String(bytes,Charsets.UTF_8))
  }finally{connection.disconnect()}
 }
 @Test fun bootstrapThroughRealGateway(){
  var stage="GUARD";var scenario:ActivityScenario<ChildActivity>?=null
  var oldServices:String?=null;var oldEnabled:String?=null
  val mode=InstrumentationRegistry.getArguments().getString("first_policy_mode")!!;check(mode in setOf("connected","connected-service"))
  val out=JSONObject().put("scope","EMULATOR_REAL_GATEWAY_FIRST_POLICY").put("mode",mode).put("physicalAcceptance",false)
  try{
   check(shell("getprop ro.kernel.qemu")=="1"&&shell("getprop ro.boot.qemu.avd_name")=="kr006_e03b4820193b4132b1fcf7950eeed7fe")
   check(!IdentityStore(c).file.exists()&&!File(c.noBackupFilesDir,"accounting.db").exists())
   stage="SYNTHETIC_AUTH"
   val email="first-policy-"+UUID.randomUUID()+"@example.test"
   val password=UUID.randomUUID().toString()+"aA1!"
   http(47361,"/signup",JSONObject().put("email",email).put("password",password))
   var confirmation:String?=null
   waitFor("SYNTHETIC_MAIL_MISSING"){
    val rows=http(47365,"/api/v1/messages").getJSONArray("messages")
    for(n in 0 until rows.length()){
     val row=rows.getJSONObject(n);val to=row.getJSONArray("To")
     if((0 until to.length()).any{to.getJSONObject(it).getString("Address")==email}){
      val mail=http(47365,"/api/v1/message/"+row.getString("ID"))
      val link=Regex("http://127\\.0\\.0\\.1:47361/verify\\?[^\\s\"<>]+").find(mail.getString("HTML").replace("&amp;","&"))!!.value
      confirmation=android.net.Uri.parse(link).getQueryParameter("token")
     }
    };confirmation!=null
   }
   val login=http(47361,"/verify",JSONObject().put("token_hash",confirmation).put("type","signup"));val jwt=login.getString("access_token")
   http(47362,"/rpc/bootstrap_household",JSONObject().put("p_timezone","Etc/UTC"),jwt)
   val api=EnrollmentApi();val pairing=api.request("/parent/pairing-sessions",JSONObject(),jwt)
   check(pairing.getString("result")=="CREATED")
   stage="APP_ENROLLMENT";scenario=ActivityScenario.launch(ChildActivity::class.java)
   lateinit var model:EnrollmentModel;scenario.onActivity{model=ViewModelProvider(it)[EnrollmentModel::class.java]}
   waitFor("MODEL_BUSY"){!model.state.loading};scenario.onActivity{model.decoded(pairing.getJSONObject("qr").toString())}
   waitFor("REAL_ENROLLMENT_FAILED"){!model.state.loading&&model.state.paired}
   val identity=IdentityStore(c).read()!!;val id=identity.getString("device_id");val epoch=identity.getString("policy_epoch")
   waitFor("BOOTSTRAP_NOT_IDLE"){!RetryStore(c).read().getBoolean("pending")}
   out.put("enrollmentConfirmed",true).put("initialAccountingAbsent",!File(c.noBackupFilesDir,"accounting.db").exists())
   if(mode=="connected-service"){
    stage="SERVICE_SETUP"
    val ops=c.getSystemService(android.app.AppOpsManager::class.java)
    check(ops.checkOpNoThrow(android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,android.os.Process.myUid(),c.packageName)==android.app.AppOpsManager.MODE_DEFAULT)
    oldServices=shell("settings get secure enabled_accessibility_services");oldEnabled=shell("settings get secure accessibility_enabled")
    val component=c.packageName+"/dev.kidremote.child.enforcement.ChildEnforcementService"
    val enabled=if(oldServices=="null"||oldServices!!.isEmpty())component else oldServices+":"+component
    dev.kidremote.child.enforcement.EnforcementRuntime.consent(c)
    shell("appops set ${c.packageName} GET_USAGE_STATS allow")
    shell("settings put secure enabled_accessibility_services $enabled");shell("settings put secure accessibility_enabled 1")
    waitFor("SERVICE_NOT_CONNECTED"){dev.kidremote.child.enforcement.EnforcementRuntime.engine()!=null}
    shell("am start -W -n ${c.packageName}/dev.kidremote.child.ChildActivity")
    out.put("serviceConnected",true)
   }
   stage="FIRST_POLICY";val operation=UUID.randomUUID().toString()
   val accepted=api.request("/parent/devices/$id/operations",JSONObject().put("protocol_version",1).put("operation_id",operation).put("device_id",id).put("kind","SET_DAILY_LIMIT").put("payload",JSONObject().put("daily_limit_seconds",3600)).put("expected_version",0),jwt)
   check(accepted.getString("status")=="accepted"&&accepted.getLong("version")==1L)
   val start=SystemClock.elapsedRealtime();val launch=shell("am start -W -n ${c.packageName}/dev.kidremote.child.ChildActivity")
   out.put("topLaunchStatusOk",launch.contains("Status: ok"));stage="AUTOMATIC_SYNC"
   waitFor("REAL_INITIAL_POLICY_TIMEOUT"){ChildAccounting(c).use{it.read().ledger?.policy?.version==1L}}
   waitFor("REAL_ACK_NOT_CONFIRMED"){ChildAccounting(c).use{it.read().ledger?.pendingAck==null}&&!RetryStore(c).read().getBoolean("pending")}
   stage="SERVER_REPORT";var report:JSONObject?=null
   waitFor("SERVER_REPORT_MISSING"){
    val devices=http(47362,"/rpc/parent_devices",JSONObject().put("p_after",JSONObject.NULL),jwt).getJSONArray("devices")
    check(devices.length()==1);val d=devices.getJSONObject(0);check(d.getString("id")==id&&d.getString("policy_epoch")==epoch)
    report=if(d.isNull("report"))null else d.getJSONObject("report");report?.getLong("version")==1L
   }
   out.put("serverReportVersion",report!!.getLong("version")).put("serverRestrictionApplied",report!!.getBoolean("restriction_applied"))
    .put("localAckConfirmed",true).put("observedMsAfterParentCommit",SystemClock.elapsedRealtime()-start).put("status","PASS")
   check(!report!!.getBoolean("restriction_applied"));i.sendStatus(0,android.os.Bundle().apply{putString("firstpolicy","REAL_ENROLLMENT_FIRST_POLICY_ROOM_SERVER_ACK")})
  }catch(e:Throwable){
   val line=e.stackTrace.firstOrNull{it.className==javaClass.name}?.lineNumber?:0
   out.put("status","FAIL").put("failureStage",stage).put("failureLine",line)
   throw AssertionError("CONNECTED_FIRST_POLICY_FAILED_"+stage+"_LINE_"+line)
  }finally{
   if(oldServices!=null)try{
    shell(if(oldServices=="null")"settings delete secure enabled_accessibility_services" else "settings put secure enabled_accessibility_services $oldServices")
    shell(if(oldEnabled=="null")"settings delete secure accessibility_enabled" else "settings put secure accessibility_enabled $oldEnabled")
    shell("appops set ${c.packageName} GET_USAGE_STATS default")
    check(shell("settings get secure enabled_accessibility_services")==oldServices&&shell("settings get secure accessibility_enabled")==oldEnabled)
    out.put("serviceSettingsCleanup","VERIFIED")
   }catch(_:Throwable){out.put("serviceSettingsCleanup","UNVERIFIED").put("status","FAIL")}
   File(c.noBackupFilesDir,"first-policy-result.json").writeText(out.toString());scenario?.close()
  }
 }
}
