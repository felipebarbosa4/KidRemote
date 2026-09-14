import com.google.zxing.BarcodeFormat;
import com.google.zxing.qrcode.QRCodeWriter;
import com.google.zxing.common.BitMatrix;
import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

/** Host-only QR display. Stdin/stdout are private pipes, never evidence or files. */
public final class HostQr {
 public static void main(String[] args) throws Exception {
  byte[] input=System.in.readNBytes(257);
  if(args.length!=0 || input.length<1 || input.length>256)System.exit(2);
  BitMatrix m=new QRCodeWriter().encode(new String(input,StandardCharsets.UTF_8),BarcodeFormat.QR_CODE,512,512);
  BufferedImage image=new BufferedImage(512,512,BufferedImage.TYPE_BYTE_BINARY);
  for(int y=0;y<512;y++)for(int x=0;x<512;x++)image.setRGB(x,y,m.get(x,y)?0xff000000:0xffffffff);
  ByteArrayOutputStream out=new ByteArrayOutputStream();ImageIO.write(image,"png",out);
  System.out.print(Base64.getEncoder().encodeToString(out.toByteArray()));
 }
}
