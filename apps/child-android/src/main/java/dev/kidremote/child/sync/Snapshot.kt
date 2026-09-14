package dev.kidremote.child.sync
import android.util.JsonReader
import android.util.JsonToken
import java.io.StringReader
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.json.JSONObject
import org.json.JSONArray
import dev.kidremote.child.accounting.Policy

/** Strict wire JSON rejects duplicates, unknown fields, coercion, non-integral/unsafe numbers. */
internal object Wire {
    fun parse(text:String):JSONObject {
        require(text.toByteArray().size<=65536)
        JsonReader(StringReader(text)).use { r->
            r.isLenient=false
            fun value(depth:Int):Any {
                require(depth<=5)
                return when(r.peek()) {
                    JsonToken.BEGIN_OBJECT->{val o=JSONObject();val seen=mutableSetOf<String>();r.beginObject();while(r.hasNext()){val k=r.nextName();require(seen.add(k));o.put(k,value(depth+1))};r.endObject();o}
                    JsonToken.BEGIN_ARRAY->{val a=JSONArray();r.beginArray();while(r.hasNext()){require(a.length()<100);a.put(value(depth+1))};r.endArray();a}
                    JsonToken.STRING->r.nextString()
                    JsonToken.NUMBER->{val s=r.nextString();require(Regex("0|[1-9][0-9]*").matches(s));s.toLong().also{require(it<=9007199254740991L)}}
                    JsonToken.BOOLEAN->r.nextBoolean()
                    JsonToken.NULL->{r.nextNull();JSONObject.NULL}
                    else->error("INVALID_WIRE")
                }
            }
            val out=value(0);require(out is JSONObject&&r.peek()==JsonToken.END_DOCUMENT);return out
        }
    }
    fun same(a:Any?,b:Any?):Boolean=when(a) {
        is JSONObject->b is JSONObject&&a.keys().asSequence().toSet()==b.keys().asSequence().toSet()&&a.keys().asSequence().all{same(a.get(it),b.get(it))}
        is JSONArray->b is JSONArray&&a.length()==b.length()&&(0 until a.length()).all{same(a.get(it),b.get(it))}
        else->a==b
    }
    fun keys(o:JSONObject,keys:Set<String>){require(o.keys().asSequence().toSet()==keys)}
    fun number(o:JSONObject,k:String)= (o.get(k) as? Long?:error("INVALID_NUMBER"))
    fun string(o:JSONObject,k:String)= (o.get(k) as? String?:error("INVALID_STRING"))
    fun bool(o:JSONObject,k:String)= (o.get(k) as? Boolean?:error("INVALID_BOOLEAN"))
    fun policy(o:JSONObject,id:JSONObject):Policy {
        keys(o,setOf("protocol_version","kind","device_id","policy_epoch","version","policy_configured","daily_limit_seconds","manual_lock","enforcement_available","timezone_name","timezone_revision","server_utc","period_key","bonus_seconds","operations","history_pruned","credential_lifecycle","snapshot_id","next_cursor"))
        require(number(o,"protocol_version")==1L&&string(o,"kind")=="CONFIGURED_SNAPSHOT"&&bool(o,"policy_configured")&&!bool(o,"enforcement_available"))
        require(string(o,"device_id")==id.getString("device_id")&&string(o,"policy_epoch")==id.getString("policy_epoch"))
        val lifecycle=o.getJSONObject("credential_lifecycle");keys(lifecycle,setOf("generation","expires_at","rotate_after","rotation_due"));require(number(lifecycle,"generation")>0);Instant.parse(string(lifecycle,"expires_at"));Instant.parse(string(lifecycle,"rotate_after"));bool(lifecycle,"rotation_due")
        val zone=string(o,"timezone_name");val revision=number(o,"timezone_revision");val utc=Instant.parse(string(o,"server_utc"))
        val date=utc.atZone(ZoneId.of(zone)).toLocalDate();require(date.year in 1..9999&&string(o,"period_key")=="$revision:$date")
        val p=Policy(id.getString("policy_epoch"),number(o,"version"),zone,revision,date.toString(),number(o,"daily_limit_seconds"),number(o,"bonus_seconds"),bool(o,"manual_lock"));p.validate();require(p.version>0)
        java.util.UUID.fromString(string(o,"snapshot_id"))
        if(!o.isNull("next_cursor"))require(Regex("[a-f0-9-]{36}:[1-9]00").matches(string(o,"next_cursor"))&&string(o,"next_cursor").startsWith(string(o,"snapshot_id")+":"))
        bool(o,"history_pruned");val ops=o.getJSONArray("operations");require(ops.length()<=100);var last=0L
        for(i in 0 until ops.length()) {
            val v=ops.getJSONObject(i);keys(v,setOf("operation_id","version","kind","period_key","status"));java.util.UUID.fromString(string(v,"operation_id"))
            val ver=number(v,"version");require(ver>last&&ver<=p.version);last=ver
            require(string(v,"status") in setOf("pending","persisted","applied","superseded","expired_for_period","failed","rejected"))
            val kind=string(v,"kind");require(kind in setOf("LOCK","UNLOCK","ADD_TIME","SET_DAILY_LIMIT"))
            if(kind=="ADD_TIME"){val day=string(v,"period_key");require(day.startsWith("$revision:"));LocalDate.parse(day.substringAfter(':'))}else require(v.isNull("period_key"))
        }
        return p
    }
}
