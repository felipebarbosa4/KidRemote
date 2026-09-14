package dev.kidremote.child.accounting
import java.io.*
import java.util.zip.CRC32
/** Bounded aggregate record; CRC detects accidental corruption, not hostile OS tampering. */
object LedgerCodec {
    fun encode(s:Ledger):ByteArray {
        s.validate();val bytes=ByteArrayOutputStream()
        DataOutputStream(bytes).use { o->
            o.writeInt(5);with(s.policy){o.writeUTF(epoch);o.writeLong(version);o.writeUTF(zone);o.writeLong(zoneRevision);o.writeUTF(bonusDate);o.writeLong(dailyLimitSeconds);o.writeLong(bonusSeconds);o.writeBoolean(manualLock)}
            o.writeUTF(s.date);for(n in listOf(s.usedMs,s.bonusSeconds,s.boot,s.cursor,s.uptime,s.anchorElapsed,s.anchorUtc))o.writeLong(n)
            with(s.signals){o.writeBoolean(interactive);o.writeBoolean(keyguard);o.writeBoolean(permitted);o.writeBoolean(awake);o.writeBoolean(blocked)}
            o.writeUTF(s.uncertainty.name);o.writeBoolean(s.previousDate!=null);s.previousDate?.let{o.writeUTF(it)};o.writeLong(s.previousUsedMs);o.writeLong(s.recoveryThrough);o.writeLong(s.observedBoot);o.writeLong(s.reportSequence);o.writeBoolean(s.pendingAck!=null);s.pendingAck?.let{o.writeUTF(it)};o.writeBoolean(s.lastAdapterObservation!=null);s.lastAdapterObservation?.let{o.writeUTF(it)}
        }
        val body=bytes.toByteArray();val crc=CRC32().apply{update(body)}.value
        return ByteArrayOutputStream().also{it.write(body);DataOutputStream(it).writeLong(crc)}.toByteArray()
    }
    fun decode(bytes:ByteArray):Ledger {
        require(bytes.size in 9..4096)
        val body=bytes.copyOf(bytes.size-8);require(CRC32().apply{update(body)}.value==DataInputStream(ByteArrayInputStream(bytes,bytes.size-8,8)).readLong())
        return DataInputStream(ByteArrayInputStream(body)).use { i->
            val format=i.readInt();require(format in 1..5)
            val p=Policy(i.readUTF(),i.readLong(),i.readUTF(),i.readLong(),i.readUTF(),i.readLong(),i.readLong(),i.readBoolean())
            val date=i.readUTF();val used=i.readLong();val bonus=i.readLong();val boot=i.readLong();val cursor=i.readLong();val uptime=i.readLong();val ae=i.readLong();val au=i.readLong()
            val signals=Signals(i.readBoolean(),i.readBoolean(),i.readBoolean(),i.readBoolean(),if(format>=5)i.readBoolean() else false);val uncertain=Uncertainty.valueOf(i.readUTF())
            val previous=if(i.readBoolean())i.readUTF() else null;val previousUsed=i.readLong()
            val through=if(format>=2)i.readLong() else 0L
            val observed=if(format>=2)i.readLong() else boot
            // Old uncertain records have no durable coverage endpoint: retain data and require B.
            val health=if(format==1&&uncertain!=Uncertainty.NONE)Uncertainty.CLOCK else uncertain
            val sequence=if(format>=3)i.readLong() else 0L;val ack=if(format>=3&&i.readBoolean())i.readUTF() else null
            val adapter=if(format>=4&&i.readBoolean())i.readUTF() else null
            require(i.available()==0)
            Ledger(p,date,used,bonus,boot,cursor,uptime,ae,au,signals,health,previous,previousUsed,through,observed,sequence,ack,adapter).also{it.validate()}
        }
    }
}
