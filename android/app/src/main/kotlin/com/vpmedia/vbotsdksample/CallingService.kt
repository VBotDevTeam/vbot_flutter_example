package com.vpmedia.vbotsdksample

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

class CallingService : Service() {
    companion object {
        const val CHANNEL_ID = "Calling channel id"
    }

    override fun onBind(p0: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        showIncomingCallPopup()
        return START_STICKY
    }

    @SuppressLint("RemoteViewLayout")
    private fun showIncomingCallPopup() {
        val hangupIntent = Intent(applicationContext, HangUpBroadcast::class.java)
        val hangupPendingIntent = PendingIntent.getBroadcast(
            applicationContext,
            0,
            hangupIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val incomingCallIntent = Intent(applicationContext, CallActivity::class.java)
        incomingCallIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val incomingCallPendingIntent = PendingIntent.getActivity(
            applicationContext,
            0,
            incomingCallIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val answerIntent = Intent(applicationContext, AnswerBroadcast::class.java)
        val answerPendingIntent = PendingIntent.getBroadcast(
            applicationContext,
            0,
            answerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val customView = RemoteViews(packageName, R.layout.incoming_call_popup).apply {
            setOnClickPendingIntent(R.id.btnAcceptCall, answerPendingIntent)
            setOnClickPendingIntent(R.id.btnRejectCall, hangupPendingIntent)
        }

        createNotificationChanel()
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setContentTitle("Tên")
            .setContentText("Số điện thoại")
            .setSubText("Cuộc gọi đến")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContent(customView)
            .setFullScreenIntent(incomingCallPendingIntent, true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVibrate(longArrayOf(0, 500, 1000))
            .setAutoCancel(true)
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        startForeground(1024, notification.build())
    }

    private fun createNotificationChanel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Incoming call"
            val important = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, important)
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}