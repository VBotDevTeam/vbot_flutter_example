package com.vpmedia.vbotsdksample

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class RandomNumbers: MethodChannel.MethodCallHandler {
    private val GENERATE = "generate"

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when(call.method) {
            GENERATE -> generate(call, result)
            else -> result.notImplemented()
        }
    }

    private fun generate(call: MethodCall, result: MethodChannel.Result) {
        val userRange = ((call.arguments as? Map<*, *>)?.get("range") ?: 100) as Int
        if(userRange > 100) {
            result.error("Out of range", "Currently we dont support > 100", Exception("outta range"))
        } else {
            val ranNum = (0..userRange).random()
            result.success(mapOf("ran" to ranNum, "rangeStart" to 0, "rangeEnd" to userRange))
        }
    }
}