package dev.kidremote.parent

enum class Screen { LOGIN, SIGNUP, VERIFY, RECOVER, RESET, SETUP, DEVICES }
data class AuthState(val screen: Screen = Screen.LOGIN, val loading: Boolean = false,
    val message: String = "", val deviceCount: Int? = null,
    val devices: List<DeviceSummary> = emptyList(), val qr: String? = null,
    val pairingSession: String? = null, val incompleteRecovery: Boolean = false)
data class DeviceSummary(val id: String,val nickname: String,val revoked: Boolean)
enum class Event { START, SIGNED_UP, RECOVERY_SENT, RECOVERY_VERIFIED, AUTHENTICATED, LOADED, FAILURE, LOGOUT }
fun reduce(state: AuthState, event: Event): AuthState = when (event) {
    Event.START -> state.copy(loading = true, message = "")
    Event.SIGNED_UP -> AuthState(Screen.VERIFY, message = "Confirme pelo e-mail local.")
    Event.RECOVERY_SENT -> AuthState(Screen.RECOVER, message = "Consulte a mensagem local, se a conta existir.")
    Event.RECOVERY_VERIFIED -> AuthState(Screen.RESET)
    Event.AUTHENTICATED -> AuthState(Screen.SETUP)
    Event.LOADED -> AuthState(Screen.DEVICES)
    Event.FAILURE -> state.copy(loading = false, message = "Não foi possível concluir. Verifique os dados ou tente novamente.")
    Event.LOGOUT -> AuthState(message = "Dados locais removidos. Tokens de acesso já emitidos podem durar até expirar.")
}

/** Accept only the exact local Auth email action, never a returned access-token fragment.
 * There is no exported custom-scheme/implicit-token callback handler in this slice. */
fun emailAction(link: String, expectedType: String, allowedOrigin: String): String? = try {
    val uri = java.net.URI(link)
    val allowed = java.net.URI(allowedOrigin)
    if (allowed.host == null || link.length > 2048 || uri.scheme != allowed.scheme || uri.host != allowed.host || uri.port != allowed.port ||
        uri.path != "/verify" || uri.userInfo != null || uri.fragment != null) null else {
        val pairs = (uri.rawQuery ?: "").split('&').map { it.split('=', limit = 2) }
        if (pairs.any { it.size != 2 } || pairs.map { it[0] }.distinct().size != pairs.size) null else {
            val query = pairs.associate { it[0] to java.net.URLDecoder.decode(it[1], "UTF-8") }
            val token = query["token"]
            if (query.keys.any { it !in setOf("token", "type", "redirect_to") } || query["type"] != expectedType ||
                (query["redirect_to"] != null && query["redirect_to"] != allowedOrigin) ||
                token == null || !token.matches(Regex("[A-Za-z0-9_-]{32,128}"))) null else token
        }
    }
} catch (_: Exception) { null }
