package dev.kidremote.child

import android.os.Process
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.ViewModelProvider
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.security.MessageDigest
import org.json.JSONObject
import org.junit.Rule
import org.junit.Test

/** Real local gateway/identity lifecycle. Invalid-envelope cases test the parser only. */
class RemovalRuntimeTest {
    @get:Rule val ui=createAndroidComposeRule<ChildActivity>()
    private val context get()=InstrumentationRegistry.getInstrumentation().targetContext
    private val store get()=IdentityStore(context)
    private val model get()=ViewModelProvider(ui.activity)[EnrollmentModel::class.java]
    private fun checkSafe(v:Boolean){if(!v)throw AssertionError("REMOVAL_ASSERTION")}
    private fun safe(action:()->Unit){try{action()}catch(_:Throwable){throw AssertionError("REMOVAL_RUNTIME_FAILED")}}
    private fun settled(){ui.waitUntil(30000){!model.state.loading}}
    private fun digest()=MessageDigest.getInstance("SHA-256").digest(store.file.readBytes()).joinToString(""){"%02x".format(it)}
    private fun mark(){File(context.noBackupFilesDir,"removal-hash").writeText(digest());File(context.noBackupFilesDir,"removal-pid").writeText(Process.myPid().toString())}
    private fun unchanged(){checkSafe(digest()==File(context.noBackupFilesDir,"removal-hash").readText())}
    private fun restarted(){checkSafe(Process.myPid()!=File(context.noBackupFilesDir,"removal-pid").readText().toInt())}
    private fun result(code:String){InstrumentationRegistry.getInstrumentation().sendStatus(0,android.os.Bundle().apply{putString("kr007",code)})}
    @Test fun remember()=safe {
        settled();checkSafe(model.state.paired&&!model.state.removed&&!store.read()!!.has("removal"));mark()
        result("REMOVAL_BASELINE_REAL_IDENTITY_NO_CONFIGURED_POLICY_PASS")
    }
    @Test fun unknown()=safe {
        settled();val original=store.read()!!
        val random=ByteArray(32).also{java.security.SecureRandom().nextBytes(it)}
        store.save(JSONObject(original.toString()).put("credential",java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(random)))
        val before=store.file.readBytes();ui.runOnIdle{model.restore()};settled()
        checkSafe(model.state.recovery&&!model.state.removed&&before.contentEquals(store.file.readBytes()))
        store.save(original);ui.runOnIdle{model.restore()};settled();checkSafe(model.state.paired);mark()
        result("UNKNOWN_REAL_GATEWAY_GENERIC_AUTH_NO_REMOVAL_NO_ERASURE_PASS")
    }
    @Test fun offlineRestart()=safe {
        settled();restarted();unchanged();checkSafe(model.state.paired&&!model.state.removed)
        ui.onNodeWithText("Identidade armazenada; contato não confirmado. Enforcement não ativo. Tente verificar novamente.").assertExists()
        result("OFFLINE_PROCESS_RESTART_IDENTITY_UNCHANGED_NOT_REMOVED_PASS")
    }
    @Test fun expired()=safe {
        settled();unchanged();checkSafe(!model.state.removed&&model.state.recovery)
        // The visible clear path must refuse a live/expired identity lacking validated removal.
        ui.runOnIdle{model.clearRemoved()};settled();unchanged();checkSafe(!model.state.removed)
        result("EXPIRED_AUTH_AND_UNVALIDATED_CLEAR_PRESERVE_IDENTITY_PASS")
    }
    @Test fun removed()=safe {
        settled();checkSafe(model.state.removed&&!model.state.paired)
        val identity=store.read()!!;validateRemoval(identity.getJSONObject("removal").toString(),identity)
        ui.onNodeWithText("Limpar identidade removida; usar novo QR").assertExists()
        ui.onNodeWithText("Escanear QR do responsável").assertDoesNotExist()
        checkSafe(!store.file.readBytes().toString(Charsets.ISO_8859_1).contains(identity.getString("credential")))
        mark();result("REAL_VALIDATED_DEVICE_REMOVAL_DURABLE_VISIBLE_NO_AUTO_PAIR_PASS")
    }
    @Test fun removedOfflineRestart()=safe {
        settled();restarted();unchanged();checkSafe(model.state.removed&&!model.state.paired)
        result("REMOVED_OFFLINE_RESTART_SAME_ENCRYPTED_STATE_PASS")
    }
    @Test fun invalidEnvelopesAndStorage()=safe {
        settled();val identity=store.read()!!;val good=identity.getJSONObject("removal").toString()
        val bad=listOf("{}",good.replace("DEVICE_REVOKED","TARGET_DENIED"),good.replace(identity.getString("device_id"),java.util.UUID.randomUUID().toString()),
            good.replace(identity.getString("policy_epoch"),java.util.UUID.randomUUID().toString()),good.dropLast(1)+",\"protocol_version\":1}",
            good.dropLast(1)+",\"extra\":true}",good.replace("\"protocol_version\":1","\"protocol_version\":\"1\""))
        for(text in bad){var rejected=false;try{validateRemoval(text,identity)}catch(_:Exception){rejected=true};checkSafe(rejected)}
        val ambiguous=JSONObject(identity.toString()).put("removal",JSONObject("{}"));store.save(ambiguous)
        val bytes=store.file.readBytes();ui.runOnIdle{model.restore()};settled()
        checkSafe(!model.state.removed&&!model.state.paired&&bytes.contentEquals(store.file.readBytes()))
        ui.runOnIdle{model.clearRemoved()};settled();checkSafe(bytes.contentEquals(store.file.readBytes())&&!model.state.removed)
        ui.runOnIdle{model.acknowledgeFreshQr()};settled();checkSafe(bytes.contentEquals(store.file.readBytes())&&!model.state.removed)
        store.save(identity)
        val damaged=store.file.readBytes().also{it[it.lastIndex]=(it.last().toInt() xor 1).toByte()};store.file.writeBytes(damaged)
        ui.runOnIdle{model.restore()};settled();checkSafe(!model.state.removed&&!model.state.paired&&damaged.contentEquals(store.file.readBytes()))
        store.save(identity);ui.runOnIdle{model.restore()};settled();checkSafe(model.state.removed)
        result("INVALID_ENVELOPES_AMBIGUOUS_AND_CORRUPT_STORAGE_NO_FALSE_REMOVAL_PASS")
    }
    @Test fun explicitClear()=safe {
        settled();checkSafe(model.state.removed)
        ui.onNodeWithText("Limpar identidade removida; usar novo QR").performClick();settled()
        checkSafe(store.read()==null&&!store.pending.exists()&&!model.state.paired&&!model.state.removed)
        ui.onNodeWithText("Escanear QR do responsável").assertExists()
        result("EXPLICIT_CONFIRMED_LOCAL_CLEAR_NO_NEW_IDENTITY_PASS")
    }
    @Test fun clearedOfflineRestart()=safe {
        settled();checkSafe(store.read()==null&&!model.state.paired&&!model.state.removed)
        result("CLEARED_OFFLINE_RESTART_STAYS_UNPAIRED_PASS")
    }
}
