package dev.kidremote.child.sync
internal object SyncFaults {
    @Volatile var afterPersist:(()->Unit)?=null
    @Volatile var afterAckResponse:(()->Unit)?=null
    @Volatile var transformSyncResponse:((String)->String)?=null
    fun syncResponse(text:String)=transformSyncResponse?.invoke(text)?:text
    fun persisted(){afterPersist?.invoke()}
    fun ackResponse(){afterAckResponse?.invoke()}
 var afterPage:((Int)->Unit)?=null
 fun pagePersisted(page:Int){afterPage?.invoke(page)}
 fun automaticAllowed(context:android.content.Context)=!java.io.File(context.noBackupFilesDir,"sync-test-control").exists()
}
