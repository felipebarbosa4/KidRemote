package dev.kidremote.child.enforcement

import android.accessibilityservice.AccessibilityService
import android.content.*
import android.graphics.Color
import android.os.*
import android.provider.Settings
import android.view.*
import android.view.accessibility.AccessibilityEvent
import android.widget.*
import dev.kidremote.child.IdentityStore
import dev.kidremote.child.accounting.*
import dev.kidremote.child.sync.*
import java.util.concurrent.Executors

/** KR-003 overlay candidate, hosted by the system-bound service. No lab controller or event history. */
class ChildEnforcementService:AccessibilityService(),EnforcementAdapter {
    private val main=Handler(Looper.getMainLooper())
    private val worker=Executors.newSingleThreadExecutor()
    private var overlay:View?=null
    private var surface=SurfaceDisposition.UNKNOWN_FAIL_OPEN
    private var target:EnforcementTarget?=null
    private var ready=false
    private var connected=false
    private var busy=false
    private var interrupted=false
    private var lastQueued:EnforcementObservation?=null
    @Volatile private var observation=EnforcementObservation(null,false,"ENFORCEMENT_UNAVAILABLE")
    private lateinit var engine:ChildAccounting
    private val screen=object:BroadcastReceiver(){override fun onReceive(c:Context?,i:Intent?){sample()}}
    private val tick=object:Runnable { override fun run(){sample();if(connected)main.postDelayed(this,250)} }
    override fun onServiceConnected(){
        super.onServiceConnected();connected=true;interrupted=false;engine=ChildAccounting(this)
        EnforcementRuntime.connect(this,engine)
        val filter=IntentFilter().apply{addAction(Intent.ACTION_SCREEN_ON);addAction(Intent.ACTION_SCREEN_OFF);addAction(Intent.ACTION_USER_PRESENT)}
        if(Build.VERSION.SDK_INT>=33)registerReceiver(screen,filter,Context.RECEIVER_NOT_EXPORTED) else @Suppress("DEPRECATION") registerReceiver(screen,filter)
        main.post(tick)
    }
    private fun sample(){
        if(!connected||busy)return
        busy=true
        worker.execute {
            var next:EnforcementTarget?=null;var usable=false
            try {
                val id=IdentityStore(this).read()
                if(id!=null&&!id.has("removal")&&id.optBoolean("accounting_initialized",false)) {
                    val result=engine.sample(AndroidAccountingClock.sample(this,true))
                    next=result.ledger?.let(EnforcementTarget::from)
                    val ops=getSystemService(android.app.AppOpsManager::class.java)
                    val usage=ops.checkOpNoThrow(android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,android.os.Process.myUid(),packageName)==android.app.AppOpsManager.MODE_ALLOWED
                    usable=!result.storageFailure&&next!=null&&EnforcementRuntime.consented(this)&&usage
                    val observed=observation
                    if(observed!=lastQueued&&observed.target==next&&result.ledger?.pendingAck==null){
                        EnforcementRuntime.persist(this,engine,observed);lastQueued=observed
                    }
                }
            }catch(_:Exception){/* Fail closed in health, preserve stored policy. */}
            main.post{busy=false;if(connected)request(next,usable)}
        }
    }
    override fun onAccessibilityEvent(event:AccessibilityEvent?){
        surface=SurfaceEventResolver.resolve(surface,SurfacePolicy.observe(event?.packageName,packageName),target?.required==true,overlay?.isAttachedToWindow==true)
        apply();sample()
    }
    override fun request(target:EnforcementTarget?,ready:Boolean){
        check(Looper.myLooper()==Looper.getMainLooper())
        this.target=target;this.ready=ready;apply()
    }
    override fun observe()=observation
    private fun apply(){
        if(!connected||interrupted||!ready||target?.required!=true||surface!=SurfaceDisposition.ORDINARY_APP){
            detach()
            publish(when {
                !connected||interrupted->"SERVICE_DISCONNECTED"
                !ready->"PERMISSION_REQUIRED"
                target?.required!=true->"UNRESTRICTED_OBSERVED"
                surface==SurfaceDisposition.SAFE_SYSTEM->"SAFE_SURFACE_AVAILABLE"
                else->"UNKNOWN_SURFACE_FAIL_OPEN"
            });return
        }
        if(overlay==null){
            val view=buildOverlay();overlay=view
            view.addOnAttachStateChangeListener(object:View.OnAttachStateChangeListener {
                override fun onViewAttachedToWindow(v:View){main.post{if(overlay===v)publish("RESTRICTED_OBSERVED")}}
                override fun onViewDetachedFromWindow(v:View){publish("ADAPTER_FAILED")}
            })
            try{getSystemService(WindowManager::class.java).addView(view,WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                android.graphics.PixelFormat.TRANSLUCENT).apply{gravity=Gravity.CENTER})}
            catch(_:RuntimeException){overlay=null;publish("ADAPTER_FAILED");return}
        }
        // Successful addView alone is not the observation. Android attachment + visibility must hold.
        publish(if(overlay?.isAttachedToWindow==true&&overlay?.isShown==true)"RESTRICTED_OBSERVED" else "ADAPTER_PENDING")
    }
    private fun detach(){
        val view=overlay?:return
        try{getSystemService(WindowManager::class.java).removeViewImmediate(view);if(!view.isAttachedToWindow)overlay=null}
        catch(_:RuntimeException){/* Retain reference; never manufacture successful clear. */}
    }
    private fun publish(health:String){
        val attached=overlay?.isAttachedToWindow==true
        val safeHealth=if(health=="RESTRICTED_OBSERVED"&&(!attached||overlay?.isShown!=true))"ADAPTER_PENDING"
            else if(attached&&health!="RESTRICTED_OBSERVED")"ADAPTER_FAILED" else health
        val next=EnforcementObservation(target,attached,safeHealth)
        EnforcementRuntime.heartbeat()
        if(next!=observation){observation=next;EnforcementRuntime.publish(this,next)}
    }
    private fun buildOverlay():View=LinearLayout(this).apply {
        orientation=LinearLayout.VERTICAL;gravity=Gravity.CENTER;setPadding(dp(32),dp(32),dp(32),dp(32));setBackgroundColor(Color.rgb(246,248,247))
        importantForAccessibility=View.IMPORTANT_FOR_ACCESSIBILITY_YES
        addView(TextView(context).apply{text="Uso restrito · confira os motivos no KidRemote";textSize=26f;setTextColor(Color.rgb(25,40,39));gravity=Gravity.CENTER})
        addView(TextView(context).apply{text="Integração local em avaliação. Superfícies de sistema e recuperação seguem o candidato KR-003.";textSize=16f;setTextColor(Color.rgb(54,69,68));gravity=Gravity.CENTER})
        addView(Button(context).apply{text="Abrir configurações do dispositivo";isAllCaps=false;minHeight=dp(48);setOnClickListener{
            startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        }})
    }
    override fun onInterrupt(){interrupted=true;apply()}
    override fun onUnbind(intent:Intent?):Boolean {shutdown();return super.onUnbind(intent)}
    override fun onDestroy(){shutdown();super.onDestroy()}
    private fun shutdown(){if(!connected)return;connected=false;main.removeCallbacks(tick);unregisterReceiver(screen);detach();publish("SERVICE_DISCONNECTED");EnforcementRuntime.disconnect(this);worker.execute{engine.close()};worker.shutdown();}
    private fun dp(n:Int)=(n*resources.displayMetrics.density).toInt()
}
