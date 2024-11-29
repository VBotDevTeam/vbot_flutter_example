package com.vpmedia.vbotsdksample

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.vpmedia.sdkvbot.client.ClientListener
import com.vpmedia.sdkvbot.en.CallState

class CallManager(val context: Context, val hashMap: HashMap<String, String>) {

    private var listener = object : ClientListener() {
        override fun onCallState(state: CallState) {
            super.onCallState(state)
            Log.d("Kdkahkdhsad", state.name)

            when (state) {
                CallState.Incoming -> {
                    MainActivity.client.startRinging()
                }

                CallState.Connecting, CallState.Calling -> {
                    MainActivity.client.stopRinging()
                    val hotlineName = hashMap["hotlineName"].toString()
                    val name = hashMap["name"].toString()
                    val intent = Intent(context, CallActivity::class.java)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_TASK_ON_HOME or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    intent.putExtra("hotlineName", hotlineName)
                    intent.putExtra("name", name)
                    context.startActivity(intent)
                    MainActivity.client.removeListener(this)
                }

                CallState.Confirmed -> {
                }

                CallState.Disconnected -> {
                    MainActivity.client.stopRinging()
                    MainActivity.client.removeListener(this)
                }

                else -> {
//                    MyApplication.client.stopRinging()
//                    MyApplication.client.removeListener(this)
                }
            }
        }
    }

    fun incomingCall() {
        Handler(Looper.getMainLooper()).post {
            MainActivity.initClient(context)
            if (!MainActivity.client.isSetup()) {
                MainActivity.client.setup()
            }
            MainActivity.client.addListener(listener)
            MainActivity.client.notificationCall(hashMap)
        }
    }
}