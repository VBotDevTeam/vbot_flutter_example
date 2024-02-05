package com.vpmedia.vbotsdksample

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.AppCompatButton

class CallActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_call)
        registerViewsEvent()
    }

    private fun registerViewsEvent() {
        findViewById<AppCompatButton>(R.id.btnRejectCall).setOnClickListener {
            MainActivity.client.declineIncomingCall(true)
            val callingService = Intent(this, CallingService::class.java)
            stopService(callingService)

            finish()
        }

        findViewById<AppCompatButton>(R.id.btnAcceptCall).setOnClickListener {
            MainActivity.client.answerIncomingCall()
            finish()
        }
    }
}