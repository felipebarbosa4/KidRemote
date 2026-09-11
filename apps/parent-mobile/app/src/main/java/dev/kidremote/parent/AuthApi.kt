package dev.kidremote.parent

import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

internal class AuthApi {
    fun request(path: String, body: JSONObject? = null, bearer: String? = null,
        rest: Boolean = false, method: String = if (body == null) "GET" else "POST"): String {
        check(BackendConfig.enabled) { "BACKEND_NOT_CONFIGURED" }
        val c = URL((if (rest) BackendConfig.rest else BackendConfig.auth) + path).openConnection() as HttpURLConnection
        try {
            c.requestMethod = method; c.connectTimeout = 10000; c.readTimeout = 10000
            c.instanceFollowRedirects = false; c.useCaches = false
            c.setRequestProperty("Content-Type", "application/json")
            if (bearer != null) c.setRequestProperty("Authorization", "Bearer $bearer")
            if (body != null) { c.doOutput = true; c.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) } }
            if (c.responseCode !in 200..299) throw IllegalStateException("AUTH_REQUEST_FAILED")
            return c.inputStream.use { stream ->
                val out = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(4096)
                while (true) {
                    val size = stream.read(buffer)
                    if (size < 0) break
                    check(out.size() + size <= 65536) { "RESPONSE_TOO_LARGE" }
                    out.write(buffer,0,size)
                }
                out.toString("UTF-8")
            }
        } finally { c.disconnect() }
    }
    fun signup(email: String, password: String) { request("/signup", JSONObject().put("email",email).put("password",password)) }
    fun login(email: String, password: String) = JSONObject(request("/token?grant_type=password", JSONObject().put("email",email).put("password",password)))
    fun refresh(token: String) = JSONObject(request("/token?grant_type=refresh_token", JSONObject().put("refresh_token",token)))
    fun verify(link: String, type: String): JSONObject {
        val token = emailAction(link,type,BackendConfig.emailOrigin) ?: throw IllegalArgumentException("INVALID_CALLBACK")
        return JSONObject(request("/verify", JSONObject().put("token_hash",token).put("type",type)))
    }
    fun recover(email: String) { request("/recover", JSONObject().put("email",email)) }
    fun updatePassword(token: String, password: String) { request("/user", JSONObject().put("password",password),token,method="PUT") }
    fun logout(token: String) { request("/logout?scope=local",JSONObject(),token) }
    fun confirmed(token: String): Boolean = !JSONObject(request("/user",bearer=token)).isNull("email_confirmed_at")
    fun setup(token: String, timezone: String): Int {
        request("/rpc/bootstrap_household",JSONObject().put("p_timezone",timezone),token,rest=true)
        check(JSONArray(request("/households?select=id",bearer=token,rest=true)).length() == 1)
        check(JSONArray(request("/profiles?select=user_id",bearer=token,rest=true)).length() == 1)
        return JSONArray(request("/devices?select=id",bearer=token,rest=true)).length()
    }
}
