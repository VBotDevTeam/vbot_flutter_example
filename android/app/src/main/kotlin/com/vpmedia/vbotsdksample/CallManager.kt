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

            when (state) {
                CallState.Incoming -> {

                }

                CallState.Connecting, CallState.Calling, CallState.Early -> {

                    val hotlineName = hashMap["hotlineName"].toString()
                    val name = hashMap["name"].toString()
                    val intent = Intent(context, MainActivity::class.java)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_TASK_ON_HOME or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    intent.putExtra("hotlineName", hotlineName)
                    intent.putExtra("name", name)
                    context.startActivity(intent)
                    MainActivity.client.removeListener(this)


                }

                CallState.Confirmed -> {
                }

                CallState.Disconnected -> {

                    MainActivity.client.removeListener(this)
                }

                else -> {
                }
            }
        }
    }

    fun incomingCall(name: String) {
        Handler(Looper.getMainLooper()).post {
            MainActivity.initClient(context)
            MainActivity.nameCall = name
            MainActivity.isIncoming = true
            MainActivity.client.addListener(listener)
            MainActivity.client.notificationCall(hashMap)
        }
    }
}