package dev.kidremote.spike.enforcement

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Test

class RecoverySettingsIntentTest {
    @Test
    fun clearsTheExistingSettingsStackWithoutCreatingOrClearingAnArbitraryTask() {
        assertEquals(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP,
            RecoverySettingsIntent.flags,
        )
        assertEquals(0, RecoverySettingsIntent.flags and Intent.FLAG_ACTIVITY_CLEAR_TASK)
        assertEquals(0, RecoverySettingsIntent.flags and Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
    }
}
