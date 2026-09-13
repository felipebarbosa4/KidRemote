package dev.kidremote.child.accounting
import java.io.*
import java.util.zip.CRC32
/** Bounded aggregate record; CRC detects accidental corruption, not hostile OS tampering. */
object LedgerCodec {
    fun encode(s:Ledger):ByteArray {
        s.validate();val bytes=ByteArrayOutputStream()
        DataOutputStream(bytes).use { o->
            o.writeInt(1);with(s.policy){o.writeUTF(epoch);o.writeLong(version);o.writeUTF(zone);o.writeLong(zoneRevision);o.writeUTF(bonusDate);o.writeLong(dailyLimitSeconds);o.writeLong(bonusSeconds);o.writeBoolean(manualLock)}
            o.writeUTF(s.date);for(n in listOf(s.usedMs,s.bonusSeconds,s.boot,s.cursor,s.uptime,s.anchorElapsed,s.anchorUtc))o.writeLong(n)
            with(s.signals){o.writeBoolean(interactive);o.writeBoolean(keyguard);o.writeBoolean(permitted);o.writeBoolean(awake)}
            o.writeUTF(s.uncertainty.name);o.writeBoolean(s.previousDate!=null);s.previousDate?.let{o.writeUTF(it)};o.writeLong(s.previousUsedMs)
        }
        val body=bytes.toByteArray();val crc=CRC32().apply{update(body)}.value
        return ByteArrayOutputStream().also{it.write(body);DataOutputStream(it).writeLong(crc)}.toByteArray()
    }
    fun decode(bytes:ByteArray):Ledger {
        require(bytes.size in 9..4096)
        val body=bytes.copyOf(bytes.size-8);require(CRC32().apply{update(body)}.value==DataInputStream(ByteArrayInputStream(bytes,bytes.size-8,8)).readLong())
        return DataInputStream(ByteArrayInputStream(body)).use { i->
            require(i.readInt()==1)
            val p=Policy(i.readUTF(),i.readLong(),i.readUTF(),i.readLong(),i.readUTF(),i.readLong(),i.readLong(),i.readBoolean())
            val date=i.readUTF();val used=i.readLong();val bonus=i.readLong();val boot=i.readLong();val cursor=i.readLong();val uptime=i.readLong();val ae=i.readLong();val au=i.readLong()
            val signals=Signals(i.readBoolean(),i.readBoolean(),i.readBoolean(),i.readBoolean());val uncertain=Uncertainty.valueOf(i.readUTF())
            val previous=if(i.readBoolean())i.readUTF() else null;val previousUsed=i.readLong()
            require(i.available()==0)
            Ledger(p,date,used,bonus,boot,cursor,uptime,ae,au,signals,uncertain,previous,previousUsed).also{it.validate()}
        }
    }
}
