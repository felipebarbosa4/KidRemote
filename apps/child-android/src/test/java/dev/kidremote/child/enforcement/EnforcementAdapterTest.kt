package dev.kidremote.child.enforcement
import dev.kidremote.child.accounting.*
import org.junit.Assert.*
import org.junit.Test
import java.time.Instant
class EnforcementAdapterTest {
 private fun state()=Accounting.start(Policy("epoch",1,"Etc/UTC",1,"2026-09-14",3600,0,false),Sample(1,0,0,Signals(true,false,true)),Instant.parse("2026-09-14T12:00:00Z").toEpochMilli())
 private fun change(s:Ledger,lock:Boolean=s.policy.manualLock,bonus:Long=s.bonusSeconds,limit:Long=s.policy.dailyLimitSeconds)=Accounting.snapshot(s,s.policy.copy(version=s.policy.version+1,manualLock=lock,bonusSeconds=bonus,dailyLimitSeconds=limit),Sample(1,s.cursor,s.uptime,s.signals))
 @Test fun persistenceIsNotObservation(){val s=change(state(),lock=true);assertTrue(s.restrictionRequired);assertFalse(EnforcementObservation(EnforcementTarget.from(s),false,"ADAPTER_PENDING").applied(s))}
 @Test fun attachedVisibleObservationMatchesVersion(){val s=change(state(),lock=true);assertTrue(EnforcementObservation(EnforcementTarget.from(s),true,"RESTRICTED_OBSERVED").applied(s))}
 @Test fun unlockPositiveClears(){assertFalse(change(change(state(),lock=true),lock=false).restrictionRequired)}
 @Test fun unlockAtZeroRetains(){assertTrue(change(change(state(),lock=true,limit=0),lock=false).restrictionRequired)}
 @Test fun bonusExpiryAndManual(){val s=change(state(),limit=0);assertFalse(change(s,bonus=600).restrictionRequired);assertTrue(change(change(s,lock=true),bonus=1800).restrictionRequired)}
 @Test fun lowerLimitPreservesUse(){val s=state().copy(usedMs=1000);val n=change(s,limit=0);assertEquals(1000,n.usedMs);assertTrue(n.restrictionRequired)}
 @Test fun staleCannotClear(){val old=state();val locked=change(old,lock=true);assertEquals(locked,Accounting.snapshot(locked,old.policy,Sample(1,0,0,old.signals)))}
 @Test fun uncertaintyRestricts(){assertTrue(state().copy(uncertainty=Uncertainty.HISTORY).restrictionRequired)}
 @Test fun oldObservationCannotAuthorizeNewVersion(){val s=change(state(),lock=true);val observed=EnforcementObservation(EnforcementTarget.from(s),true,"RESTRICTED_OBSERVED");assertFalse(observed.applied(change(s,bonus=600)))}
 @Test fun safeSurfaceIsNotApplied(){val s=change(state(),lock=true);assertFalse(EnforcementObservation(EnforcementTarget.from(s),false,"SAFE_SURFACE_AVAILABLE").applied(s));assertEquals(SurfaceDisposition.SAFE_SYSTEM,SurfacePolicy.classify("com.android.settings","child"))}
 @Test fun unknownIsFailOpen(){assertEquals(SurfaceDisposition.UNKNOWN_FAIL_OPEN,SurfacePolicy.classify(null,"child"))}
 @Test fun ownOverlayEventKeepsOrdinary(){assertEquals(SurfaceDisposition.ORDINARY_APP,SurfaceEventResolver.resolve(SurfaceDisposition.ORDINARY_APP,SurfacePolicy.observe("child","child"),true,true))}
}
