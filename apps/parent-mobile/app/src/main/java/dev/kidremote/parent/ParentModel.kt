package dev.kidremote.parent

import android.app.Application
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import org.json.JSONObject
import java.util.concurrent.Executors

class ParentModel(application: Application) : AndroidViewModel(application) {
    var state by mutableStateOf(AuthState()); private set
    private val api = AuthApi()
    private val vault = SessionVault(application)
    private val requestVault = SessionVault(application,"parent-control",strict=true)
    private var account: String? = null
    private val pairingIdFile=java.io.File(application.noBackupFilesDir,"pairing-session-id")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val lock = Any()
    private var epoch = 0
    private var access: String? = null
    init { restore() }
    fun navigate(screen: Screen) { if (!state.loading) state = AuthState(screen) }
    private fun work(action: (Int) -> AuthState) {
        if(state.loading)return
        val generation = synchronized(lock) { epoch }
        state = reduce(state,Event.START)
        worker.execute {
            val result = try { action(generation) } catch (_: Exception) { reduce(state,Event.FAILURE) }
            main.post { if (synchronized(lock) { epoch == generation }) state = result }
        }
    }
    private fun accept(session: JSONObject, generation: Int, recovery: Boolean = false): AuthState {
        val token=session.getString("access_token")
        check(api.confirmed(token))
        synchronized(lock) {
            check(epoch == generation)
            // Recovery privilege is memory-only: process restart returns to login,
            // never converts an unfinished password reset into a normal restored session.
            if (recovery) vault.clear() else vault.save(session.getString("refresh_token"))
            access=token
            account=session.getJSONObject("user").getString("id")
        }
        val pending=if(recovery)null else requestVault.read()?.let(::storedRequest)?.takeIf{it.account==account}?.let{ControlResult(it,"failed",retryable=true)}
        return AuthState(if (recovery) Screen.RESET else Screen.SETUP,control=pending,pairingSession=pairingIdFile.takeIf{it.exists()}?.readText()?.takeIf{it.matches(Regex("[0-9a-f-]{36}"))})
    }
    fun restore() = work { generation ->
        val saved=vault.read()
        if (saved == null) AuthState() else accept(api.refresh(saved),generation)
    }
    fun signup(email: String, password: String) = work { api.signup(email,password); reduce(state,Event.SIGNED_UP) }
    fun login(email: String, password: String) = work { generation -> accept(api.login(email,password),generation) }
    fun verify(link: String, recovery: Boolean) = work { generation ->
        val session=api.verify(link,if (recovery) "recovery" else "signup")
        if (recovery) accept(session,generation,true) else AuthState(message="E-mail confirmado. Entre com sua senha.")
    }
    fun recover(email: String) = work { api.recover(email); reduce(state,Event.RECOVERY_SENT) }
    fun reset(password: String) = work {
        val token=synchronized(lock) { access } ?: error("NO_SESSION")
        api.updatePassword(token,password)
        synchronized(lock) { vault.clear(); access=null }
        AuthState(message="Senha alterada. Entre novamente.")
    }
    fun setup(timezone: String) = work {
        val token=synchronized(lock) { access } ?: error("NO_SESSION")
        api.setup(token,timezone)
        val rows=api.devices(token);state.copy(screen=Screen.DEVICES,loading=false,deviceCount=rows.size,devices=rows,readAtElapsed=android.os.SystemClock.elapsedRealtime())
    }
    fun refreshDevices() = work {
        val token=synchronized(lock){access}?:error("NO_SESSION")
        val rows=api.devices(token,state.listAfter).map{retainNewer(state.devices.find{old->old.id==it.id},it)}
        val result=state.control?.let { api.status(token,it) }
        state.copy(loading=false,deviceCount=rows.size,devices=rows,control=result,readAtElapsed=android.os.SystemClock.elapsedRealtime())
    }
    fun nextPage(){if(!state.loading&&state.devices.size==50){state=state.copy(listAfter=state.devices.last().id,selected=null);refreshDevices()}}
    fun firstPage(){if(!state.loading){state=state.copy(listAfter=null,selected=null);refreshDevices()}}
    fun openDevice(id:String){if(!state.loading){state=state.copy(screen=Screen.DETAIL,selected=id,qr=null);refreshDevices()}}
    fun backToDevices(){if(!state.loading)state=state.copy(screen=Screen.DEVICES,selected=null,qr=null)}
    fun control(kind:ControlKind,value:Int?=null) {
        if(state.loading||state.control?.retryable==true)return
        val d=state.devices.find{it.id==state.selected}?:return
        val q=try{ControlRequest.create(account?:error("NO_SESSION"),d,kind,value)}catch(_:Exception){state=state.copy(message="Valor inválido. Informe de 0 a 86400 segundos.");return}
        state=state.copy(control=ControlResult(q))
        submit(q)
    }
    fun setDailyLimit(text:String){val n=parseDailyLimit(text);if(n==null){state=state.copy(message="Valor inválido. Informe de 0 a 86400 segundos.");return};control(ControlKind.SET_DAILY_LIMIT,n)}
    fun retryControl(){if(!state.loading)state.control?.takeIf{it.retryable||it.status in setOf("accepted","pending")}?.request?.let(::submit)}
    private fun submit(q:ControlRequest)=work { generation ->
        val token=try{synchronized(lock){check(epoch==generation&&account==q.account);requestVault.save(q.stored());access}?:error("NO_SESSION")}
        catch(_:Exception){return@work state.copy(loading=false,control=ControlResult(q,"failed",retryable=true),message="Não foi possível salvar a solicitação. Nenhum novo envio foi iniciado.")}
        val result=try{ControlResult(q,"accepted",api.operation(token,q))}catch(e:ApiFailure){
            ControlResult(q,if(e.status in 400..499&&e.status!=429)"rejected" else "failed",retryable=e.status==429||e.status>=500,code=e.code)
        }catch(_:Exception){ControlResult(q,"failed",retryable=true)}
        state.copy(loading=false,control=result,message="")
    }
    fun createPairing() = work {
        val token=synchronized(lock){access}?:error("NO_SESSION")
        val r=api.pair(token);check(r.getString("result")=="CREATED")
        val q=r.getJSONObject("qr");val session=q.getString("session_id")
        pairingIdFile.writeText(session) // nonsecret recovery reference; server still checks current membership
        val ttl=java.time.Instant.parse(r.getString("expires_at")).toEpochMilli()-System.currentTimeMillis()
        main.post {main.postDelayed({if(state.pairingSession==session)clearPairingQr()},ttl.coerceIn(0,300000))}
        state.copy(loading=false,qr=q.toString(),pairingSession=session,incompleteRecovery=false,message="QR de uso único. Não compartilhe. Expira em até cinco minutos.")
    }
    fun clearPairingQr(){state=state.copy(qr=null)}
    fun finishPairing(revoke: Boolean=false)=work {
        val token=synchronized(lock){access}?:error("NO_SESSION")
        val id=state.pairingSession?:error("NO_SESSION")
        val r=api.cancel(token,id,revoke).getString("result")
        val rows=api.devices(token)
        state.copy(loading=false,qr=null,deviceCount=rows.size,devices=rows,incompleteRecovery=r=="ALREADY_REDEEMED",
            message=when(r){"CANCELLED"->"QR cancelado.";"ALREADY_REDEEMED"->"QR consumido. Se a credencial não foi salva, revogue o pareamento incompleto e gere outro QR.";"REVOKED_FRESH_QR_REQUIRED"->"Pareamento incompleto revogado. Gere outro QR.";else->"Operação indisponível; não foi confirmada a revogação."})
    }
    fun logout() {
        var cleared=true
        val token=synchronized(lock) {
            epoch++; val old=access; access=null;account=null
            pairingIdFile.delete()
            try { vault.clear();requestVault.clear() } catch (_: Exception) { cleared=false }
            old
        }
        state=if(cleared) reduce(state,Event.LOGOUT) else AuthState(message="Sessão em memória encerrada, mas a limpeza do armazenamento não foi confirmada. Não compartilhe este perfil do aparelho.")
        if (token != null) worker.execute {
            try { api.logout(token) } catch (_: Exception) {
                main.post { if (cleared && state.screen==Screen.LOGIN) state=state.copy(message="Dados locais removidos. Revogação no servidor não confirmada; tokens podem continuar válidos até expirar.") }
            }
        }
    }
    override fun onCleared() { worker.shutdownNow(); synchronized(lock) { epoch++; access=null }; super.onCleared() }
}
