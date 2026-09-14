package dev.kidremote.child

import android.app.Application
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.compose.runtime.*
import androidx.lifecycle.AndroidViewModel
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

internal fun parseQr(text: String): JSONObject? = try {
    check(text.toByteArray(Charsets.UTF_8).size<=256)
    val q=JSONObject(text)
    check(q.keys().asSequence().toSet()==setOf("protocol_version","session_id","token"))
    check(q.get("protocol_version") is Int && q.getInt("protocol_version")==1)
    check(q.getString("session_id").matches(Regex("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}")))
    val token=q.getString("token");check(token.matches(Regex("[A-Za-z0-9_-]{43}")))
    check(java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(java.util.Base64.getUrlDecoder().decode(token))==token)
    // Reject duplicate keys too; JSONObject otherwise silently keeps the last one.
    check(Regex("\"(?:protocol_version|session_id|token)\"\\s*:").findAll(text).count()==3)
    q
}catch(_:Exception){null}

internal class IdentityStore(private val context: Context) {
    val file=File(context.noBackupFilesDir,"device-identity")
    val pending=File(context.noBackupFilesDir,"pairing-pending")
    private val alias="device-identity-v1"
    private fun key(create:Boolean):SecretKey {
        val ks=KeyStore.getInstance("AndroidKeyStore").apply{load(null)}
        (ks.getKey(alias,null) as? SecretKey)?.let{return it}
        check(create){"IDENTITY_KEY_UNAVAILABLE"}
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    fun save(value:JSONObject) {
        val c=Cipher.getInstance("AES/GCM/NoPadding").apply{init(Cipher.ENCRYPT_MODE,key(true))}
        val a=android.util.AtomicFile(file);val s=a.startWrite()
        try{s.write(c.iv+c.doFinal(value.toString().toByteArray(Charsets.UTF_8)));a.finishWrite(s)}catch(e:Exception){a.failWrite(s);throw e}
        pending.delete()
    }
    fun read():JSONObject? {
        if(!file.exists())return null
        check(file.length() in 29..8192)
        val bytes=file.readBytes();val c=Cipher.getInstance("AES/GCM/NoPadding").apply{init(Cipher.DECRYPT_MODE,key(false),GCMParameterSpec(128,bytes.copyOfRange(0,12)))}
        val v=JSONObject(String(c.doFinal(bytes.copyOfRange(12,bytes.size)),Charsets.UTF_8))
        check(v.getString("credential").matches(Regex("[A-Za-z0-9_-]{43}")));java.util.UUID.fromString(v.getString("device_id"));java.util.UUID.fromString(v.getString("policy_epoch"))
        if(v.has("rotation")) {
            val r=v.getJSONObject("rotation");java.util.UUID.fromString(r.getString("operation_id"))
            check(r.getString("new_credential").matches(Regex("[A-Za-z0-9_-]{43}")))
            check(r.getString("new_credential")!=v.getString("credential"))
        }
        if(v.has("removal"))validateRemoval(v.getJSONObject("removal").toString(),v)
        return v
    }
    fun clearConfirmedRemoval():Boolean {
        val value=read()?:return false
        if(!value.has("removal"))return false
        validateRemoval(value.getJSONObject("removal").toString(),value)
        dev.kidremote.child.accounting.clearAccountingForValidatedRemoval(context)
        android.util.AtomicFile(file).delete()
        pending.delete()
        check(!file.exists()&&!pending.exists())
        KeyStore.getInstance("AndroidKeyStore").apply{load(null);if(containsAlias(alias))deleteEntry(alias)}
        return true
    }
    fun recoverMissingIdentity():Boolean {
        if(file.exists())return false
        pending.delete();return !pending.exists()
    }
}
internal class DeviceRemoved(val removal:JSONObject):SecurityException("DEVICE_REVOKED")
internal fun validateRemoval(text:String,identity:JSONObject):JSONObject {
    check(text.toByteArray(Charsets.UTF_8).size<=4096)
    val keys=setOf("protocol_version","code","device_id","policy_epoch")
    val seen=mutableSetOf<String>();val r=JSONObject()
    android.util.JsonReader(java.io.StringReader(text)).use { reader->
        reader.isLenient=false;reader.beginObject()
        while(reader.hasNext()) {
            val name=reader.nextName();check(name in keys&&seen.add(name))
            if(name=="protocol_version") {
                check(reader.peek()==android.util.JsonToken.NUMBER&&reader.nextString()=="1");r.put(name,1)
            } else {
                check(reader.peek()==android.util.JsonToken.STRING);r.put(name,reader.nextString())
            }
        }
        reader.endObject();check(reader.peek()==android.util.JsonToken.END_DOCUMENT&&seen==keys)
    }
    check(r.getString("code")=="DEVICE_REVOKED")
    for(k in listOf("device_id","policy_epoch"))check(r.getString(k)==identity.getString(k))
    return r
}
internal class EnrollmentApi {
    private fun rotation(identity:JSONObject,phase:String,useNew:Boolean):JSONObject {
        val pending=identity.getJSONObject("rotation")
        val body=JSONObject().put("protocol_version",1).put("operation_id",pending.getString("operation_id")).put("phase",phase)
        if(phase=="BEGIN")body.put("new_credential",pending.getString("new_credential"))
        val result=request("/device/credentials/rotate",body,if(useNew)pending.getString("new_credential") else identity.getString("credential"))
        // Debug instrumentation may withhold this REAL committed HTTP reply before renewal consumes it.
        EnrollmentFaults.afterRotationResponse(phase)
        check(result.getString("operation_id")==pending.getString("operation_id")&&result.getString("device_id")==identity.getString("device_id")&&result.getString("policy_epoch")==identity.getString("policy_epoch"))
        check(result.getLong("generation")>1)
        return result
    }
    fun contact(store:IdentityStore,identity:JSONObject):JSONObject {
        check(!identity.has("removal"))
        try{return renew(store,identity)}catch(e:SecurityException){
            if(e is DeviceRemoved)throw e
            // Rotation 403 alone is not a removal instruction. Validate through own sync.
            initial(identity)
            throw e
        }
    }
    private fun renew(store:IdentityStore,identity:JSONObject):JSONObject {
        if(!identity.has("rotation")) {
            val state=initial(identity)
            if(!state.getJSONObject("credential_lifecycle").getBoolean("rotation_due"))return state
            val bytes=ByteArray(32).also{java.security.SecureRandom().nextBytes(it)}
            identity.put("rotation",JSONObject().put("operation_id",java.util.UUID.randomUUID().toString()).put("new_credential",java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)))
            store.save(identity) // One encrypted AtomicFile contains BOTH candidates and operation before BEGIN.
        }
        val confirmed=try { rotation(identity,"CONFIRM",true) } catch(e:SecurityException) {
            if(e.message!="CREDENTIAL_REJECTED")throw e
            check(rotation(identity,"BEGIN",false).getString("result")=="PENDING")
            rotation(identity,"CONFIRM",true)
        }
        check(confirmed.getString("result")=="CONFIRMED")
        identity.put("credential",identity.getJSONObject("rotation").getString("new_credential"))
        identity.remove("rotation")
        identity.put("generation",confirmed.getLong("generation")).put("expires_at",confirmed.getString("expires_at")).put("rotate_after",confirmed.getString("rotate_after"))
        store.save(identity)
        return initial(identity)
    }
    fun request(path:String,body:JSONObject,credential:String?=null,identity:JSONObject?=null,parse:(String)->JSONObject={JSONObject(it)}):JSONObject {
        check(Backend.endpoint.isNotEmpty())
        val c=URL(Backend.endpoint+path).openConnection() as HttpURLConnection
        try {
            c.requestMethod="POST";c.connectTimeout=10000;c.readTimeout=10000;c.instanceFollowRedirects=false;c.useCaches=false;c.doOutput=true
            c.setRequestProperty("Content-Type","application/json");if(credential!=null)c.setRequestProperty("Authorization","Bearer $credential")
            c.outputStream.use{it.write(body.toString().toByteArray(Charsets.UTF_8))}
            if(c.responseCode==403) {
                if(path=="/device/sync"&&identity!=null) {
                    val bytes=c.errorStream?.use{input->val out=java.io.ByteArrayOutputStream();val buffer=ByteArray(1024)
                        while(out.size()<=4096){val n=input.read(buffer);if(n<0)break;out.write(buffer,0,n)};out.toByteArray()}?:byteArrayOf()
                    check(bytes.size<=4096)
                    val text=String(bytes,Charsets.UTF_8)
                    if(JSONObject(text).optString("code")!="DEVICE_REVOKED")throw SecurityException("CREDENTIAL_REJECTED")
                    throw DeviceRemoved(validateRemoval(text,identity))
                }
                throw SecurityException("DEVICE_REVOKED")
            }
            if(c.responseCode==401)throw SecurityException("CREDENTIAL_REJECTED")
            if(c.responseCode==410&&path=="/device/sync")throw dev.kidremote.child.sync.RestartSnapshot()
            if(c.responseCode in listOf(429,503))throw dev.kidremote.child.sync.RetryableSync(dev.kidremote.child.sync.RetryTiming.retryAfter(c.getHeaderField("Retry-After"),c.getHeaderField("Date")))
            if(c.responseCode>=500)throw dev.kidremote.child.sync.RetryableSync()
            check(c.responseCode==200){"ENROLLMENT_UNAVAILABLE"}
            val bytes=c.inputStream.use{input->val out=java.io.ByteArrayOutputStream();val buffer=ByteArray(4096)
                while(true){val n=input.read(buffer);if(n<0)break;check(out.size()+n<=65536);out.write(buffer,0,n)};out.toByteArray()}
            return parse(String(bytes,Charsets.UTF_8))
        }finally{c.disconnect()}
    }
    fun redeem(q:JSONObject)=request("/pairing/redeem",JSONObject().put("qr",q).put("metadata",JSONObject().put("platform","android").put("os_major",android.os.Build.VERSION.RELEASE.substringBefore('.').toInt()).put("agent_version","0.0.1-local").put("nickname","Dispositivo Android")))
    fun initial(identity:JSONObject):JSONObject {
        val r=request("/device/sync",JSONObject().put("protocol_version",1).put("after_version",0),identity.getString("credential"),identity,dev.kidremote.child.sync.Wire::parse)
        if(r.optString("kind")=="CONFIGURED_SNAPSHOT"){dev.kidremote.child.sync.Wire.policy(r,identity);return r}
        check(r.getInt("protocol_version")==1&&r.getString("kind")=="ENROLLMENT_BOOTSTRAP"&&r.getString("device_id")==identity.getString("device_id")&&r.getString("policy_epoch")==identity.getString("policy_epoch"))
        check(!r.getBoolean("policy_configured")&&r.isNull("daily_limit_seconds")&&!r.getBoolean("enforcement_available"))
        return r
    }
}
data class EnrollmentState(val loading:Boolean=false,val paired:Boolean=false,val message:String="Não pareado. Enforcement não disponível.",val recovery:Boolean=false,val removed:Boolean=false,val pairingRecovery:Boolean=false)
class EnrollmentModel(application:Application):AndroidViewModel(application) {
    var state by mutableStateOf(EnrollmentState());private set
    private val store=IdentityStore(application);private val api=EnrollmentApi();private val executor=Executors.newSingleThreadExecutor();private val main=Handler(Looper.getMainLooper())
    init{restore()}
    private fun run(action:()->EnrollmentState) {
        if(state.loading)return
        state=state.copy(loading=true)
        executor.execute {
            val next=try{action()}catch(_:Exception){EnrollmentState(message="Identidade ou contato não confirmado. Não repita um QR consumido. O responsável deve verificar, revogar o pareamento incompleto e gerar novo QR.",recovery=true,pairingRecovery=!store.file.exists())}
            main.post{state=next}
        }
    }
    fun restore(explicitRecovery:Boolean=false)=run {
        val saved=store.read()
        if(saved==null){if(store.pending.exists())throw IllegalStateException("INTERRUPTED_PAIRING");EnrollmentState()}
        else if(saved.has("removal"))removedState()
        else {
            dev.kidremote.child.sync.SyncRecovery.request(getApplication(),explicitRecovery)
            val result=dev.kidremote.child.accounting.ChildAccounting(getApplication()).use{it.read()}
            EnrollmentState(paired=true,message=if(result.ledger!=null)"Política local preservada; sincronização solicitada. Enforcement não disponível." else "Identidade armazenada; sincronização solicitada. Enforcement não ativo; configuração incompleta.")
        }
    }
    fun decoded(text:String)=run {
        check(store.read()==null&&!store.pending.exists())
        val qr=parseQr(text)?:return@run EnrollmentState(message="QR inválido. Use apenas o QR do responsável neste ambiente.").also{EnrollmentFaults.cameraStage(5)}
        // Durable uncertainty boundary BEFORE HTTP. Never auto-replay on restart/response loss.
        val marker=android.util.AtomicFile(store.pending);val out=marker.startWrite();try{out.write(byteArrayOf(1));marker.finishWrite(out)}catch(e:Exception){marker.failWrite(out);throw e}
        val identity=api.redeem(qr);check(identity.getString("result")=="REDEEMED")
        EnrollmentFaults.beforeIdentitySave()
        store.save(identity);api.initial(identity);dev.kidremote.child.sync.SyncRecovery.notify(getApplication())
        EnrollmentState(paired=true,message="Pareado. Leitura autenticada concluída. Enforcement não ativo; configuração incompleta.")
    }
    private fun removedState()=EnrollmentState(message="Removido pelo responsável. Pareamento encerrado; limpe a identidade local para usar um novo QR. Enforcement não ativo.",recovery=true,removed=true)
    fun clearRemoved()=run {
        check(store.clearConfirmedRemoval())
        EnrollmentState(message="Identidade removida deste aplicativo. Peça um novo QR ao responsável. Enforcement não ativo.")
    }
    fun acknowledgeFreshQr() {
        // No persisted policy/identity is discarded. Missing identity recovery requires explicit parent action.
        if(!state.loading&&!store.file.exists()&&store.recoverMissingIdentity()) state=EnrollmentState(message="Use somente um novo QR após a revogação pelo responsável.")
    }
    override fun onCleared(){executor.shutdownNow();super.onCleared()}
}
