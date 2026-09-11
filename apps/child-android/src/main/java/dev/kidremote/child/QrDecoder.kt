package dev.kidremote.child
import com.google.zxing.*
import com.google.zxing.common.HybridBinarizer
internal fun decodePixels(pixels:IntArray,width:Int,height:Int):String? = try {
    check(width in 1..1920 && height in 1..1920 && pixels.size==width*height)
    com.google.zxing.qrcode.QRCodeReader().decode(BinaryBitmap(HybridBinarizer(RGBLuminanceSource(width,height,pixels))),mapOf(DecodeHintType.TRY_HARDER to true)).text
}catch(_:Exception){null}
