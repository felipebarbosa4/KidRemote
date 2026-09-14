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
        val s=engine.read();if(s.storageFailure)error("LOCAL_STORAGE_UNAVAILABLE")
        val pending=s.ledger?.pendingAck?:return
        val body=Wire.parse(pending)
        val r=api.request("/device/ack",body,id.getString("credential"),parse=Wire::parse)
        SyncFaults.ackResponse() // REAL successful HTTP response, before local delivery confirmation.
        Wire.keys(r,setOf("code","report_sequence","received_at"))
        require(Wire.string(r,"code")=="ACKNOWLEDGED"&&Wire.number(r,"report_sequence")==s.ledger.reportSequence)
        Instant.parse(Wire.string(r,"received_at"))
        check(!engine.confirmReport(s.ledger.reportSequence,sample()).storageFailure)
    }
    fun sync():AccountingResult=synchronized(lock) {
        val id=identity.read()?:error("IDENTITY_REQUIRED");check(!id.has("removal"))
        try {
            if(id.has("rotation"))api.contact(identity,id)
            if(id.optBoolean("accounting_initialized",false))sendPending(id)
            val old=engine.read();if(old.storageFailure)error("LOCAL_STORAGE_UNAVAILABLE")
            var r=api.request("/device/sync",JSONObject().put("protocol_version",1).put("after_version",old.ledger?.policy?.version?:0),id.getString("credential"),id,{Wire.parse(SyncFaults.syncResponse(it))})
            if(r.optString("kind")=="ENROLLMENT_BOOTSTRAP") {
                check(old.ledger==null&&!r.getBoolean("policy_configured")&&r.isNull("daily_limit_seconds")&&r.getString("device_id")==id.getString("device_id")&&r.getString("policy_epoch")==id.getString("policy_epoch"))
                return@synchronized old
            }
            Wire.policy(r,id)
            if(r.getJSONObject("credential_lifecycle").getBoolean("rotation_due"))r=api.contact(identity,id)
            val policy=Wire.policy(r,id);val utc=Instant.parse(Wire.string(r,"server_utc")).toEpochMilli()
            val result=engine.applySnapshot(policy,sample(),utc){s->JSONObject().put("protocol_version",1).put("device_id",id.getString("device_id")).put("policy_epoch",s.policy.epoch)
                .put("applied_version",s.policy.version).put("report_sequence",s.reportSequence).put("period_key",s.periodKey).put("used_ms",s.usedMs).put("bonus_seconds",s.bonusSeconds).put("remaining_ms",s.remainingMs)
                .put("manual_lock",s.policy.manualLock).put("restriction_required",s.restrictionRequired).put("restriction_applied",false).put("health","ENFORCEMENT_UNAVAILABLE").put("accounting_status",s.uncertainty.name).put("observed_at",Wire.string(r,"server_utc")).toString()}
            check(!result.storageFailure);SyncFaults.persisted();sendPending(id);engine.read()
        }catch(e:DeviceRemoved){id.put("removal",e.removal);identity.save(id);throw e}
    }
    fun retryAck()=synchronized(lock){sendPending(identity.read()?:error("IDENTITY_REQUIRED"))}
    override fun close(){engine.close()}
}
