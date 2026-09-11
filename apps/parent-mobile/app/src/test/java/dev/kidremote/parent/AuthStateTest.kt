package dev.kidremote.parent
import org.junit.Assert.*
import org.junit.Test
class AuthStateTest {
    @Test fun transitionsAndRecovery() {
        val pending=reduce(reduce(AuthState(Screen.SIGNUP),Event.START),Event.SIGNED_UP)
        assertEquals(Screen.VERIFY,pending.screen);assertFalse(pending.loading)
        assertEquals(Screen.RESET,reduce(pending,Event.RECOVERY_VERIFIED).screen)
        assertEquals(Screen.SETUP,reduce(pending,Event.AUTHENTICATED).screen)
    }
    @Test fun errorIsRetryableWithoutInventingAuthentication() {
        val result=reduce(AuthState(Screen.LOGIN,true),Event.FAILURE)
        assertFalse(result.loading);assertEquals(Screen.LOGIN,result.screen);assertNull(result.deviceCount)
    }
    @Test fun logoutClearsSensitivePresentation() {
        val result=reduce(AuthState(Screen.DEVICES,deviceCount=4),Event.LOGOUT)
        assertEquals(Screen.LOGIN,result.screen);assertNull(result.deviceCount)
    }
    @Test fun callbacksRejectForeignHostsFragmentsOverridesAndDuplicates() {
        val token="a".repeat(64)
        val good="http://127.0.0.1:57361/verify?token=$token&type=recovery"
        val origin="http://127.0.0.1:57361"
        assertEquals(token,emailAction(good,"recovery",origin))
        for(bad in listOf(good.replace("127.0.0.1","evil.example"),good+"#access_token=forged",good+"&type=signup",
            good+"&redirect_to=https%3A%2F%2Fevil.example",good.replace("/verify","/user"),good.replace("http:","kidremote:")))
            assertNull(emailAction(bad,"recovery",origin))
        assertNull(emailAction(good,"signup",origin))
        assertNull(emailAction(good,"recovery",""))
    }
}
