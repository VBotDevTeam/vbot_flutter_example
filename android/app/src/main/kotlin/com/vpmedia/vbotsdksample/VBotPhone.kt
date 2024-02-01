package com.vpmedia.vbotsdksample

import com.vpmedia.sdkvbot.client.VBotClient
import com.vpmedia.vbotsdksample.MainActivity.Companion.tokenFirebase
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class VBotPhone : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when(call.method) {
            Methods.CONNECT.value -> connect(call, result)
            else -> result.notImplemented()
        }
    }

    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        val token = ((call.arguments as? Map<*, *>)?.get("token") ?: "") as String

        MainActivity.client.registerAccount(token, tokenFirebase)

        result.success(mapOf("displayName" to "Display Name"))
    }

}