package dev.kidremote.parent

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

internal class SessionVault(context: Context) {
    private val file = File(context.noBackupFilesDir,"parent-session")
    private val alias = "parent-session-v1"
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias,null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    @Synchronized fun save(refresh: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE,key()) }
        val atomic = android.util.AtomicFile(file)
        val out = atomic.startWrite()
        try { out.write(cipher.iv + cipher.doFinal(refresh.toByteArray(Charsets.UTF_8))); atomic.finishWrite(out) }
        catch (e: Exception) { atomic.failWrite(out); throw e }
    }
    @Synchronized fun read(): String? {
        if (!file.exists()) return null
        return try {
            check(file.length() <= 8192)
            val data=file.readBytes(); check(data.size > 28)
            val cipher=Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.DECRYPT_MODE,key(),GCMParameterSpec(128,data.copyOfRange(0,12))) }
            String(cipher.doFinal(data.copyOfRange(12,data.size)),Charsets.UTF_8)
        } catch (_: Exception) { clear(); null }
    }
    @Synchronized fun clear() {
        android.util.AtomicFile(file).delete()
        KeyStore.getInstance("AndroidKeyStore").apply { load(null); if (containsAlias(alias)) deleteEntry(alias) }
        check(!file.exists())
    }
}
