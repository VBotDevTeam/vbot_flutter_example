package com.vpmedia.vbotsdksample

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.ImageView
import androidx.appcompat.app.AppCompatActivity


class CallActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContentView(R.layout.activity_call)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        registerViewsEvent()
    }

    private fun registerViewsEvent() {
        findViewById<ImageView>(R.id.btnRejectCall).setOnClickListener {
            MainActivity.client.endcall()
            finish()
        }

        findViewById<ImageView>(R.id.btnAcceptCall).setOnClickListener {
            MainActivity.client.answerCall()
            finish()
        }
    }
}