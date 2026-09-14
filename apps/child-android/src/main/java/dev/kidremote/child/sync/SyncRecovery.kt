package dev.kidremote.child.sync

import android.app.Application
import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.os.SystemClock
import android.provider.Settings
import android.util.AtomicFile
import androidx.work.*
import dev.kidremote.child.IdentityStore
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.json.JSONObject

/** Durable transport intent only. Canonical policy, identity and ACK stay in their existing stores. */
internal class RetryStore(context:Context) {
 private val file=AtomicFile(File(context.noBackupFilesDir,"sync-retry"))
 fun read():JSONObject {
  if(!file.baseFile.exists())return JSONObject().put("format",1).put("pending",false).put("stopped",false).put("attempt",0).put("boot",-1).put("due",0).put("delay",0).put("identity","")
  val bytes=file.openRead().use{it.readBytes()};check(bytes.size<=1024)
  val s=JSONObject(String(bytes));check(s.length()==8&&s.getInt("format")==1&&s.getInt("attempt") in 0..30&&s.getLong("due")>=0&&s.getLong("delay") in 0..86400000)
  s.getBoolean("pending");s.getBoolean("stopped");s.getString("identity");s.getInt("boot");return s
 }
 fun save(s:JSONObject){val out=file.startWrite();try{out.write(s.toString().toByteArray());file.finishWrite(out)}catch(e:Exception){file.failWrite(out);throw e}}
}
internal object SyncRecovery {
 private val gate=Any()
 private val executor=Executors.newSingleThreadScheduledExecutor()
 private val triggers=Executors.newSingleThreadExecutor()
 fun notify(context:Context){triggers.execute{try{request(context)}catch(_:Exception){}}}
 private var active=false;private var follow=false;private var timer:java.util.concurrent.ScheduledFuture<*>?=null
 private fun boot(c:Context)=Settings.Global.getInt(c.contentResolver,Settings.Global.BOOT_COUNT,-1)
 private fun remaining(c:Context,s:JSONObject):Long=if(s.getInt("boot")==boot(c))maxOf(0,s.getLong("due")-SystemClock.elapsedRealtime()) else s.getLong("delay")
 fun request(context:Context,explicitRecovery:Boolean=false) {
  val c=context.applicationContext
  synchronized(gate) {
   val id=IdentityStore(c).read()?:return
   if(id.has("removal"))return
   val store=RetryStore(c);val s=store.read();val key=id.getString("device_id")+":"+id.getString("policy_epoch")
   if(s.getString("identity")!=key||explicitRecovery){s.put("identity",key).put("stopped",false).put("attempt",0).put("due",0).put("delay",0)}
   if(s.getBoolean("stopped"))return
   if(s.getInt("boot")!=boot(c)){s.put("boot",boot(c)).put("due",SystemClock.elapsedRealtime()+s.getLong("delay"))}
   s.put("pending",true);store.save(s)
   // Persist recovery work before attempting HTTP. Only one recovery work item is retained.
   WorkManager.getInstance(c).enqueueUniqueWork("child-sync-recovery",ExistingWorkPolicy.KEEP,
    OneTimeWorkRequestBuilder<SyncWorker>().setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()).setInitialDelay(5,TimeUnit.MINUTES).build()).result.get()
   if(active){follow=true;return}
   timer?.cancel(false);timer=executor.schedule({run(c)},remaining(c,s),TimeUnit.MILLISECONDS)
  }
 }
 fun run(context:Context):Boolean {
  val c=context.applicationContext
  synchronized(gate){if(active){follow=true;return false};active=true;follow=false}
  try {
   for(pass in 0..1) {
    val state=synchronized(gate){val store=RetryStore(c);store.read().also{if(it.getInt("boot")!=boot(c)){it.put("boot",boot(c)).put("due",SystemClock.elapsedRealtime()+it.getLong("delay"));store.save(it)}}}
    if(!state.getBoolean("pending")||state.getBoolean("stopped"))return true
    if(remaining(c,state)>0){schedule(c,remaining(c,state));return false}
    try {
     DeviceSync(c).use{it.sync()}
     synchronized(gate){val s=RetryStore(c).read();s.put("pending",false).put("attempt",0).put("delay",0).put("due",0);RetryStore(c).save(s)}
    }catch(e:Exception) {
     synchronized(gate){val s=RetryStore(c).read()
      if(e is SecurityException || e !is IOException){s.put("stopped",true).put("pending",false);RetryStore(c).save(s);return true}
      val delay=RetryTiming.delay(s.getInt("attempt"),Math.random(),(e as? RetryableSync)?.delayMs?:0)
      s.put("pending",true).put("attempt",minOf(30,s.getInt("attempt")+1)).put("boot",boot(c)).put("delay",delay).put("due",SystemClock.elapsedRealtime()+delay);RetryStore(c).save(s);schedule(c,delay);return false
     }
    }
    synchronized(gate){if(!follow||pass==1)return true;follow=false;val s=RetryStore(c).read().put("pending",true);RetryStore(c).save(s)}
   }
   return true
  }finally{synchronized(gate){active=false;follow=false}}
 }
 private fun schedule(c:Context,delay:Long){synchronized(gate){timer?.cancel(false);timer=executor.schedule({run(c)},delay,TimeUnit.MILLISECONDS)}}
}
class SyncWorker(context:Context,parameters:WorkerParameters):Worker(context,parameters) {
 override fun doWork():Result=try{if(SyncRecovery.run(applicationContext))Result.success()else Result.retry()}catch(_:Exception){Result.failure()}
}
class ChildApplication:Application() {
 override fun onCreate(){super.onCreate();if(!SyncFaults.automaticAllowed(this))return
  // Callback is process-local. WorkManager supplies durable best-effort recovery.
  getSystemService(ConnectivityManager::class.java).registerDefaultNetworkCallback(object:ConnectivityManager.NetworkCallback(){override fun onAvailable(network:Network){recover()}})
  recover()
 }
 private fun recover(){SyncRecovery.notify(this)}
}
