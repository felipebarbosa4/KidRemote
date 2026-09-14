package dev.kidremote.child.accounting
import java.io.*
import java.util.zip.CRC32

/** Tiny durable write intent, not a policy/identity replica. CRC detects accidental corruption. */
internal data class RecoveryIntent(val epoch:String,val revision:Long,val boot:Long,val through:Long,val clock:Boolean,val observedBoot:Long=boot) {
    fun encode():ByteArray {
        val body=ByteArrayOutputStream().also{b->DataOutputStream(b).use{o->o.writeInt(1);o.writeUTF(epoch);o.writeLong(revision);o.writeLong(boot);o.writeLong(through);o.writeBoolean(clock);o.writeLong(observedBoot)}}.toByteArray()
        return ByteArrayOutputStream().also{it.write(body);DataOutputStream(it).writeLong(CRC32().apply{update(body)}.value)}.toByteArray()
    }
    companion object {
        fun decode(bytes:ByteArray):RecoveryIntent {
            require(bytes.size in 34..256)
            val body=bytes.copyOf(bytes.size-8)
            require(CRC32().apply{update(body)}.value==DataInputStream(ByteArrayInputStream(bytes,bytes.size-8,8)).readLong())
            return DataInputStream(ByteArrayInputStream(body)).use { i->
                require(i.readInt()==1)
                val p=RecoveryIntent(i.readUTF(),i.readLong(),i.readLong(),i.readLong(),i.readBoolean(),i.readLong())
                require(i.available()==0&&p.epoch.isNotBlank()&&p.epoch.length<=64&&p.revision>=0&&p.boot>=0&&p.through>=0&&p.observedBoot>=p.boot);p
            }
        }
    }
}
