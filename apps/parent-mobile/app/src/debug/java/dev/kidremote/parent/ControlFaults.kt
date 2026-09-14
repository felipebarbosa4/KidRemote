package dev.kidremote.parent
internal object ControlFaults {
    fun automatic(context:android.content.Context)=!java.io.File(context.noBackupFilesDir,"control-test").exists()
    @Volatile var loseNextResponse=false
    fun afterOperation(){if(loseNextResponse){loseNextResponse=false;throw java.io.IOException("RESPONSE_LOST")}}
}
