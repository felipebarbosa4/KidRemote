package dev.kidremote.child.accounting
import android.app.usage.UsageEvents
import android.app.usage.UsageEventsQuery
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build

/** Lab-only transient measurement. The OS does NOT provide a completeness certificate. */
internal object UsageHistoryProbe {
    data class Result(val events:List<SignalEvent>,val coverageProven:Boolean=false)
    fun query(context:Context,wallStart:Long,wallEnd:Long,elapsedStart:Long,clockMappingStable:Boolean):Result {
        if(!clockMappingStable||wallEnd<wallStart||wallEnd-wallStart>48*60*60*1000L)return Result(emptyList())
        return try {
            val manager=context.getSystemService(UsageStatsManager::class.java)
            val events=if(Build.VERSION.SDK_INT>=35)manager.queryEvents(UsageEventsQuery.Builder(wallStart,wallEnd)
                .setEventTypes(UsageEvents.Event.SCREEN_INTERACTIVE,UsageEvents.Event.SCREEN_NON_INTERACTIVE,UsageEvents.Event.KEYGUARD_SHOWN,UsageEvents.Event.KEYGUARD_HIDDEN).build())
                else manager.queryEvents(wallStart,wallEnd)
            val out=mutableListOf<SignalEvent>();val event=UsageEvents.Event();var count=0
            while(events!=null&&events.hasNextEvent()) {
                if(++count>10000)return Result(emptyList())
                events.getNextEvent(event)
                val kind=when(event.eventType) {
                    UsageEvents.Event.SCREEN_INTERACTIVE->SignalKind.INTERACTIVE
                    UsageEvents.Event.SCREEN_NON_INTERACTIVE->SignalKind.NON_INTERACTIVE
                    UsageEvents.Event.KEYGUARD_SHOWN->SignalKind.KEYGUARD_SHOWN
                    UsageEvents.Event.KEYGUARD_HIDDEN->SignalKind.KEYGUARD_HIDDEN
                    else->continue
                }
                if(event.timeStamp !in wallStart..wallEnd)return Result(emptyList())
                out.add(SignalEvent(Math.addExact(elapsedStart,event.timeStamp-wallStart),kind))
            }
            Result(out) // not eligible for charging without independent coverage/permission evidence
        }catch(_:Exception){Result(emptyList())}
    }
}
