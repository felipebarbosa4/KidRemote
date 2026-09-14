package dev.kidremote.child.accounting
import android.os.Process
import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import androidx.test.platform.app.InstrumentationRegistry
import dev.kidremote.accounting.storage.LedgerDatabase
import dev.kidremote.child.IdentityStore
import java.io.File
import java.time.Instant
import java.util.UUID
import org.json.JSONObject
import org.junit.Test

/** Synthetic canonical inputs, actual Room/SQLite/Keystore and process death; no network/enforcement. */
class AccountingRuntimeTest {
    private val context get()=InstrumentationRegistry.getInstrumentation().targetContext
    private val file get()=File(context.noBackupFilesDir,"accounting.db")
    private val yes=Signals(true,false,true)
    private fun now(t:Long)=Sample(7,t,t,yes)
    private fun safe(action:()->Unit){try{action()}catch(error:Throwable){
        val line=error.stackTrace.firstOrNull{it.className.startsWith("dev.kidremote.child.accounting.")}?.lineNumber?:0
        result("ACCOUNTING_FAILURE_LINE_"+maxOf(0,line));throw AssertionError("ACCOUNTING_RUNTIME_FAILED")
    }}
    private fun checkSafe(v:Boolean){if(!v)throw AssertionError("ACCOUNTING_ASSERTION")}
    private fun result(code:String){InstrumentationRegistry.getInstrumentation().sendStatus(0,android.os.Bundle().apply{putString("kr008",code)})}
    private fun database()=Room.databaseBuilder(context,LedgerDatabase::class.java,file.absolutePath).addMigrations(LedgerDatabase.MIGRATION_1_2).build()
    private fun identity():JSONObject {
        val bytes=ByteArray(32).also{java.security.SecureRandom().nextBytes(it)}
        return JSONObject().put("device_id",UUID.randomUUID().toString()).put("policy_epoch",UUID.randomUUID().toString())
            .put("credential",java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(bytes))
    }
    private fun policy(epoch:String)=Policy(epoch,2,"Etc/UTC",1,"2026-09-13",3600,600,true)
    private fun prepare():Ledger {
        context.deleteDatabase(file.absolutePath)
        android.util.AtomicFile(File(context.noBackupFilesDir,"accounting-write-intent")).delete()
        val id=identity();IdentityStore(context).save(id)
        val policy=policy(id.getString("policy_epoch")).copy(manualLock=false)
        ChildAccounting(context).use { engine->
            checkSafe(!engine.initialize(policy,now(0),Instant.parse("2026-09-13T12:00:00Z").toEpochMilli()).storageFailure)
            val s=engine.sample(now(1000));checkSafe(s.ledger!!.usedMs==1000L)
            return s.ledger
        }
    }
    private fun persisted()=database().let{db->try{LedgerCodec.decode(db.ledger().read()!!.payload)}finally{db.close()}}
    private fun crashMarker(name:String){File(context.noBackupFilesDir,"accounting-crash").outputStream().use{it.write(name.toByteArray());it.fd.sync()};File(context.noBackupFilesDir,"accounting-pid").writeText(Process.myPid().toString());result(name)}
    @Test fun preparePersistence()=safe {
        val state=prepare();ChildAccounting(context).use{engine->
            val r=engine.acceptPolicy(state.policy.copy(version=3,manualLock=true),now(1000))
            checkSafe(r.ledger!!.usedMs==state.usedMs&&r.ledger.policy.manualLock&&r.restrictionRequired)
        }
        File(context.noBackupFilesDir,"accounting-pid").writeText(Process.myPid().toString())
        result("REAL_ROOM_INITIALIZED_AGGREGATE_PERSISTED_NO_NETWORK")
    }
    @Test fun restartAndReconcile()=safe {
        checkSafe(Process.myPid()!=File(context.noBackupFilesDir,"accounting-pid").readText().toInt())
        ChildAccounting(context).use { engine->
            val old=engine.read().ledger!!;checkSafe(old.usedMs==1000L&&old.policy.version==3L&&old.bonusSeconds==600L&&old.policy.manualLock)
            checkSafe(engine.acceptPolicy(old.policy.copy(version=4,manualLock=false),now(1000)).ledger!!.policy.version==4L)
            val gap=engine.resume(now(3000));checkSafe(gap.restrictionRequired&&gap.ledger!!.usedMs==1000L)
            val ranges=listOf(Range(7,0,2000,yes),Range(7,2000,3000,yes.copy(interactive=false)))
            val done=engine.reconcile(ranges,now(3000),true);checkSafe(done.ledger!!.usedMs==2000L)
            checkSafe(engine.reconcile(ranges,now(3000),true).ledger!!.usedMs==2000L)
        }
        result("REAL_PROCESS_RESTART_UNCOVERED_SUFFIX_ONCE")
    }
    @Test fun migrationAndRefusedDowngrade()=safe {
        val original=prepare();val bytes=LedgerCodec.encode(original)
        context.deleteDatabase(file.absolutePath)
        SQLiteDatabase.openOrCreateDatabase(file,null).use{db->
            db.execSQL("CREATE TABLE ledger (id INTEGER NOT NULL PRIMARY KEY,payload BLOB NOT NULL)")
            db.execSQL("INSERT INTO ledger VALUES(1,?)",arrayOf(bytes));db.version=1
        }
        checkSafe(persisted()==original)
        SQLiteDatabase.openDatabase(file.absolutePath,null,SQLiteDatabase.OPEN_READWRITE).use{it.version=3}
        ChildAccounting(context).use{checkSafe(it.read().storageFailure&&it.initialize(original.policy,now(0),0).restrictionRequired)}
        SQLiteDatabase.openDatabase(file.absolutePath,null,SQLiteDatabase.OPEN_READWRITE).use{db->checkSafe(db.version==3);db.version=2}
        checkSafe(persisted()==original)
        result("REAL_SQLITE_V1_V2_MIGRATION_PRESERVED_DOWNGRADE_REFUSED")
    }
    @Test fun crashBeforeCommit() {
        prepare();val db=database()
        db.runInTransaction {
            val row=db.ledger().read()!!;row.payload=LedgerCodec.encode(LedgerCodec.decode(row.payload).copy(usedMs=2000,cursor=2000,uptime=2000))
            db.ledger().write(row);crashMarker("EXPECTED_KILL_BEFORE_COMMIT");Process.killProcess(Process.myPid())
            error("KILL_DID_NOT_TERMINATE")
        }
    }
    @Test fun afterUncommittedCrash()=safe {
        checkSafe(Process.myPid()!=File(context.noBackupFilesDir,"accounting-pid").readText().toInt())
        checkSafe(persisted().usedMs==1000L);result("REAL_KILL_UNCOMMITTED_TRANSACTION_ROLLED_BACK")
    }
    @Test fun crashAfterCommit() {
        ChildAccounting(context).use{val r=it.reconcile(listOf(Range(7,1000,2000,yes)),now(2000),true);checkSafe(!r.storageFailure&&r.ledger!!.usedMs==2000L)}
        crashMarker("EXPECTED_KILL_AFTER_COMMIT");Process.killProcess(Process.myPid());error("KILL_DID_NOT_TERMINATE")
    }
    @Test fun afterCommittedCrash()=safe {
        checkSafe(Process.myPid()!=File(context.noBackupFilesDir,"accounting-pid").readText().toInt());val s=persisted()
        checkSafe(s.usedMs==2000L&&s.cursor==2000L&&s.policy.version==2L&&s.bonusSeconds==600L)
        result("REAL_KILL_COMMITTED_AGGREGATE_AND_CURSOR_SURVIVE")
    }
    @Test fun writeFailureAndCorruption()=safe {
        val before=persisted()
        database().let{db->try{db.openHelper.writableDatabase.execSQL("CREATE TRIGGER fail_ledger BEFORE INSERT ON ledger BEGIN SELECT RAISE(ABORT,'SYNTHETIC_WRITE_FAILURE'); END")}finally{db.close()}}
        ChildAccounting(context).use{engine->val r=engine.reconcile(listOf(Range(7,2000,3000,yes)),now(3000),true);checkSafe(r.storageFailure&&r.restrictionRequired&&r.ledger!!.usedMs==before.usedMs)}
        checkSafe(persisted()==before)
        database().let{db->try{db.openHelper.writableDatabase.execSQL("DROP TRIGGER fail_ledger");db.openHelper.writableDatabase.execSQL("UPDATE ledger SET payload=X'01'")}finally{db.close()}}
        ChildAccounting(context).use{checkSafe(it.read().storageFailure&&it.initialize(before.policy,now(0),0).storageFailure)}
        database().let{db->try{checkSafe(db.ledger().read()!!.payload.contentEquals(byteArrayOf(1)))}finally{db.close()}}
        result("REAL_WRITE_FAILURE_AND_CORRUPTION_NO_RESET_NO_FREE_ALLOWANCE")
    }
    @Test fun concurrentSuffixAndIdentityBoundary()=safe {
        prepare()
        val pool=java.util.concurrent.Executors.newFixedThreadPool(2)
        try {
            val tasks=(1..2).map{pool.submit<Boolean>{ChildAccounting(context).use{e->!e.reconcile(listOf(Range(7,0,2000,yes)),now(2000),true).storageFailure}}}
            checkSafe(tasks.all{it.get()});checkSafe(persisted().usedMs==2000L)
        }finally{pool.shutdownNow()}
        val store=IdentityStore(context);val id=store.read()!!;id.put("expires_at","2000-01-01T00:00:00Z");store.save(id)
        ChildAccounting(context).use{checkSafe(it.read().ledger!!.usedMs==2000L)} // expiry is not a policy lease
        val foreign=policy(UUID.randomUUID().toString())
        ChildAccounting(context).use{checkSafe(it.acceptPolicy(foreign,now(2000)).storageFailure)}
        checkSafe(persisted().usedMs==2000L)
        // Validated-removal shape supplied only as local fixture; not network-removal evidence.
        id.put("removal",JSONObject().put("protocol_version",1).put("code","DEVICE_REVOKED").put("device_id",id.getString("device_id")).put("policy_epoch",id.getString("policy_epoch")));store.save(id)
        ChildAccounting(context).use{checkSafe(it.read().restrictionRequired)}
        checkSafe(store.clearConfirmedRemoval())
        database().let{db->try{checkSafe(db.ledger().read()==null)}finally{db.close()}}
        result("REAL_CONCURRENT_SUFFIX_IDENTITY_EXPIRY_AND_REMOVAL_BOUNDARY")
    }
    @Test fun missingDatabaseAndSignals()=safe {
        val s=prepare();context.deleteDatabase(file.absolutePath)
        ChildAccounting(context).use{checkSafe(it.initialize(s.policy,now(0),0).storageFailure)}
        val actual=AndroidAccountingClock.sample(context,false);checkSafe(actual.boot>=0&&actual.elapsed>=actual.uptime&&!actual.signals.permitted)
        val utc=System.currentTimeMillis()
        val query=UsageHistoryProbe.query(context,utc-1000,utc,actual.elapsed-1000,true)
        checkSafe(!query.coverageProven)
        checkSafe(UsageHistoryProbe.query(context,utc-1000,utc,actual.elapsed,false).events.isEmpty())
        result("MISSING_DB_FAILS_CLOSED_OS_SIGNALS_USAGE_HISTORY_UNVERIFIED")
    }
}
