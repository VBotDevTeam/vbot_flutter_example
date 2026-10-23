package com.vpmedia.vbotsdksample

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.content.Intent
import android.os.Looper
import android.net.Uri
import android.provider.Settings
import com.google.firebase.messaging.FirebaseMessaging
import com.vpmedia.sdkvbot.client.ClientListener
import com.vpmedia.sdkvbot.client.VBotClient
import com.vpmedia.sdkvbot.client.VBotCompletion
import com.vpmedia.sdkvbot.client.VBotConfig
import com.vpmedia.sdkvbot.client.VBotEnvironment
import com.vpmedia.sdkvbot.en.AccountRegistrationState
import com.vpmedia.sdkvbot.en.CallState
import com.vpmedia.sdkvbot.en.VBotCallEndParty
import com.vpmedia.sdkvbot.en.VBotEndCallReason
import com.vpmedia.vbotsdksample.ChannelName.CALL_STATE_CHANNEL
import com.vpmedia.vbotsdksample.ChannelName.VBOT_CHANNEL
import io.flutter.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest

object ChannelName {
    const val VBOT_CHANNEL = "com.vpmedia.vbot-sdk/vbot_phone"
    const val CALL_STATE_CHANNEL = "com.vpmedia.vbot-sdk/call"
}

enum class Methods(val value: String) {
    ISUSERCONNECTED("isUserConnected"),
    USERDISPLAYNAME("userDisplayName"),
    CONNECT("connect"),
    DISCONNECT("disconnect"),
    STARTCALL("startCall"),
    GETHOTLINE("getHotlines"),
    ANSWER("answer"),
    HANGUP("hangup"),
    MUTE("mute"),
    SPEAKER("speaker"),
    SENDDTMF("sendDTMF"),
    HOLD("hold"),
}

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private var resultWrapper: ResultWrapper? = null

    companion object {
        var tokenFirebase: String = ""
        @SuppressLint("StaticFieldLeak")
        lateinit var client: VBotClient

        var events: EventChannel.EventSink? = null
        var nameCall = ""
        var currentCallState = "none"
        var isIncoming = false
        var isMute = false
        var isSpeaker = false
        var onHold = false

        var isForeground = false
        var isWaitingToAnswer = false

        // ═══════════════════════════════════════════════
        // TRACKING CONTEXT — dùng để phân tích call end reason
        // ═══════════════════════════════════════════════

        /** Cuộc gọi đã từng đạt trạng thái Confirmed (đã bắt máy) chưa? */
        var wasConfirmed = false

        /** Timestamp khi cuộc gọi bắt đầu (Calling/Incoming) */
        var callStartTimestamp: Long = 0

        /** Timestamp khi cuộc gọi được confirmed (bắt máy) */
        var callConfirmedTimestamp: Long = 0

        /** User local chủ động hangup? */
        var localHangup = false

        /** Timestamp khi chuyển sang trạng thái Early (SIP 183 / 180 có early media) */
        var callEarlyTimestamp: Long = 0L

        /** Đánh dấu cuộc gọi có trải qua trạng thái Early không */
        var isInEarlyState: Boolean = false

        /** Thời gian shipper ở trong trạng thái Early (nghe nhạc chuông hoặc thông báo) */
        var earlyDuration: Long = 0L

        /** Timestamp khi shipper bấm gác máy */
        var hangupTimestamp: Long = 0L

        /** Lưu externalCallId để query server */
        var externalCallId: String = ""

        /** Lưu lịch sử trạng thái cuộc gọi */
        var callStateHistory: MutableList<String> = mutableListOf()

        /** Lưu transId của cuộc gọi hiện tại */
        var currentTransId: String = ""

        /** Đếm số callback được gọi trong 1 cuộc gọi */
        var callbackCounter = 0

        fun clientExists(): Boolean {
            return ::client.isInitialized
        }

        fun resetCallTracking() {
            Log.d("VBotPhone", "🔄 [TRACKING] Reset all tracking vars")
            wasConfirmed = false
            callStartTimestamp = 0
            callConfirmedTimestamp = 0
            callEarlyTimestamp = 0
            isInEarlyState = false
            earlyDuration = 0
            hangupTimestamp = 0
            localHangup = false
            externalCallId = ""
            currentTransId = ""
            callStateHistory.clear()
            callbackCounter = 0
        }

        fun enableSdkLogging() {
            try {
                val clz = Class.forName("com.vpmedia.sdkvbot.client.VBotLogger")
                val instanceField = clz.getDeclaredField("INSTANCE")
                val logger = instanceField.get(null)
                val debugField = clz.getDeclaredField("debugMode")
                debugField.isAccessible = true
                debugField.set(logger, true)
                Log.i("VBotPhone", "🚀 [SDK-LOGGER] Đã kích hoạt VBotLogger.debugMode = true thành công!")
            } catch (e: Exception) {
                Log.w("VBotPhone", "⚠️ [SDK-LOGGER] Không thể gán debugMode qua reflection: ${e.message}")
            }
        }

        fun initClient(context: Context) {
            enableSdkLogging()
            if (clientExists()) return
            client = VBotClient(context)
            client.setup(VBotConfig(VBotEnvironment.STAGING))
            enableSdkLogging()
        }

        fun getEndReasonVietnamese(reason: VBotEndCallReason): String {
            return when (reason) {
                VBotEndCallReason.normaly -> "Kết thúc bình thường (Normal)"
                VBotEndCallReason.busy -> "Máy bận (Busy)"
                VBotEndCallReason.timeOut -> "Hết thời gian chờ kết nối (Timeout)"
                VBotEndCallReason.incomingCallTimeout -> "Hết thời gian chờ nhận cuộc gọi (Incoming Call Timeout)"
                VBotEndCallReason.decline -> "Từ chối cuộc gọi (Decline)"
                VBotEndCallReason.callerCanceled -> "Người gọi đã huỷ / gác máy (Caller Canceled)"
                VBotEndCallReason.connectionError -> "Lỗi kết nối máy chủ (Connection Error)"
                VBotEndCallReason.transmissionError -> "Lỗi đường truyền âm thanh / RTP (Transmission Error)"
                VBotEndCallReason.destinationNotFound -> "Không tìm thấy số đích / máy nhánh (404 Not Found)"
                VBotEndCallReason.destinationGone -> "Số máy nhánh không còn khả dụng (Destination Gone)"
                VBotEndCallReason.temporarilyUnavailable -> "Tạm thời không liên lạc được (Temporarily Unavailable)"
                VBotEndCallReason.recipientAbsent -> "Người nhận vắng mặt / không phản hồi (Recipient Absent)"
                VBotEndCallReason.recipientBlocksCalls -> "Người nhận chặn cuộc gọi (Recipient Blocks Calls)"
                VBotEndCallReason.doNotDisturb -> "Chế độ không làm phiền (Do Not Disturb)"
                VBotEndCallReason.insufficientBalance -> "Tài khoản không đủ số dư (Insufficient Balance)"
                VBotEndCallReason.packageExpired -> "Gói cước đã hết hạn (Package Expired)"
                VBotEndCallReason.projectExpired -> "Dự án đã hết hạn (Project Expired)"
                VBotEndCallReason.unauthenticated -> "Chưa xác thực tài khoản (Unauthenticated)"
                VBotEndCallReason.authenticatedFailed -> "Xác thực thất bại (Authentication Failed)"
                VBotEndCallReason.noAccount -> "Không tìm thấy tài khoản SIP (No Account)"
                VBotEndCallReason.noVBotUser -> "Không tìm thấy người dùng VBot (No VBot User)"
                VBotEndCallReason.invalidPhoneNumber -> "Số điện thoại không hợp lệ (Invalid Phone Number)"
                VBotEndCallReason.microphonePermissionDenied -> "Chưa cấp quyền Microphone (Microphone Permission Denied)"
                VBotEndCallReason.anotherCallInProgress -> "Đang có cuộc gọi khác đang diễn ra (Another Call In Progress)"
                VBotEndCallReason.unknownError -> "Lỗi không xác định (Unknown Error)"
                else -> {
                    val desc = try { reason.description } catch (_: Exception) { null }
                    if (!desc.isNullOrEmpty()) desc else reason.name
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        isForeground = true
    }

    override fun onPause() {
        super.onPause()
        isForeground = false
    }

    private var listener = object : ClientListener() {
        override fun onUserConnected(displayName: String) {
            runOnUiThread {
                Log.d("VBotPhone", "onUserConnected: $displayName")
                val callSink = CallSink(
                    name = nameCall,
                    state = currentCallState,
                    isIncoming = isIncoming,
                    isMute = isMute,
                    onHold = onHold,
                    message = "👤 [User Connected] Đã kết nối người dùng: $displayName"
                )
                events?.success(callSink.toMap())
            }
        }

        override fun onAccountRegistrationState(status: AccountRegistrationState, reason: String) {
            runOnUiThread {
                Log.d("VBotPhone", "onAccountRegistrationState: status=$status, reason=$reason")
                val statusText = if (status == AccountRegistrationState.Ok) "🟢 Đã đăng ký SIP thành công (Ok)" else "🔴 Trạng thái SIP: $status"
                val callSink = CallSink(
                    name = nameCall,
                    state = currentCallState,
                    isIncoming = isIncoming,
                    isMute = isMute,
                    onHold = onHold,
                    message = "🌐 [SIP Registration] $statusText (Lý do: $reason)"
                )
                events?.success(callSink.toMap())
            }
        }

        override fun onCallState(state: CallState) {
            runOnUiThread {
                val hasActive = if (clientExists()) client.hasActiveCall() else false
                val duration = if (clientExists()) client.getDuration() else null

                // ══════ TRACKING: ghi lại lịch sử ══════
                callbackCounter++
                callStateHistory.add("${state.name}@${System.currentTimeMillis()}")
                Log.d("VBotPhone", "═══════════════════════════════════════")
                Log.d("VBotPhone", "📊 [CALLBACK #$callbackCounter] onCallState: ${state.name}")
                Log.d("VBotPhone", "  ├─ hasActiveCall=$hasActive")
                Log.d("VBotPhone", "  ├─ duration=$duration")
                Log.d("VBotPhone", "  ├─ wasConfirmed=$wasConfirmed")
                Log.d("VBotPhone", "  ├─ isIncoming=$isIncoming")
                Log.d("VBotPhone", "  ├─ localHangup=$localHangup")
                Log.d("VBotPhone", "  └─ history=${callStateHistory.joinToString(" → ")}")
                Log.d("VBotPhone", "═══════════════════════════════════════")

                currentCallState = when (state) {
                    CallState.Null -> {
                        isIncoming = false
                        "none"
                    }
                    CallState.Calling -> {
                        isIncoming = false
                        // ══ TRACKING: ghi timestamp bắt đầu gọi ══
                        if (callStartTimestamp == 0L) {
                            callStartTimestamp = System.currentTimeMillis()
                            localHangup = false
                            Log.d("VBotPhone", "⏱️ [TRACKING] Call started (CALLING) at: $callStartTimestamp")
                        }
                        "calling"
                    }
                    CallState.Early -> {
                        isIncoming = false
                        if (callStartTimestamp == 0L) {
                            callStartTimestamp = System.currentTimeMillis()
                            localHangup = false
                        }
                        if (callEarlyTimestamp == 0L) {
                            callEarlyTimestamp = System.currentTimeMillis()
                            isInEarlyState = true
                            val callingWait = callEarlyTimestamp - callStartTimestamp
                            Log.d("VBotPhone", "🎵 [TRACKING] Cuộc gọi chuyển sang EARLY (SIP 183 Early Media / 180 Ringback) sau ${callingWait}ms Calling")
                            Log.d("VBotPhone", "  └─ 📢 Đang nhận luồng âm thanh hoặc thông báo tự động từ tổng đài!")
                        }
                        "calling"
                    }
                    CallState.Incoming -> {
                        isIncoming = true
                        // ══ TRACKING: ghi timestamp nhận cuộc gọi ══
                        if (callStartTimestamp == 0L) {
                            callStartTimestamp = System.currentTimeMillis()
                            localHangup = false
                            Log.d("VBotPhone", "⏱️ [TRACKING] Incoming call at: $callStartTimestamp")
                        }
                        if (nameCall.isEmpty()) {
                            nameCall = client.callName() ?: ""
                        }
                        if (isForeground) {
                            try {
                                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                                notificationManager.cancelAll()
                            } catch (_: Exception) {}
                        }
                        "incoming"
                    }
                    CallState.Connecting -> "connecting"
                    CallState.Confirmed -> {
                        // ═══ TRACKING: đánh dấu đã bắt máy ═══
                        wasConfirmed = true
                        callConfirmedTimestamp = System.currentTimeMillis()
                        Log.d("VBotPhone", "✅ [TRACKING] Call CONFIRMED at: $callConfirmedTimestamp")
                        Log.d("VBotPhone", "  └─ Ring duration: ${callConfirmedTimestamp - callStartTimestamp}ms")
                        OngoingCallNotification.show(
                            applicationContext,
                            nameCall.ifEmpty { "Cuộc gọi" }
                        )
                        "confirmed"
                    }
                    else -> {
                        isMute = false
                        isSpeaker = false
                        OngoingCallNotification.cancel(applicationContext)
                        Log.d("VBotPhone", "📊 [CALLBACK #$callbackCounter] onCallState: Disconnected — ĐÂY KHÔNG PHẢI HÀM TRẢ KẾT QUẢ (không có endedReason/endedBy)")
                        "disconnected"
                    }
                }

                val callSink = CallSink(
                    name = nameCall,
                    state = currentCallState,
                    isIncoming = isIncoming,
                    isMute = isMute,
                    onHold = onHold,
                    message = "⚡ [onCallState] -> ${state.name.uppercase()} (hasActiveCall=$hasActive, duration=${duration ?: 0}s, incoming=$isIncoming)"
                )
                events?.success(callSink.toMap())

                if (state == CallState.Disconnected || state == CallState.Null) {
                    isIncoming = false
                    nameCall = ""
                    currentCallState = "none"
                    // Lưu ý: KHÔNG reset tracking vars ở đây
                    // để onCallEnded còn dùng, reset sau trong onCallEnded
                }
            }
        }

        override fun onCallEnded(reason: VBotEndCallReason, endedBy: VBotCallEndParty) {
            runOnUiThread {
                callbackCounter++
                val now = System.currentTimeMillis()
                val totalDuration = if (callStartTimestamp > 0) now - callStartTimestamp else 0
                val confirmedDuration = if (wasConfirmed && callConfirmedTimestamp > 0) now - callConfirmedTimestamp else 0
                if (localHangup && isInEarlyState && callEarlyTimestamp > 0 && earlyDuration == 0L) {
                    earlyDuration = (if (hangupTimestamp > 0) hangupTimestamp else now) - callEarlyTimestamp
                }

                // ═══════════════════════════════════════════════════
                // LOG 1: ⭐ HÀM TRẢ KẾT QUẢ — onCallEnded(2 params)
                // ═══════════════════════════════════════════════════
                Log.d("VBotPhone", "🔴🔴🔴═══════════════════════════════════════")
                Log.d("VBotPhone", "🔴 [CALLBACK #$callbackCounter] onCallEnded(reason, endedBy)")
                Log.d("VBotPhone", "🔴 ⭐ ĐÂY LÀ HÀM TRẢ KẾT QUẢ (có endedReason + endedBy)")
                Log.d("VBotPhone", "  ├─ SDK reason     : ${reason.name}")
                Log.d("VBotPhone", "  ├─ SDK endedBy    : ${endedBy.name}")
                Log.d("VBotPhone", "  ├─ wasConfirmed   : $wasConfirmed")
                Log.d("VBotPhone", "  ├─ localHangup    : $localHangup")
                Log.d("VBotPhone", "  ├─ isIncoming     : $isIncoming")
                Log.d("VBotPhone", "  ├─ isInEarlyState : $isInEarlyState")
                Log.d("VBotPhone", "  ├─ earlyDuration  : ${earlyDuration}ms (${earlyDuration / 1000}s)")
                Log.d("VBotPhone", "  ├─ totalDuration  : ${totalDuration}ms (${totalDuration/1000}s)")
                Log.d("VBotPhone", "  ├─ confirmedDur   : ${confirmedDuration}ms")
                Log.d("VBotPhone", "  ├─ externalCallId : $externalCallId")
                Log.d("VBotPhone", "  └─ stateHistory   : ${callStateHistory.joinToString(" → ")}")
                Log.d("VBotPhone", "🔴🔴🔴═══════════════════════════════════════")

                // ═══════════════════════════════════════════════════
                // DIAGNOSTIC LOG (Case 3 / Case 4 / Case 5)
                // ═══════════════════════════════════════════════════
                Log.d("VBotPhone", "🎯═══════════════════════════════════════")
                Log.d("VBotPhone", "🎯 [TEST TRACKING DIAGNOSTIC]:")
                Log.d("VBotPhone", "  ├─ SDK raw reason   : ${reason.name}")
                Log.d("VBotPhone", "  ├─ SDK raw endedBy  : ${endedBy.name}")
                Log.d("VBotPhone", "  ├─ Ring duration    : ${totalDuration}ms (${totalDuration / 1000}s)")
                Log.d("VBotPhone", "  ├─ wasConfirmed     : $wasConfirmed")
                Log.d("VBotPhone", "  ├─ isIncoming       : $isIncoming")
                Log.d("VBotPhone", "  ├─ isInEarlyState   : $isInEarlyState")
                Log.d("VBotPhone", "  ├─ earlyDuration    : ${earlyDuration}ms (${earlyDuration / 1000}s)")
                Log.d("VBotPhone", "  ├─ externalCallId   : $externalCallId")
                when {
                    localHangup && !wasConfirmed && !isIncoming && isInEarlyState -> {
                        Log.w("VBotPhone", "  🚨═══════════════════════════════════════════════")
                        Log.w("VBotPhone", "  🚨 [CASE CHẾ ĐỘ MÁY BAY / EARLY MEDIA ANNOUNCEMENT]:")
                        Log.w("VBotPhone", "  🚨 Shipper cúp máy sau ${earlyDuration / 1000}s nghe thông báo tự động (Early Media)!")
                        Log.w("VBotPhone", "  🚨 SDK gốc trả về: ${reason.name} / ${endedBy.name}")
                        Log.w("VBotPhone", "  🚨 Kỳ vọng nghiệp vụ: recipientAbsent (nếu máy bay/thuê bao).")
                        Log.w("VBotPhone", "  🚨 Nhưng hiện tại đang bị Case 6 map thành callerCanceled do localHangup=true!")
                        Log.w("VBotPhone", "  🚨═══════════════════════════════════════════════")
                    }
                    localHangup && !wasConfirmed && !isIncoming -> {
                        if (reason == VBotEndCallReason.callerCanceled) {
                            Log.d("VBotPhone", "  └─ ✅ CASE 6: SDK TRẢ ĐÚNG callerCanceled (SIP 487 / Cancel)!")
                        } else {
                            Log.d("VBotPhone", "  └─ 🎯 CASE 6: Người gọi chủ động dập máy (localHangup=true, chưa bắt máy) → SDK trả ${reason.name}. Cần fix trong SDK!")
                        }
                    }
                    reason == VBotEndCallReason.destinationNotFound -> {
                        Log.d("VBotPhone", "  └─ ✅ CASE 7: SDK TRẢ ĐÚNG destinationNotFound (SIP 404 / Không tìm thấy số đích)!")
                    }
                    reason == VBotEndCallReason.invalidPhoneNumber -> {
                        Log.d("VBotPhone", "  └─ ✅ CASE 7: SDK TRẢ ĐÚNG invalidPhoneNumber (Số điện thoại không hợp lệ / Mã 2004)!")
                    }
                    reason == VBotEndCallReason.timeOut -> {
                        Log.d("VBotPhone", "  └─ ✅ CASE 5: SDK TRẢ ĐÚNG timeOut (SIP 408)!")
                    }
                    reason == VBotEndCallReason.temporarilyUnavailable && totalDuration / 1000 > 25 && !wasConfirmed -> {
                        Log.d("VBotPhone", "  └─ ⚠️ CASE 5: Ring ${totalDuration / 1000}s (>25s) → SDK trả temporarilyUnavailable (SIP 480). Cần server gửi SIP 408!")
                    }
                    reason == VBotEndCallReason.doNotDisturb -> {
                        Log.d("VBotPhone", "  └─ ✅ CASE 4: SDK TRẢ ĐÚNG doNotDisturb (SIP 409)!")
                    }
                    reason == VBotEndCallReason.recipientBlocksCalls -> {
                        Log.d("VBotPhone", "  └─ ✅ CASE 3: SDK TRẢ ĐÚNG recipientBlocksCalls (SIP 403)!")
                    }
                    reason == VBotEndCallReason.temporarilyUnavailable && totalDuration / 1000 < 5 -> {
                        Log.d("VBotPhone", "  └─ ⚠️ Ngắt tức thì (<5s): SDK trả temporarilyUnavailable (SIP 480). Cần đối chiếu Server xem là Case 7 (404), Case 3 (403) hay Case 4 (409)!")
                    }
                    reason == VBotEndCallReason.busy -> {
                        Log.d("VBotPhone", "  └─ ℹ️ SDK trả busy (SIP 486).")
                    }
                    else -> {
                        Log.d("VBotPhone", "  └─ ℹ️ SDK trả ${reason.name}. Cần đối chiếu Server (externalCallId=$externalCallId)")
                    }
                }
                Log.d("VBotPhone", "🎯═══════════════════════════════════════")

                // ═══════════════════════════════════════════════════
                // RESOLVER: Phân tích và trả kết quả cuối cùng
                // ═══════════════════════════════════════════════════
                val resolvedReason: VBotEndCallReason
                val resolvedConfidence: String
                val resolvedExplanation: String

                when {
                    // CASE 1: decline + wasConfirmed → normaly
                    reason == VBotEndCallReason.decline && wasConfirmed -> {
                        resolvedReason = VBotEndCallReason.normaly
                        resolvedConfidence = "high"
                        resolvedExplanation = "CASE 1: Cuộc gọi đã confirmed (bắt máy) rồi kết thúc → normaly"
                    }
                    // CASE 6: localHangup + chưa confirmed + outgoing → callerCanceled
                    localHangup && !wasConfirmed && !isIncoming -> {
                        resolvedReason = VBotEndCallReason.callerCanceled
                        resolvedConfidence = "high"
                        resolvedExplanation = "CASE 6: Người gọi chủ động hủy trước khi bắt máy (localHangup=true) → callerCanceled"
                    }
                    // CASE 5: temporarilyUnavailable + > 25s → timeout
                    reason == VBotEndCallReason.temporarilyUnavailable && totalDuration / 1000 > 25 && !wasConfirmed -> {
                        resolvedReason = VBotEndCallReason.timeOut
                        resolvedConfidence = "high"
                        resolvedExplanation = "CASE 5: Ring ${totalDuration/1000}s > 25s → timeout"
                    }
                    // CASE 2/3/4/7: temporarilyUnavailable — giữ nguyên SDK, chờ server sửa SIP code
                    // Root cause: SIP server trả 480 thay vì 603 khi callee reject
                    // Khi server sửa, SDK sẽ tự động map đúng 603 → decline
                    reason == VBotEndCallReason.temporarilyUnavailable && !wasConfirmed -> {
                        resolvedReason = reason
                        resolvedConfidence = "sdk_original"
                        resolvedExplanation = "temporarilyUnavailable ring ${totalDuration/1000}s — giữ nguyên SDK, chờ server sửa SIP code (480→603)"
                    }
                    // Các case khác: giữ nguyên SDK
                    else -> {
                        resolvedReason = reason
                        resolvedConfidence = "sdk_original"
                        resolvedExplanation = "SDK reason không cần điều chỉnh"
                    }
                }

                val wasAdjusted = resolvedReason != reason
                Log.d("VBotPhone", "🟢═══════════════════════════════════════")
                Log.d("VBotPhone", "🟢 [RESOLVED] KẾT QUẢ CUỐI CÙNG:")
                Log.d("VBotPhone", "  ├─ SDK gốc       : ${reason.name}")
                Log.d("VBotPhone", "  ├─ Resolved      : ${resolvedReason.name}")
                Log.d("VBotPhone", "  ├─ Confidence    : $resolvedConfidence")
                Log.d("VBotPhone", "  ├─ Đã điều chỉnh : ${if (wasAdjusted) "✅ CÓ" else "❌ KHÔNG"}")
                Log.d("VBotPhone", "  ├─ Giải thích    : $resolvedExplanation")
                Log.d("VBotPhone", "  └─ Server kỳ vọng: Cần kiểm tra → externalCallId=$externalCallId")
                Log.d("VBotPhone", "🟢═══════════════════════════════════════")

                val reasonVi = getEndReasonVietnamese(resolvedReason)
                val callSink = CallSink(
                    name = nameCall,
                    state = "disconnected",
                    isIncoming = isIncoming,
                    isMute = isMute,
                    onHold = onHold,
                    endedReason = resolvedReason.key,
                    endedBy = endedBy.key,
                    message = buildString {
                        append("🔴 [onCallEnded] $reasonVi (${resolvedReason.name}), Kết thúc bởi: ${endedBy.name}")
                        append("\n📊 SDK gốc: reason=${reason.name}, endedBy=${endedBy.name}")
                        append("\n🔄 Resolver: ${resolvedReason.name} ($resolvedConfidence)")
                        append("\n⏱️ Duration: total=${totalDuration/1000}s, confirmed=${confirmedDuration/1000}s")
                        if (wasAdjusted) {
                            append("\n⚠️ ĐÃ ĐIỀU CHỈNH: ${reason.name} → ${resolvedReason.name}")
                            append("\n📝 $resolvedExplanation")
                        }
                    }
                )
                events?.success(callSink.toMap())

                // ═══ Reset tracking sau khi đã dùng xong ═══
                resetCallTracking()
            }
        }

        override fun onCallEnded(reason: VBotEndCallReason) {
            runOnUiThread {
                callbackCounter++
                val now = System.currentTimeMillis()
                val totalDuration = if (callStartTimestamp > 0) now - callStartTimestamp else 0

                Log.d("VBotPhone", "🔴═══════════════════════════════════════")
                Log.d("VBotPhone", "🔴 [CALLBACK #$callbackCounter] onCallEnded(1 param) — KHÔNG có endedBy")
                Log.d("VBotPhone", "  ├─ SDK reason     : ${reason.name}")
                Log.d("VBotPhone", "  ├─ wasConfirmed   : $wasConfirmed")
                Log.d("VBotPhone", "  ├─ totalDuration  : ${totalDuration}ms")
                Log.d("VBotPhone", "  └─ stateHistory   : ${callStateHistory.joinToString(" → ")}")
                Log.d("VBotPhone", "🔴═══════════════════════════════════════")

                val resolvedReason = if (reason == VBotEndCallReason.decline && wasConfirmed) {
                    Log.d("VBotPhone", "🟢 [CASE1-RESOLVED] decline → normaly")
                    VBotEndCallReason.normaly
                } else {
                    reason
                }

                val wasAdjusted = resolvedReason != reason
                val reasonVi = getEndReasonVietnamese(resolvedReason)
                Log.d("VBotPhone", "🟢 [RESOLVED] ${reason.name} → ${resolvedReason.name} (adjusted=$wasAdjusted)")

                val callSink = CallSink(
                    name = nameCall,
                    state = "disconnected",
                    isIncoming = isIncoming,
                    isMute = isMute,
                    onHold = onHold,
                    endedReason = resolvedReason.key,
                    endedBy = "unknown",
                    message = buildString {
                        append("🔴 [onCallEnded(1 param)] $reasonVi (${resolvedReason.name})")
                        append("\n📊 SDK gốc: reason=${reason.name}")
                        append("\n⏱️ Duration: total=${totalDuration/1000}s")
                        if (wasAdjusted) {
                            append("\n⚠️ ĐÃ ĐIỀU CHỈNH: ${reason.name} → ${resolvedReason.name}")
                        }
                    }
                )
                events?.success(callSink.toMap())

                // ═══ Reset tracking ═══
                resetCallTracking()
            }
        }

        override fun onExternalCallId(externalCallId: String) {
            callbackCounter++
            Log.d("VBotPhone", "═══════════════════════════════════════")
            Log.d("VBotPhone", "📊 [CALLBACK #$callbackCounter] onExternalCallId")
            Log.d("VBotPhone", "  └─ externalCallId: $externalCallId")
            Log.d("VBotPhone", "═══════════════════════════════════════")
            // ══ TRACKING: lưu ID để so sánh với server ══
            MainActivity.externalCallId = externalCallId
            runOnUiThread {
                val callSink = CallSink(
                    name = nameCall,
                    state = currentCallState,
                    isIncoming = isIncoming,
                    isMute = isMute,
                    onHold = onHold,
                    message = "🆔 [External Call ID]: $externalCallId"
                )
                events?.success(callSink.toMap())
            }
        }

        override fun onCallMuteStateChanged(muted: Boolean) {
            Log.d("VBotPhone", "onCallMuteStateChanged: muted=$muted")
            runOnUiThread {
                isMute = muted
                val callSink = CallSink(
                    name = nameCall,
                    state = currentCallState,
                    isIncoming = isIncoming,
                    isMute = isMute,
                    onHold = onHold,
                    message = "🎙️ [Mute State Changed]: $muted"
                )
                events?.success(callSink.toMap())
            }
        }

        override fun onNetworkUnreachable() {
            val hasActive = if (clientExists()) client.hasActiveCall() else false
            val duration = if (clientExists()) client.getDuration() else 0
            val now = System.currentTimeMillis()
            Log.w("VBotPhone", "⚠️⚠️⚠️═══════════════════════════════════════")
            Log.w("VBotPhone", "⚠️ [CALLBACK] onNetworkUnreachable() ĐƯỢC GỌI TỪ SDK!")
            Log.w("VBotPhone", "  ├─ Timestamp     : $now")
            Log.w("VBotPhone", "  ├─ CallState     : $currentCallState")
            Log.w("VBotPhone", "  ├─ hasActiveCall : $hasActive")
            Log.w("VBotPhone", "  ├─ Duration      : ${duration}s")
            Log.w("VBotPhone", "  ├─ TransId       : $currentTransId")
            Log.w("VBotPhone", "  └─ wasConfirmed  : $wasConfirmed")
            Log.w("VBotPhone", "⚠️⚠️⚠️═══════════════════════════════════════")
            runOnUiThread {
                val callSink = CallSink(
                    name = nameCall,
                    state = currentCallState,
                    isIncoming = isIncoming,
                    isMute = isMute,
                    onHold = onHold,
                    message = "⚠️ [SDK Callback] onNetworkUnreachable() - Mạng không thể truy cập (hasActive=$hasActive, dur=${duration}s)"
                )
                events?.success(callSink.toMap())
            }
        }

        override fun onErrorCode(erCode: Int, message: String) {
            Log.d("VBotPhone", "onErrorCode: $erCode -- $message")
            runOnUiThread {
                val callSink = CallSink(
                    name = nameCall,
                    state = currentCallState,
                    isIncoming = isIncoming,
                    isMute = isMute,
                    onHold = onHold,
                    message = "❌ [Lỗi SDK $erCode]: $message"
                )
                events?.success(callSink.toMap())
                resultWrapper?.error(erCode.toString(), message, null)
            }
        }
    }

    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var networkLostTimestamp: Long = 0L

    private fun setupNetworkMonitoring() {
        if (networkCallback != null) return
        try {
            connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()

            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    super.onAvailable(network)
                    val now = System.currentTimeMillis()
                    val disconnectDuration = if (networkLostTimestamp > 0) now - networkLostTimestamp else 0
                    val hasActive = if (clientExists()) client.hasActiveCall() else false
                    val duration = if (wasConfirmed && callConfirmedTimestamp > 0) ((now - callConfirmedTimestamp) / 1000).toInt() else 0

                    Log.i("VBotPhone", "🌐🌐🌐═════════════════════════════════════════════════════")
                    Log.i("VBotPhone", "🌐 [NETWORK MONITOR] ✅ CÓ MẠNG TRỞ LẠI (onAvailable)")
                    Log.i("VBotPhone", "  ├─ Timestamp          : $now")
                    Log.i("VBotPhone", "  ├─ Disconnect Dur     : ${disconnectDuration}ms (${disconnectDuration / 1000}s)")
                    Log.i("VBotPhone", "  ├─ CallState          : $currentCallState")
                    Log.i("VBotPhone", "  ├─ hasActiveCall      : $hasActive")
                    Log.i("VBotPhone", "  ├─ Call Duration      : ${duration}s")
                    Log.i("VBotPhone", "  ├─ TransId            : $currentTransId")
                    Log.i("VBotPhone", "  ├─ wasConfirmed       : $wasConfirmed")
                    Log.i("VBotPhone", "  └─ isIncoming         : $isIncoming")
                    Log.i("VBotPhone", "🌐🌐🌐═════════════════════════════════════════════════════")

                    runOnUiThread {
                        val callSink = CallSink(
                            name = nameCall,
                            state = currentCallState,
                            isIncoming = isIncoming,
                            isMute = isMute,
                            onHold = onHold,
                            message = "🌐 [Mạng] ✅ Có mạng trở lại sau ${disconnectDuration / 1000}s! (CallState=$currentCallState, hasActive=$hasActive, duration=${duration}s)"
                        )
                        events?.success(callSink.toMap())
                    }

                    // SDK đã tự động quản lý NetworkCallback bên trong (VBotClient.registerNetworkMonitor)
                    // và tự động kích hoạt handleIpChange() kèm debounce 1000ms.
                }

                override fun onLost(network: Network) {
                    super.onLost(network)
                    networkLostTimestamp = System.currentTimeMillis()
                    val hasActive = if (clientExists()) client.hasActiveCall() else false
                    val duration = if (wasConfirmed && callConfirmedTimestamp > 0) ((networkLostTimestamp - callConfirmedTimestamp) / 1000).toInt() else 0

                    Log.w("VBotPhone", "🚨🚨🚨═════════════════════════════════════════════════════")
                    Log.w("VBotPhone", "🚨 [NETWORK MONITOR] ❌ MẤT MẠNG ĐỘT NGỘT (onLost)")
                    Log.w("VBotPhone", "  ├─ Timestamp      : $networkLostTimestamp")
                    Log.w("VBotPhone", "  ├─ CallState      : $currentCallState")
                    Log.w("VBotPhone", "  ├─ hasActiveCall  : $hasActive")
                    Log.w("VBotPhone", "  ├─ Duration       : ${duration}s")
                    Log.w("VBotPhone", "  ├─ TransId        : $currentTransId")
                    Log.w("VBotPhone", "  ├─ wasConfirmed   : $wasConfirmed")
                    Log.w("VBotPhone", "  └─ isIncoming     : $isIncoming")
                    Log.w("VBotPhone", "🚨🚨🚨═════════════════════════════════════════════════════")

                    runOnUiThread {
                        val callSink = CallSink(
                            name = nameCall,
                            state = currentCallState,
                            isIncoming = isIncoming,
                            isMute = isMute,
                            onHold = onHold,
                            message = "🚨 [Mạng] ❌ Đã mất kết nối mạng! (CallState=$currentCallState, hasActive=$hasActive, duration=${duration}s)"
                        )
                        events?.success(callSink.toMap())
                    }
                }

                override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                    val hasInternet = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    val isValidated = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                    Log.d("VBotPhone", "📶 [NETWORK MONITOR] onCapabilitiesChanged: Internet=$hasInternet, Validated=$isValidated")
                }
            }

            connectivityManager?.registerNetworkCallback(request, networkCallback!!)
            Log.d("VBotPhone", "✅ [NETWORK MONITOR] Đã đăng ký NetworkCallback thành công")
        } catch (e: Exception) {
            Log.e("VBotPhone", "❌ [NETWORK MONITOR] Lỗi đăng ký NetworkCallback: ${e.message}")
        }
    }



    override fun onDestroy() {
        super.onDestroy()
        try {
            networkCallback?.let { connectivityManager?.unregisterNetworkCallback(it) }
            networkCallback = null
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        initClient(context)
        client.addListener(listener)
        getTokenFirebase()
        setupNetworkMonitoring()

        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VBOT_CHANNEL)
            .setMethodCallHandler(this)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_STATE_CHANNEL)
            .setStreamHandler(this)

        requestCallPermissions()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        if (intent.getBooleanExtra("from_incoming_call", false)) {
            emitCurrentCallState()
        }
    }

    private fun emitCurrentCallState() {
        if (!clientExists() || !client.hasActiveCall()) return
        if (currentCallState == "disconnected" || currentCallState == "none") return

        if (nameCall.isEmpty()) {
            nameCall = client.callName() ?: ""
        }
        isMute = client.isCallMute()
        isIncoming = true

        val state = if (currentCallState != "none") currentCallState else {
            val duration = client.getDuration()
            if (duration != null && duration > 0) "confirmed" else "incoming"
        }

        val callSink = CallSink(
            name = nameCall,
            state = state,
            isIncoming = isIncoming,
            isMute = isMute,
            onHold = onHold,
            message = "🔄 [Sync State] Cập nhật trạng thái cuộc gọi khi mở app: $state"
        )
        runOnUiThread {
            events?.success(callSink.toMap())
        }
    }

    private fun requestCallPermissions() {
        val needed = mutableListOf(Manifest.permission.RECORD_AUDIO)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            needed.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        val ungranted = needed.filter {
            context.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (ungranted.isNotEmpty()) {
            requestPermissions(ungranted.toTypedArray(), 1)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(context)) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivity(intent)
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (!notificationManager.canUseFullScreenIntent()) {
                try {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                } catch (e: Exception) {
                    Log.e("VBotPhone", "Error opening MANAGE_APP_USE_FULL_SCREEN_INTENT settings: ${e.message}")
                }
            }
        }
    }

    private fun getTokenFirebase(callback: ((String) -> Unit)? = null) {
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            try {
                if (task.isSuccessful) {
                    val token = task.result
                    if (!token.isNullOrEmpty()) {
                        tokenFirebase = token
                        Log.d("VBotPhone", "Firebase token retrieved successfully: $tokenFirebase")
                        callback?.invoke(token)
                        return@addOnCompleteListener
                    }
                } else {
                    Log.e("VBotPhone", "Failed to get Firebase token: ${task.exception?.message}")
                }
            } catch (e: Exception) {
                Log.e("VBotPhone", "Exception in getTokenFirebase: ${e.message}")
            }
            callback?.invoke(tokenFirebase)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        resultWrapper = ResultWrapper(result)
        when (call.method) {
            Methods.ISUSERCONNECTED.value -> isUserConnected(call)
            Methods.USERDISPLAYNAME.value -> userDisplayName(call)
            Methods.CONNECT.value -> connect(call)
            Methods.DISCONNECT.value -> disconnect(call)
            Methods.STARTCALL.value -> startCall(call)
            Methods.GETHOTLINE.value -> getHotline(call)
            Methods.ANSWER.value -> answer(call)
            Methods.HANGUP.value -> hangUp(call)
            Methods.MUTE.value -> mute(call)
            Methods.SPEAKER.value -> speaker(call)
            Methods.SENDDTMF.value -> sendDTMF(call)
            Methods.HOLD.value -> hold(call)
            else -> resultWrapper?.notImplemented()
        }
    }

    private fun isUserConnected(call: MethodCall) {
        val isConnected = if (clientExists()) {
            client.isUserConnected() || client.getStateAccount() == AccountRegistrationState.Ok
        } else false
        resultWrapper?.success(mapOf("isUserConnected" to isConnected))
    }

    private fun userDisplayName(call: MethodCall) {
        val displayName = if (clientExists()) {
            val name = client.userDisplayName()
            if (!name.isNullOrEmpty()) name else client.getAccountUsername() ?: ""
        } else ""
        resultWrapper?.success(mapOf("userDisplayName" to displayName))
    }

    private fun connect(call: MethodCall) {
        val args = call.arguments as? Map<*, *>
        val token = (args?.get("token") ?: "") as String
        val envStr = (args?.get("environment") ?: "") as String
        val baseUrl = (args?.get("baseUrl") ?: "") as String

        val environment = try {
            if (envStr.isNotEmpty()) VBotEnvironment.valueOf(envStr.uppercase()) else VBotEnvironment.STAGING
        } catch (_: Exception) {
            VBotEnvironment.STAGING
        }
        val customUrl = if (baseUrl.isNotEmpty()) baseUrl else null
        val config = VBotConfig(environment, customUrl)
        client.setup(config)

        val executeConnect = { fcm: String ->
            val finalFcm = if (fcm.isNotEmpty()) fcm else "dummy_fcm_token_sample"
            Log.d("VBotPhone", "connect: token length=${token.length}, env=$envStr, customUrl=$customUrl, fcmToken=$finalFcm")

            client.connect(token, finalFcm, VBotCompletion { displayName, error ->
                runOnUiThread {
                    if (error == null) {
                        Log.d("VBotPhone", "connect SUCCESS: displayName=$displayName")
                        resultWrapper?.success(mapOf("displayName" to (displayName ?: "")))
                    } else {
                        Log.d("VBotPhone", "connect ERROR: code=${error.code}, message=${error.message}")
                        resultWrapper?.error(error.code.toString(), error.message, null)
                    }
                }
            })
        }

        if (tokenFirebase.isNotEmpty()) {
            executeConnect(tokenFirebase)
        } else {
            Log.d("VBotPhone", "tokenFirebase is empty, fetching FCM token before connect...")
            getTokenFirebase { fcm ->
                executeConnect(fcm)
            }
        }
    }

    private fun disconnect(call: MethodCall) {
        client.disconnect(VBotCompletion { _, error ->
            runOnUiThread {
                if (error == null) {
                    resultWrapper?.success(mapOf("disconnect" to true))
                } else {
                    resultWrapper?.error(error.code.toString(), error.message, null)
                }
            }
        })
    }

    private fun startCall(call: MethodCall) {
        val args = call.arguments as? Map<*, *>
        val phoneNumber = (args?.get("phoneNumber") ?: "") as String
        val hotline = (args?.get("hotline") ?: "") as String

        resetCallTracking()
        nameCall = phoneNumber
        isIncoming = false
        callStartTimestamp = System.currentTimeMillis()
        Log.d("VBotPhone", "📞 [START CALL] Bắt đầu gọi: $phoneNumber qua Hotline: $hotline (timestamp=$callStartTimestamp)")
        Log.d("VBotPhone", "📞 [TEST NOTE] Đang theo dõi cuộc gọi (đặc biệt cho Case 3: Chặn cuộc gọi)...")

        client.startOutgoingCall(
            hotline,
            phoneNumber,
            "",
            VBotCompletion { _, error ->
                runOnUiThread {
                    if (error == null) {
                        resultWrapper?.success(mapOf("phoneNumber" to phoneNumber))
                    } else {
                        resultWrapper?.error(error.code.toString(), error.message, null)
                    }
                }
            }
        )
    }

    private fun getHotline(call: MethodCall) {
        CoroutineScope(Dispatchers.IO).launch {
            val list = client.getHotlines()
            runOnUiThread {
                if (list != null) {
                    val listMap = arrayListOf<Map<String, String>>()
                    for (i in list) {
                        listMap.add(mapOf("name" to i.name, "phoneNumber" to i.phoneNumber))
                    }
                    resultWrapper?.success(listMap)
                } else {
                    resultWrapper?.error("ERROR", "Failed to get hotlines", null)
                }
            }
        }
    }

    private fun answer(call: MethodCall) {
        answerIncomingCallWhenReady()
        resultWrapper?.success(null)
    }

    /**
     * Chờ cuộc gọi active từ SIP rồi thực hiện answerCall().
     * Gửi log chi tiết qua EventChannel cho Flutter Box Log.
     */
    private fun answerIncomingCallWhenReady() {
        val initialHasActive = if (clientExists()) client.hasActiveCall() else false
        Log.d("VBotPhone", "👉 answerIncomingCallWhenReady() invoked, clientExists=${clientExists()}, hasActiveCall=$initialHasActive")
        
        if (isWaitingToAnswer) {
            Log.d("VBotPhone", "⚠️ Đang trong hàng đợi chờ trả lời cuộc gọi (isWaitingToAnswer=true)")
            val callSink = CallSink(
                name = nameCall,
                state = currentCallState,
                isIncoming = isIncoming,
                isMute = isMute,
                onHold = onHold,
                message = "⚠️ Đang trong hàng đợi chờ kết nối cuộc gọi để bắt máy..."
            )
            events?.success(callSink.toMap())
            return
        }
        isWaitingToAnswer = true

        val handler = Handler(Looper.getMainLooper())
        var attempts = 0
        val answerWhenReady = object : Runnable {
            override fun run() {
                val hasCall = if (clientExists()) client.hasActiveCall() else false
                Log.d("VBotPhone", "⏳ [Attempt $attempts] client.hasActiveCall() = $hasCall")
                if (hasCall) {
                    isWaitingToAnswer = false
                    Log.d("VBotPhone", "📞 Gọi client.answerCall()...")
                    client.answerCall()
                    val callSink = CallSink(
                        name = nameCall,
                        state = "connecting",
                        isIncoming = true,
                        isMute = isMute,
                        onHold = onHold,
                        message = "📞 [Bắt Máy Thành Công] client.answerCall() đã được gọi (hasActiveCall=true sau $attempts lần thử)"
                    )
                    events?.success(callSink.toMap())
                } else if (attempts < 30) {
                    if (attempts == 1 || attempts % 3 == 0) {
                        val callSink = CallSink(
                            name = nameCall,
                            state = currentCallState,
                            isIncoming = isIncoming,
                            isMute = isMute,
                            onHold = onHold,
                            message = "⏳ [Chờ SIP INVITE] Lần thử $attempts/30: hasActiveCall=false (Đang chờ gói tin SIP từ máy chủ...)"
                        )
                        events?.success(callSink.toMap())
                    }
                    attempts++
                    handler.postDelayed(this, 300)
                } else {
                    isWaitingToAnswer = false
                    Log.e("VBotPhone", "❌ Không tìm thấy cuộc gọi active để trả lời (timeout sau 30 attempts)")
                    val callSink = CallSink(
                        name = nameCall,
                        state = currentCallState,
                        isIncoming = isIncoming,
                        isMute = isMute,
                        onHold = onHold,
                        message = "❌ [Timeout Bắt Máy] Không tìm thấy cuộc gọi active (hasActiveCall=false sau 30 lần thử / 9s). Chưa nhận được SIP INVITE hoặc AutoCall đã huỷ cuộc gọi."
                    )
                    events?.success(callSink.toMap())
                }
            }
        }
        handler.post(answerWhenReady)
    }

    private fun hangUp(call: MethodCall) {
        // ══ TRACKING: đánh dấu user chủ động gác máy ══
        localHangup = true
        val hasCall = if (clientExists()) client.hasActiveCall() else false
        Log.d("VBotPhone", "🔴 Native hangUp() called, hasActiveCall=$hasCall, currentCallState=$currentCallState")
        Log.d("VBotPhone", "📞 [TRACKING] localHangup=true, wasConfirmed=$wasConfirmed, isIncoming=$isIncoming")
        val callSink = CallSink(
            name = nameCall,
            state = "disconnected",
            isIncoming = isIncoming,
            isMute = isMute,
            onHold = onHold,
            message = "🔴 [Native HangUp] Thực thi client.endCall()..."
        )
        events?.success(callSink.toMap())
        client.endCall()
        resultWrapper?.success(null)
    }

    private fun mute(call: MethodCall) {
        isMute = !isMute
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.isMicrophoneMute = isMute
            Log.d("VBotPhone", "mute toggled: isMute=$isMute, audioManager.isMicrophoneMute=${audioManager.isMicrophoneMute}")
        } catch (e: Exception) {
            Log.e("VBotPhone", "Error setting isMicrophoneMute: ${e.message}")
        }
        val callSink = CallSink(
            name = nameCall,
            state = currentCallState,
            isIncoming = isIncoming,
            isMute = isMute,
            onHold = onHold,
            message = "🎙️ [Mic] Trạng thái Mic: ${if (isMute) "Đã tắt Mic (Muted)" else "Đã bật Mic (Unmuted)"}"
        )
        events?.success(callSink.toMap())
        resultWrapper?.success(null)
    }

    private fun speaker(call: MethodCall) {
        isSpeaker = !isSpeaker
        client.onOffSpeaker(isSpeaker)
        Log.d("VBotPhone", "speaker toggled: isSpeaker=$isSpeaker")
        val callSink = CallSink(
            name = nameCall,
            state = currentCallState,
            isIncoming = isIncoming,
            isMute = isMute,
            onHold = onHold,
            message = "🔊 [Loa] Trạng thái Loa: ${if (isSpeaker) "Loa ngoài (Speaker ON)" else "Loa trong (Earpiece)"}"
        )
        events?.success(callSink.toMap())
        resultWrapper?.success(null)
    }

    private fun sendDTMF(call: MethodCall) {
        val value = ((call.arguments as? Map<*, *>)?.get("value") ?: "") as String
        client.sendDTMF(value)
        val callSink = CallSink(
            name = nameCall,
            state = currentCallState,
            isIncoming = isIncoming,
            isMute = isMute,
            onHold = onHold,
            message = "🔢 [DTMF] Gửi phím: $value"
        )
        events?.success(callSink.toMap())
        resultWrapper?.success(null)
    }

    private fun hold(call: MethodCall) {
        onHold = !onHold
        val callSink = CallSink(
            name = nameCall,
            state = currentCallState,
            isIncoming = isIncoming,
            isMute = isMute,
            onHold = onHold,
            message = "⏸️ [Hold] Trạng thái giữ máy: $onHold"
        )
        events?.success(callSink.toMap())
        resultWrapper?.success(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        MainActivity.events = events
        emitCurrentCallState()
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }
}

open class CallSink(
    var name: String,
    var state: String,
    var isIncoming: Boolean,
    var isMute: Boolean,
    var onHold: Boolean,
    var endedReason: String? = null,
    var endedBy: String? = null,
    var message: String? = null
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "name" to name,
        "state" to state,
        "isIncoming" to isIncoming,
        "isMute" to isMute,
        "onHold" to onHold,
        "endedReason" to endedReason,
        "endedBy" to endedBy,
        "message" to message
    )
}

class ResultWrapper(private var result: MethodChannel.Result?) {
    fun success(data: Any?) {
        result?.success(data)
        result = null
    }

    fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        result?.error(errorCode, errorMessage, errorDetails)
        result = null
    }

    fun notImplemented() {
        result?.notImplemented()
        result = null
    }
}
