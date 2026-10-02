package dev.kidremote.parent

import java.time.Instant
import java.util.UUID

data class DeviceReport(val version:Long,val sequence:Long,val period:String,val remainingMs:Long,
    val usedMs:Long,val bonusSeconds:Int,val manualLock:Boolean,val restrictionRequired:Boolean,
    val restrictionApplied:Boolean,val health:String,val receivedAt:Instant)
data class DeviceSummary(val id:String,val nickname:String,val revoked:Boolean,val model:String?=null,
    val epoch:String="",val version:Long=0,val configured:Boolean=false,val dailyLimit:Int?=null,
    val period:String="",val serverUtc:Instant=Instant.EPOCH,val report:DeviceReport?=null) {
    fun reasons():List<String> = buildList {
        if(report?.manualLock==true)add("Bloqueio manual solicitado")
        if(report?.remainingMs==0L)add("Tempo esgotado · Adicione tempo para permitir o uso")
    }
    fun healthText():String = when {
        revoked -> "Removido · novo pareamento necessário"
        !configured -> "Pareado · configuração incompleta · proteção não verificada"
        report==null -> "Aguardando primeiro relatório · proteção não verificada"
        report.health.contains("UPDATE") -> "Atualize o aplicativo do dispositivo"
        report.health.contains("PERMISSION") -> "Permissão necessária no dispositivo"
        report.restrictionApplied&&report.health.startsWith("RESTRICTED_OBSERVED:") -> "Restrição observada pelo adaptador" + if(report.health.endsWith(":NONE")) " · relatório do dispositivo" else " · contabilidade degradada"
        report.health=="UNRESTRICTED_OBSERVED:NONE" -> "Sobreposição ausente no último relatório"
        report.health.startsWith("SAFE_SURFACE_AVAILABLE:") -> "Superfície de sistema disponível · restrição solicitada"
        report.health.endsWith(":CLOCK") -> "Proteção indisponível · horário incerto"
        report.health.endsWith(":HISTORY") -> "Proteção indisponível · contabilidade incompleta"
        report.health.endsWith(":STORAGE") -> "Proteção indisponível · falha de armazenamento"
        else -> "Proteção indisponível · adaptador não confirmado"
    }
    // No Online assertion: receipt freshness alone cannot establish radio/enforcement health.
    fun freshness(ageSinceReadMs:Long):String {
        val r=report?:return "Sem relatório recebido"
        val age=java.time.Duration.between(r.receivedAt,serverUtc).toMillis()+ageSinceReadMs.coerceAtLeast(0)
        return if(age in 0..120000) "Relatório recente · não comprova conexão atual" else "Dados antigos / offline · última informação conhecida"
    }
}
enum class ControlKind { ADD_TIME, LOCK, UNLOCK, SET_DAILY_LIMIT }
data class ControlRequest(val id:String,val account:String,val device:String,val epoch:String,
    val kind:ControlKind,val expected:Long?,val period:String?,val value:Int?) {
    companion object {
        fun create(account:String,d:DeviceSummary,kind:ControlKind,value:Int?=null):ControlRequest {
            require(!d.revoked)
            if(kind==ControlKind.ADD_TIME)require(d.configured&&value in listOf(600,1800))
            if(kind==ControlKind.SET_DAILY_LIMIT)require(value!=null&&value in 0..86400)
            return ControlRequest(UUID.randomUUID().toString(),account,d.id,d.epoch,kind,
                if(kind==ControlKind.ADD_TIME)null else d.version,if(kind==ControlKind.ADD_TIME)d.period else null,value)
        }
    }
}
data class ControlResult(val request:ControlRequest,val status:String="submitting",val version:Long?=null,
    val retryable:Boolean=false,val code:String="") {
    fun text():String=when(status){
        "submitting"->"Enviando solicitação…"
        "accepted"->"Solicitação aceita · aguardando dispositivo"
        "pending"->"Aguardando dispositivo"
        "persisted"->"Persistido no dispositivo · proteção indisponível"
        "applied"->"Execução confirmada pelo dispositivo"
        "superseded"->"Solicitação substituída por uma mais recente"
        "expired_for_period"->"Tempo adicional expirou para o dia solicitado"
        "rejected"->when(code){"VERSION_CONFLICT","OPERATION_CONFLICT","PERIOD_CONFLICT"->"Conflito: atualize e revise antes de uma nova solicitação";"ALLOWANCE_CAP"->"Limite total excedido; revise o valor";else->"Solicitação rejeitada; revise os dados"}
        else->if(retryable)"Resposta não confirmada · tente novamente com a mesma solicitação" else "Falha na solicitação"
    }
}
fun parseDailyLimit(text:String):Int? = if(text.matches(Regex("[0-9]{1,5}")))text.toIntOrNull()?.takeIf{it in 0..86400}else null
fun reportedTime(ms:Long?):String = if(ms==null)"Tempo ainda não informado" else "${ms/60000} min ${(ms/1000)%60} s"
/** A lower report or policy may never replace a newer observed local presentation. */
fun retainNewer(old:DeviceSummary?,next:DeviceSummary):DeviceSummary {
    if(old==null||old.epoch!=next.epoch)return next
    if(next.version<old.version)return old
    val report=if(old.report!=null&&(next.report==null||next.report.sequence<old.report.sequence))old.report else next.report
    return next.copy(report=report)
}
