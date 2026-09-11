package dev.kidremote.child
import android.os.Process
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.ViewModelProvider
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Rule
import org.junit.Test
import java.io.File
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter

class EnrollmentRuntimeTest {
    @get:Rule val ui=createAndroidComposeRule<ChildActivity>()
    private val context get()=InstrumentationRegistry.getInstrumentation().targetContext
    private fun safe(code:String,action:()->Unit){try{action()}catch(_:Throwable){throw AssertionError(code)}}
    private fun expect(b:Boolean){if(!b)throw AssertionError("ENROLLMENT_ASSERTION_FAILED")}
    private fun result(code:String){InstrumentationRegistry.getInstrumentation().sendStatus(0,android.os.Bundle().apply{putString("kr007",code)})}
    private fun waitPaired()=ui.waitUntil(30000){ui.onAllNodes(hasText("Pareado. Leitura autenticada concluída. Enforcement não ativo; configuração incompleta.")).fetchSemanticsNodes().isNotEmpty()}
    @Test fun decodeRedeemAndRead()=safe("CHILD_DECODE_REDEEM_READ_FAILED") {
        val q=File(context.noBackupFilesDir,"qr-handoff").readText();expect(parseQr(q)!=null)
        val m=QRCodeWriter().encode(q,BarcodeFormat.QR_CODE,512,512)
        val pixels=IntArray(512*512){if(m[it%512,it/512])0xff000000.toInt() else -1}
        val decoded=decodePixels(pixels,512,512);expect(decoded==q)
        val model=ViewModelProvider(ui.activity)[EnrollmentModel::class.java]
        ui.waitUntil(10000){!model.state.loading}
        // Generated QR pixels -> real decoder -> same callback as foreground analyzer.
        // This is NOT camera capture/permission/physical scan evidence.
        ui.runOnIdle{model.decoded(decoded!!)};waitPaired()
        val stored=IdentityStore(context).read()!!;expect(stored.getString("credential").length==43)
        expect(IdentityStore(context).file.length()>28)
        File(context.noBackupFilesDir,"runtime-pid").writeText(Process.myPid().toString())
        result("ACTUAL_DECODER_REDEMPTION_PERSISTENCE_INITIAL_READ_PASS")
    }
    @Test fun restartAndNegatives()=safe("CHILD_RESTART_NEGATIVES_FAILED") {
        expect(Process.myPid()!=File(context.noBackupFilesDir,"runtime-pid").readText().toInt());waitPaired()
        val identity=IdentityStore(context).read()!!;val api=EnrollmentApi()
        for(target in listOf(java.util.UUID.randomUUID().toString(),java.util.UUID.randomUUID().toString())) {
            var denied=false;try{api.request("/device/sync",org.json.JSONObject().put("protocol_version",1).put("after_version",0).put("device_id",target),identity.getString("credential"))}catch(_:Exception){denied=true};expect(denied)
        }
        var denied=false;try{api.request("/parent/pairing-sessions",org.json.JSONObject(),identity.getString("credential"))}catch(_:Exception){denied=true};expect(denied)
        denied=false;try{api.redeem(parseQr(File(context.noBackupFilesDir,"qr-handoff").readText())!!)}catch(_:Exception){denied=true};expect(denied)
        expect(parseQr("{}") == null);expect(parseQr("{\"backend\":\"https://invalid.example\"}")==null)
        result("CHILD_PROCESS_RESTART_SCOPED_DENIALS_REPLAY_PASS")
    }
    @Test fun corruptIdentityRecovery()=safe("CORRUPT_IDENTITY_RECOVERY_FAILED") {
        waitPaired();IdentityStore(context).file.writeBytes(byteArrayOf(1,2,3))
        val model=ViewModelProvider(ui.activity)[EnrollmentModel::class.java]
        ui.runOnIdle{model.restore()};ui.waitUntil(10000){model.state.recovery&&!model.state.loading}
        expect(!model.state.paired);result("CORRUPT_IDENTITY_NO_FALSE_PAIRED_PASS")
    }
}
