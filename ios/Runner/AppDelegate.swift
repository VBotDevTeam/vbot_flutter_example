import AVFoundation
import Flutter
import MediaPlayer
import PushKit
import UIKit
import VBotPhoneSDK

enum ChannelName {
    static let VBOT_CHANNEL = "com.vpmedia.vbot-sdk/vbot_phone"
    static let CALL_STATE_CHANNEL = "com.vpmedia.vbot-sdk/call"
}

enum Methods: String {
    case ISUSERCONNECTED = "isUserConnected"
    case USERDISPLAYNAME = "userDisplayName"
    case CONNECT = "connect"
    case DISCONNECT = "disconnect"
    case STARTCALL = "startCall"
    case GETHOTLINE = "getHotlines"
    case HANGUP = "hangup"
    case MUTE = "mute"
    case SPEAKER = "speaker"
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var voipRegistry: PKPushRegistry?
    let client = VBotPhone.sharedInstance
    private var lastCallState: VBotCallState = .null
    private var lastCallName: String = ""
    
    // ═══════════════════════════════════════════════
    // TRACKING CONTEXT — dùng để phân tích call end reason
    // ═══════════════════════════════════════════════
    private var wasConfirmed = false
    private var callStartTime: Date?
    private var callConfirmedTime: Date?
    private var localHangup = false
    private var callbackCounter = 0
    private var callStateHistory: [String] = []
    private var isIncomingCall = false
    private var externalCallId: String = ""
    
    private func resetCallTracking() {
        print("🔄 [TRACKING] Reset all tracking vars")
        wasConfirmed = false
        callStartTime = nil
        callConfirmedTime = nil
        localHangup = false
        callbackCounter = 0
        callStateHistory = []
        isIncomingCall = false
        externalCallId = ""
    }

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
      
        let config = VBotConfig(
            iconTemplateImageData: UIImage(named: "callkit-icon")?.pngData(),
            environment: .staging
        )
        
        VBotPhone.sharedInstance.setup(with: config)
        VBotPhone.sharedInstance.addDelegate(self)
        
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        
        let vbotChannel = FlutterMethodChannel(name: ChannelName.VBOT_CHANNEL, binaryMessenger: controller.binaryMessenger)
        vbotChannel.setMethodCallHandler(self.methodCall)
        
        let chargingChannel = FlutterEventChannel(name: ChannelName.CALL_STATE_CHANNEL,
                                                  binaryMessenger: controller.binaryMessenger)
        chargingChannel.setStreamHandler(self)

        self.setupPushKit()
        self.checkMicrophonePermission()
      
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func setupPushKit() {
        self.voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        self.voipRegistry?.delegate = self
        self.voipRegistry?.desiredPushTypes = [.voIP]
    }

