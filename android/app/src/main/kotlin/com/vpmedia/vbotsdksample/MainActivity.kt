package com.vpmedia.vbotsdksample

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import com.google.firebase.messaging.FirebaseMessaging
import com.vpmedia.sdkvbot.client.ClientListener
import com.vpmedia.sdkvbot.client.VBotClient
import com.vpmedia.sdkvbot.en.AccountRegistrationState
import com.vpmedia.sdkvbot.en.CallState
import com.vpmedia.vbotsdksample.ChannelName.CALL_STATE_CHANNEL
import com.vpmedia.vbotsdksample.ChannelName.VBOT_CHANNEL
import io.flutter.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

object ChannelName {
    const val VBOT_CHANNEL = "com.vpmedia.vbot-sdk/vbot_phone"
    const val CALL_STATE_CHANNEL = "com.vpmedia.vbot-sdk/call"
}

enum class Methods(val value: String) {
    CONNECT("connect"),
    DISCONNECT("disconnect"),
    STARTCALL("startCall"),
    GETHOTLINE("getHotlines"),
    HANGUP("hangup"),
    MUTE("mute"),
    SPEAKER("speaker"),
    SENDDTMF("sendDTMF"),
    HOLD("hold"),
}


class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private var tokenFirebase: String = ""
    private var resultWrapper: ResultWrapper? = null

    private var isMic = true
    private var isSpeaker = true
    private var onHold = false
    private var typeCall = ""
    private var handler = Handler(Looper.getMainLooper())

    companion object {
        lateinit var client: VBotClient

        var events: EventChannel.EventSink? = null
        var nameCall = ""
        fun clientExists(): Boolean {
            return ::client.isInitialized
        }
    }

    private var runnable: Runnable = object : Runnable {
        override fun run() {
            val callSink = CallSink(
                nameCall,
                typeCall,
                client.getDuration().toString(),
                isMic,
                onHold
            )
            events?.success(callSink.toMap())
            handler.postDelayed(this, 1000)

        }
    }

    private var listener = object : ClientListener() {
        //Lắng nghe trạng thái Account register
        override fun onAccountRegistrationState(status: AccountRegistrationState, reason: String) {
            Log.d("VBotPhone", "state=$status")
            when (status) {
                AccountRegistrationState.Ok -> {
                    try {
                        Log.d("VBotPhone", "AccountRegistrationState.Ok")
                        resultWrapper?.success(mapOf("displayName" to client.getAccountUsername()))
                    } catch (e: Exception) {
                        Log.d("VBotPhone", "error=$e")
                        return
                    }

                }

                AccountRegistrationState.Error -> {
                    try {
                        Log.d("VBotPhone", "AccountRegistrationState.Error")
                        resultWrapper?.error("ERROR", reason, null)
                    } catch (e: Exception) {
                        Log.d("VBotPhone", "error=$e")
                        return
                    }

                }

                else -> {

                }
            }
        }

        //Lắng nghe lỗi
        override fun onErrorCode(erCode: Int, message: String) {
            super.onErrorCode(erCode, message)
            Log.d("VBotPhone", "onErrorCode: $erCode -- $message")

            resultWrapper?.error(erCode.toString(), message, null)


        }

        override fun onCallState(state: CallState) {
            super.onCallState(state)
            runOnUiThread {
                Log.d("VBotPhone", "state: $state")
                val stateCall = when (state) {

                    CallState.Calling, CallState.Early -> {
                        "calling"
                    }

                    CallState.Incoming -> {
                        "incoming"
                    }

                    CallState.Connecting -> {
                        handler.postDelayed(runnable, 1000)
                        "connecting"
                    }

                    CallState.Confirmed -> {
                        "confirmed"
                    }

                    else -> {
                        handler.removeCallbacks(runnable, 1000)
                        "disconnected"
                    }
                }
                typeCall = stateCall

                val callSink = CallSink(
                    nameCall,
                    stateCall,
                    client.getDuration().toString(),
                    isMic,
                    onHold
                )
                events?.success(callSink.toMap())
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        client = VBotClient(context)
        client.addListener(listener)
        client.setup()
        getTokenFirebase()
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, VBOT_CHANNEL
        ).setMethodCallHandler(this)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger, CALL_STATE_CHANNEL
        ).setStreamHandler(this)

        if (hasPermission(this, Manifest.permission.RECORD_AUDIO) && hasPermission(this, Manifest.permission.READ_PHONE_STATE)) {
            Log.d("VBotPhone", "PERMISSION_GRANTED")
        } else {
            requestPermissions(
                arrayOf(
                    Manifest.permission.RECORD_AUDIO,
                    Manifest.permission.READ_PHONE_STATE
                ), 1
            )
        }
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
        resultWrapper = ResultWrapper(result)
        when (call.method) {
            Methods.CONNECT.value -> connect(call, result)
            Methods.DISCONNECT.value -> disconnect(call, result)
            Methods.STARTCALL.value -> startCall(call, result)
            Methods.GETHOTLINE.value -> getHotline(call, result)
            Methods.HANGUP.value -> hangUp(call, result)
            Methods.MUTE.value -> mute(call, result)
            Methods.SPEAKER.value -> speaker(call, result)
            Methods.SENDDTMF.value -> sendDTMF(call, result)
            Methods.HOLD.value -> holdCall(call, result)
            else -> result.notImplemented()
        }
    }

    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        val token = ((call.arguments as? Map<*, *>)?.get("token") ?: "") as String

        if (client.getStateAccount() == AccountRegistrationState.Ok) {
            client.unregisterAndDeleteAccount()
        }
        client.connect(token, tokenFirebase)
    }

    private fun disconnect(call: MethodCall, result: MethodChannel.Result) {
        val isDone = client.disconnect();
        resultWrapper?.success(mapOf("disconnect" to isDone))
    }

    private fun startCall(call: MethodCall, result: MethodChannel.Result) {
        if (hasPermission(this, Manifest.permission.RECORD_AUDIO) && hasPermission(
                this, Manifest.permission.READ_PHONE_STATE
            )
        ) {
            val phoneNumber = ((call.arguments as? Map<*, *>)?.get("phoneNumber") ?: "") as String
            val hotline = ((call.arguments as? Map<*, *>)?.get("hotline") ?: "") as String

            Log.d("VBotPhone", "phoneNumber=$phoneNumber--hotline=$hotline")
            nameCall = phoneNumber
            client.startCall(hotline, phoneNumber)
            result.success(mapOf("phoneNumber" to phoneNumber))
        } else {
            //check quyền
            requestPermissions(
                arrayOf(
                    Manifest.permission.RECORD_AUDIO,
                    Manifest.permission.READ_PHONE_STATE
                ), 1
            )
        }


    }

    private fun mute(call: MethodCall, result: MethodChannel.Result) {
        isMic = !isMic
        client.muteCall(isMic)
    }

    private fun speaker(call: MethodCall, result: MethodChannel.Result) {
        isSpeaker = !isSpeaker
        client.onOffSpeaker(isSpeaker)
    }

    private fun sendDTMF(call: MethodCall, result: MethodChannel.Result) {
        val value = ((call.arguments as? Map<*, *>)?.get("value") ?: "") as String
        client.sendDTMF(value)
    }

    private fun holdCall(call: MethodCall, result: MethodChannel.Result) {
        onHold = !onHold
        client.holdCall(onHold)
    }

    private fun getHotline(call: MethodCall, result: MethodChannel.Result) {
        Log.d("VBotPhone", "getHotline")

        CoroutineScope(Dispatchers.IO).launch {
            runBlocking {
                val list = client.getHotlines()
                Log.d("VBotPhone", "list $list")
                if (list != null) {
                    val listMap: ArrayList<Map<String, String>> = arrayListOf()

                    for (i in list) {
                        listMap.add(mapOf("name" to i.name, "phoneNumber" to i.phoneNumber))
                    }

                    Log.d("VBotPhone", "map=$listMap")

                    result.success(listMap)
                }
            }
        }
    }

    private fun hangUp(call: MethodCall, result: MethodChannel.Result) {
        client.endCall()
    }

    private fun hasPermission(context: Context, permission: String): Boolean {
        return context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        MainActivity.events = events
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

}

open class CallSink(
    var name: String,
    var state: String,
    var duration: String,
    var isMute: Boolean,
    var onHold: Boolean,
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "name" to name,
            "state" to state,
            "duration" to duration,
            "isMute" to isMute,
            "onHold" to onHold,
        )
    }
}

class ResultWrapper(private var result: MethodChannel.Result?) {
    fun success(data: Any?) {
        result?.success(data)
        result = null
    }

    fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        result?.error(errorCode, errorMessage, errorDetails)
        result = null
    }
}