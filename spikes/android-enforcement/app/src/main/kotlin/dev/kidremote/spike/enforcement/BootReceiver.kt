package dev.kidremote.spike.enforcement

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_LOCKED_BOOT_COMPLETED) {
            LabTimerStore(context).markClockUncertain()
        }
        // Package replacement intentionally preserves state and does not start background work.
    }
}
