package dev.kidremote.child.sync
import android.content.Context
import android.util.AtomicFile
import java.io.File
internal class SyncProgress(context:Context) {
 private val file=AtomicFile(File(context.noBackupFilesDir,"sync-page-progress"))
 fun checkpoint(version:Long,page:Int){require(version>0&&page in 0..9);val out=file.startWrite();try{out.write("1:$version:$page".toByteArray());file.finishWrite(out)}catch(e:Exception){file.failWrite(out);throw e}}
 fun clear(){file.delete()}
}
