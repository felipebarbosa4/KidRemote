package dev.kidremote.child
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Test
import java.io.File

/** Separate synthetic fixture test. Never launches the app, camera or model callback. */
class InvalidQrFixtureTest {
    @Test fun retainedPngIsInvalidPayloadQr() {
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        var stage="READ_PNG"
        fun mark(value:String){stage=value;InstrumentationRegistry.getInstrumentation().sendStatus(0,android.os.Bundle().apply{putString("kr007",value)})}
        try {
            val bitmap=android.graphics.BitmapFactory.decodeFile(File(context.noBackupFilesDir,"scene-invalid.png").path)
            check(bitmap!=null)
            mark("FIXTURE_PNG_LOADED")
            try {
                val pixels=IntArray(bitmap.width*bitmap.height);bitmap.getPixels(pixels,0,bitmap.width,0,0,bitmap.width,bitmap.height)
                mark("FIXTURE_PIXELS_READ")
                val decoded=decodePixels(pixels,bitmap.width,bitmap.height)
                check(decoded!=null);mark("FIXTURE_QR_DECODED")
                check(decoded=="{}");mark("FIXTURE_EXPECTED_NONSECRET_PAYLOAD")
                check(parseQr(decoded)==null);mark("FIXTURE_SCHEMA_REJECTED")
            } finally {bitmap.recycle()}
            InstrumentationRegistry.getInstrumentation().sendStatus(0,android.os.Bundle().apply{putString("kr007","INVALID_PNG_DECODER_AND_SCHEMA_CONTROL_PASS_NOT_CAMERA")})
        }catch(e:Throwable){
            val kind=when(e){is IllegalStateException->"ILLEGAL_STATE";is AssertionError->"ASSERTION";else->"OTHER"}
            mark("FIXTURE_FAILURE_"+stage+"_"+kind)
            throw AssertionError("INVALID_PNG_FIXTURE_CONTROL_FAILED")
        }
    }
}
