package dev.kidremote.child.accounting
/** Only screen/keyguard transitions. No package identity or application totals are accepted. */
enum class SignalKind { INTERACTIVE, NON_INTERACTIVE, KEYGUARD_SHOWN, KEYGUARD_HIDDEN }
data class SignalEvent(val elapsed:Long,val kind:SignalKind)
object History {
    fun ranges(boot:Long,start:Long,end:Long,predecessor:Signals,events:List<SignalEvent>):List<Range> {
        require(start>=0&&end>=start&&events.size<=10000)
        require(events.zipWithNext().all{(a,b)->a.elapsed<=b.elapsed})
        require(events.all{it.elapsed in start..end})
        require(events.groupBy{it.elapsed}.values.none{v->
            (v.any{it.kind==SignalKind.INTERACTIVE}&&v.any{it.kind==SignalKind.NON_INTERACTIVE})||
            (v.any{it.kind==SignalKind.KEYGUARD_SHOWN}&&v.any{it.kind==SignalKind.KEYGUARD_HIDDEN})})
        var state=predecessor;var at=start;val ranges=mutableListOf<Range>()
        for(e in events) {
            if(e.elapsed>at)ranges.add(Range(boot,at,e.elapsed,state))
            state=when(e.kind){SignalKind.INTERACTIVE->state.copy(interactive=true);SignalKind.NON_INTERACTIVE->state.copy(interactive=false)
                SignalKind.KEYGUARD_SHOWN->state.copy(keyguard=true);SignalKind.KEYGUARD_HIDDEN->state.copy(keyguard=false)}
            at=e.elapsed
        }
        if(at<end)ranges.add(Range(boot,at,end,state))
        return ranges
    }
}
