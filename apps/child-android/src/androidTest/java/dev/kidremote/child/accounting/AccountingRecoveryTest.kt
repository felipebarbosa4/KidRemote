package dev.kidremote.child.accounting

import android.os.Process
import androidx.room.Room
import androidx.test.platform.app.InstrumentationRegistry
import dev.kidremote.accounting.storage.LedgerDatabase
import dev.kidremote.child.IdentityStore
import java.io.File
import java.time.Instant
import java.util.UUID
import org.json.JSONObject
import org.junit.Test

/** Local canonical fixtures; real encrypted identity, Room, failed writes and process kills. */
class AccountingRecoveryTest {
    private val context get()=InstrumentationRegistry.getInstrumentation().targetContext
    private val file get()=File(context.noBackupFilesDir,"accounting.db")
    private val intent get()=android.util.AtomicFile(File(context.noBackupFilesDir,"accounting-write-intent"))
    private val yes=Signals(true,false,true)
    private fun at(t:Long,boot:Long=7)=Sample(boot,t,t,yes)
    private fun result(code:String){InstrumentationRegistry.getInstrumentation().sendStatus(0,android.os.Bundle().apply{putString("kr008",code)})}
    private fun ck(v:Boolean){if(!v)throw AssertionError("RECOVERY_ASSERTION")}
    private fun safe(action:()->Unit){try{action()}catch(error:Throwable){
        val line=error.stackTrace.firstOrNull{it.className.startsWith("dev.kidremote.child.accounting.")}?.lineNumber?:0
        result("RECOVERY_FAILURE_LINE_"+maxOf(0,line));throw AssertionError("RECOVERY_RUNTIME_FAILED")
    }}
    private fun db()=Room.databaseBuilder(context,LedgerDatabase::class.java,file.absolutePath).addMigrations(LedgerDatabase.MIGRATION_1_2).build()
    private fun raw()=db().let{d->try{LedgerCodec.decode(d.ledger().read()!!.payload)}finally{d.close()}}
    private fun sql(statement:String)=db().let{d->try{d.openHelper.writableDatabase.execSQL(statement)}finally{d.close()}}
    private fun prepare(lock:Boolean=false):Ledger {
        context.deleteDatabase(file.absolutePath);intent.delete()
        val bytes=ByteArray(32).also{java.security.SecureRandom().nextBytes(it)}
        val id=JSONObject().put("device_id",UUID.randomUUID().toString()).put("policy_epoch",UUID.randomUUID().toString())
            .put("credential",java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(bytes))
        IdentityStore(context).save(id)
        val p=Policy(id.getString("policy_epoch"),7,"America/Toronto",3,"2026-09-13",3600,600,false)
        ChildAccounting(context).use{e->
            ck(!e.initialize(p,at(0),Instant.parse("2026-09-13T16:00:00Z").toEpochMilli()).storageFailure)
            ck(e.sample(at(1000)).ledger!!.usedMs==1000L)
            if(lock)ck(!e.acceptPolicy(p.copy(version=8,manualLock=true),at(1000)).storageFailure)
        }
        return raw()
    }
    private fun trust(s:Ledger,date:String="2026-09-14T04:00:00Z",sample:Sample=at(4000))=
        TrustedTime(s.policy.epoch,s.policy.zone,s.policy.zoneRevision,Instant.parse(date).toEpochMilli(),sample)
    private fun pid(){File(context.noBackupFilesDir,"recovery-pid").writeText(Process.myPid().toString())}
    private fun restarted(){ck(Process.myPid()!=File(context.noBackupFilesDir,"recovery-pid").readText().toInt())}
    private fun kill(code:String){File(context.noBackupFilesDir,"recovery-crash").outputStream().use{it.write(code.toByteArray());it.fd.sync()};pid();result(code);Process.killProcess(Process.myPid());error("KILL_FAILED")}
    @Test fun completeAndIncompleteRecovery()=safe {
        val old=prepare()
        ChildAccounting(context).use{e->
            val gap=e.resume(at(3000)).ledger!!;ck(gap.usedMs==old.usedMs&&gap.recoveryThrough==3000L)
            val partial=e.reconcile(listOf(Range(7,1000,2000,yes)),at(3000),true);ck(partial.ledger==gap&&partial.restrictionRequired)
            ck(e.reconcile(listOf(Range(7,1000,3000,yes),Range(7,2000,3000,yes.copy(keyguard=true))),at(3000),true).ledger==gap)
            ck(e.reconcile(emptyList(),at(1000),true).ledger==gap)
            val ranges=listOf(Range(7,0,2000,yes),Range(7,2000,3000,yes.copy(interactive=false)))
            val done=e.reconcile(ranges,at(3000),true);ck(!done.storageFailure&&done.ledger!!.usedMs==2000L&&!done.restrictionRequired)
            ck(e.reconcile(ranges.reversed(),at(3000),true).ledger==done.ledger);ck(raw()==done.ledger)
        };result("ROOM_COMPLETE_SUFFIX_ONLY_ONCE_PARTIAL_CONTRADICTION_RESTRICTED")
    }
    @Test fun prepareStorageFailure()=safe {
        val old=prepare();sql("CREATE TRIGGER fail_recovery BEFORE INSERT ON ledger BEGIN SELECT RAISE(ABORT,'SYNTHETIC_RECOVERY_WRITE_FAILURE'); END")
        ChildAccounting(context).use{e->val r=e.resume(at(3000));ck(r.storageFailure&&r.restrictionRequired)}
        ck(raw()==old&&intent.baseFile.exists());sql("DROP TRIGGER fail_recovery");pid()
        result("ROOM_WRITE_ABORT_PRESERVED_LEDGER_DURABLE_INTENT")
    }
    @Test fun restartStorageRecovery()=safe {
        restarted();ChildAccounting(context).use{e->
            val old=e.read().ledger!!;ck(old.uncertainty==Uncertainty.STORAGE&&old.recoveryThrough==3000L)
            val same=e.resume(at(3000));ck(same.restrictionRequired&&same.ledger!!.usedMs==1000L)
            val clock=e.recoverTrustedTime(trust(old,"2026-09-13T20:00:00Z",at(3000)));ck(clock.restrictionRequired)
            ck(e.reconcile(emptyList(),at(1000),true).restrictionRequired)
            val done=e.reconcile(listOf(Range(7,1000,3000,yes)),at(3000),true)
            ck(!done.storageFailure&&!done.restrictionRequired&&done.ledger!!.usedMs==3000L&&!intent.baseFile.exists())
        };result("WRITABLE_RESTART_STAYS_UNCERTAIN_UNTIL_FULL_SUFFIX")
    }
    @Test fun trustedPeriodRecovery()=safe {
        val old=prepare(true);ChildAccounting(context).use{e->
            ck(e.resume(at(10,8)).ledger!!.uncertainty==Uncertainty.CLOCK)
            ck(e.reconcile(listOf(Range(8,0,100,yes)),at(100,8),true).ledger!!.usedMs==old.usedMs)
            val same=e.recoverTrustedTime(trust(old,"2026-09-13T20:00:00Z",at(100,8)));ck(same.restrictionRequired&&same.ledger!!.date==old.date)
            val input=trust(old,"2026-09-30T04:00:00Z",at(200,8));val next=e.recoverTrustedTime(input).ledger!!
            ck(next.date=="2026-09-30"&&next.usedMs==0L&&next.bonusSeconds==0L&&next.policy==old.policy&&next.policy.manualLock)
            ck(next.boot==8L&&next.cursor==200L&&next.anchorUtc==input.utcMillis&&next.anchorElapsed==200L&&next.uncertainty==Uncertainty.NONE)
            ck(e.recoverTrustedTime(input).ledger==next);ck(raw()==next)
        };result("TRUSTED_NEW_PERIOD_ONCE_REBOOT_SKIPPED_DATES_LOCK_POLICY_PRESERVED")
    }
    @Test fun killBeforeRecoveryCommit() {
        val old=prepare(true);ChildAccounting(context).use{e->
            ck(e.resume(at(3000)).restrictionRequired)
            AccountingFaults.beforeRecoveryCommit={kill("EXPECTED_KILL_RECOVERY_BEFORE_COMMIT")}
            e.recoverTrustedTime(trust(old));error("KILL_NOT_REACHED")
        }
    }
    @Test fun afterRecoveryRollback()=safe {
        restarted();val old=raw();ck(old.date=="2026-09-13"&&old.usedMs==1000L&&old.bonusSeconds==600L&&old.policy.manualLock)
        ck(old.cursor==1000L&&old.anchorElapsed==0L&&old.recoveryThrough==3000L&&old.uncertainty==Uncertainty.HISTORY)
        ChildAccounting(context).use{e->val state=e.read();ck(state.restrictionRequired&&state.ledger!!.recoveryThrough==4000L&&state.ledger.uncertainty==Uncertainty.STORAGE)}
        result("REAL_RECOVERY_KILL_ROLLED_BACK_NO_HYBRID_INTENT_RESTRICTS")
    }
    @Test fun killAfterRecoveryCommit() {
        ChildAccounting(context).use{e->val old=e.read().ledger!!
            AccountingFaults.afterRecoveryCommit={kill("EXPECTED_KILL_RECOVERY_AFTER_COMMIT")}
            e.recoverTrustedTime(trust(old));error("KILL_NOT_REACHED")
        }
    }
    @Test fun afterRecoveryCommit()=safe {
        restarted();val s=raw();ck(s.date=="2026-09-14"&&s.usedMs==0L&&s.bonusSeconds==0L&&s.policy.manualLock&&s.policy.version==8L)
        ck(s.cursor==4000L&&s.anchorElapsed==4000L&&s.recoveryThrough==0L&&s.uncertainty==Uncertainty.NONE)
        ck(intent.baseFile.exists());val identity=IdentityStore(context).read()!!;ck(s.policy.epoch==identity.getString("policy_epoch"))
        ChildAccounting(context).use{e->
            ck(!e.read().storageFailure)
            val done=e.reconcile(emptyList(),at(4000),true);ck(done.ledger==s&&!done.storageFailure&&!intent.baseFile.exists())
            ck(e.recoverTrustedTime(trust(s)).ledger==s)
        };result("REAL_RECOVERY_COMMIT_SURVIVES_KILL_COMPLETE_ANCHOR_IDENTITY_NO_SECOND_RESET")
    }
    @Test fun corruptRecoveryFailsClosed()=safe {
        val old=prepare();ChildAccounting(context).use{e->
            ck(e.resume(at(3000)).restrictionRequired)
            val bad=e.recoverTrustedTime(trust(old).copy(epoch="foreign"));ck(bad.restrictionRequired&&bad.ledger!!.usedMs==old.usedMs&&bad.ledger.date==old.date)
        }
        val before=raw();val out=intent.startWrite();out.write(byteArrayOf(1));intent.finishWrite(out)
        ChildAccounting(context).use{e->ck(e.read().storageFailure);ck(e.recoverTrustedTime(trust(old)).storageFailure)}
        ck(raw()==before)
        db().let{d->try{d.openHelper.readableDatabase.query("SELECT name FROM sqlite_master WHERE type='table'").use{c->while(c.moveToNext())ck(c.getString(0) in setOf("ledger","room_master_table","android_metadata"))}}finally{d.close()}}
        result("CORRUPT_INPUT_INTENT_FAIL_CLOSED_AGGREGATE_TABLE_ONLY")
    }
}
