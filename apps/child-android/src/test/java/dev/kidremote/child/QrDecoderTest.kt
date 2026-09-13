package dev.kidremote.child
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import org.junit.Assert.*
import org.junit.Test
class QrDecoderTest {
    @Test fun actualDecoderReadsGeneratedQr(){val m=QRCodeWriter().encode("synthetic-qr-decoder",BarcodeFormat.QR_CODE,256,256);val p=IntArray(256*256){if(m[it%256,it/256])0xff000000.toInt() else -1};assertEquals("synthetic-qr-decoder",decodePixels(p,256,256))}
    @Test fun blankIsUnknown(){assertNull(decodePixels(IntArray(256*256){-1},256,256))}
    @Test fun invalidBoundsAreRejected(){assertNull(decodePixels(intArrayOf(0),0,0))}
}
