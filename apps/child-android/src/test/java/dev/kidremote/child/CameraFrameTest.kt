package dev.kidremote.child
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import org.junit.Assert.*
import org.junit.Test
import java.nio.ByteBuffer
class CameraFrameTest {
    @Test fun paddedStridesOffsetAndFourOrientations() {
        val n=256;val m=QRCodeWriter().encode("synthetic-stride",BarcodeFormat.QR_CODE,n,n)
        for(rotation in 0..3)for(stride in 1..2){val row=n*stride+17;val b=ByteBuffer.allocate(11+row*n);b.position(11)
            for(y in 0 until n)for(x in 0 until n){val p=when(rotation){0->x to y;1->y to n-1-x;2->n-1-x to n-1-y;else->n-1-y to x};b.put(11+y*row+x*stride,if(m[p.first,p.second])0 else 255.toByte())}
            assertEquals("synthetic-stride",decodeLuma(b,n,n,row,stride));assertEquals(11,b.position())
        }
    }
    @Test fun truncatedAndInvalidPlanesAreUnknown(){assertNull(decodeLuma(ByteBuffer.allocate(20),256,256,256,1));assertNull(decodeLuma(ByteBuffer.allocate(20),0,10,1,1));assertNull(decodeLuma(ByteBuffer.allocate(20),2,2,0,1))}
}
