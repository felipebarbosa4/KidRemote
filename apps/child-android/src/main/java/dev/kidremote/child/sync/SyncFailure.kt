package dev.kidremote.child.sync
import java.io.IOException
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
internal class LocalStorageFailure:IllegalStateException("LOCAL_STORAGE_UNAVAILABLE")
internal class RetryableSync(val delayMs:Long=0):IOException("SYNC_RETRY")
internal class RestartSnapshot:IOException("SNAPSHOT_RESTART_REQUIRED")
internal object RetryTiming {
 fun delay(attempt:Int,random:Double,retryAfter:Long=0):Long {
  require(attempt in 0..30 && random>=0 && random<1 && retryAfter>=0)
  val cap=minOf(300000L,1000L shl minOf(attempt,9))
  return maxOf((random*(cap+1)).toLong(),minOf(retryAfter,86400000L))
 }
 fun retryAfter(value:String?,date:String?):Long {
  if(value==null)return 0
  value.toLongOrNull()?.let{return it.coerceIn(0,86400)*1000}
  return try{val server=ZonedDateTime.parse(date,DateTimeFormatter.RFC_1123_DATE_TIME).toInstant();val target=ZonedDateTime.parse(value,DateTimeFormatter.RFC_1123_DATE_TIME).toInstant();(target.toEpochMilli()-server.toEpochMilli()).coerceIn(0,86400000)}catch(_:Exception){0}
 }
}
