package dev.kidremote.child

import android.Manifest
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Handler
import android.os.Looper
import android.os.Process
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelProvider
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Rule
import org.junit.Test
import java.io.File
import java.security.KeyStore

/** Real platform camera/Keystore tests. No decoder input or successful state injection. */
class CameraStorageRuntimeTest {
    @get:Rule val ui=createAndroidComposeRule<ChildActivity>()
    private val context get()=InstrumentationRegistry.getInstrumentation().targetContext
    private val model get()=ViewModelProvider(ui.activity)[EnrollmentModel::class.java]
    private fun expect(value:Boolean){if(!value)throw AssertionError("CAMERA_STORAGE_ASSERTION_FAILED")}
    private fun safe(code:String,body:()->Unit){try{body()}catch(e:Throwable){result(when(e){is AssertionError->"FAILURE_ASSERTION";is IllegalStateException->"FAILURE_ILLEGAL_STATE";is java.util.concurrent.TimeoutException->"FAILURE_TIMEOUT";else->"FAILURE_OTHER"});throw AssertionError(code)}}
    private fun result(code:String){InstrumentationRegistry.getInstrumentation().sendStatus(0,android.os.Bundle().apply{putString("kr007",code)})}
    private fun settled(){ui.waitUntil(30000){!model.state.loading}}
    private fun paired(){ui.waitUntil(30000){model.state.paired&&model.state.message.contains("Leitura autenticada concluída")}}
    private fun scan(){settled();ui.onNodeWithText("Escanear QR do responsável").performClick()}
    private fun keys()=KeyStore.getInstance("AndroidKeyStore").apply{load(null)}
    private fun permissionButton(name:String){val d=UiDevice.getInstance(InstrumentationRegistry.getInstrumentation());val button=d.wait(Until.findObject(By.res("com.android.permissioncontroller",name)),10000);checkNotNull(button).click()}
    private inner class CameraProbe:AutoCloseable {
        private val manager=context.getSystemService(CameraManager::class.java)
        private val id=manager.cameraIdList.first{manager.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING)==CameraCharacteristics.LENS_FACING_BACK}
        @Volatile var available:Boolean?=null
        private val callback=object:CameraManager.AvailabilityCallback(){override fun onCameraAvailable(cameraId:String){if(cameraId==id)available=true};override fun onCameraUnavailable(cameraId:String){if(cameraId==id)available=false}}
        init{manager.registerAvailabilityCallback(callback,Handler(Looper.getMainLooper()))}
        fun waitFor(free:Boolean){ui.waitUntil(15000){available==free}}
        override fun close(){manager.unregisterAvailabilityCallback(callback)}
    }
    @Test fun permissionAndLifecycle()=safe("CAMERA_PERMISSION_LIFECYCLE_FAILED") {
        settled();expect(!model.state.paired);expect(context.checkSelfPermission(Manifest.permission.CAMERA)==PackageManager.PERMISSION_DENIED)
        CameraProbe().use{camera->
            camera.waitFor(true);Thread.sleep(800);expect(camera.available==true);result("NO_CAMERA_BEFORE_EXPLICIT_SCAN_PASS")
            scan();result("SCAN_PERMISSION_REQUEST_CLICKED");permissionButton("permission_deny_button");result("SYSTEM_PERMISSION_DENY_CLICKED")
            ui.waitUntil(10000){ui.onAllNodes(hasText("Câmera recusada. Pareamento não concluído; tente novamente quando desejar.")).fetchSemanticsNodes().isNotEmpty()}
            expect(!IdentityStore(context).file.exists()&&!IdentityStore(context).pending.exists());camera.waitFor(true);result("ACTUAL_CAMERA_PERMISSION_DENIAL_NO_REDEMPTION_PASS")
            scan();permissionButton("permission_allow_foreground_only_button");camera.waitFor(false);result("ACTUAL_PERMISSION_GRANT_CAMERA_OPEN_PASS")
            ui.onNodeWithText("Parar câmera").performClick();camera.waitFor(true)
            scan();camera.waitFor(false);ui.activityRule.scenario.moveToState(Lifecycle.State.CREATED);camera.waitFor(true)
            ui.activityRule.scenario.moveToState(Lifecycle.State.RESUMED);settled();expect(camera.available==true)
            scan();camera.waitFor(false);ui.activityRule.scenario.recreate();camera.waitFor(true);settled()
            scan();camera.waitFor(false);ui.onNodeWithText("Parar câmera").performClick();camera.waitFor(true)
            expect(!IdentityStore(context).pending.exists());result("CANCEL_BACKGROUND_RECREATE_EXPLICIT_REACQUIRE_PASS")
        }
    }
    @Test fun revocationVictim()=safe("CAMERA_REVOCATION_VICTIM_FAILED") {
        CameraProbe().use{camera->scan();camera.waitFor(false)
            File(context.noBackupFilesDir,"camera-revoke-ready").writeText(Process.myPid().toString())
            result("CAMERA_OPEN_BEFORE_HOST_PERMISSION_REVOCATION")
            Thread.sleep(60000);throw AssertionError("OS_DID_NOT_TERMINATE_REVOKED_PROCESS")
        }
    }
    @Test fun afterPermissionRevocation()=safe("CAMERA_REVOKED_RESTART_FAILED") {
        settled();expect(context.checkSelfPermission(Manifest.permission.CAMERA)==PackageManager.PERMISSION_DENIED)
        expect(Process.myPid()!=File(context.noBackupFilesDir,"camera-revoke-ready").readText().toInt())
        CameraProbe().use{it.waitFor(true);expect(!model.state.paired&&!IdentityStore(context).pending.exists())}
        scan();permissionButton("permission_allow_foreground_only_button")
        CameraProbe().use{it.waitFor(false);ui.onNodeWithText("Parar câmera").performClick();it.waitFor(true)}
        result("OS_REVOKE_PROCESS_RESTART_EXPLICIT_REGRANT_PASS")
    }
    @Test fun invalidCameraQr()=safe("INVALID_VIRTUAL_CAMERA_QR_FAILED") {
        scan();ui.waitUntil(45000){model.state.message.startsWith("QR inválido")&&!model.state.loading}
        expect(!model.state.paired&&!IdentityStore(context).file.exists()&&!IdentityStore(context).pending.exists())
        result("ACTUAL_CAMERA_INVALID_QR_NO_IDENTITY_PASS")
    }
    @Test fun invalidCameraBoundary()=safe("INVALID_CAMERA_BOUNDARY_FAILED") {
        settled();expect(!model.state.paired&&!model.state.recovery)
        // Separate fixture-generation control, never counted as camera acquisition.
        val bitmap=android.graphics.BitmapFactory.decodeFile(File(context.noBackupFilesDir,"scene-invalid.png").path)
        expect(bitmap!=null);val pixels=IntArray(bitmap.width*bitmap.height);bitmap.getPixels(pixels,0,bitmap.width,0,0,bitmap.width,bitmap.height)
        expect(decodePixels(pixels,bitmap.width,bitmap.height)=="{}"&&parseQr("{}")==null);bitmap.recycle()
        result("INVALID_PNG_DECODER_AND_SCHEMA_CONTROL_PASS_NOT_CAMERA")
        for(i in 0..7)EnrollmentFaults.cameraCounts.set(i,0)
        var open=false;var verdict="UNRUN"
        try {
            CameraProbe().use{camera->
                scan();if(context.checkSelfPermission(Manifest.permission.CAMERA)!=PackageManager.PERMISSION_GRANTED)permissionButton("permission_allow_foreground_only_button")
                camera.waitFor(false);open=true;result("CAMERA_OPEN_OBSERVED")
                ui.waitUntil(45000){model.state.message.startsWith("QR inválido")&&!model.state.loading}
                expect(!model.state.paired&&!IdentityStore(context).file.exists()&&!IdentityStore(context).pending.exists())
                ui.onNodeWithText("QR inválido. Use apenas o QR do responsável neste ambiente.").assertIsDisplayed()
                verdict="REJECTED_IN_UI";result("ACTUAL_CAMERA_INVALID_QR_NO_IDENTITY_PASS")
            }
        } catch(e:Throwable){verdict=when(e){is ComposeTimeoutException->"COMPOSE_TIMEOUT";is AssertionError->"ASSERTION";is IllegalStateException->"ILLEGAL_STATE";else->"OTHER"};throw AssertionError("INVALID_CAMERA_BOUNDARY_FAILED")}
        finally {
            val counts=(0..7).map{EnrollmentFaults.cameraCounts.get(it)}
            val metrics=org.json.JSONObject().put("counts",org.json.JSONArray(counts)).put("cameraOpen",open).put("verdict",verdict).put("schemaRejected",model.state.message.startsWith("QR inválido")).put("scanningUi",ui.onAllNodes(hasText("Parar câmera")).fetchSemanticsNodes().isNotEmpty())
            InstrumentationRegistry.getInstrumentation().sendStatus(0,android.os.Bundle().apply{putString("kr007metrics",metrics.toString())})
        }
    }
    @Test fun validCameraQr()=safe("VALID_VIRTUAL_CAMERA_QR_FAILED") {
        scan();paired();val first=IdentityStore(context).read()!!
        CameraProbe().use{it.waitFor(true)};Thread.sleep(2000)
        expect(IdentityStore(context).read()!!.getString("device_id")==first.getString("device_id"))
        File(context.noBackupFilesDir,"camera-identity-id").writeText(first.getString("device_id"))
        File(context.noBackupFilesDir,"camera-identity-pid").writeText(Process.myPid().toString())
        result("VIRTUAL_CAMERA_CAMERAX_DECODER_REAL_REDEMPTION_PASS")
    }
    @Test fun sameIdentityAfterCameraRestart()=safe("CAMERA_IDENTITY_RESTART_FAILED") {
        paired();expect(Process.myPid()!=File(context.noBackupFilesDir,"camera-identity-pid").readText().toInt())
        expect(IdentityStore(context).read()!!.getString("device_id")==File(context.noBackupFilesDir,"camera-identity-id").readText())
        result("CAMERA_ENROLLED_SAME_IDENTITY_PROCESS_RESTART_PASS")
    }
    @Test fun backendOutagePreservesIdentity()=safe("STORAGE_OUTAGE_FAILED") {
        settled();expect(model.state.paired&&model.state.message.contains("contato não confirmado"))
        val before=IdentityStore(context).file.readBytes();val identity=IdentityStore(context).read()!!
        File(context.noBackupFilesDir,"gateway-restore-ready").writeText("READY")
        var reached=false
        repeat(40){if(!reached){try{EnrollmentApi().initial(identity);reached=true}catch(_:Exception){Thread.sleep(500)}}}
        expect(reached);ui.runOnIdle{model.restore()};paired()
        expect(before.contentEquals(IdentityStore(context).file.readBytes()))
        expect(IdentityStore(context).read()!!.getString("device_id")==identity.getString("device_id"));expect(!IdentityStore(context).pending.exists())
        result("REAL_GATEWAY_OUTAGE_SAME_CIPHERTEXT_IDENTITY_RECOVERY_PASS")
    }
    @Test fun authenticatedCiphertextCorruption()=safe("CIPHERTEXT_TAMPER_FAILED") {
        paired();val store=IdentityStore(context);val original=store.file.readBytes();val altered=original.clone();altered[altered.lastIndex]=(altered.last().toInt() xor 1).toByte()
        store.file.writeBytes(altered);ui.runOnIdle{model.restore()};ui.waitUntil(10000){!model.state.loading&&model.state.recovery};expect(!model.state.paired)
        result("AUTHENTICATED_CIPHERTEXT_TAMPER_REJECTED")
        store.file.writeBytes(original);ui.runOnIdle{model.restore()};paired();result("ORIGINAL_CIPHERTEXT_CONTROL_RECOVERED_PASS")
    }
    @Test fun missingKeyDiagnostic()=safe("MISSING_KEY_DIAGNOSTIC_FAILED") {
        paired();keys().deleteEntry("device-identity-v1");expect(!keys().containsAlias("device-identity-v1"))
        ui.runOnIdle{model.restore()};ui.waitUntil(10000){!model.state.loading&&model.state.recovery};expect(!model.state.paired)
        expect(!keys().containsAlias("device-identity-v1"));result("MISSING_KEY_FAIL_CLOSED_NO_KEY_CREATION_PASS")
    }
    @Test fun isolatedCiphertextWithoutKey()=safe("ISOLATED_CIPHERTEXT_RESTORE_FAILED") {
        settled();expect(model.state.recovery&&!model.state.paired)
        var rejected=false;try{IdentityStore(context).read()}catch(_:Exception){rejected=true};expect(rejected)
        expect(!keys().containsAlias("device-identity-v1"))
        result("CLEAN_INSTALL_CIPHERTEXT_WITHOUT_ORIGINAL_KEY_REJECTED_PASS")
    }
}
