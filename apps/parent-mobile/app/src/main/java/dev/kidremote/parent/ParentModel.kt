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
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val lock = Any()
    private var epoch = 0
    private var access: String? = null
    init { restore() }
    fun navigate(screen: Screen) { if (!state.loading) state = AuthState(screen) }
    private fun work(action: (Int) -> AuthState) {
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
        }
        return AuthState(if (recovery) Screen.RESET else Screen.SETUP)
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
        AuthState(Screen.DEVICES,deviceCount=api.setup(token,timezone))
    }
    fun logout() {
        var cleared=true
        val token=synchronized(lock) {
            epoch++; val old=access; access=null
            try { vault.clear() } catch (_: Exception) { cleared=false }
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
