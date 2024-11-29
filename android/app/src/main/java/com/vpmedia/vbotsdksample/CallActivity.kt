package com.vpmedia.vbotsdksample

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.ImageView
import androidx.appcompat.app.AppCompatActivity

class CallActivity : AppCompatActivity() {
    @Suppress("DEPRECATION")
    @SuppressLint("InvalidWakeLockTag")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContentView(R.layout.activity_call)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    or WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                    or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                    or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    or WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )

        registerViewsEvent()
    }

    private fun registerViewsEvent() {
        findViewById<ImageView>(R.id.btnRejectCall).setOnClickListener {
            MainActivity.client.declineIncomingCall(true)
//            val callingService = Intent(this, CallingService::class.java)
//            stopService(callingService)
            finish()
        }

        findViewById<ImageView>(R.id.btnAcceptCall).setOnClickListener {
            MainActivity.client.answerCall()
//            val i = Intent(this, CallingService::class.java)
//            stopService(i)
            finish()
        }
    }
}