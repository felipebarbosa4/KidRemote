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

internal class IdentityStore(context: Context) {
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
        return v
    }
    fun discardUnreadable():Boolean {
        if(file.exists()){try{if(read()!=null)return false}catch(_:Exception){};android.util.AtomicFile(file).delete()
            KeyStore.getInstance("AndroidKeyStore").apply{load(null);if(containsAlias(alias))deleteEntry(alias)}}
        pending.delete();return !file.exists()&&!pending.exists()
    }
}
internal class EnrollmentApi {
    fun request(path:String,body:JSONObject,credential:String?=null):JSONObject {
        check(Backend.endpoint.isNotEmpty())
        val c=URL(Backend.endpoint+path).openConnection() as HttpURLConnection
        try {
            c.requestMethod="POST";c.connectTimeout=10000;c.readTimeout=10000;c.instanceFollowRedirects=false;c.useCaches=false;c.doOutput=true
            c.setRequestProperty("Content-Type","application/json");if(credential!=null)c.setRequestProperty("Authorization","Bearer $credential")
            c.outputStream.use{it.write(body.toString().toByteArray(Charsets.UTF_8))}
            if(c.responseCode==403)throw SecurityException("DEVICE_REVOKED")
            if(c.responseCode==401)throw SecurityException("CREDENTIAL_REJECTED")
            check(c.responseCode==200){"ENROLLMENT_UNAVAILABLE"}
            val bytes=c.inputStream.use{input->val out=java.io.ByteArrayOutputStream();val buffer=ByteArray(4096)
                while(true){val n=input.read(buffer);if(n<0)break;check(out.size()+n<=65536);out.write(buffer,0,n)};out.toByteArray()}
            return JSONObject(String(bytes,Charsets.UTF_8))
        }finally{c.disconnect()}
    }
    fun redeem(q:JSONObject)=request("/pairing/redeem",JSONObject().put("qr",q).put("metadata",JSONObject().put("platform","android").put("os_major",android.os.Build.VERSION.RELEASE.substringBefore('.').toInt()).put("agent_version","0.0.1-local").put("nickname","Dispositivo Android")))
    fun initial(identity:JSONObject):JSONObject {
        val r=request("/device/sync",JSONObject().put("protocol_version",1).put("after_version",0),identity.getString("credential"))
        check(r.getInt("protocol_version")==1&&r.getString("kind")=="ENROLLMENT_BOOTSTRAP"&&r.getString("device_id")==identity.getString("device_id")&&r.getString("policy_epoch")==identity.getString("policy_epoch"))
        check(!r.getBoolean("policy_configured")&&r.isNull("daily_limit_seconds")&&!r.getBoolean("enforcement_available"))
        return r
    }
}
data class EnrollmentState(val loading:Boolean=false,val paired:Boolean=false,val message:String="Não pareado. Enforcement não disponível.",val recovery:Boolean=false)
class EnrollmentModel(application:Application):AndroidViewModel(application) {
    var state by mutableStateOf(EnrollmentState());private set
    private val store=IdentityStore(application);private val api=EnrollmentApi();private val executor=Executors.newSingleThreadExecutor();private val main=Handler(Looper.getMainLooper())
    init{restore()}
    private fun run(action:()->EnrollmentState) {
        if(state.loading)return
        state=state.copy(loading=true)
        executor.execute {
            val next=try{action()}catch(_:Exception){EnrollmentState(message="Identidade ou contato não confirmado. Não repita um QR consumido. O responsável deve verificar, revogar o pareamento incompleto e gerar novo QR.",recovery=true)}
            main.post{state=next}
        }
    }
    fun restore()=run {
        val saved=store.read()
        if(saved==null){if(store.pending.exists())throw IllegalStateException("INTERRUPTED_PAIRING");EnrollmentState()}
        else {
            try{api.initial(saved);EnrollmentState(paired=true,message="Pareado. Leitura autenticada concluída. Enforcement não ativo; configuração incompleta.")}
            catch(_:SecurityException){EnrollmentState(message="Credencial recusada ou revogada. Identidade local preservada; procure o responsável. Enforcement não ativo.",recovery=true)}
            catch(_:Exception){EnrollmentState(paired=true,message="Identidade armazenada; contato não confirmado. Enforcement não ativo. Tente verificar novamente.")}
        }
    }
    fun decoded(text:String)=run {
        check(store.read()==null&&!store.pending.exists())
        val qr=parseQr(text)?:return@run EnrollmentState(message="QR inválido. Use apenas o QR do responsável neste ambiente.")
        // Durable uncertainty boundary BEFORE HTTP. Never auto-replay on restart/response loss.
        val marker=android.util.AtomicFile(store.pending);val out=marker.startWrite();try{out.write(byteArrayOf(1));marker.finishWrite(out)}catch(e:Exception){marker.failWrite(out);throw e}
        val identity=api.redeem(qr);check(identity.getString("result")=="REDEEMED")
        EnrollmentFaults.beforeIdentitySave()
        store.save(identity);api.initial(identity)
        EnrollmentState(paired=true,message="Pareado. Leitura autenticada concluída. Enforcement não ativo; configuração incompleta.")
    }
    fun acknowledgeFreshQr() {
        // No persisted policy/identity is discarded. Missing identity recovery requires explicit parent action.
        if(!state.loading&&store.discardUnreadable()) state=EnrollmentState(message="Use somente um novo QR após a revogação pelo responsável.")
    }
    override fun onCleared(){executor.shutdownNow();super.onCleared()}
}
