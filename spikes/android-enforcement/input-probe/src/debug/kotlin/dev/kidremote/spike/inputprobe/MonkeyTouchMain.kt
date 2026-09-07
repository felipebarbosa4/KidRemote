package dev.kidremote.spike.inputprobe

import android.os.SystemClock
import android.view.MotionEvent
import java.lang.reflect.InvocationTargetException

/** Lab tool entry only: runs as the authorized shell, independently of fixture/candidate UIDs. */
object MonkeyTouchMain {
    private enum class Outcome { INJECTED, INPUT_REJECTED, SECURITY_EXCEPTION, UNSUPPORTED, OTHER, INVALID_ARGUMENTS }
    private enum class Stage { ARGUMENTS, RESOLVE, DOWN, UP, COMPLETE }

    @JvmStatic
    fun main(args: Array<String>) {
        val x = args.getOrNull(0)?.toIntOrNull() ?: -1
        val y = args.getOrNull(1)?.toIntOrNull() ?: -1
        val request = args.getOrNull(2)?.toLongOrNull() ?: -1
        var stage = Stage.ARGUMENTS
        var outcome = Outcome.INVALID_ARGUMENTS
        var down = false
        var up = false
        try {
            if (args.size != 3 || x !in 0..16383 || y !in 0..16383 || request <= 0) return
            stage = Stage.RESOLVE
            // AOSP Android 10 Monkey tool methods, not a supported product SDK API.
            // Never invoke Monkey.main: it changes global activity/rotation behaviour.
            val type = Class.forName("com.android.commands.monkey.MonkeyTouchEvent")
            val constructor = type.getConstructor(Int::class.javaPrimitiveType)
            val setDownTime = type.getMethod("setDownTime", Long::class.javaPrimitiveType)
            val setEventTime = type.getMethod("setEventTime", Long::class.javaPrimitiveType)
            val addPointer = type.getMethod("addPointer", Int::class.javaPrimitiveType,
                Float::class.javaPrimitiveType, Float::class.javaPrimitiveType,
                Float::class.javaPrimitiveType, Float::class.javaPrimitiveType)
            val inject = type.getMethod("injectEvent", Class.forName("android.view.IWindowManager"),
                Class.forName("android.app.IActivityManager"), Int::class.javaPrimitiveType)
            val time = SystemClock.uptimeMillis()
            fun touch(action: Int): Boolean {
                val event = constructor.newInstance(action)
                setDownTime.invoke(event, time)
                setEventTime.invoke(event, SystemClock.uptimeMillis())
                addPointer.invoke(event, 0, x.toFloat(), y.toFloat(), 1f, 5f)
                // Android 10 MonkeyMotionEvent uses neither manager argument; verbose=0 avoids event output.
                return inject.invoke(event, null, null, 0) == 1
            }
            stage = Stage.DOWN
            try { down = touch(MotionEvent.ACTION_DOWN) } catch (e: Exception) { outcome = classify(e) }
            val downFailed = outcome != Outcome.INVALID_ARGUMENTS
            try {
                if (!downFailed) stage = Stage.UP
                up = touch(MotionEvent.ACTION_UP)
            } catch (e: Exception) { if (!downFailed) outcome = classify(e) }
            if (outcome == Outcome.INVALID_ARGUMENTS) {
                outcome = if (down && up) Outcome.INJECTED else Outcome.INPUT_REJECTED
                stage = Stage.COMPLETE
            }
        } catch (e: Exception) { outcome = classify(e) }
        catch (_: LinkageError) { outcome = Outcome.UNSUPPORTED }
        finally {
            // The only permitted stdout sink: fixed enums/booleans and transient numeric request.
            System.out.println("KR003_MONKEY:v1,$request,$stage,$outcome,$down,$up")
        }
    }

    private fun classify(error: Exception): Outcome {
        val cause = if (error is InvocationTargetException) error.targetException else error
        return when (cause) {
            is SecurityException -> Outcome.SECURITY_EXCEPTION
            is ReflectiveOperationException, is LinkageError -> Outcome.UNSUPPORTED
            else -> Outcome.OTHER
        }
    }
}
