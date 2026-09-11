package dev.kidremote.parent

import android.os.Process
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Rule
import org.junit.Test
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import java.util.UUID

/** Actual activity, Compose actions and AuthApi. No fake state/network or admin confirmation.
 * Secrets are generated in the test process and retained only in its local no-backup file.
 * Assertions emit stable codes, never semantics trees, URLs, passwords or provider bodies. */
class ParentRuntimeTest {
    @get:Rule val ui = createAndroidComposeRule<MainActivity>()
    private val target get() = InstrumentationRegistry.getInstrumentation().targetContext
    // Instrumentation executes as the target UID; never write another package's data directory.
    private val fixture get() = File(target.noBackupFilesDir,"runtime-fixture")
    private fun checkThat(ok: Boolean, code: String) { if (!ok) throw AssertionError(code) }
    private fun safe(code: String, action: () -> Unit) {
        try { action() } catch (_: Throwable) { throw AssertionError(code) }
    }
    private fun node(text: String) = ui.onNode(hasText(text) and hasClickAction())
    private fun click(text: String) = safe("UI_ACTION_REJECTED") { node(text).performScrollTo().performClick() }
    private fun field(label: String, value: String) = safe("UI_INPUT_REJECTED") {
        ui.onNode(hasText(label) and hasSetTextAction()).performScrollTo().performTextReplacement(value)
    }
    private fun waitText(text: String) = safe("UI_EXPECTED_STATE_TIMEOUT") {
        ui.waitUntil(30000) { ui.onAllNodes(hasText(text)).fetchSemanticsNodes().isNotEmpty() }
        ui.waitUntil(30000) { ui.onAllNodes(hasText("Aguarde…")).fetchSemanticsNodes().isEmpty() }
    }
    private fun result(code: String) {
        InstrumentationRegistry.getInstrumentation().sendStatus(0,android.os.Bundle().apply { putString("kr006",code) })
    }
    private fun get(path: String): String {
        val c=URL("http://10.0.2.2:$path").openConnection() as HttpURLConnection
        try { c.connectTimeout=2000;c.readTimeout=2000;c.instanceFollowRedirects=false
            checkThat(c.responseCode==200,"LOCAL_HTTP_UNAVAILABLE")
            return c.inputStream.bufferedReader().use { it.readText() }
        } finally { c.disconnect() }
    }
    private fun mail(email: String, type: String): String {
        repeat(30) {
            val messages=JSONObject(get("57365/api/v1/messages")).getJSONArray("messages")
            for(i in 0 until messages.length()) {
                val m=messages.getJSONObject(i)
                if(!m.getJSONArray("To").toString().contains(email)) continue
                val detail=JSONObject(get("57365/api/v1/message/"+m.getString("ID")))
                val content=detail.optString("Text")+detail.optString("HTML")
                val link=Regex("http://127\\.0\\.0\\.1:57361/verify\\?[^\\s\"<>]+").find(content)?.value?.replace("&amp;","&")
                if(link!=null && emailAction(link,type,BackendConfig.emailOrigin)!=null) return link
            }
            Thread.sleep(1000)
        }
        throw AssertionError("LOCAL_EMAIL_ACTION_MISSING")
    }
    private fun login(email: String, pass: String) { field("E-mail sintético",email);field("Senha",pass);click("Entrar") }
    private fun emptyList() { waitText("Preparar sua casa");field("Fuso IANA","Etc/UTC");click("Confirmar e abrir dispositivos");waitText("Nenhum dispositivo cadastrado.") }
    private fun cleared() {
        checkThat(!File(target.noBackupFilesDir,"parent-session").exists(),"SESSION_FILE_REMAINS")
        checkThat(!KeyStore.getInstance("AndroidKeyStore").apply{load(null)}.containsAlias("parent-session-v1"),"SESSION_KEY_REMAINS")
        checkThat(SessionVault(target).read()==null,"SESSION_CREDENTIAL_REMAINS")
    }
    @Test fun enrollAndPersist() = safe("ENROLLMENT_RUNTIME_FAILED") {
        get("57361/health");get("57362/");get("57365/api/v1/messages");result("EMULATOR_BACKEND_CONNECTIVITY_PASS")
        checkThat(!fixture.exists(),"FRESH_FIXTURE_REQUIRED")
        val email="kr006-runtime-"+UUID.randomUUID()+"@example.test"
        val pass="Kr6!"+UUID.randomUUID();val next="Kr6!"+UUID.randomUUID()
        fixture.writeText(JSONObject().put("email",email).put("pass",pass).put("next",next).put("pid",Process.myPid()).toString())
        waitText("Entrar");click("Criar conta");field("E-mail sintético",email);field("Senha",pass);click("Enviar confirmação")
        waitText("Verificar e-mail");result("SIGNUP_VERIFICATION_PENDING_PASS")
        click("Sair e limpar dados locais");waitText("Entrar");login(email,pass)
        waitText("Não foi possível concluir. Verifique os dados ou tente novamente.");cleared();result("UNVERIFIED_APP_LOGIN_DENIED")
        click("Criar conta");field("E-mail sintético",email);field("Senha",pass);click("Enviar confirmação");waitText("Verificar e-mail")
        field("Link do e-mail local",mail(email,"signup"));click("Verificar link");waitText("E-mail confirmado. Entre com sua senha.")
        result("REAL_EMAIL_CONFIRMATION_PASS");login(email,pass);emptyList();result("LOGIN_HOUSEHOLD_EMPTY_LIST_PASS")
        checkThat(File(target.noBackupFilesDir,"parent-session").length()>28,"ENCRYPTED_SESSION_MISSING")
        checkThat(SessionVault(target).read()!=null,"ACTUAL_VAULT_DECRYPT_FAILED")
        ui.activityRule.scenario.recreate();waitText("Nenhum dispositivo cadastrado.")
        checkThat(Process.myPid()==JSONObject(fixture.readText()).getInt("pid"),"RECREATION_NOT_SAME_PROCESS")
        result("ACTIVITY_RECREATION_PASS")
    }
    @Test fun restoreAndLogout() = safe("RESTORE_LOGOUT_RUNTIME_FAILED") {
        val f=JSONObject(fixture.readText());checkThat(Process.myPid()!=f.getInt("pid"),"PROCESS_DID_NOT_RESTART")
        emptyList();result("PROCESS_RESTART_VAULT_SESSION_RESTORED_PASS")
        click("Sair e limpar dados locais");waitText("Entrar");cleared()
        safe("SENSITIVE_FORM_NOT_CLEARED") {
            val text=ui.onNode(hasText("E-mail sintético") and hasSetTextAction()).fetchSemanticsNode().config[androidx.compose.ui.semantics.SemanticsProperties.EditableText].text
            checkThat(text.isEmpty(),"EMAIL_REMAINS")
        }
        f.put("pid",Process.myPid());fixture.writeText(f.toString());result("LOGOUT_STORAGE_KEY_UI_CLEAR_PASS")
    }
    @Test fun restartLoggedOutAndRecover() = safe("RECOVERY_RUNTIME_FAILED") {
        val f=JSONObject(fixture.readText());checkThat(Process.myPid()!=f.getInt("pid"),"PROCESS_DID_NOT_RESTART")
        waitText("Entrar");cleared();result("RESTART_AFTER_LOGOUT_UNAUTHENTICATED_PASS")
        click("Esqueci a senha");field("E-mail sintético",f.getString("email"));click("Enviar recuperação")
        waitText("Consulte a mensagem local, se a conta existir.")
        field("Link do e-mail local",mail(f.getString("email"),"recovery"));click("Verificar link");waitText("Nova senha")
        checkThat(!File(target.noBackupFilesDir,"parent-session").exists(),"RECOVERY_SESSION_PERSISTED")
        field("Senha",f.getString("next"));click("Salvar nova senha");waitText("Senha alterada. Entre novamente.")
        login(f.getString("email"),f.getString("pass"));waitText("Não foi possível concluir. Verifique os dados ou tente novamente.")
        login(f.getString("email"),f.getString("next"));emptyList();result("REAL_EMAIL_RECOVERY_OLD_PASSWORD_DENIED_NEW_LOGIN_PASS")
    }
    @Test fun networkFailureAndRecovery() = safe("NETWORK_RECOVERY_RUNTIME_FAILED") {
        waitText("Preparar sua casa");field("Fuso IANA","Etc/UTC");click("Confirmar e abrir dispositivos")
        waitText("Não foi possível concluir. Verifique os dados ou tente novamente.");result("ACTUAL_REST_OUTAGE_RECOVERABLE_UI_PASS")
        File(target.filesDir,"kr006-restore-rest").writeText("RESTORE")
        var ready=false
        repeat(45) { if(!ready) { try { get("57362/");ready=true } catch(_:Exception){Thread.sleep(1000)} } }
        checkThat(ready,"REST_NOT_RESTORED");emptyList();result("NETWORK_RECOVERY_SAME_PROCESS_PASS")
        click("Sair e limpar dados locais");waitText("Entrar");cleared()
        checkThat(fixture.delete(),"TEST_FIXTURE_CLEANUP_FAILED");File(target.filesDir,"kr006-restore-rest").delete()
        result("RUNTIME_FINAL_LOGOUT_CLEANUP_PASS")
    }
    @Test fun createEnrollmentQr() = safe("PARENT_QR_RUNTIME_FAILED") {
        enrollAndPersist()
        click("Criar QR de pareamento")
        waitText("QR de uso único. Não compartilhe. Expira em até cinco minutos.")
        click("Cancelar ou verificar QR");waitText("QR cancelado.")
        click("Criar QR de pareamento");waitText("QR de uso único. Não compartilhe. Expira em até cinco minutos.")
        val model=androidx.lifecycle.ViewModelProvider(ui.activity)[ParentModel::class.java]
        var qr:String?=null;ui.runOnIdle {qr=model.state.qr}
        checkThat(qr!=null,"ACTUAL_PARENT_QR_MISSING")
        // Test-only local capability handoff, never an image upload or parent session transfer.
        File(target.noBackupFilesDir,"qr-handoff").writeText(qr!!)
        result("PARENT_AUTH_CREATE_DISPLAY_CANCEL_FRESH_QR_PASS")
    }
    @Test fun parentSeesEnrollment() = safe("PARENT_ENROLLED_LIST_FAILED") {
        waitText("Preparar sua casa");field("Fuso IANA","Etc/UTC");click("Confirmar e abrir dispositivos")
        waitText("Dispositivo Android");waitText("Pareado · configuração incompleta · proteção não verificada")
        val model=androidx.lifecycle.ViewModelProvider(ui.activity)[ParentModel::class.java]
        ui.runOnIdle {checkThat(model.state.devices.size==1,"NOT_EXACTLY_ONE_DEVICE")}
        result("PARENT_ACTUAL_ENROLLED_LIST_PASS")
    }
    private fun openExistingList() {waitText("Preparar sua casa");field("Fuso IANA","Etc/UTC");click("Confirmar e abrir dispositivos");waitText("Controles e enforcement não estão disponíveis nesta etapa.")}
    private fun exportNewQr() {
        click("Criar QR de pareamento");waitText("QR de uso único. Não compartilhe. Expira em até cinco minutos.")
        val model=androidx.lifecycle.ViewModelProvider(ui.activity)[ParentModel::class.java]
        var q:String?=null;ui.runOnIdle{q=model.state.qr};checkThat(q!=null,"ACTUAL_QR_MISSING")
        File(target.noBackupFilesDir,"qr-handoff").writeText(q!!)
    }
    @Test fun prepareInterruptedQr()=safe("PARENT_INTERRUPTION_QR_FAILED") {openExistingList();exportNewQr();result("PARENT_FRESH_INTERRUPTION_QR_PASS")}
    @Test fun recoverInterruptedQr()=safe("PARENT_REVOKE_FRESH_QR_FAILED") {
        openExistingList();click("Cancelar ou verificar QR")
        waitText("QR consumido. Se a credencial não foi salva, revogue o pareamento incompleto e gere outro QR.")
        click("Revogar pareamento incompleto");waitText("Pareamento incompleto revogado. Gere outro QR.")
        exportNewQr();result("PARENT_REVOKED_LOST_RESPONSE_IDENTITY_FRESH_QR_PASS")
    }
}
