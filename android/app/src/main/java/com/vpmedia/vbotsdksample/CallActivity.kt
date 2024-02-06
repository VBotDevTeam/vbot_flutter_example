package com.vpmedia.vbotsdksample

import android.content.Intent
import android.os.Bundle
import android.widget.ImageView
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.AppCompatButton

class CallActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_call)
        registerViewsEvent()
    }

    private fun registerViewsEvent() {
        findViewById<ImageView>(R.id.btnRejectCall).setOnClickListener {
            MainActivity.client.declineIncomingCall(true)
            val callingService = Intent(this, CallingService::class.java)
            stopService(callingService)
            finish()
        }

        findViewById<ImageView>(R.id.btnAcceptCall).setOnClickListener {
            MainActivity.client.answerIncomingCall()
            finish()
        }
    }
}