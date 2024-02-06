package com.vpmedia.vbotsdksample

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class HangUpBroadcast : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d("jhdjshdjs", "HangUpBroadcast")

        context?.let { context ->
            MainActivity.client.declineIncomingCall(true)
            val i = Intent(context, CallingService::class.java)
            context.stopService(i)
            Log.d("jhdjshdjs", "HangUpBroadcastp0?.let")
        }
    }
}