package dev.kidremote.child.sync
import android.os.Bundle
import androidx.test.platform.app.InstrumentationRegistry
import dev.kidremote.child.accounting.*
import org.junit.Test
/** Controlled permitted interval, real existing identity/Room/sync/ACK, no screenshots. */
class ParentControlRuntimeTest {
 @Test fun step(){try{
  val i=InstrumentationRegistry.getInstrumentation();val c=i.targetContext;val args=InstrumentationRegistry.getArguments()
  val yes=Signals(true,false,true);fun at(t:Long)=Sample(17,t,t,yes)
  if(args.getString("step")=="initialize"){
   DeviceSync(c,{at(0)}).use{check(it.sync().ledger!!.policy.version==1L)}
   ChildAccounting(c).use{check(it.reconcile(listOf(Range(17,0,3600000,yes)),at(3600000),true).ledger!!.usedMs==3600000L)}
  }
  val state=DeviceSync(c,{at(3600000)}).use{it.sync()}
  check(!state.storageFailure&&state.ledger!!.usedMs==3600000L)
  check(state.ledger!!.remainingMs==args.getString("remaining")!!.toLong())
  check(state.ledger.policy.manualLock==(args.getString("manual")=="true"))
  check(state.ledger.pendingAck==null)
  i.sendStatus(0,Bundle().apply{putString("kr010","CHILD_REAL_ROOM_SYNC_ACK_PASS")})
 }catch(_:Throwable){throw AssertionError("PARENT_CHILD_SYNC_FAILED")}}
}