    private func checkMicrophonePermission() {
        let status = AVAudioSession.sharedInstance().recordPermission
        if status == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }
    }
    
    func methodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let mode = Methods(rawValue: call.method)
        switch mode {
        case .ISUSERCONNECTED:
            self.isUserConnected(call, result)
        case .USERDISPLAYNAME:
            self.userDisplayName(call, result)
        case .CONNECT:
            self.connect(call, result)
        case .DISCONNECT:
            self.disconnect(call, result)
        case .STARTCALL:
            self.startCall(call, result)
        case .GETHOTLINE:
            self.getHotlines(call, result)
        case .HANGUP:
            self.hangup(call, result)
        case .MUTE:
            self.mute(call, result)
        case .SPEAKER:
            self.speaker(call, result)
        default:
            result(FlutterMethodNotImplemented)
            return
        }
    }

    func isUserConnected(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let isUserConnected = self.client.isUserConnected()
        result(["isUserConnected": isUserConnected])
    }
    
    func userDisplayName(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let userDisplayName = self.client.userDisplayName()
        result(["userDisplayName": userDisplayName])
    }
    
    func connect(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let token = (args?["token"] as? String ?? "")
        let envStr = (args?["environment"] as? String)
        let baseUrl = (args?["baseUrl"] as? String)

        let customUrl = (baseUrl?.isEmpty == false) ? baseUrl : nil

        if envStr != nil || customUrl != nil {
            var env: VBotEnvironment = .production
            switch envStr?.uppercased() {
            case "STAGING": env = .staging
            case "SANDBOX": env = .sandbox
            default: env = .production
            }
            let config = VBotConfig(environment: env, customBaseUrl: customUrl)
            VBotPhone.sharedInstance.setConfig(config: config)
        }

        let pushkitToken = self.client.pushKitToken ?? ""
        self.client.connect(token: token, pushkitToken: pushkitToken) { displayName, error in
            if let error = error as NSError? {
                result(FlutterError(code: "\(error.code)", message: error.localizedDescription, details: nil))
                return
            }
            
            result(["displayName": displayName])
        }
    }
    
    func disconnect(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        self.client.disconnect { error in
            if let error = error as NSError? {
                result(FlutterError(code: "\(error.code)", message: error.localizedDescription, details: nil))
                return
            }
            
            result(["disconnect": true])
        }
    }
    
    func startCall(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let name = ((call.arguments as? [String: Any])?["name"] as? String ?? "")
        let phoneNumber = ((call.arguments as? [String: Any])?["phoneNumber"] as? String ?? "")
        let hotline = ((call.arguments as? [String: Any])?["hotline"] as? String ?? "")
        
        self.resetCallTracking()
        self.lastCallName = name.isEmpty ? phoneNumber : name
        print("📞 [START CALL] Bắt đầu gọi: \(phoneNumber) qua Hotline: \(hotline)")
        print("📞 [TEST NOTE] Đang theo dõi cuộc gọi (đặc biệt cho Case 3: Chặn cuộc gọi)...")
        
        self.client.startOutgoingCall(displayName: name, number: phoneNumber, hotline: hotline) { success, error in
            if let error = error {
                result(FlutterError(code: "\(error.code)", message: error.localizedDescription, details: nil))
                return
            }
            result(["phoneNumber": phoneNumber])
        }
    }
    
    func getHotlines(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        self.client.getHotlines { hotlines, error in
            if let error = error as NSError? {
                result(FlutterError(code: "\(error.code)", message: error.localizedDescription, details: nil))
                return
            }
            let hotlinesMap = hotlines?.map { hotline in
                ["name": hotline.name, "phoneNumber": hotline.phoneNumber]
            }
            result(hotlinesMap)
        }
    }
    
    func hangup(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        // ══ TRACKING: đánh dấu user chủ động gác máy ══
        localHangup = true
        print("📞 [TRACKING] localHangup=true, wasConfirmed=\(wasConfirmed)")
        self.client.endCall { error in
            if let error = error as NSError? {
                result(FlutterError(code: "\(error.code)", message: error.localizedDescription, details: nil))
                return
            }
            result(nil)
        }
    }
    
    func mute(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        self.client.muteCall()
        result(nil)
    }
    
    func speaker(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        self.client.onOffSpeaker()
        result(nil)
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

extension AppDelegate: VBotPhoneDelegate {
    func callStateChanged(state: VBotCallState) {
        self.lastCallState = state
        
        // ══════ TRACKING: ghi lại lịch sử ══════
        callbackCounter += 1
        let stateStr = CallSink.getCallState(state)
        callStateHistory.append("\(stateStr)@\(Date().timeIntervalSince1970)")
        
        print("═══════════════════════════════════════")
        print("📊 [CALLBACK #\(callbackCounter)] callStateChanged: \(stateStr)")
        print("  ├─ wasConfirmed=\(wasConfirmed)")
        print("  ├─ localHangup=\(localHangup)")
        print("  └─ history=\(callStateHistory.joined(separator: " → "))")
        print("═══════════════════════════════════════")
        
        // ══ TRACKING: ghi timestamp ══
        switch state {
        case .incoming:
            isIncomingCall = true
            if callStartTime == nil {
                callStartTime = Date()
                localHangup = false
                print("⏱️ [TRACKING] Call started (INCOMING) at: \(callStartTime!)")
            }
        case .calling, .early:
            if callStartTime == nil {
                callStartTime = Date()
                localHangup = false
                print("⏱️ [TRACKING] Call started (OUTGOING) at: \(callStartTime!)")
            }
        case .confirmed:
            wasConfirmed = true
            callConfirmedTime = Date()
            let ringDuration = callConfirmedTime!.timeIntervalSince(callStartTime ?? Date())
            print("✅ [TRACKING] Call CONFIRMED, ring duration: \(String(format: "%.1f", ringDuration))s")
        case .disconnected, .null:
            print("📊 [CALLBACK #\(callbackCounter)] callStateChanged: Disconnected — ĐÂY KHÔNG PHẢI HÀM TRẢ KẾT QUẢ (không có endedReason/endedBy)")
        default:
            break
        }
        
        guard let eventSink = eventSink else {
            return
        }
        eventSink(CallSink(state, name: self.lastCallName, isMute: self.client.isCallMute(), onHold: self.client.isCallHold()).toMap)
    }
    
    func callMuteStateDidChange(muted: Bool) {
        guard let eventSink = eventSink else {
            return
        }
        eventSink(CallSink(self.lastCallState, name: self.lastCallName, isMute: muted, onHold: self.client.isCallHold()).toMap)
    }
    
    func didReceiveExternalCallId(_ externalCallId: String) {
        callbackCounter += 1
        self.externalCallId = externalCallId
        print("═══════════════════════════════════════")
        print("📊 [CALLBACK #\(callbackCounter)] didReceiveExternalCallId")
        print("  └─ externalCallId: \(externalCallId)")
        print("═══════════════════════════════════════")
    }

    func callEnded(reason: VBotEndCallReason, endedBy: VBotCallEndParty) {
        callbackCounter += 1
        let now = Date()
        let totalDuration = callStartTime != nil ? now.timeIntervalSince(callStartTime!) : 0
        let confirmedDuration = (wasConfirmed && callConfirmedTime != nil) ? now.timeIntervalSince(callConfirmedTime!) : 0
        
        // ═══════════════════════════════════════════════════
        // LOG 1: ⭐ HÀM TRẢ KẾT QUẢ — callEnded(2 params)
        // ═══════════════════════════════════════════════════
        print("🔴🔴🔴═══════════════════════════════════════")
        print("🔴 [CALLBACK #\(callbackCounter)] callEnded(reason, endedBy)")
        print("🔴 ⭐ ĐÂY LÀ HÀM TRẢ KẾT QUẢ (có endedReason + endedBy)")
        print("  ├─ reason       : \(reason.key) (rawValue: \(reason.rawValue))")
        print("  ├─ endedBy      : \(endedBy.description) (rawValue: \(endedBy.rawValue))")
        print("  ├─ description  : \(reason.description)")
        print("  ├─ isIncoming   : \(isIncomingCall)")
        print("  ├─ wasConfirmed : \(wasConfirmed)")
        print("  ├─ localHangup  : \(localHangup)")
        print("  ├─ totalDuration: \(String(format: "%.1f", totalDuration))s")
        print("  ├─ confirmedDur : \(String(format: "%.1f", confirmedDuration))s")
        print("  ├─ externalCallId: \(externalCallId)")
        print("  └─ stateHistory : \(callStateHistory.joined(separator: " → "))")
        print("🔴🔴🔴═══════════════════════════════════════")

        // ═══════════════════════════════════════════════════
        // CASE 3, 4, 5 & 6 DIAGNOSTIC LOG
        // ═══════════════════════════════════════════════════
        print("🎯═══════════════════════════════════════")
        print("🎯 [TEST TRACKING DIAGNOSTIC]:")
        print("  ├─ SDK raw reason   : \(reason.key) (rawValue: \(reason.rawValue))")
        print("  ├─ SDK raw endedBy  : \(endedBy.description) (rawValue: \(endedBy.rawValue))")
        print("  ├─ Ring duration    : \(String(format: "%.1f", totalDuration))s")
        print("  ├─ wasConfirmed     : \(wasConfirmed)")
        print("  ├─ localHangup      : \(localHangup)")
        print("  ├─ isIncoming       : \(isIncomingCall)")
        print("  ├─ externalCallId   : \(externalCallId)")
        if localHangup && !wasConfirmed && !isIncomingCall {
            if reason == .callerCanceled {
                print("  └─ ✅ CASE 6: SDK TRẢ ĐÚNG callerCanceled (rawValue: \(reason.rawValue))!")
            } else {
                print("  └─ 🎯 CASE 6: Người gọi chủ động dập máy (localHangup=true, chưa bắt máy) → SDK trả \(reason.key). Cần fix trong SDK!")
            }
        } else if reason == .destinationNotFound {
            print("  └─ ✅ CASE 7: SDK TRẢ ĐÚNG destinationNotFound (rawValue: \(reason.rawValue) / SIP 404 / Không tìm thấy số đích)!")
        } else if reason == .invalidPhoneNumber {
            print("  └─ ✅ CASE 7: SDK TRẢ ĐÚNG invalidPhoneNumber (rawValue: \(reason.rawValue) / Mã 2004 / Số điện thoại không hợp lệ)!")
        } else if reason == .timeOut {
            print("  └─ ✅ CASE 5: SDK TRẢ ĐÚNG timeOut (rawValue: \(reason.rawValue) / SIP 408)!")
        } else if reason == .temporarilyUnavailable && totalDuration > 25 && !wasConfirmed {
            print("  └─ ⚠️ CASE 5: Ring \(String(format: "%.1f", totalDuration))s (>25s) → SDK trả temporarilyUnavailable (SIP 480). Cần server gửi SIP 408!")
        } else if reason == .doNotDisturb {
            print("  └─ ✅ CASE 4: SDK TRẢ ĐÚNG doNotDisturb (rawValue: 2036 / SIP 409)!")
        } else if reason == .recipientBlocksCalls {
            print("  └─ ✅ CASE 3: SDK TRẢ ĐÚNG recipientBlocksCalls (rawValue: 2032 / SIP 403)!")
        } else if reason == .temporarilyUnavailable && totalDuration < 5 {
            print("  └─ ⚠️ Ngắt tức thì (<5s): SDK trả temporarilyUnavailable (SIP 480). Cần đối chiếu Server xem là Case 7 (404), Case 3 (403) hay Case 4 (409)!")
        } else if reason == .busy {
            print("  └─ ℹ️ SDK trả busy (rawValue: 1001 / SIP 486). Thiết bị có thể báo bận khi bật DND.")
        } else {
            print("  └─ ℹ️ SDK trả \(reason.key). Cần kiểm tra Server Call History cho externalCallId=\(externalCallId)")
        }
        print("🎯═══════════════════════════════════════")

        // ═══ LOG 2: Kết quả resolved ═══
        var resolvedReason = reason.key
        var resolvedConfidence = "sdk_original"
        var resolvedExplanation = "SDK reason không cần điều chỉnh"

        if localHangup && !wasConfirmed && !isIncomingCall {
            resolvedReason = "caller_canceled"
            resolvedConfidence = "high"
            resolvedExplanation = "CASE 6: Người gọi chủ động hủy trước khi bắt máy (localHangup=true) → caller_canceled"
        } else if !wasConfirmed && totalDuration > 25 {
            resolvedReason = "time_out"
            resolvedConfidence = "high"
            resolvedExplanation = "CASE 5: Ring \(String(format: "%.1f", totalDuration))s > 25s (chưa bắt máy) → time_out"
        } else if reason == .normaly && !wasConfirmed {
            // Dự phòng cho SDK 1.1.9: cuộc gọi chưa kết nối nhưng bị fallback nhầm về normaly
            resolvedReason = "temporarily_unavailable"
            resolvedConfidence = "medium"
            resolvedExplanation = "SDK_FALLBACK_ANOMALY: Cuộc gọi chưa kết nối nhưng SDK fallback normaly → chuẩn hóa về temporarily_unavailable"
        }

        print("🟢═══════════════════════════════════════")
        print("🟢 [RESOLVED] KẾT QUẢ CUỐI CÙNG:")
        print("  ├─ SDK gốc       : \(reason.key)")
        print("  ├─ Resolved      : \(resolvedReason)")
        print("  ├─ Confidence    : \(resolvedConfidence)")
        print("  ├─ Đã điều chỉnh : \(resolvedReason != reason.key ? "✅ CÓ" : "❌ KHÔNG")")
        print("  ├─ Giải thích    : \(resolvedExplanation)")
        print("  └─ Server kỳ vọng: Cần kiểm tra lịch sử cuộc gọi trên server (externalCallId=\(externalCallId))")
        print("🟢═══════════════════════════════════════")

        guard let eventSink = eventSink else {
            resetCallTracking()
            return
        }
        
        let message = """
        🔴 [callEnded] \(resolvedReason), Kết thúc bởi: \(endedBy.key)
        📊 SDK: reason=\(reason.key) (raw:\(reason.rawValue)), endedBy=\(endedBy.key) (raw:\(endedBy.rawValue))
        ⏱️ Duration: total=\(String(format: "%.1f", totalDuration))s, confirmed=\(String(format: "%.1f", confirmedDuration))s
        📝 wasConfirmed=\(wasConfirmed), localHangup=\(localHangup)
        """
        
        eventSink(CallSink.ended(
            name: self.lastCallName,
            endedReason: resolvedReason,
            endedBy: endedBy.key,
            message: message
        ).toMap)
        
        resetCallTracking()
    }
    
    func callEnded(reason: VBotEndCallReason) {
        callbackCounter += 1
        let totalDuration = callStartTime != nil ? Date().timeIntervalSince(callStartTime!) : 0
        
        print("🔴═══════════════════════════════════════")
        print("🔴 [CALLBACK #\(callbackCounter)] callEnded(1 param) — KHÔNG có endedBy")
        print("  ├─ reason=\(reason.key) (rawValue: \(reason.rawValue))")
        print("  ├─ wasConfirmed=\(wasConfirmed)")
        print("  ├─ totalDuration=\(String(format: "%.1f", totalDuration))s")
        print("  ├─ externalCallId=\(externalCallId)")
        print("  └─ stateHistory=\(callStateHistory.joined(separator: " → "))")
        print("🔴═══════════════════════════════════════")

        guard let eventSink = eventSink else {
            resetCallTracking()
            return
        }
        eventSink(CallSink.ended(
            name: self.lastCallName,
            endedReason: reason.key,
            endedBy: "unknown",
            message: "🔴 [callEnded(1 param)] \(reason.key), Duration: \(String(format: "%.1f", totalDuration))s"
        ).toMap)
        
        resetCallTracking()
    }
}

extension AppDelegate: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let token = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
        self.client.pushKitToken = token
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        self.client.startIncomingCall(payload: payload) {
            completion()
        }
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        self.client.pushKitToken = nil
    }
}

