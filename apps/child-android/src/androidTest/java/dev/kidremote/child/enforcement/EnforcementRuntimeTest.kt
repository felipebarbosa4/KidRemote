package dev.kidremote.child.enforcement

import android.app.UiAutomation
import android.content.Intent
import android.os.Bundle
import android.os.ParcelFileDescriptor
import androidx.test.platform.app.InstrumentationRegistry
import dev.kidremote.child.IdentityStore
import dev.kidremote.child.accounting.*
import org.json.JSONObject
import org.junit.Test
import java.io.File
import java.util.UUID

/** Actual system-bound product service on the owned emulator. Canonical fixtures, not network evidence. */
class EnforcementRuntimeTest {
 @Test fun serviceLifecycle()=exercise(false)
 @Test fun networkLock()=exercise(true)
 @Test fun killWhileRestricted()=exercise(false,true)
 @Test fun killNetworkRestricted()=exercise(true,true)
 private fun exercise(network:Boolean,death:Boolean=false){
    val i=InstrumentationRegistry.getInstrumentation();val c=i.targetContext
    val automation=i.getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
    fun shell(command:String)=ParcelFileDescriptor.AutoCloseInputStream(automation.executeShellCommand(command)).bufferedReader().use{it.readText().trim()}
    check(shell("getprop ro.kernel.qemu")=="1")
    check(shell("getprop ro.boot.qemu.avd_name")=="kr006_e03b4820193b4132b1fcf7950eeed7fe")
    val component=c.packageName+"/dev.kidremote.child.enforcement.ChildEnforcementService"
    val previous=shell("settings get secure enabled_accessibility_services")
    val enabled=shell("settings get secure accessibility_enabled")
    fun waitFor(code:String,predicate:()->Boolean){val until=android.os.SystemClock.elapsedRealtime()+15000;while(!predicate()&&android.os.SystemClock.elapsedRealtime()<until)Thread.sleep(100);if(!predicate()){i.sendStatus(0,Bundle().apply{putString("enforcement","WAIT_FAILED_"+code)});EnforcementRuntime.engine()?.read()?.ledger?.let{s->i.sendStatus(0,Bundle().apply{putString("enforcement",EnforcementRuntime.report(c,s).health)})}};check(predicate()){code};i.sendStatus(0,Bundle().apply{putString("enforcement",code)})}
    try {
        File(c.noBackupFilesDir,"sync-test-control").writeText("controlled")
        c.deleteDatabase(File(c.noBackupFilesDir,"accounting.db").absolutePath)
        android.util.AtomicFile(File(c.noBackupFilesDir,"accounting-write-intent")).delete()
        val realIdentity=if(network)JSONObject(File(c.noBackupFilesDir,"sync-handoff").readText()) else null
        val epoch=realIdentity?.getString("policy_epoch")?:UUID.randomUUID().toString()
        IdentityStore(c).save(realIdentity?:JSONObject().put("device_id",UUID.randomUUID().toString()).put("policy_epoch",epoch).put("credential",java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(ByteArray(32).also{java.security.SecureRandom().nextBytes(it)})))
        val sample=AndroidAccountingClock.sample(c,true)
        val utc=java.time.Instant.parse("2026-09-14T12:00:00Z").toEpochMilli()
        if(network)dev.kidremote.child.sync.DeviceSync(c,{AndroidAccountingClock.sample(c,true)}).use{check(!it.sync().storageFailure)} else ChildAccounting(c).use{check(!it.initialize(Policy(epoch,1,"Etc/UTC",1,"2026-09-14",3600,600,true),sample,utc).storageFailure)}
        EnforcementRuntime.consent(c)
        shell("appops set ${c.packageName} GET_USAGE_STATS allow")
        shell("settings put secure enabled_accessibility_services $component");shell("settings put secure accessibility_enabled 1")
        waitFor("SERVICE_CONNECTED"){EnforcementRuntime.engine()!=null}
        shell("input keyevent KEYCODE_WAKEUP");shell("wm dismiss-keyguard");shell("am start -W -a android.settings.SETTINGS");shell("am start -W -n dev.kidremote.spike.ordinary/.FixtureActivity")
        waitFor("LOCK_ATTACHED_OBSERVED"){EnforcementRuntime.text().startsWith("Restrição observada")}
        val engine=EnforcementRuntime.engine()!!
        waitFor("OBSERVATION_DURABLE_OFFLINE"){engine.read().ledger?.lastAdapterObservation?.let{JSONObject(it).getBoolean("attached")}==true}
        if(network){dev.kidremote.child.sync.DeviceSync(c).use{check(!it.sync().storageFailure)};i.sendStatus(0,Bundle().apply{putString("enforcement","REAL_PARENT_LOCK_ROOM_ADAPTER_ACK_SENT")})}
        var before=engine.read().ledger!!
        check(before.policy.manualLock&&before.bonusSeconds==(if(network)0L else 600L))
        if(!network){
            // Local canonical/time fixtures, explicitly not authenticated network evidence.
            val t=AndroidAccountingClock.sample(c,true)
            check(!engine.recoverTrustedTime(TrustedTime(epoch,"Etc/UTC",1,utc+86400000,t)).storageFailure)
            fun policy(manual:Boolean,limit:Long,bonus:Long){val old=engine.read().ledger!!;check(!engine.acceptPolicy(old.policy.copy(version=old.policy.version+1,manualLock=manual,dailyLimitSeconds=limit,bonusSeconds=bonus,bonusDate=old.date),AndroidAccountingClock.sample(c,true)).storageFailure)}
            policy(false,3600,0)
            waitFor("UNLOCK_POSITIVE_DETACHED"){EnforcementRuntime.text().startsWith("Sobreposição local ausente")}
            val model=dev.kidremote.child.EnrollmentModel(c.applicationContext as android.app.Application)
            waitFor("CHILD_UI_USES_LIVE_LEDGER"){model.state.paired&&!model.state.localReasons.contains("Contabilidade incerta")&&model.state.message.contains("estado atual do adaptador")}
            policy(false,0,0)
            waitFor("ZERO_REQUIRES_ATTACHED"){EnforcementRuntime.text().startsWith("Restrição observada")}
            policy(true,0,0);policy(false,0,0)
            check(engine.read().ledger!!.restrictionRequired)
            i.sendStatus(0,Bundle().apply{putString("enforcement","UNLOCK_ZERO_STILL_REQUIRED")})
            policy(false,0,600)
            waitFor("PLUS10_CLEARS_EXPIRY_DETACHED"){EnforcementRuntime.text().startsWith("Sobreposição local ausente")}
            policy(false,0,2400)
            check(engine.read().ledger!!.bonusSeconds==2400L)
            policy(true,0,2400)
            waitFor("PLUS30_MANUAL_LOCK_ATTACHED"){EnforcementRuntime.text().startsWith("Restrição observada")}
            val locked=engine.read().ledger!!
            check(engine.acceptPolicy(locked.policy.copy(version=1,manualLock=false),AndroidAccountingClock.sample(c,true)).ledger!!.restrictionRequired)
            i.sendStatus(0,Bundle().apply{putString("enforcement","STALE_UNLOCK_REJECTED")})
            before=engine.read().ledger!!
        }
        // Safe-system route preserves desired state and detaches the overlay.
        c.startActivity(Intent(android.provider.Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        waitFor("SAFE_SURFACE_DETACHED"){EnforcementRuntime.text().startsWith("Superfície de sistema")}
        shell("input keyevent KEYCODE_WAKEUP");shell("wm dismiss-keyguard");shell("am start -W -a android.settings.SETTINGS");shell("am start -W -n dev.kidremote.spike.ordinary/.FixtureActivity")
        waitFor("ORDINARY_REENTRY_ATTACHED"){EnforcementRuntime.text().startsWith("Restrição observada")}
        if(death){
            val saved=engine.read().ledger!!
            val record=JSONObject().put("device_id",IdentityStore(c).read()!!.getString("device_id")).put("pid",android.os.Process.myPid()).put("epoch",saved.policy.epoch).put("version",saved.policy.version).put("used",saved.usedMs).put("bonus",saved.bonusSeconds).put("period",saved.periodKey)
            File(c.noBackupFilesDir,"enforcement-death-state").outputStream().use{it.write(record.toString().toByteArray());it.fd.sync()}
            File(c.noBackupFilesDir,"enforcement-crash").outputStream().use{it.write("EXPECTED_PRODUCT_ENFORCEMENT_KILL".toByteArray());it.fd.sync()}
            i.sendStatus(0,Bundle().apply{putString("enforcement","EXPECTED_PRODUCT_ENFORCEMENT_KILL")})
            android.os.Process.killProcess(android.os.Process.myPid());Thread.sleep(10000);error("KILL_DID_NOT_TERMINATE")
        }
        shell("settings put secure enabled_accessibility_services null")
        waitFor("SERVICE_DISCONNECTED_VISIBLE"){EnforcementRuntime.engine()==null}
        waitFor("DISCONNECT_OBSERVATION_DURABLE"){ChildAccounting(c).use{it.read().ledger?.lastAdapterObservation?.let{r->JSONObject(r).optString("health")=="SERVICE_DISCONNECTED"}==true}}
        shell("settings put secure enabled_accessibility_services $component");shell("settings put secure accessibility_enabled 1")
        waitFor("SERVICE_RECONNECTED"){EnforcementRuntime.engine()!=null}
        shell("input keyevent KEYCODE_WAKEUP");shell("wm dismiss-keyguard");shell("am start -W -a android.settings.SETTINGS");shell("am start -W -n dev.kidremote.spike.ordinary/.FixtureActivity")
        waitFor("OFFLINE_RESTRICTION_RESTORED"){EnforcementRuntime.text().startsWith("Restrição observada")}
        val restored=EnforcementRuntime.engine()!!.read().ledger!!
        check(restored.usedMs>=before.usedMs&&restored.policy==before.policy&&restored.bonusSeconds==before.bonusSeconds)
        // Existing A/B rule: same-period service gap cannot be silently forgiven.
        check(restored.uncertainty!=Uncertainty.NONE)
        i.sendStatus(0,Bundle().apply{putString("enforcement","LEDGER_AND_UNCERTAINTY_PRESERVED")})
        // Validated removal envelope, same existing identity store (no automatic replacement).
        val id=IdentityStore(c).read()!!;id.put("removal",JSONObject().put("protocol_version",1).put("code","DEVICE_REVOKED").put("device_id",id.getString("device_id")).put("policy_epoch",epoch));IdentityStore(c).save(id)
        waitFor("REMOVAL_CLEARS_ACTIVE_ADAPTER"){!EnforcementRuntime.sample(c).signals.blocked&&!EnforcementRuntime.text().startsWith("Restrição observada")}
    }catch(e:Throwable){val line=e.stackTrace.firstOrNull{it.className.contains("EnforcementRuntimeTest")}?.lineNumber?:0;throw AssertionError("ENFORCEMENT_RUNTIME_FAILED_LINE_$line")}
    finally {
        if(previous=="null")shell("settings delete secure enabled_accessibility_services") else shell("settings put secure enabled_accessibility_services $previous")
        if(enabled=="null")shell("settings delete secure accessibility_enabled") else shell("settings put secure accessibility_enabled $enabled")
        shell("appops set ${c.packageName} GET_USAGE_STATS default")
    }
 }
 @Test fun restartAfterDeath(){
    val i=InstrumentationRegistry.getInstrumentation();val c=i.targetContext
    val automation=i.getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
    fun shell(command:String)=ParcelFileDescriptor.AutoCloseInputStream(automation.executeShellCommand(command)).bufferedReader().use{it.readText().trim()}
    check(shell("getprop ro.kernel.qemu")=="1"&&shell("getprop ro.boot.qemu.avd_name")=="kr006_e03b4820193b4132b1fcf7950eeed7fe")
    fun waitFor(code:String,p:()->Boolean){val until=android.os.SystemClock.elapsedRealtime()+15000;while(!p()&&android.os.SystemClock.elapsedRealtime()<until)Thread.sleep(100);check(p()){code};i.sendStatus(0,Bundle().apply{putString("enforcement",code)})}
    try {
        val before=JSONObject(File(c.noBackupFilesDir,"enforcement-death-state").readText())
        check(before.getInt("pid")!=android.os.Process.myPid())
        shell("am start -W -n ${c.packageName}/dev.kidremote.child.ChildActivity")
        waitFor("NEW_PROCESS_SERVICE_CONNECTED"){EnforcementRuntime.engine()!=null}
        shell("input keyevent KEYCODE_WAKEUP");shell("wm dismiss-keyguard");shell("am start -W -a android.settings.SETTINGS");shell("am start -W -n dev.kidremote.spike.ordinary/.FixtureActivity")
        waitFor("PROCESS_DEATH_RESTRICTION_REOBSERVED"){EnforcementRuntime.text().startsWith("Restrição observada")}
        val state=EnforcementRuntime.engine()!!.read().ledger!!
        check(state.policy.epoch==before.getString("epoch")&&state.policy.version==before.getLong("version")&&state.usedMs==before.getLong("used")&&state.bonusSeconds==before.getLong("bonus")&&state.periodKey==before.getString("period")&&state.policy.manualLock&&state.uncertainty!=Uncertainty.NONE)
        i.sendStatus(0,Bundle().apply{putString("enforcement","PROCESS_DEATH_LEDGER_NO_RESET_OR_REPLAY")})
        val id=IdentityStore(c).read()!!
        id.put("removal",JSONObject().put("protocol_version",1).put("code","DEVICE_REVOKED").put("device_id",id.getString("device_id")).put("policy_epoch",id.getString("policy_epoch")));IdentityStore(c).save(id)
        waitFor("RESTART_REMOVAL_DETACHED"){!EnforcementRuntime.sample(c).signals.blocked&&!EnforcementRuntime.text().startsWith("Restrição observada")}
    }catch(e:Throwable){val line=e.stackTrace.firstOrNull{it.className.contains("EnforcementRuntimeTest")}?.lineNumber?:0;throw AssertionError("ENFORCEMENT_RUNTIME_FAILED_LINE_$line")}
 }
 @Test fun verifyHostRecovery(){
    val i=InstrumentationRegistry.getInstrumentation();val c=i.targetContext
    val automation=i.getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
    fun shell(command:String)=ParcelFileDescriptor.AutoCloseInputStream(automation.executeShellCommand(command)).bufferedReader().use{it.readText().trim()}
    check(shell("getprop ro.kernel.qemu")=="1"&&shell("getprop ro.boot.qemu.avd_name")=="kr006_e03b4820193b4132b1fcf7950eeed7fe")
    fun waitFor(code:String,p:()->Boolean){val until=android.os.SystemClock.elapsedRealtime()+15000;while(!p()&&android.os.SystemClock.elapsedRealtime()<until)Thread.sleep(100);check(p()){code};i.sendStatus(0,Bundle().apply{putString("enforcement",code)})}
    try {
        val before=JSONObject(File(c.noBackupFilesDir,"enforcement-death-state").readText())
        check(before.getInt("pid")!=android.os.Process.myPid())
        check(android.os.Process.myPid()==InstrumentationRegistry.getArguments().getString("host_pid")!!.toInt())
        check(IdentityStore(c).read()!!.getString("device_id")==before.getString("device_id"))
        waitFor("NEW_PROCESS_SERVICE_CONNECTED"){EnforcementRuntime.engine()!=null}
        shell("input keyevent KEYCODE_WAKEUP");shell("wm dismiss-keyguard");shell("am start -W -a android.settings.SETTINGS");shell("am start -W -n dev.kidremote.spike.ordinary/.FixtureActivity")
        waitFor("PROCESS_DEATH_RESTRICTION_REOBSERVED"){EnforcementRuntime.text().startsWith("Restrição observada")}
        val state=EnforcementRuntime.engine()!!.read().ledger!!
        check(state.policy.epoch==before.getString("epoch")&&state.policy.version==before.getLong("version")&&state.usedMs==before.getLong("used")&&state.bonusSeconds==before.getLong("bonus")&&state.periodKey==before.getString("period")&&state.policy.manualLock&&state.uncertainty!=Uncertainty.NONE)
        i.sendStatus(0,Bundle().apply{putString("enforcement","PROCESS_DEATH_LEDGER_NO_RESET_OR_REPLAY")})
        check(state.restrictionRequired)
        waitFor("RECOVERED_OBSERVATION_DURABLE"){
            val latest=EnforcementRuntime.engine()!!.read().ledger!!
            val observed=latest.lastAdapterObservation?.let{JSONObject(it)}
            observed?.optString("health")=="RESTRICTED_OBSERVED"&&observed.optBoolean("attached")&&observed.optLong("version")==state.policy.version&&EnforcementRuntime.report(c,latest).applied(latest)
        }
        if(InstrumentationRegistry.getArguments().getString("network_recovery")=="true"){
            dev.kidremote.child.sync.DeviceSync(c).use{check(!it.sync().storageFailure)}
            i.sendStatus(0,Bundle().apply{putString("enforcement","RECOVERED_OBSERVED_ACK_SENT")})
        }
        val id=IdentityStore(c).read()!!
        id.put("removal",JSONObject().put("protocol_version",1).put("code","DEVICE_REVOKED").put("device_id",id.getString("device_id")).put("policy_epoch",id.getString("policy_epoch")));IdentityStore(c).save(id)
        waitFor("RESTART_REMOVAL_DETACHED"){!EnforcementRuntime.sample(c).signals.blocked&&!EnforcementRuntime.text().startsWith("Restrição observada")}
    }catch(e:Throwable){val line=e.stackTrace.firstOrNull{it.className.contains("EnforcementRuntimeTest")}?.lineNumber?:0;throw AssertionError("ENFORCEMENT_RUNTIME_FAILED_LINE_$line")}
 }
}
