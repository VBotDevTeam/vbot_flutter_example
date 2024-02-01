package com.vpmedia.vbotsdksample

import android.os.Bundle
import android.os.PersistableBundle
import com.google.firebase.messaging.FirebaseMessaging
import com.vpmedia.sdkvbot.client.VBotClient
import com.vpmedia.vbotsdksample.ChannelName.VBOT_CHANNEL
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



class MainActivity: FlutterActivity() {

    companion object {
        lateinit var client: VBotClient
        var tokenFirebase: String = ""
    }
    init {

        getTokenFirebase()
    }
    var cache: String = ""
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {


        GeneratedPluginRegistrant.registerWith(flutterEngine);
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VBOT_CHANNEL).setMethodCallHandler(VBotPhone())
    }

    override fun onCreate(savedInstanceState: Bundle?, persistentState: PersistableBundle?) {
        super.onCreate(savedInstanceState, persistentState)
        cache = "cache cache cache"

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



}