extension Encodable {
    /// Converting object to postable JSON
    func toJSON(_ encoder: JSONEncoder = JSONEncoder()) throws -> NSString {
        let data = try encoder.encode(self)
        let result = String(decoding: data, as: UTF8.self)
        return NSString(string: result)
    }
}

struct CallSink {
    let name: String
    let state: String
    let isIncoming: Bool
    let isMute: Bool
    let onHold: Bool
    let endedReason: String?
    let endedBy: String?
    let message: String?
    
    init(_ callState: VBotCallState, name: String, isMute: Bool = false, onHold: Bool = false) {
        self.name = name
        self.state = CallSink.getCallState(callState)
        self.isIncoming = (callState == .incoming)
        self.isMute = isMute
        self.onHold = onHold
        self.endedReason = nil
        self.endedBy = nil
        self.message = nil
    }
    
    private init(name: String, state: String, isIncoming: Bool, isMute: Bool, onHold: Bool, endedReason: String?, endedBy: String?, message: String?) {
        self.name = name
        self.state = state
        self.isIncoming = isIncoming
        self.isMute = isMute
        self.onHold = onHold
        self.endedReason = endedReason
        self.endedBy = endedBy
        self.message = message
    }
    
    /// Factory cho trường hợp cuộc gọi kết thúc — emit endedReason + endedBy lên Flutter
    static func ended(name: String, endedReason: String, endedBy: String, message: String? = nil) -> CallSink {
        return CallSink(
            name: name,
            state: "disconnected",
            isIncoming: false,
            isMute: false,
            onHold: false,
            endedReason: endedReason,
            endedBy: endedBy,
            message: message ?? "🔴 [callEnded] \(endedReason), Kết thúc bởi: \(endedBy)"
        )
    }
    
    public static func getCallState(_ state: VBotCallState) -> String {
        switch state {
        case .calling, .early:
            return "calling"
        case .incoming:
            return "incoming"
        case .connecting:
            return "connecting"
        case .confirmed:
            return "confirmed"
        default:
            return "disconnected"
        }
    }
                      
    private static var dateComponentsFormatter: DateComponentsFormatter = {
        let dateComponentsFormatter = DateComponentsFormatter()
        dateComponentsFormatter.zeroFormattingBehavior = .pad
        dateComponentsFormatter.allowedUnits = [.minute, .second]
        return dateComponentsFormatter
    }()
    
    var toMap: [String: Any] {
        var map: [String: Any] = [
            "name": self.name,
            "state": self.state,
            "isIncoming": self.isIncoming,
            "isMute": self.isMute,
            "onHold": self.onHold
        ]
        if let endedReason = self.endedReason {
            map["endedReason"] = endedReason
        }
        if let endedBy = self.endedBy {
            map["endedBy"] = endedBy
        }
        if let message = self.message {
            map["message"] = message
        }
        return map
    }
}
