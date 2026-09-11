package dev.kidremote.parent

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.Image
import androidx.compose.ui.graphics.asImageBitmap
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel

class MainActivity : ComponentActivity() {
    override fun onStop(){ViewModelProvider(this)[ParentModel::class.java].clearPairingQr();super.onStop()}
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE,WindowManager.LayoutParams.FLAG_SECURE)
        // No implicit token/deep-link callbacks accepted; email actions use the strict form parser.
        intent.data = null
        setContent {
            MaterialTheme(colorScheme=lightColorScheme(primary=Color(0xFF176B5B),background=Color(0xFFF7F9F7),
                surface=Color.White,onSurface=Color(0xFF172B2A),error=Color(0xFF9C2F33))) {
                ParentScreen(viewModel())
            }
        }
    }
}

@Composable fun ParentScreen(model: ParentModel) {
    val state=model.state
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var link by remember { mutableStateOf("") }
    var timezone by remember { mutableStateOf(java.util.TimeZone.getDefault().id) }
    LaunchedEffect(state.screen) { password=""; link=""; if(state.screen==Screen.LOGIN) email="" }
    Surface(Modifier.fillMaxSize()) {
        Column(Modifier.safeDrawingPadding().verticalScroll(rememberScrollState()).padding(24.dp),
            verticalArrangement=Arrangement.spacedBy(12.dp)) {
            Text("KidRemote · laboratório local",style=MaterialTheme.typography.headlineSmall)
            Text(when(state.screen) { Screen.LOGIN->"Entrar"; Screen.SIGNUP->"Criar conta"; Screen.VERIFY->"Verificar e-mail"
                Screen.RECOVER->"Recuperar senha"; Screen.RESET->"Nova senha"; Screen.SETUP->"Preparar sua casa"; Screen.DEVICES->"MY DEVICES" },
                style=MaterialTheme.typography.titleLarge)
            if(!BackendConfig.enabled) Text("Backend de distribuição não configurado. Esta versão não permite uso real.")
            if(state.loading) { CircularProgressIndicator(); Text("Aguarde…") }
            if(state.message.isNotEmpty()) Text(state.message)
            if(state.screen in setOf(Screen.LOGIN,Screen.SIGNUP,Screen.RECOVER))
                OutlinedTextField(email,{email=it},label={Text("E-mail sintético")},singleLine=true,enabled=!state.loading,modifier=Modifier.fillMaxWidth())
            if(state.screen in setOf(Screen.LOGIN,Screen.SIGNUP,Screen.RESET))
                OutlinedTextField(password,{password=it},label={Text("Senha")},visualTransformation=PasswordVisualTransformation(),
                    keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Password,autoCorrectEnabled=false),
                    singleLine=true,enabled=!state.loading,modifier=Modifier.fillMaxWidth())
            when(state.screen) {
                Screen.LOGIN -> {
                    Action("Entrar",!state.loading) { val p=password;password="";model.login(email,p) }
                    TextButton({model.navigate(Screen.SIGNUP)},enabled=!state.loading) {Text("Criar conta")}
                    TextButton({model.navigate(Screen.RECOVER)},enabled=!state.loading) {Text("Esqueci a senha")}
                    TextButton({model.restore()},enabled=!state.loading) {Text("Tentar restaurar sessão")}
                }
                Screen.SIGNUP -> Action("Enviar confirmação",!state.loading) {val p=password;password="";model.signup(email,p)}
                Screen.VERIFY,Screen.RECOVER -> {
                    if(state.screen==Screen.RECOVER) Action("Enviar recuperação",!state.loading) {model.recover(email)}
                    Text("Abra a caixa de e-mail local no computador e cole o link recebido. Nenhum e-mail é enviado externamente neste laboratório.")
                    OutlinedTextField(link,{link=it},label={Text("Link do e-mail local")},enabled=!state.loading,modifier=Modifier.fillMaxWidth())
                    Action("Verificar link",!state.loading) {val l=link;link="";model.verify(l,state.screen==Screen.RECOVER)}
                }
                Screen.RESET -> Action("Salvar nova senha",!state.loading) {val p=password;password="";model.reset(p)}
                Screen.SETUP -> {
                    Text("Confirme o fuso da casa. Repetir esta ação não cria outra casa nem altera o fuso existente.")
                    OutlinedTextField(timezone,{timezone=it},label={Text("Fuso IANA")},enabled=!state.loading)
                    Action("Confirmar e abrir dispositivos",!state.loading) {model.setup(timezone)}
                }
                Screen.DEVICES -> {
                    if(state.deviceCount==0) Text("Nenhum dispositivo cadastrado.")
                    state.devices.forEach { Text(it.nickname);Text(if(it.revoked) "Revogado" else "Pareado · configuração incompleta · proteção não verificada") }
                    Action("Atualizar dispositivos",!state.loading){model.refreshDevices()}
                    Action("Criar QR de pareamento",!state.loading&&state.qr==null){model.createPairing()}
                    state.qr?.let { payload ->
                        val bitmap=remember(payload){pairingBitmap(payload)}
                        Image(bitmap.asImageBitmap(),"QR de pareamento de uso único",Modifier.fillMaxWidth().height(280.dp))
                    }
                    if(state.pairingSession!=null) Action("Cancelar ou verificar QR",!state.loading){model.finishPairing()}
                    if(state.incompleteRecovery) Action("Revogar pareamento incompleto",!state.loading){model.finishPairing(true)}
                    Text("Controles e enforcement não estão disponíveis nesta etapa.")
                }
            }
            if(state.screen!=Screen.LOGIN) TextButton({password="";email="";link="";model.logout()}) {Text("Sair e limpar dados locais")}
        }
    }
}
internal fun pairingBitmap(text: String): android.graphics.Bitmap {
    val m=com.google.zxing.qrcode.QRCodeWriter().encode(text,com.google.zxing.BarcodeFormat.QR_CODE,512,512)
    val pixels=IntArray(512*512){if(m[it%512,it/512]) android.graphics.Color.BLACK else android.graphics.Color.WHITE}
    return android.graphics.Bitmap.createBitmap(pixels,512,512,android.graphics.Bitmap.Config.ARGB_8888)
}
@Composable private fun Action(label: String,enabled: Boolean,onClick:()->Unit) {
    Button(onClick,enabled=enabled,modifier=Modifier.fillMaxWidth().heightIn(min=56.dp)) {Text(label)}
}
