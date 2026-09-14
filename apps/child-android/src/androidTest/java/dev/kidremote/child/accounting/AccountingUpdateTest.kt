package dev.kidremote.child.accounting

import android.database.sqlite.SQLiteDatabase
import android.os.Process
import androidx.room.Room
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.test.platform.app.InstrumentationRegistry
import dev.kidremote.accounting.storage.LedgerDatabase
import dev.kidremote.child.IdentityStore
import java.io.File
import java.security.MessageDigest
import java.time.Instant
import java.util.UUID
import org.json.JSONObject
import org.junit.Test

/** Only local fixture digests are retained as test oracles; no policy/identity contents leave the app. */
class AccountingUpdateTest {
    private val context get()=InstrumentationRegistry.getInstrumentation().targetContext
    private val file get()=File(context.noBackupFilesDir,"accounting.db")
    private val oracleFile get()=File(context.noBackupFilesDir,"update-oracle")
    private val countFile get()=File(context.noBackupFilesDir,"update-migration-attempts")
    private val yes=Signals(true,false,true)
    private fun now(t:Long)=Sample(7,t,t,yes)
    private fun digest(bytes:ByteArray)=MessageDigest.getInstance("SHA-256").digest(bytes).joinToString(""){"%02x".format(it)}
    private fun checkSafe(value:Boolean){if(!value)throw AssertionError("UPDATE_ASSERTION")}
    private fun result(code:String){InstrumentationRegistry.getInstrumentation().sendStatus(0,android.os.Bundle().apply{putString("kr008",code)})}
    private fun safe(action:()->Unit){try{action()}catch(e:Throwable){val line=e.stackTrace.firstOrNull{it.className.contains("AccountingUpdateTest")&&it.methodName!="checkSafe"}?.lineNumber?:0;result("UPDATE_FAILURE_LINE_"+maxOf(0,line));throw AssertionError("UPDATE_RUNTIME_FAILED")}}
    private fun write(file:File,value:String){val atomic=android.util.AtomicFile(file);val stream=atomic.startWrite();try{stream.write(value.toByteArray());atomic.finishWrite(stream)}catch(e:Exception){atomic.failWrite(stream);throw e}}
    private fun oracle()=JSONObject(oracleFile.readText())
    private fun version()=context.packageManager.getPackageInfo(context.packageName,0).longVersionCode
    private fun raw()=SQLiteDatabase.openDatabase(file.absolutePath,null,SQLiteDatabase.OPEN_READWRITE)
    private fun schema()=raw().use{it.version}
    private fun revisionColumn()=raw().use{db->db.rawQuery("PRAGMA table_info(ledger)",null).use{c->var found=false;while(c.moveToNext())if(c.getString(1)=="revision")found=true;found}}
    private fun payload()=raw().use{db->db.rawQuery("SELECT payload FROM ledger WHERE id=1",null).use{c->checkSafe(c.moveToFirst());c.getBlob(0)}}
    private fun rowRevision()=if(revisionColumn())raw().use{db->db.rawQuery("SELECT revision FROM ledger WHERE id=1",null).use{c->checkSafe(c.moveToFirst());c.getLong(0)}} else 0L
    private fun rowCount()=raw().use{db->db.rawQuery("SELECT count(*) FROM ledger",null).use{c->c.moveToFirst();c.getInt(0)}}
    private fun verifyIdentity() {
        val store=IdentityStore(context);val id=store.read()!!
        checkSafe(digest(store.file.readBytes())==oracle().getString("identity_digest"))
        checkSafe(id.getBoolean("accounting_initialized")&&id.getString("policy_epoch")==LedgerCodec.decode(payload()).policy.epoch)
        checkSafe(Process.myUid()==oracle().getInt("uid"))
    }
    private fun unchanged(expectedSchema:Int) {
        checkSafe(version()==2L&&schema()==expectedSchema&&rowCount()==1)
        checkSafe(Process.myPid()!=oracle().getInt("pid"))
        checkSafe(digest(payload())==oracle().getString("payload_digest")&&rowRevision()==oracle().getLong("revision"))
        verifyIdentity()
    }
    private fun prepare(legacy:Boolean) {
        checkSafe(version()==1L&&!oracleFile.exists()&&!file.exists()&&IdentityStore(context).read()==null)
        val credential=ByteArray(32).also{java.security.SecureRandom().nextBytes(it)}
        val id=JSONObject().put("device_id",UUID.randomUUID().toString()).put("policy_epoch",UUID.randomUUID().toString())
            .put("credential",java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(credential))
        val store=IdentityStore(context);store.save(id)
        val p=Policy(id.getString("policy_epoch"),6,"America/Toronto",3,"2026-09-13",3600,600,false)
        ChildAccounting(context).use{engine->
            checkSafe(!engine.initialize(p,now(0),Instant.parse("2026-09-13T16:00:00Z").toEpochMilli()).storageFailure)
            checkSafe(engine.sample(now(120000)).ledger!!.usedMs==120000L)
            checkSafe(!engine.acceptPolicy(p.copy(version=7,manualLock=true),now(120000)).storageFailure)
            checkSafe(engine.resume(now(125000)).ledger!!.uncertainty==Uncertainty.HISTORY)
        }
        if(legacy) {
            // Existing legacy schema fixture, created before APK replacement; not a shipped v1 app claim.
            val bytes=payload();checkSafe(context.deleteDatabase(file.absolutePath))
            SQLiteDatabase.openOrCreateDatabase(file,null).use{db->db.beginTransaction();try{
                db.execSQL("CREATE TABLE ledger (id INTEGER NOT NULL PRIMARY KEY,payload BLOB NOT NULL)")
                db.execSQL("INSERT INTO ledger VALUES(1,?)",arrayOf(bytes));db.version=1;db.setTransactionSuccessful()
            }finally{db.endTransaction()}}
        }
        val s=LedgerCodec.decode(payload())
        checkSafe(s.usedMs==120000L&&s.policy.version==7L&&s.bonusSeconds==600L&&s.policy.dailyLimitSeconds==3600L&&s.policy.manualLock)
        checkSafe(s.periodKey=="3:2026-09-13"&&s.cursor==120000L&&s.uncertainty==Uncertainty.HISTORY)
        write(oracleFile,JSONObject().put("payload_digest",digest(payload())).put("identity_digest",digest(store.file.readBytes()))
            .put("revision",rowRevision()).put("pid",Process.myPid()).put("uid",Process.myUid()).put("schema",schema()).toString())
        write(countFile,"0");result(if(legacy)"PRE_UPDATE_V1_LEGACY_SCHEMA1_PREPARED" else "PRE_UPDATE_V1_SCHEMA2_PREPARED")
    }
    @Test fun prepareCurrent()=safe{prepare(false)}
    @Test fun prepareLegacy()=safe{prepare(true)}
    @Test fun verifyReplacement()=safe {
        unchanged(oracle().getInt("schema"))
        result("APK_V2_REPLACED_V1_UID_IDENTITY_AND_AGGREGATE_UNCHANGED")
    }
    private fun openObserved(kill:Boolean=false) {
        val migration=object:Migration(1,2) {
            override fun migrate(db:SupportSQLiteDatabase) {
                checkSafe(db.inTransaction())
                write(countFile,(countFile.readText().toInt()+1).toString())
                LedgerDatabase.MIGRATION_1_2.migrate(db) // exact production migration; Room still validates/commits
                if(kill) {
                    write(File(context.noBackupFilesDir,"update-crash"),"EXPECTED_KILL_DURING_MIGRATION")
                    result("EXPECTED_KILL_DURING_MIGRATION");Process.killProcess(Process.myPid());error("KILL_FAILED")
                }
            }
        }
        val db=Room.databaseBuilder(context,LedgerDatabase::class.java,file.absolutePath).addMigrations(migration).build()
        try{db.openHelper.writableDatabase;checkSafe(db.ledger().read()!=null)}finally{db.close()}
    }
    @Test fun refuseMissingMigration()=safe {
        unchanged(1)
        val db=Room.databaseBuilder(context,LedgerDatabase::class.java,file.absolutePath).build()
        try{val failure=runCatching{db.openHelper.writableDatabase}.exceptionOrNull();checkSafe(failure is IllegalStateException&&failure.message?.contains("migration",ignoreCase=true)==true)}finally{db.close()}
        unchanged(1);checkSafe(!revisionColumn());result("ROOM_MISSING_PATH_REFUSED_SCHEMA_AND_DATA_RETAINED")
    }
    @Test fun killDuringMigration(){unchanged(1);openObserved(true);error("EXPECTED_KILL_MISSING")}
    @Test fun verifyMigrationRollback()=safe {
        unchanged(1);checkSafe(!revisionColumn()&&countFile.readText()=="1")
        result("MIGRATION_PROCESS_DEATH_ROLLED_BACK_SCHEMA_AND_LEDGER")
    }
    @Test fun completeMigrationAndReopen()=safe {
        checkSafe(schema()==1&&countFile.readText()=="1")
        openObserved();unchanged(2);checkSafe(countFile.readText()=="2"&&revisionColumn())
        repeat(3){openObserved();unchanged(2);checkSafe(countFile.readText()=="2")}
        ChildAccounting(context).use{checkSafe(!it.read().storageFailure)}
        result("ONE_COMMITTED_MIGRATION_AFTER_ROLLBACK_REOPEN_NO_REPLAY")
    }
    @Test fun currentSchemaNeedsNoMigration()=safe {
        unchanged(2);repeat(3){openObserved();unchanged(2)}
        checkSafe(countFile.readText()=="0");result("CURRENT_SCHEMA_UPDATE_NO_MIGRATION_NO_RESET")
    }
    @Test fun reconcileAfterUpdate()=safe {
        unchanged(2)
        val before=LedgerCodec.decode(payload())
        ChildAccounting(context).use { engine->
            checkSafe(engine.read().ledger==before&&engine.read().restrictionRequired)
            val covered=listOf(Range(7,0,120000,yes),Range(7,120000,125000,yes.copy(permitted=false)))
            val recovered=engine.reconcile(covered,now(125000),true).ledger!!
            checkSafe(recovered==before.copy(uncertainty=Uncertainty.NONE,cursor=125000,uptime=125000,recoveryThrough=0))
            checkSafe(engine.reconcile(covered,now(125000),true).ledger==recovered)
            val unlocked=engine.acceptPolicy(before.policy.copy(version=8,manualLock=false),now(125000)).ledger!!
            val n=engine.reconcile(listOf(Range(7,0,126000,yes)),now(126000),true).ledger!!
            checkSafe(n.usedMs==121000L&&n.cursor==126000L&&n.policy==unlocked.policy)
            checkSafe(engine.reconcile(listOf(Range(7,0,126000,yes)),now(126000),true).ledger==n)
        }
        verifyIdentity()
        write(oracleFile,oracle().put("payload_digest",digest(payload())).put("revision",rowRevision()).toString())
        result("POST_UPDATE_COVERED_INTERVAL_ZERO_DUPLICATE_SUFFIX_COUNTED_ONCE")
    }
    @Test fun verifyRefusedApkDowngrade()=safe {
        unchanged(2)
        // Only expected ledger/Room metadata tables; no package or raw usage-event storage.
        raw().use{db->db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'",null).use{c->while(c.moveToNext())checkSafe(c.getString(0) in setOf("ledger","room_master_table","android_metadata","sqlite_sequence"))}}
        result("APK_DOWNGRADE_REFUSED_V2_IDENTITY_DATA_AND_AGGREGATE_SCHEMA_INTACT")
    }
}
