//package com.vpmedia.vbotsdksample
//
//import android.content.BroadcastReceiver
//import android.content.Context
//import android.content.Intent
//import android.util.Log
//
//class AnswerBroadcast : BroadcastReceiver() {
//
//    override fun onReceive(context: Context?, intent: Intent?) {
//        Log.d("VBotPhone", "AnswerBroadcast")
//
//        context?.let { context ->
//            MainActivity.client.answerCall()
//            val i = Intent(context, CallingService::class.java)
//            context.stopService(i)
//            Log.d("VBotPhone", "AnswerBroadcastp0?.let")
//        }
//    }
//}