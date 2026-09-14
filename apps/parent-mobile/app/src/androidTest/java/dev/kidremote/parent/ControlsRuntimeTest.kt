package dev.kidremote.parent
import android.os.Bundle
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.ViewModelProvider
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Rule
import org.junit.Test
import java.io.File

/** Real Compose actions and Auth/gateway reports. Emits only bounded result codes. */
class ControlsRuntimeTest {
 @get:Rule val ui=createAndroidComposeRule<MainActivity>()
 private val context get()=InstrumentationRegistry.getInstrumentation().targetContext
 private val model get()=ViewModelProvider(ui.activity)[ParentModel::class.java]
 private fun ck(v:Boolean){if(!v)throw AssertionError("CONTROL_ASSERTION")}
 private fun result(code:String){InstrumentationRegistry.getInstrumentation().sendStatus(0,Bundle().apply{putString("kr010",code)})}
 private fun waitReady(){ui.waitUntil(30000){!model.state.loading};ui.waitForIdle()}
 private fun click(s:String){ui.onNode(hasText(s) and hasClickAction()).performScrollTo().performClick();waitReady()}
 private fun text(s:String){ui.onNodeWithText(s).assertExists()}
 private fun input(s:String){ui.onNode(hasText("Limite diário em segundos (0–86400)") and hasSetTextAction()).performScrollTo().performTextReplacement(s)}
 private fun open(){waitReady();if(model.state.screen==Screen.SETUP){ui.onNode(hasText("Fuso IANA") and hasSetTextAction()).performTextReplacement("Etc/UTC");click("Confirmar e abrir dispositivos")};ck(model.state.screen==Screen.DEVICES);click("Abrir Dispositivo Android");ck(model.state.screen==Screen.DETAIL)}
 private fun report()=model.state.devices.single().report!!
 @Test fun step(){try{
  val args=InstrumentationRegistry.getArguments();val step=args.getString("step")!!;open()
  when(step){
   "limit"->{input(args.getString("value")!!);click("Salvar limite diário");ck(model.state.control?.status=="accepted");text("Solicitação aceita · aguardando dispositivo")}
   "report"->{val expected=args.getString("remaining")!!.toLong();ck(report().remainingMs==expected);text(reportedTime(expected));ck(!report().restrictionApplied);text(model.state.devices.single().healthText());
     if(args.getString("manual")=="true")text("Bloqueio manual solicitado")
     if(expected==0L)text("Tempo esgotado · Adicione tempo para permitir o uso")
     args.getString("outcome")?.let{ck(model.state.control?.status==it);text(model.state.control!!.text())}}
   "plus10","plus30","lock","unlock","loss"->{
     val before=report();if(step=="loss")ControlFaults.loseNextResponse=true
     click(when(step){"plus10"->"+10 min";"plus30","loss"->"+30 min";"lock"->"Solicitar bloqueio";else->"Solicitar desbloqueio"})
     ck(report()==before);val c=model.state.control!!
     ck(c.status==if(step=="loss")"failed" else "accepted")
     if(step=="loss"){ck(c.retryable);File(context.noBackupFilesDir,"control-retry-id").writeText(c.request.id)}
     text(c.text());ck(!c.text().contains("Execução confirmada"))}
   "retry"->{val id=File(context.noBackupFilesDir,"control-retry-id").readText();
     click("Repetir mesma solicitação");ck(model.state.control!!.request.id==id);ck(model.state.control!!.status=="accepted")
     click("Atualizar relatório");ck(model.state.control!!.request.id==id);ck(model.state.control!!.status=="pending")}
   "invalid"->{val before=model.state.control;for(value in listOf("-1","86401","1.5")){input(value);click("Salvar limite diário");text("Valor inválido. Informe de 0 a 86400 segundos.");ck(model.state.control==before)}}
   "outage"->{val before=report();File(context.noBackupFilesDir,"control-ready").writeText("READY")
     repeat(300){if(!File(context.noBackupFilesDir,"control-release").exists())Thread.sleep(100)}
     ck(File(context.noBackupFilesDir,"control-release").delete());click("Atualizar relatório");ck(report()==before);ck(model.state.message.isNotEmpty());text("Dados mantidos com o horário do último relatório. Use Atualizar para tentar novamente.")}
   "stale"->{ck(model.state.devices.single().freshness(0).contains("offline"));ck(ui.onAllNodes(hasText("Online")).fetchSemanticsNodes().isEmpty())}
   "conflict"->{File(context.noBackupFilesDir,"control-ready").writeText("READY");repeat(300){if(!File(context.noBackupFilesDir,"control-release").exists())Thread.sleep(100)};ck(File(context.noBackupFilesDir,"control-release").delete());click("Solicitar desbloqueio");ck(model.state.control!!.status=="rejected");text("Conflito: atualize e revise antes de uma nova solicitação")}
   "accessibility"->{for(label in listOf("+10 min","+30 min","Solicitar bloqueio","Solicitar desbloqueio","Salvar limite diário")){
     val node=ui.onNode(hasText(label) and hasClickAction());node.performScrollTo().assertIsDisplayed().assertHeightIsAtLeast(androidx.compose.ui.unit.Dp(48f));
     val layouts=mutableListOf<androidx.compose.ui.text.TextLayoutResult>();ui.onNodeWithText(label,useUnmergedTree=true).performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.GetTextLayoutResult){it(layouts)};ck(layouts.none{it.hasVisualOverflow})
    }}
   "logout"->{click("Sair e limpar dados locais");ck(model.state.devices.isEmpty()&&model.state.control==null);ck(SessionVault(context).read()==null);ck(SessionVault(context,"parent-control",strict=true).read()==null);text("Entrar")}
   else->error("UNKNOWN_STEP")
  };result("PARENT_"+step.uppercase()+"_PASS")
 }catch(e:Throwable){val line=e.stackTrace.firstOrNull{it.className==javaClass.name}?.lineNumber?:0;result("PARENT_FAILURE_LINE_"+line.coerceAtLeast(0));throw AssertionError("CONTROL_RUNTIME_FAILED")}}
}
