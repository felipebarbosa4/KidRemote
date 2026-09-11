package dev.kidremote.child
import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModelProvider
import java.util.concurrent.Executors

class ChildActivity:ComponentActivity() {
    private lateinit var model:EnrollmentModel
    private var scanning by mutableStateOf(false)
    private var cameraMessage by mutableStateOf("")
    private var camera:ProcessCameraProvider?=null
    private val analyzer=Executors.newSingleThreadExecutor()
    private val permission=registerForActivityResult(ActivityResultContracts.RequestPermission()){granted->scanning=granted;cameraMessage=if(granted)"" else "Câmera recusada. Pareamento não concluído; tente novamente quando desejar."}
    override fun onCreate(state:Bundle?) {
        super.onCreate(state);window.setFlags(WindowManager.LayoutParams.FLAG_SECURE,WindowManager.LayoutParams.FLAG_SECURE)
        model=ViewModelProvider(this)[EnrollmentModel::class.java]
        setContent {MaterialTheme {Surface(Modifier.fillMaxSize()){Column(Modifier.safeDrawingPadding().padding(24.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
            Text("KidRemote Child · laboratório local",style=MaterialTheme.typography.titleLarge)
            Text(model.state.message);Text("Nenhum bloqueio ou proteção está ativo neste aplicativo.")
            if(model.state.loading)CircularProgressIndicator()
            if(cameraMessage.isNotEmpty())Text(cameraMessage)
            if(!model.state.paired&&!model.state.loading&&!model.state.recovery)Button(onClick={if(ContextCompat.checkSelfPermission(this@ChildActivity,Manifest.permission.CAMERA)==PackageManager.PERMISSION_GRANTED)scanning=true else permission.launch(Manifest.permission.CAMERA)}){Text("Escanear QR do responsável")}
            Button(onClick={model.restore()},enabled=!model.state.loading){Text("Verificar identidade e contato")}
            if(model.state.recovery)Button(onClick={model.acknowledgeFreshQr()}){Text("Responsável revogou; usar novo QR")}
            if(scanning) {
                AndroidView(factory={context->PreviewView(context).also{startCamera(it)}},modifier=Modifier.fillMaxWidth().height(300.dp))
                Button(onClick={stopCamera()}){Text("Parar câmera")}
            }
        }}}}
    }
    private fun startCamera(view:PreviewView) {
        val f=ProcessCameraProvider.getInstance(this)
        f.addListener({
            if(!scanning || !lifecycle.currentState.isAtLeast(androidx.lifecycle.Lifecycle.State.STARTED))return@addListener
            try {
                val provider=f.get();camera=provider
                val preview=Preview.Builder().build().also{it.surfaceProvider=view.surfaceProvider}
                val analysis=ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                analysis.setAnalyzer(analyzer){image->
                    try {
                        val w=image.width;val h=image.height
                        if(w<=1920&&h<=1920){val p=image.planes[0]
                            val decoded=decodeLuma(p.buffer,w,h,p.rowStride,p.pixelStride)
                            if(decoded!=null)runOnUiThread {if(scanning){stopCamera();model.decoded(decoded)}}
                        }
                    }catch(_:Exception){/* discard unrecognized frame, never persist it */}finally{image.close()}
                }
                provider.bindToLifecycle(this,CameraSelector.DEFAULT_BACK_CAMERA,preview,analysis)
            }catch(_:Exception){stopCamera();cameraMessage="Câmera indisponível. Nenhum pareamento foi confirmado."}
        },ContextCompat.getMainExecutor(this))
    }
    private fun stopCamera(){scanning=false;camera?.unbindAll()}
    override fun onPause(){stopCamera();super.onPause()}
    override fun onDestroy(){analyzer.shutdownNow();super.onDestroy()}
}
