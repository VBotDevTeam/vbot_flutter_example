package com.vpmedia.vbotsdksample

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AnswerBroadcast : BroadcastReceiver() {
    override fun onReceive(p0: Context?, p1: Intent?) {
        p0?.let { context ->
            MainActivity.client.answerIncomingCall()
            val intent = Intent(context, CallingService::class.java)
            context.stopService(intent)
        }
    }
}