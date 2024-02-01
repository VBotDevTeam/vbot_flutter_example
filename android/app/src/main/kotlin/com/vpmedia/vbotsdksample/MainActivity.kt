package com.vpmedia.vbotsdksample

import android.os.Bundle
import android.os.PersistableBundle
import com.google.firebase.messaging.FirebaseMessaging
import com.vpmedia.sdkvbot.client.ClientListener
import com.vpmedia.sdkvbot.client.VBotClient
import com.vpmedia.sdkvbot.en.AccountRegistrationState
import com.vpmedia.vbotsdksample.ChannelName.VBOT_CHANNEL
import io.flutter.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

object ChannelName {
    const val VBOT_CHANNEL = "com.vpmedia.vbot-sdk-example-dev/vbot_phone"
    const val CALL_STATE_CHANNEL = "com.vpmedia.vbot-sdk-example-dev/call_state"
}

enum class Methods(val value: String) {
    CONNECT("connect"),
    STARTCALL("startcall"),
    GETHOTLINE("gethotline")
}



class MainActivity: FlutterActivity(), MethodChannel.MethodCallHandler {

   lateinit var client: VBotClient
    var tokenFirebase: String = ""

    var cache: String = ""

    private var listener = object : ClientListener() {
        //Lắng nghe trạng thái Account register
        override fun onAccountRegistrationState(status: AccountRegistrationState, reason: String) {
            loginState(status)
        }
        //Lắng nghe lỗi
        override fun onErrorCode(erCode: Int, message: String) {
            super.onErrorCode(erCode, message)
            Log.d("LogApp", "Error: $erCode -- $message")

        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        client = VBotClient(context)
        client.addListener(listener)
        client.startClient()
        getTokenFirebase()
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VBOT_CHANNEL).setMethodCallHandler(this)
    }


    private fun loginState(state: AccountRegistrationState) {
        Log.d("LogApp", "state=$state")


    }
    private fun getTokenFirebase() {
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            try {
                if (task.isSuccessful) {
                    val token = task.result
                    if (!token.isNullOrEmpty()) {
                        tokenFirebase = token

                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when(call.method) {
            Methods.CONNECT.value -> connect(call, result)
            Methods.STARTCALL.value -> startCall(call, result)
            else -> result.notImplemented()
        }
    }

    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        val token = ((call.arguments as? Map<*, *>)?.get("token") ?: "") as String

        client.registerAccount(token, tokenFirebase)

        result.success(mapOf("displayName" to "Display Name"))
    }

    private fun startCall(call: MethodCall, result: MethodChannel.Result) {
        val phoneNumber = ((call.arguments as? Map<*, *>)?.get("phoneNumber") ?: "") as String
        val hotline = ((call.arguments as? Map<*, *>)?.get("hotline") ?: "") as String

        client.addOutgoingCall(hotline, phoneNumber)

        result.success(mapOf("phoneNumber" to phoneNumber))
    }

}
