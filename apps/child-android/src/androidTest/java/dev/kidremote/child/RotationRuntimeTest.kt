package dev.kidremote.child
import android.os.Process
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean
import org.junit.Test

/** Actual encrypted storage + app contact + local HTTP/SQL. No fake credential/authorization state. */
class RotationRuntimeTest {
    private val context get()=InstrumentationRegistry.getInstrumentation().targetContext
    private val store get()=IdentityStore(context)
    private fun checkSafe(v:Boolean){if(!v)throw AssertionError("ROTATION_RUNTIME_ASSERTION")}
    private fun safe(action:()->Unit){try{action()}catch(_:Throwable){throw AssertionError("ROTATION_RUNTIME_FAILED")}finally{EnrollmentFaults.afterRotationResponse={}}}
    private fun waitFor(predicate:()->Boolean){val end=System.nanoTime()+30_000_000_000L;while(System.nanoTime()<end){if(predicate())return;Thread.sleep(100)};throw AssertionError("ROTATION_RUNTIME_TIMEOUT")}
    private fun result(code:String){InstrumentationRegistry.getInstrumentation().sendStatus(0,android.os.Bundle().apply{putString("kr007",code)})}
    @Test fun normal()=safe {
        val before=store.read()!!
        ActivityScenario.launch(ChildActivity::class.java).use {
            waitFor{store.read()?.optLong("generation",0)==2L}
            val after=store.read()!!;checkSafe(!after.has("rotation")&&after.getString("credential")!=before.getString("credential"))
            checkSafe(after.getString("device_id")==before.getString("device_id")&&after.getString("policy_epoch")==before.getString("policy_epoch"))
            checkSafe(EnrollmentApi().initial(after).getString("device_id")==before.getString("device_id"))
            var denied=false;try{EnrollmentApi().initial(before)}catch(_:SecurityException){denied=true};checkSafe(denied)
            result("ACTUAL_APP_NORMAL_ROTATION_NEW_READ_OLD_DENIED_PASS")
        }
    }
    private fun lose(phase:String) {
        val before=store.read()!!;val hit=AtomicBoolean(false)
        EnrollmentFaults.afterRotationResponse={p->if(p==phase){hit.set(true);throw IOException("SYNTHETIC_REPLY_WITHHELD")}}
        ActivityScenario.launch(ChildActivity::class.java).use {
            waitFor{hit.get()};Thread.sleep(500)
            val pending=store.read()!!;checkSafe(pending.has("rotation"));checkSafe(pending.getString("credential")==before.getString("credential"))
            val bytes=store.file.readBytes().toString(Charsets.ISO_8859_1)
            checkSafe(!bytes.contains(pending.getString("credential"))&&!bytes.contains(pending.getJSONObject("rotation").getString("new_credential")))
            File(context.noBackupFilesDir,"rotation-operation").writeText(pending.getJSONObject("rotation").getString("operation_id"))
            File(context.noBackupFilesDir,"rotation-device").writeText(pending.getString("device_id"))
            File(context.noBackupFilesDir,"rotation-pid").writeText(Process.myPid().toString())
            result(if(phase=="BEGIN")"REAL_BEGIN_COMMITTED_REPLY_WITHHELD_FROM_RENEWAL" else "REAL_CONFIRM_COMMITTED_REPLY_WITHHELD_FROM_RENEWAL")
        }
    }
    @Test fun loseBegin()=safe{lose("BEGIN")}
    @Test fun loseConfirm()=safe{lose("CONFIRM")}
    @Test fun restartPending()=safe {
        checkSafe(Process.myPid()!=File(context.noBackupFilesDir,"rotation-pid").readText().toInt())
        val pending=store.read()!!;checkSafe(pending.has("rotation"))
        checkSafe(pending.getJSONObject("rotation").getString("operation_id")==File(context.noBackupFilesDir,"rotation-operation").readText())
        val expected=pending.getJSONObject("rotation").getString("new_credential")
        ActivityScenario.launch(ChildActivity::class.java).use {
            waitFor{store.read()?.has("rotation")==false}
            val after=store.read()!!;checkSafe(after.getString("credential")==expected)
            checkSafe(after.getString("device_id")==File(context.noBackupFilesDir,"rotation-device").readText())
            checkSafe(EnrollmentApi().initial(after).getString("device_id")==after.getString("device_id"))
            result("ACTUAL_PENDING_PROCESS_RESTART_SAME_CANDIDATE_NEW_READ_PASS")
        }
    }
    @Test fun outageRetains()=safe {
        val before=store.file.readBytes()
        ActivityScenario.launch(ChildActivity::class.java).use {
            Thread.sleep(12000);checkSafe(before.contentEquals(store.file.readBytes()))
            checkSafe(store.read()!=null);result("ACTUAL_BACKEND_OUTAGE_ENCRYPTED_IDENTITY_UNCHANGED_PASS")
        }
    }
}
