package dev.kidremote.child.sync
import org.junit.Assert.*
import org.junit.Test
class RetryTimingTest {
 @Test fun fullJitterBounds(){for(a in 0..30){val cap=minOf(300000L,1000L shl minOf(a,9));assertEquals(0L,RetryTiming.delay(a,0.0));assertTrue(RetryTiming.delay(a,0.999999)<=cap)}}
 @Test fun exponentialCap(){assertEquals(500L,RetryTiming.delay(0,0.5));assertEquals(1000L,RetryTiming.delay(1,0.5));assertEquals(150000L,RetryTiming.delay(30,0.5))}
 @Test fun retryAfterFloor(){assertEquals(60000L,RetryTiming.delay(0,0.0,60000));assertEquals(86400000L,RetryTiming.delay(0,0.0,Long.MAX_VALUE))}
 @Test fun retryAfterSeconds(){assertEquals(3000L,RetryTiming.retryAfter("3",null));assertEquals(0L,RetryTiming.retryAfter("-1",null));assertEquals(0L,RetryTiming.retryAfter("bad",null))}
 @Test fun retryAfterDateUsesServerDate(){assertEquals(60000L,RetryTiming.retryAfter("Mon, 14 Sep 2026 12:01:00 GMT","Mon, 14 Sep 2026 12:00:00 GMT"));assertEquals(0L,RetryTiming.retryAfter("Mon, 14 Sep 2026 12:01:00 GMT",null))}
 @Test fun corruptInputsFailClosed(){assertTrue(runCatching{RetryTiming.delay(-1,0.5)}.isFailure);assertTrue(runCatching{RetryTiming.delay(0,Double.NaN)}.isFailure);assertTrue(runCatching{RetryTiming.delay(0,1.0)}.isFailure)}
}
