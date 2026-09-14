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
private val accountingLock=Any() // Existing child uses one process; serialize all facade instances and intent cleanup.
internal class ChildAccounting(private val context:Context):AutoCloseable {
    private val identity=IdentityStore(context)
    private val file=File(context.noBackupFilesDir,"accounting.db")
    private val pending=android.util.AtomicFile(File(context.noBackupFilesDir,"accounting-write-intent"))
    private var database:LedgerDatabase?=null
    private var attached=false
    private fun db():LedgerDatabase=database?:Room.databaseBuilder(context,LedgerDatabase::class.java,file.absolutePath)
        .addMigrations(LedgerDatabase.MIGRATION_1_2).build().also{database=it}
    private fun epoch():String {
        val value=identity.read()?:error("IDENTITY_REQUIRED")
        check(!value.has("removal"));return value.getString("policy_epoch")
    }
    private fun guarded(row:LedgerRow,bound:String):Ledger {
        val s=LedgerCodec.decode(row.payload);check(s.policy.epoch==bound)
        if(!pending.baseFile.exists()&&!File(pending.baseFile.path+".bak").exists())return s
        val p=RecoveryIntent.decode(pending.readFully());check(p.epoch==bound)
        // A committed Room revision proves the complete mutation survived a crash before intent cleanup.
        if(row.revision==Math.addExact(p.revision,1))return s
        check(row.revision==p.revision&&p.boot==s.boot&&p.through>=s.cursor)
        return s.copy(uncertainty=if(p.clock||s.uncertainty==Uncertainty.CLOCK)Uncertainty.CLOCK else Uncertainty.STORAGE,
            recoveryThrough=maxOf(s.recoveryThrough,p.through),observedBoot=maxOf(s.observedBoot,p.observedBoot))
    }
    private fun intent(value:RecoveryIntent) {
        val bytes=value.encode();val out=pending.startWrite()
        try{out.write(bytes);out.fd.sync();pending.finishWrite(out)}catch(e:Exception){pending.failWrite(out);throw e}
        check(pending.readFully().contentEquals(bytes))
    }
    fun initialize(input:Policy,now:Sample,trustedUtc:Long,prepare:(Ledger)->Ledger={it}):AccountingResult=synchronized(accountingLock) {
        try {
            val bound=epoch();require(input.epoch==bound)
            val value=identity.read()!!
            if(value.optBoolean("accounting_initialized",false))return@synchronized read()
            val created=prepare(Accounting.start(input,now,trustedUtc)).also{it.validate()}
            value.put("accounting_initialized",true);identity.save(value)
            val state=db().runInTransaction(Callable {
                check(db().ledger().read()==null&&!pending.baseFile.exists())
                db().ledger().write(LedgerRow().apply{payload=LedgerCodec.encode(created)})
                created
            })
            attached=true;AccountingResult(state)
        }catch(_:Exception){attached=false;AccountingResult(null,storageFailure=true)}
    }
    fun read():AccountingResult=synchronized(accountingLock) { try {
        val bound=epoch()
        if(!file.exists())AccountingResult(null,storageFailure=identity.read()!!.optBoolean("accounting_initialized",false),unavailable=true)
        else {
            val row=db().ledger().read()?:error("LEDGER_MISSING")
            val state=guarded(row,bound)
            AccountingResult(if(attached||state.uncertainty!=Uncertainty.NONE)state else state.copy(uncertainty=Uncertainty.HISTORY))
        }
    }catch(_:Exception){attached=false;AccountingResult(null,storageFailure=true)} }
    private fun update(now:Sample,reduce:(Ledger)->Ledger):AccountingResult=synchronized(accountingLock) {
        var last:Ledger?=null
        try {
            val bound=epoch();check(file.exists())
            val state=db().runInTransaction(Callable {
                val row=db().ledger().read()?:error("LEDGER_MISSING")
                val stored=guarded(row,bound)
                val previous=if(!attached&&stored.uncertainty==Uncertainty.NONE)Accounting.uncertain(stored,now) else stored;last=previous
                val risk=Accounting.uncertain(previous,now,Uncertainty.STORAGE)
                intent(RecoveryIntent(bound,row.revision,previous.boot,maxOf(previous.cursor,risk.recoveryThrough),risk.uncertainty==Uncertainty.CLOCK,risk.observedBoot))
                val next=reduce(previous);next.validate();check(next.policy.epoch==bound)
                db().ledger().write(LedgerRow().apply{payload=LedgerCodec.encode(next);revision=Math.addExact(row.revision,1)})
                AccountingFaults.beforeRecoveryCommit()
                next
            })
            AccountingFaults.afterRecoveryCommit()
            pending.delete();check(!pending.baseFile.exists());epoch();AccountingResult(state)
        }catch(_:Exception){attached=false;AccountingResult(last?.let{Accounting.uncertain(it,now,Uncertainty.STORAGE)},storageFailure=true)}
    }
    fun sample(now:Sample)=synchronized(accountingLock) { if(!attached)resume(now) else update(now){Accounting.sample(it,now)} }
    fun resume(now:Sample)=synchronized(accountingLock) { update(now){Accounting.resume(it,now)}.also{attached=!it.storageFailure} }
    fun acceptPolicy(input:Policy,now:Sample)=synchronized(accountingLock) { update(now){Accounting.snapshot(if(attached)it else Accounting.resume(it,now),input,now)}.also{attached=!it.storageFailure} }
    fun reconcile(ranges:List<Range>,through:Sample,coverageProven:Boolean)=synchronized(accountingLock) { update(through){Accounting.reconcile(it,ranges,through,coverageProven)}.also{attached=!it.storageFailure;syncAfterRecovery(it)} }
    private fun syncAfterRecovery(result:AccountingResult){if(!result.storageFailure&&result.ledger?.uncertainty==Uncertainty.NONE&&dev.kidremote.child.sync.SyncFaults.automaticAllowed(context))dev.kidremote.child.sync.SyncRecovery.postLocalRecovery(context)}
    fun recoverTrustedTime(input:TrustedTime)=synchronized(accountingLock) { update(input.at){Accounting.recoverTrustedTime(if(attached)it else Accounting.resume(it,input.at),input)}.also{attached=!it.storageFailure;syncAfterRecovery(it)} }
    fun applySnapshot(input:Policy,now:Sample,trustedUtc:Long,receipt:(Ledger)->String):AccountingResult=synchronized(accountingLock) {
        fun queued(s:Ledger):Ledger {
            check(s.pendingAck==null)
            val next=s.copy(reportSequence=Math.addExact(s.reportSequence,1))
            return next.copy(pendingAck=receipt(next)).also{it.validate()}
        }
        if(!identity.read()!!.optBoolean("accounting_initialized",false))initialize(input,now,trustedUtc){queued(it)}
        else update(now){check(it.pendingAck==null);queued(SyncMerge.accept(it,input,now,trustedUtc))}.also{attached=!it.storageFailure}
    }
    fun queueObservation(now:Sample,accept:(Ledger)->Boolean,receipt:(Ledger)->String):AccountingResult=synchronized(accountingLock) {
        val current=read()
        if(current.storageFailure||current.ledger==null||current.ledger.pendingAck!=null||!accept(current.ledger))return@synchronized current
        update(now){s->check(accept(s));val next=s.copy(reportSequence=Math.addExact(s.reportSequence,1));next.copy(pendingAck=receipt(next))}
    }
    fun confirmReport(sequence:Long,now:Sample)=synchronized(accountingLock) {
        update(now){check(it.reportSequence==sequence&&it.pendingAck!=null);it.copy(pendingAck=null)}.also{attached=!it.storageFailure}
    }
    override fun close()=synchronized(accountingLock){database?.close();database=null;attached=false}
}
internal object AndroidAccountingClock {
    fun sample(context:Context,permitted:Boolean):Sample {
        val boot=Settings.Global.getInt(context.contentResolver,Settings.Global.BOOT_COUNT,-1).toLong()
        var elapsed:Long;var uptime:Long
        do {elapsed=SystemClock.elapsedRealtime();uptime=SystemClock.uptimeMillis()}while(elapsed!=SystemClock.elapsedRealtime())
        val power=context.getSystemService(android.os.PowerManager::class.java)
        val guard=context.getSystemService(android.app.KeyguardManager::class.java)
        return Sample(boot,elapsed,uptime,Signals(power.isInteractive,guard.isKeyguardLocked,permitted))
    }
}

internal fun clearAccountingForValidatedRemoval(context:Context)=synchronized(accountingLock) {
    val file=File(context.noBackupFilesDir,"accounting.db")
    if(!file.exists())return@synchronized
    val database=Room.databaseBuilder(context,LedgerDatabase::class.java,file.absolutePath).addMigrations(LedgerDatabase.MIGRATION_1_2).build()
    try{database.runInTransaction{database.ledger().clear()};android.util.AtomicFile(File(context.noBackupFilesDir,"accounting-write-intent")).delete()}finally{database.close()}
}
