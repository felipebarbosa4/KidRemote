package dev.kidremote.child
import com.google.zxing.*
import com.google.zxing.common.HybridBinarizer
import java.nio.ByteBuffer
// Camera Y plane conversion, shared verbatim with synthetic stride/orientation tests.
internal fun decodeLuma(buffer:ByteBuffer,width:Int,height:Int,rowStride:Int,pixelStride:Int):String? = try {
    check(width in 1..1920 && height in 1..1920 && rowStride>0 && pixelStride>0)
    val start=buffer.position()
    val rgb=IntArray(width*height){i->val y=buffer.get(start+(i/width)*rowStride+(i%width)*pixelStride).toInt() and 255;(0xff000000.toInt() or (y shl 16) or (y shl 8) or y)}
    EnrollmentFaults.cameraStage(2)
    decodePixels(rgb,width,height)
}catch(_:Exception){EnrollmentFaults.cameraStage(7);null}
internal fun decodePixels(pixels:IntArray,width:Int,height:Int):String? = try {
    check(width in 1..1920 && height in 1..1920 && pixels.size==width*height)
    com.google.zxing.qrcode.QRCodeReader().decode(BinaryBitmap(HybridBinarizer(RGBLuminanceSource(width,height,pixels))),mapOf(DecodeHintType.TRY_HARDER to true)).text
}catch(_:Exception){null}
