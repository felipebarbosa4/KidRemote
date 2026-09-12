package dev.kidremote.child
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Test
import java.io.File

/** Separate synthetic fixture test. Never launches the app, camera or model callback. */
class InvalidQrFixtureTest {
    @Test fun retainedPngIsInvalidPayloadQr() {
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        try {
            val bitmap=android.graphics.BitmapFactory.decodeFile(File(context.noBackupFilesDir,"scene-invalid.png").path)
            check(bitmap!=null)
            try {
                val pixels=IntArray(bitmap.width*bitmap.height);bitmap.getPixels(pixels,0,bitmap.width,0,0,bitmap.width,bitmap.height)
                check(decodePixels(pixels,bitmap.width,bitmap.height)=="{}"&&parseQr("{}")==null)
            } finally {bitmap.recycle()}
            InstrumentationRegistry.getInstrumentation().sendStatus(0,android.os.Bundle().apply{putString("kr007","INVALID_PNG_DECODER_AND_SCHEMA_CONTROL_PASS_NOT_CAMERA")})
        }catch(_:Throwable){throw AssertionError("INVALID_PNG_FIXTURE_CONTROL_FAILED")}
    }
}
