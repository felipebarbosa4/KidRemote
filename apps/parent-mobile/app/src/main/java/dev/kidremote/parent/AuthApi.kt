package dev.kidremote.parent

import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

internal class AuthApi {
    fun request(path: String, body: JSONObject? = null, bearer: String? = null,
        rest: Boolean = false, method: String = if (body == null) "GET" else "POST", gateway: Boolean = false): String {
        check(BackendConfig.enabled) { "BACKEND_NOT_CONFIGURED" }
        val c = URL((if(gateway) BackendConfig.gateway else if (rest) BackendConfig.rest else BackendConfig.auth) + path).openConnection() as HttpURLConnection
        try {
            c.requestMethod = method; c.connectTimeout = 10000; c.readTimeout = 10000
            c.instanceFollowRedirects = false; c.useCaches = false
            c.setRequestProperty("Content-Type", "application/json")
            if (bearer != null) c.setRequestProperty("Authorization", "Bearer $bearer")
            if (body != null) { c.doOutput = true; c.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) } }
            if (c.responseCode !in 200..299) {
                val code=try { c.errorStream?.use { stream -> val out=java.io.ByteArrayOutputStream();while(out.size()<=4096){val b=stream.read();if(b<0)break;out.write(b)};val bytes=out.toByteArray(); if(bytes.size>4096) "" else JSONObject(String(bytes,Charsets.UTF_8)).optString("code") } } catch(_:Exception){ null }
                throw ApiFailure(c.responseCode,code?.takeIf { it in setOf("VERSION_CONFLICT","OPERATION_CONFLICT","PERIOD_CONFLICT","ALLOWANCE_CAP","POLICY_NOT_CONFIGURED","INVALID_OPERATION","TARGET_DENIED") }?:"REQUEST_FAILED")
            }
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
    fun devices(token: String,after:String?=null): List<DeviceSummary> {
        val root=JSONObject(request("/rpc/parent_devices",JSONObject().put("p_after",after?:JSONObject.NULL),token,rest=true))
        check(root.getInt("protocol_version")==1)
        val now=java.time.Instant.parse(root.getString("server_utc"));val rows=root.getJSONArray("devices")
        check(rows.length()<=50)
        return (0 until rows.length()).map { val r=rows.getJSONObject(it)
            val report=if(r.isNull("report"))null else r.getJSONObject("report").let { a ->
                DeviceReport(a.safeLong("version"),a.safeLong("sequence"),a.getString("period_key"),a.safeLong("remaining_ms",86400000),
                    a.safeLong("used_ms"),a.safeLong("bonus_seconds",86400).toInt(),a.getBoolean("manual_lock"),a.getBoolean("restriction_required"),
                    a.getBoolean("restriction_applied"),a.getString("health"),java.time.Instant.parse(a.getString("received_at"))) }
            DeviceSummary(r.uuid("id"),r.getString("nickname"),r.getBoolean("revoked"),if(r.isNull("model"))null else r.getString("model"),
                r.uuid("policy_epoch"),r.safeLong("version"),r.getBoolean("policy_configured"),
                if(r.isNull("daily_limit_seconds"))null else r.safeLong("daily_limit_seconds",86400).toInt(),r.getString("period_key"),now,report)
        }
    }
    fun operation(token:String,q:ControlRequest):Long {
        val r=JSONObject(request("/parent/devices/${q.device}/operations",q.envelope(),token,gateway=true))
        check(r.getString("status")=="accepted"&&r.getString("operation_id")==q.id&&r.getString("device_id")==q.device&&r.getString("policy_epoch")==q.epoch)
        ControlFaults.afterOperation()
        return r.safeLong("version")
    }
    fun status(token:String,current:ControlResult):ControlResult {
        val rows=JSONArray(request("/parent/devices/${current.request.device}/operations",bearer=token,gateway=true))
        check(rows.length()<=100)
        for(i in 0 until rows.length()) { val r=rows.getJSONObject(i); if(r.getString("operation_id")!=current.request.id)continue
            check(r.getString("device_id")==current.request.device)
            val version=r.safeLong("version");check(current.version==null||version==current.version)
            var status=r.getString("status");check(status in setOf("pending","persisted","applied","superseded","expired_for_period","failed","rejected"))
            // This local stack has no enforcement adapter; never invent observed application.
            if(status=="applied")status="persisted"
            return current.copy(status=status,version=version,retryable=false,code="")
        }
        return current // Window omission cannot fabricate an outcome.
    }
    fun pair(token: String)=JSONObject(request("/parent/pairing-sessions",JSONObject(),token,gateway=true))
    fun cancel(token: String,id: String,revoke: Boolean)=JSONObject(request("/rpc/finish_pairing",JSONObject().put("p_session",id).put("p_revoke_incomplete",revoke),token,rest=true))
}

internal class ApiFailure(val status:Int,val code:String):java.io.IOException("REQUEST_FAILED")
internal fun JSONObject.safeLong(key:String,max:Long=9007199254740991):Long {
    val v=get(key);check(v is Number && v.toString().matches(Regex("[0-9]+")))
    return v.toString().toLong().also{check(it in 0..max)}
}
internal fun JSONObject.uuid(key:String):String=getString(key).also{check(it.matches(Regex("[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}")))}
internal fun ControlRequest.envelope():JSONObject {
    val payload=JSONObject()
    when(kind){ControlKind.ADD_TIME->payload.put("seconds",value).put("period_key",period)
        ControlKind.SET_DAILY_LIMIT->payload.put("daily_limit_seconds",value);else->Unit}
    return JSONObject().put("protocol_version",1).put("operation_id",id).put("device_id",device).put("kind",kind.name)
        .put("payload",payload).put("expected_version",expected?:JSONObject.NULL)
}
internal fun ControlRequest.stored():String=JSONObject().put("account",account).put("epoch",epoch).put("request",envelope()).toString()
internal fun storedRequest(text:String):ControlRequest {
    val root=JSONObject(text);val r=root.getJSONObject("request");val kind=ControlKind.valueOf(r.getString("kind"));val p=r.getJSONObject("payload")
    return ControlRequest(r.uuid("operation_id"),root.uuid("account"),r.uuid("device_id"),root.uuid("epoch"),kind,
        if(r.isNull("expected_version"))null else r.safeLong("expected_version"),
        if(kind==ControlKind.ADD_TIME)p.getString("period_key")else null,
        when(kind){ControlKind.ADD_TIME->p.safeLong("seconds",1800).toInt();ControlKind.SET_DAILY_LIMIT->p.safeLong("daily_limit_seconds",86400).toInt();else->null})
}
