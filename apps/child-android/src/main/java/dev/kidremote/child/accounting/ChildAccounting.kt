package dev.kidremote.child.accounting

import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import androidx.room.Room
import dev.kidremote.accounting.storage.LedgerDatabase
import dev.kidremote.accounting.storage.LedgerRow
import dev.kidremote.child.IdentityStore
import java.io.File
import java.util.concurrent.Callable

/** No receipt/adapter success is manufactured on failure. Call off the UI thread. */
data class AccountingResult(val ledger:Ledger?,val storageFailure:Boolean=false,val unavailable:Boolean=false) {
    val restrictionRequired get()=storageFailure||unavailable||ledger?.restrictionRequired!=false
}
internal class ChildAccounting(private val context:Context):AutoCloseable {
    private val identity=IdentityStore(context)
    private val file=File(context.noBackupFilesDir,"accounting.db")
    private var database:LedgerDatabase?=null
    private var attached=false
    private fun db():LedgerDatabase=database?:Room.databaseBuilder(context,LedgerDatabase::class.java,file.absolutePath)
        .addMigrations(LedgerDatabase.MIGRATION_1_2).build().also{database=it}
    private fun epoch():String {
        val value=identity.read()?:error("IDENTITY_REQUIRED")
        check(!value.has("removal"));return value.getString("policy_epoch")
    }
    fun initialize(input:Policy,now:Sample,trustedUtc:Long):AccountingResult {
        return try {
            val bound=epoch();require(input.epoch==bound)
            val value=identity.read()!!
            if(value.optBoolean("accounting_initialized",false))return read()
            val created=Accounting.start(input,now,trustedUtc)
            // Durable uncertainty marker BEFORE first ledger mutation: a missing DB cannot mint a new allowance.
            value.put("accounting_initialized",true);identity.save(value)
            val state=db().runInTransaction(Callable {
                check(db().ledger().read()==null)
                db().ledger().write(LedgerRow().apply{payload=LedgerCodec.encode(created)})
                created
            })
            attached=true;AccountingResult(state)
        }catch(_:Exception){AccountingResult(null,storageFailure=true)}
    }
    fun read():AccountingResult=try {
        val bound=epoch()
        if(!file.exists())AccountingResult(null,storageFailure=identity.read()!!.optBoolean("accounting_initialized",false),unavailable=true)
        else {
            val row=db().ledger().read()?:error("LEDGER_MISSING")
            val state=LedgerCodec.decode(row.payload);check(state.policy.epoch==bound)
            AccountingResult(if(attached||state.uncertainty!=Uncertainty.NONE)state else state.copy(uncertainty=Uncertainty.HISTORY))
        }
    }catch(_:Exception){AccountingResult(null,storageFailure=true)}
    private fun update(reduce:(Ledger)->Ledger):AccountingResult {
        var last:Ledger?=null
        return try {
            val bound=epoch();check(file.exists())
            val state=db().runInTransaction(Callable {
                val row=db().ledger().read()?:error("LEDGER_MISSING")
                val previous=LedgerCodec.decode(row.payload);check(previous.policy.epoch==bound);last=previous
                val next=reduce(previous);next.validate();check(next.policy.epoch==bound)
                db().ledger().write(LedgerRow().apply{payload=LedgerCodec.encode(next);revision=Math.addExact(row.revision,1)})
                next
            })
            epoch();AccountingResult(state)
        }catch(_:Exception){attached=false;AccountingResult(last?.copy(uncertainty=Uncertainty.STORAGE),storageFailure=true)}
    }
    fun sample(now:Sample)=if(!attached)resume(now) else update{Accounting.sample(it,now)}
    fun resume(now:Sample)=update{Accounting.resume(it,now)}.also{attached=!it.storageFailure}
    fun acceptPolicy(input:Policy,now:Sample)=update{Accounting.snapshot(if(attached)it else Accounting.resume(it,now),input,now)}.also{attached=!it.storageFailure}
    fun reconcile(ranges:List<Range>,through:Sample,coverageProven:Boolean)=update{Accounting.reconcile(it,ranges,through,coverageProven)}.also{attached=!it.storageFailure}
    override fun close(){database?.close();database=null;attached=false}
}
internal object AndroidAccountingClock {
    fun sample(context:Context,permitted:Boolean):Sample {
        val boot=Settings.Global.getInt(context.contentResolver,Settings.Global.BOOT_COUNT,-1).toLong()
        val elapsed=SystemClock.elapsedRealtime();val uptime=SystemClock.uptimeMillis()
        val power=context.getSystemService(android.os.PowerManager::class.java)
        val guard=context.getSystemService(android.app.KeyguardManager::class.java)
        return Sample(boot,elapsed,uptime,Signals(power.isInteractive,guard.isKeyguardLocked,permitted))
    }
}

internal fun clearAccountingForValidatedRemoval(context:Context) {
    val file=File(context.noBackupFilesDir,"accounting.db")
    if(!file.exists())return
    val database=Room.databaseBuilder(context,LedgerDatabase::class.java,file.absolutePath).addMigrations(LedgerDatabase.MIGRATION_1_2).build()
    try{database.runInTransaction{database.ledger().clear()}}finally{database.close()}
}
