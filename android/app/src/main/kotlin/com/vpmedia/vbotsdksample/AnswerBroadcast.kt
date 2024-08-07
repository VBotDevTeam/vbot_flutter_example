package com.vpmedia.vbotsdksample

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AnswerBroadcast : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d("jhdjshdjs", "AnswerBroadcast")

        context?.let { context ->
            MainActivity.client.answerCall()
            val i = Intent(context, CallingService::class.java)
            context.stopService(i)
            Log.d("jhdjshdjs", "AnswerBroadcastp0?.let")
        }
    }
}