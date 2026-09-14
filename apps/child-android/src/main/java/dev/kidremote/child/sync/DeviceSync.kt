package dev.kidremote.child.sync
import android.content.Context
import dev.kidremote.child.IdentityStore
import dev.kidremote.child.EnrollmentApi
import dev.kidremote.child.DeviceRemoved
import dev.kidremote.child.accounting.*
import org.json.JSONObject
import java.time.Instant

/** Explicit single-flight sync; pending ACK survives restart. No push, timer or enforcement adapter. */
internal class DeviceSync(private val context:Context,private val sample:()->Sample={AndroidAccountingClock.sample(context,false)}):AutoCloseable {
    private val identity=IdentityStore(context)
    private val engine=ChildAccounting(context)
    private val api=EnrollmentApi()
    companion object {private val lock=Any()}
    private fun sendPending(id:JSONObject) {
        val s=engine.read();if(s.storageFailure)throw LocalStorageFailure()
        val pending=s.ledger?.pendingAck?:return
        val body=Wire.parse(pending)
        val r=api.request("/device/ack",body,id.getString("credential"),parse=Wire::parse)
        SyncFaults.ackResponse() // REAL successful HTTP response, before local delivery confirmation.
        Wire.keys(r,setOf("code","report_sequence","received_at"))
        require(Wire.string(r,"code")=="ACKNOWLEDGED"&&Wire.number(r,"report_sequence")==s.ledger.reportSequence)
        Instant.parse(Wire.string(r,"received_at"))
        if(engine.confirmReport(s.ledger.reportSequence,sample()).storageFailure)throw LocalStorageFailure()
    }
    fun sync():AccountingResult=synchronized(lock) {
        val id=identity.read()?:error("IDENTITY_REQUIRED");check(!id.has("removal"))
        try {
            if(id.has("rotation"))api.contact(identity,id)
            if(id.optBoolean("accounting_initialized",false))sendPending(id)
            val old=engine.read();if(old.storageFailure)throw LocalStorageFailure()
            val after=old.ledger?.policy?.version?:0
            fun first()=api.request("/device/sync",JSONObject().put("protocol_version",1).put("after_version",after),id.getString("credential"),id,{Wire.parse(SyncFaults.syncResponse(it))})
            var r=first()
            if(r.getJSONObject("credential_lifecycle").getBoolean("rotation_due")){api.contact(identity,id);r=first()}
            if(r.optString("kind")=="ENROLLMENT_BOOTSTRAP") {
                check(old.ledger==null&&!r.getBoolean("policy_configured")&&r.isNull("daily_limit_seconds")&&r.getString("device_id")==id.getString("device_id")&&r.getString("policy_epoch")==id.getString("policy_epoch"))
                return@synchronized old
            }
            // Retain no operation history. Only commit canonical state after a complete compatible sequence.
            for(restart in 0..1) {
                try {
                    Wire.policy(r,id)
                    val fixed=JSONObject(r.toString()).apply{remove("operations");remove("next_cursor")}.toString()
                    var current=r;var last=0L
                    for(page in 0..9) {
                        Wire.policy(current,id)
                        check(JSONObject(current.toString()).apply{remove("operations");remove("next_cursor")}.toString()==fixed)
                        val ops=current.getJSONArray("operations")
                        for(i in 0 until ops.length()){val v=ops.getJSONObject(i).getLong("version");check(v>last);last=v}
                        SyncProgress(context).checkpoint(Wire.number(r,"version"),page)
                        SyncFaults.pagePersisted(page)
                        if(current.isNull("next_cursor"))break
                        check(page<9&&ops.length()==100)
                        val cursor=Wire.string(current,"next_cursor");check(cursor==Wire.string(r,"snapshot_id")+":"+((page+1)*100))
                        current=api.request("/device/sync",JSONObject().put("protocol_version",1).put("after_version",after).put("cursor",cursor),id.getString("credential"),id,{Wire.parse(SyncFaults.syncResponse(it))})
                    }
                    break
                }catch(e:RestartSnapshot){if(restart==1)throw RetryableSync();r=first()}
            }
            val policy=Wire.policy(r,id);val utc=Instant.parse(Wire.string(r,"server_utc")).toEpochMilli()
            val result=engine.applySnapshot(policy,sample(),utc){s->JSONObject().put("protocol_version",1).put("device_id",id.getString("device_id")).put("policy_epoch",s.policy.epoch)
                .put("applied_version",s.policy.version).put("report_sequence",s.reportSequence).put("period_key",s.periodKey).put("used_ms",s.usedMs).put("bonus_seconds",s.bonusSeconds).put("remaining_ms",s.remainingMs)
                .put("manual_lock",s.policy.manualLock).put("restriction_required",s.restrictionRequired).put("restriction_applied",false).put("health","ENFORCEMENT_UNAVAILABLE").put("accounting_status",s.uncertainty.name).put("observed_at",Wire.string(r,"server_utc")).toString()}
            if(result.storageFailure)throw LocalStorageFailure();SyncProgress(context).clear();SyncFaults.persisted();sendPending(id);engine.read()
        }catch(e:DeviceRemoved){id.put("removal",e.removal);identity.save(id);throw e}
    }
    fun retryAck()=synchronized(lock){sendPending(identity.read()?:error("IDENTITY_REQUIRED"))}
    override fun close(){engine.close()}
}
