package dev.kidremote.child.accounting
import java.io.*
import java.util.zip.CRC32
/** Frozen pre-enforcement payload layout, independent of the current encoder. */
object LegacyFixture {
 fun encode(s:Ledger,format:Int):ByteArray {
  val out=ByteArrayOutputStream();DataOutputStream(out).use{o->
   o.writeInt(format);with(s.policy){o.writeUTF(epoch);o.writeLong(version);o.writeUTF(zone);o.writeLong(zoneRevision);o.writeUTF(bonusDate);o.writeLong(dailyLimitSeconds);o.writeLong(bonusSeconds);o.writeBoolean(manualLock)}
   o.writeUTF(s.date);for(n in listOf(s.usedMs,s.bonusSeconds,s.boot,s.cursor,s.uptime,s.anchorElapsed,s.anchorUtc))o.writeLong(n)
   with(s.signals){o.writeBoolean(interactive);o.writeBoolean(keyguard);o.writeBoolean(permitted);o.writeBoolean(awake)}
   o.writeUTF(s.uncertainty.name);o.writeBoolean(s.previousDate!=null);s.previousDate?.let{o.writeUTF(it)};o.writeLong(s.previousUsedMs)
   if(format>=2){o.writeLong(s.recoveryThrough);o.writeLong(s.observedBoot)}
   if(format>=3){o.writeLong(s.reportSequence);o.writeBoolean(s.pendingAck!=null);s.pendingAck?.let{o.writeUTF(it)}}
   if(format>=4){o.writeBoolean(s.lastAdapterObservation!=null);s.lastAdapterObservation?.let{o.writeUTF(it)}}
  };val body=out.toByteArray();return ByteArrayOutputStream().also{it.write(body);DataOutputStream(it).writeLong(CRC32().apply{update(body)}.value)}.toByteArray()
 }
}
