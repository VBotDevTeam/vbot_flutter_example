package com.vpmedia.vbotsdksample

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.vpmedia.sdkvbot.client.ClientListener
import com.vpmedia.sdkvbot.en.CallState
import io.flutter.Log

class FirebaseService : FirebaseMessagingService() {

    companion object {
        @Volatile
        private var incomingCallListener: ClientListener? = null
    }

    /**
     * Đăng ký listener để launch MainActivity khi user accept cuộc gọi từ notification SDK.
     */
    private fun registerIncomingCallListener() {
        if (incomingCallListener != null) {
            MainActivity.client.addListener(incomingCallListener!!)
            return
        }

        val appContext = applicationContext
        val listener = object : ClientListener() {
            override fun onCallState(state: CallState) {
                Log.d("VBotPhone", "FirebaseService.listener.onCallState: $state")
                when (state) {
                    CallState.Connecting, CallState.Confirmed -> {
                        MainActivity.currentCallState = if (state == CallState.Confirmed) "confirmed" else "connecting"

                        Handler(Looper.getMainLooper()).post {
                            try {
                                val intent = Intent(appContext, MainActivity::class.java).apply {
                                    addFlags(
                                        Intent.FLAG_ACTIVITY_NEW_TASK
                                                or Intent.FLAG_ACTIVITY_SINGLE_TOP
                                                or Intent.FLAG_ACTIVITY_CLEAR_TOP
                                    )
                                    putExtra("from_incoming_call", true)
                                }
                                appContext.startActivity(intent)
                                Log.d("VBotPhone", "FirebaseService -> launched MainActivity for: $state")
                            } catch (e: Exception) {
                                Log.d("VBotPhone", "FirebaseService -> launch failed: ${e.message}")
                            }
                        }
                    }
                    CallState.Disconnected, CallState.Null -> {
                        MainActivity.currentCallState = "none"
                        OngoingCallNotification.cancel(appContext)
                    }
                    else -> { /* Incoming: chỉ hiện notification SDK, không mở app */ }
                }
            }
        }
        incomingCallListener = listener
        MainActivity.client.addListener(listener)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d("VBotPhone", "FirebaseService -> onNewToken: $token")
        MainActivity.tokenFirebase = token
        
        if (MainActivity.events != null) {
            Handler(Looper.getMainLooper()).post {
                val callSink = CallSink(
                    name = MainActivity.nameCall,
                    state = MainActivity.currentCallState,
                    isIncoming = MainActivity.isIncoming,
                    isMute = MainActivity.isMute,
                    onHold = MainActivity.onHold,
                    message = "🔑 [FCM Token Mới]: $token"
                )
                MainActivity.events?.success(callSink.toMap())
            }
        }
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val map = HashMap(remoteMessage.data)
        val notifTitle = remoteMessage.notification?.title ?: ""
        val notifBody = remoteMessage.notification?.body ?: ""

        Log.d("VBotPhone", "FirebaseService -> onMessageReceived: data=$map, notifTitle=$notifTitle, notifBody=$notifBody, isForeground=${MainActivity.isForeground}")

        val hasCallInfo = map.containsKey("transId") || map.containsKey("callId") || map.containsKey("hotline")

        if (hasCallInfo) {
            val callerName = map["name"] ?: map["caller"] ?: "AutoCall / Khách hàng"
            val hotline = map["hotline"] ?: ""
            val transId = map["transId"] ?: map["callId"] ?: ""
            MainActivity.currentTransId = transId
            
            if (callerName.isNotEmpty()) {
                MainActivity.nameCall = callerName
                MainActivity.isIncoming = true
            }
            MainActivity.currentCallState = "incoming"

            MainActivity.initClient(applicationContext)
            registerIncomingCallListener()

            // Gọi notificationCall của SDK để xử lý SIP incoming
            try {
                MainActivity.client.notificationCall(map)
                Log.d("VBotPhone", "FirebaseService -> client.notificationCall(map) thành công")
            } catch (e: Exception) {
                Log.e("VBotPhone", "FirebaseService -> client.notificationCall(map) lỗi: ${e.message}")
            }

            // Gửi log chi tiết sang Flutter Box Log
            if (MainActivity.events != null) {
                Handler(Looper.getMainLooper()).post {
                    val callSink = CallSink(
                        name = MainActivity.nameCall,
                        state = "incoming",
                        isIncoming = true,
                        isMute = MainActivity.isMute,
                        onHold = MainActivity.onHold,
                        message = "📩 [FCM Push Cuộc Gọi Đến]: Tên=$callerName, Hotline=$hotline, TransId=$transId, Payload=$map"
                    )
                    MainActivity.events?.success(callSink.toMap())

                    // Nếu app đang foreground thì cancel system notification banner để tránh che UI
                    if (MainActivity.isForeground) {
                        try {
                            val notificationManager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            notificationManager.cancelAll()
                        } catch (_: Exception) {}
                    }
                }
            }
        } else {
            // Push không phải cuộc gọi hoặc format khác
            if (MainActivity.events != null) {
                Handler(Looper.getMainLooper()).post {
                    val callSink = CallSink(
                        name = MainActivity.nameCall,
                        state = MainActivity.currentCallState,
                        isIncoming = MainActivity.isIncoming,
                        isMute = MainActivity.isMute,
                        onHold = MainActivity.onHold,
                        message = "📩 [FCM Push Nhận Được]: data=$map, notification=$notifTitle / $notifBody"
                    )
                    MainActivity.events?.success(callSink.toMap())
                }
            }
        }
    }
}
