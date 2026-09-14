package dev.kidremote.child.enforcement

import android.content.Context
import android.os.SystemClock
import dev.kidremote.child.accounting.*
import dev.kidremote.child.sync.*

/** Ephemeral OS observations are never restored as applied after process death. */
internal object EnforcementRuntime {
    @Volatile private var service:ChildEnforcementService?=null
    @Volatile private var session:ChildAccounting?=null
    @Volatile private var observation=EnforcementObservation(null,false,"ENFORCEMENT_UNAVAILABLE")
    @Volatile private var checked=0L
    fun consented(c:Context)=c.getSharedPreferences("enforcement-consent",Context.MODE_PRIVATE).getBoolean("accessibility",false)
    fun consent(c:Context){check(c.getSharedPreferences("enforcement-consent",Context.MODE_PRIVATE).edit().putBoolean("accessibility",true).commit())}
    fun connect(s:ChildEnforcementService,e:ChildAccounting){service=s;session=e;observation=EnforcementObservation(null,false,"ADAPTER_PENDING");checked=SystemClock.elapsedRealtime()}
    fun disconnect(s:ChildEnforcementService){if(service===s){service=null;session=null;observation=EnforcementObservation(null,false,"SERVICE_DISCONNECTED");checked=SystemClock.elapsedRealtime()}}
    fun engine():ChildAccounting?=session
    fun sample(c:Context):Sample {
        val usage=c.getSystemService(android.app.AppOpsManager::class.java).checkOpNoThrow(android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,android.os.Process.myUid(),c.packageName)==android.app.AppOpsManager.MODE_ALLOWED
        val s=AndroidAccountingClock.sample(c,consented(c)&&usage&&session!=null)
        return s.copy(signals=s.signals.copy(blocked=observation.attached))
    }
    fun heartbeat(){checked=SystemClock.elapsedRealtime()}
    fun publish(c:Context,value:EnforcementObservation){observation=value;checked=SystemClock.elapsedRealtime()}
    fun persist(c:Context,e:ChildAccounting,value:EnforcementObservation){
        try {
            val id=dev.kidremote.child.IdentityStore(c).read()?:return
            if(id.has("removal"))return
            val result=e.queueObservation(AndroidAccountingClock.sample(c,true),value::matches,org.json.JSONObject().put("epoch",value.target?.epoch).put("version",value.target?.version).put("period",value.target?.period).put("required",value.target?.required).put("attached",value.attached).put("health",value.health).toString()){s->
                org.json.JSONObject().put("protocol_version",1).put("device_id",id.getString("device_id")).put("policy_epoch",s.policy.epoch)
                    .put("applied_version",s.policy.version).put("report_sequence",s.reportSequence).put("period_key",s.periodKey)
                    .put("used_ms",s.usedMs).put("bonus_seconds",s.bonusSeconds).put("remaining_ms",s.remainingMs)
                    .put("manual_lock",s.policy.manualLock).put("restriction_required",s.restrictionRequired)
                    .put("restriction_applied",value.applied(s)).put("health",value.health).put("accounting_status",s.uncertainty.name)
                    .put("observed_at",java.time.Instant.ofEpochMilli(s.anchorUtc+s.cursor-s.anchorElapsed).toString()).toString()
            }
            if(!result.storageFailure&&SyncFaults.automaticAllowed(c))SyncRecovery.notify(c)
        }catch(_:Exception){/* Existing storage/identity failure never manufactures an ACK. */}
    }
    fun report(c:Context,s:Ledger):EnforcementObservation {
        val o=observation
        if(!consented(c))return EnforcementObservation(null,false,"ENFORCEMENT_UNAVAILABLE")
        if(service==null)return EnforcementObservation(null,false,"SERVICE_DISCONNECTED")
        if(!o.matches(s)||SystemClock.elapsedRealtime()-checked>2000)return EnforcementObservation(null,false,"ADAPTER_PENDING")
        return o
    }
    fun text():String=when(observation.health){
        "RESTRICTED_OBSERVED"->"Restrição observada pelo adaptador local · aceitação física pendente"
        "UNRESTRICTED_OBSERVED"->"Sobreposição local ausente · aceitação física pendente"
        "SAFE_SURFACE_AVAILABLE"->"Superfície de sistema disponível · restrição continua solicitada"
        "PERMISSION_REQUIRED"->"Configuração ou permissão necessária · proteção não confirmada"
        else->"Proteção não confirmada · adaptador indisponível ou degradado"
    }
}
