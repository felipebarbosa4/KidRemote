package dev.kidremote.parent
import org.junit.Assert.*
import org.junit.Test
import java.time.Instant
class ControlsTest {
 private val time=Instant.parse("2026-09-14T00:00:00Z")
 private fun device(remaining:Long=0,manual:Boolean=false)=DeviceSummary("d","Lab",false,epoch="e",version=8,configured=true,dailyLimit=3600,period="1:2026-09-14",serverUtc=time,
  report=DeviceReport(8,4,"1:2026-09-14",remaining,1000,0,manual,true,false,"ENFORCEMENT_UNAVAILABLE:NONE",time))
 @Test fun uuidIsPerIntentAndRetryKeepsEnvelope(){val a=ControlRequest.create("a",device(),ControlKind.ADD_TIME,600);val b=ControlRequest.create("a",device(),ControlKind.ADD_TIME,600);assertNotEquals(a.id,b.id);assertEquals(a,ControlResult(a,retryable=true).request);assertNull(a.expected);assertEquals(device().period,a.period)}
 @Test fun expectedVersionForConflictingChanges(){for(k in listOf(ControlKind.LOCK,ControlKind.UNLOCK,ControlKind.SET_DAILY_LIMIT))assertEquals(8L,ControlRequest.create("a",device(),k,0).expected)}
 @Test fun strictLimitNoClamping(){for(s in listOf("-1","86401","1.5","1e3",""," 2","999999999"))assertNull(parseDailyLimit(s));assertEquals(0,parseDailyLimit("0"));assertEquals(86400,parseDailyLimit("86400"))}
 @Test fun bothReasonsSurvivePresentation(){assertEquals(2,device(manual=true).reasons().size);assertEquals(1,device().reasons().size);assertTrue(device().reasons().single().contains("Adicione tempo"));assertTrue(device(600000,true).reasons().single().contains("manual"))}
 @Test fun noCountdownAndNoOnline(){val d=device(600000);assertEquals("10 min 0 s",reportedTime(d.report?.remainingMs));assertTrue(d.freshness(121000).contains("offline"));assertFalse(d.freshness(0).contains("Online"));assertEquals("10 min 0 s",reportedTime(d.report?.remainingMs))}
 @Test fun olderReportAndPolicyDoNotRollback(){val d=device();assertEquals(d,retainNewer(d,d.copy(version=7)));assertEquals(d.report,retainNewer(d,d.copy(report=d.report!!.copy(sequence=3,remainingMs=999)) ).report)}
 @Test fun statesNeverConflatePersistenceWithEnforcement(){val q=ControlRequest.create("a",device(),ControlKind.LOCK);for(s in listOf("accepted","pending","persisted","superseded","expired_for_period","failed","rejected")){val text=ControlResult(q,s).text();assertFalse(text.contains("Execução confirmada"));assertFalse(text.contains("dispositivo bloqueado"))}}
 @Test fun missingHealthAndSetupNeverHealthy(){assertTrue(device().copy(configured=false).healthText().contains("incompleta"));assertTrue(device().copy(report=null).healthText().contains("primeiro"));assertTrue(device().healthText().contains("indisponível"));assertTrue(device().copy(revoked=true).healthText().contains("Removido"))}
 @Test fun permissionUpdateAndAccountingFailuresNamed(){val d=device();for((health,word) in listOf("UPDATE_REQUIRED" to "Atualize","PERMISSION_REQUIRED" to "Permissão","ENFORCEMENT_UNAVAILABLE:CLOCK" to "horário","ENFORCEMENT_UNAVAILABLE:HISTORY" to "contabilidade","ENFORCEMENT_UNAVAILABLE:STORAGE" to "armazenamento"))assertTrue(d.copy(report=d.report!!.copy(health=health)).healthText().contains(word))}
 @Test fun rejectedAndUncertainRequestsAreDistinct(){val q=ControlRequest.create("a",device(),ControlKind.UNLOCK);assertTrue(ControlResult(q,"rejected",code="VERSION_CONFLICT").text().contains("Conflito"));assertTrue(ControlResult(q,"failed",retryable=true).text().contains("mesma solicitação"))}
}
