import Flutter
import MediaPlayer
import UIKit
import VBotPhoneSDK
import VBotSIP
import Starscream
import KeychainSwift

enum ChannelName {
    static let VBOT_CHANNEL = "com.vpmedia.vbot-sdk/vbot_phone"
    static let CALL_STATE_CHANNEL = "com.vpmedia.vbot-sdk/call"
}

enum Methods: String {
    case CONNECT = "connect"
    case STARTCALL = "startCall"
    case GETHOTLINE = "getHotlines"
    case HANGUP = "hangup"
    case MUTE = "mute"
}

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    let client = VBotPhone.sharedInstance
    fileprivate var connectDurationTimer: Timer?
   
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
      
        self.client.setup()
        
        setupObservers()

        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        
        let vbotChannel = FlutterMethodChannel(name: ChannelName.VBOT_CHANNEL, binaryMessenger: controller.binaryMessenger)
        vbotChannel.setMethodCallHandler(self.methodCall)
        
        let chargingChannel = FlutterEventChannel(name: ChannelName.CALL_STATE_CHANNEL,
                                                  binaryMessenger: controller.binaryMessenger)
        chargingChannel.setStreamHandler(self)
      
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func applicationWillTerminate(_ application: UIApplication) {
        removeObservers()
    }
    
    func methodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let mode = Methods(rawValue: call.method)
        switch mode {
        case .CONNECT:
            self.connect(call, result)
        case .STARTCALL:
            self.startCall(call, result)
        case .GETHOTLINE:
            self.getHotlines(call, result)
        case .HANGUP:
            self.hangup(call, result)
        case .MUTE:
            self.mute(call, result)
        default:
            result(FlutterMethodNotImplemented)
            return
        }
    }
    
    func connect(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let token = ((call.arguments as? [String: Any])?["token"] as? String ?? "")
        
        self.client.connect(token: token) { displayName, error in
            
            if let error = error as NSError? {
                result(FlutterError(code: "\(error.code)", message: error.localizedDescription, details: nil))
                return
            }
            
            result(["displayName": displayName])
        }
    }
    
    func startCall(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let phoneNumber = ((call.arguments as? [String: Any])?["phoneNumber"] as? String ?? "")
        let hotline = ((call.arguments as? [String: Any])?["hotline"] as? String ?? "")
        
        checkMicrophonePermission { startCalling in
            if startCalling {
                self.client.startCall(hotline: hotline, phoneNumber: phoneNumber) { error in
                        
                    if let error = error as NSError? {
                        result(FlutterError(code: "\(error.code)", message: error.localizedDescription, details: nil))
                        return
                    }
                    
                    result(["phoneNumber": phoneNumber])
                }
            } else {
                self.presentEnableMicrophoneAlert()
            }
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
            dump(hotlinesMap)
            result(hotlinesMap)
        }
    }
    
    func hangup(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        self.client.endCall { error in
            if let error = error as NSError? {
                result(FlutterError(code: "\(error.code)", message: error.localizedDescription, details: nil))
                return
            }
        }
    }
    
    func mute(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        self.client.muteCall { error in
            if let error = error as NSError? {
                result(FlutterError(code: "\(error.code)", message: error.localizedDescription, details: nil))
                return
            }
        }
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    func startConnectDurationTimer() {
        DispatchQueue.main.async {
            if self.connectDurationTimer == nil || !self.connectDurationTimer!.isValid {
                self.connectDurationTimer?.invalidate()
                self.connectDurationTimer = nil
                self.connectDurationTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.setupCall), userInfo: nil, repeats: true)
            }
        }
    }
    
    @objc func setupCall(_ cacheCall: VBotCall? = nil) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let cache = self.client.getActiveCall() ?? cacheCall
            guard let call = cache else { return }
            
            if call.callState != .null && call.callState != .disconnected {
                self.startConnectDurationTimer()
            }
            self.updateEventOnCallState(call)
        }
    }
    
    private func updateEventOnCallState(_ call: VBotCall) {
        guard let eventSink = eventSink else {
            return
        }
        
        if call.callState == .disconnected {
            self.handleCallEnd()
        }
        eventSink(CallSink(call, name: self.client.callName).toMap)
    }
    
    private func handleCallEnd() {
        self.connectDurationTimer?.invalidate()
        self.connectDurationTimer = nil
    }
}

extension AppDelegate {
    /// Hook up the observers that AppDelegate should listen to
    fileprivate func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.callStateChanged(_:)), name: NSNotification.Name.VBotCallStateChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.errorDuringCallSetup(_:)), name: Notification.Name.VBotCallErrorDuringSetupCall, object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.directlyShowActiveCallController(_:)),
                                               name: Notification.Name.CallKitProviderDelegateInboundCallAccepted,
                                               object: nil)
    }
    
    fileprivate func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.VBotCallStateChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.VBotCallErrorDuringSetupCall, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.CallKitProviderDelegateInboundCallAccepted, object: nil)
    }
    
    @objc fileprivate func callStateChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let call = userInfo[VBotNotificationUserInfoCallKey] as? VBotCall
        else {
            return
        }
        self.setupCall(call)
    }
    
    @objc func errorDuringCallSetup(_ notification: NSNotification) {
        guard let eventSink = eventSink else {
            return
        }
        eventSink("callerror")
    }
    
    @objc func directlyShowActiveCallController(_ notification: Notification) {
        guard let eventSink = eventSink else {
            return
        }
        eventSink("callaccepted")
    }
}

extension AppDelegate {
    func checkMicrophonePermission(completion: @escaping ((_ startCalling: Bool) -> Void)) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if granted {
                completion(true)
            } else {
                completion(false)
            }
        }
    }
    
    /// Show a notification that makes it possible to open the settings and enable the microphone
    ///
    /// Activating the microphone permission will terminate the app.
    func presentEnableMicrophoneAlert() {
        let alertController = UIAlertController(title: NSLocalizedString("Access to microphone denied", comment: "Access to microphone denied"),
                                                message: NSLocalizedString("Give permission to use your microphone.\nGo to",
                                                                           comment: "Give permission to use your microphone.\nGo to"),
                                                preferredStyle: .alert)
        
        // Cancel the call, without audio, calling isn't possible.
        let noAction = UIAlertAction(title: NSLocalizedString("Cancel call", comment: "Cancel call"), style: .cancel) { _ in
        }
        alertController.addAction(noAction)
        
        // User wants to open the settings to enable microphone permission.
        let settingsAction = UIAlertAction(title: NSLocalizedString("Settings", comment: "Settings"), style: .default) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
        alertController.addAction(settingsAction)
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        controller.present(alertController, animated: true, completion: nil)
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
    let duration: String
    let isMute: Bool
    let onHold: Bool
    
    init(_ call: VBotCall, name: String) {
        self.name = name
        self.state = CallSink.getCallState(call.callState)
        self.isMute = call.muted
        self.onHold = call.onHold
        self.duration = CallSink.dateComponentsFormatter.string(from: call.connectDuration) ?? ""
    }
    
    private static func getCallState(_ state: VBotCallState) -> String {
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
            return [
                "name": name,
                "state": state,
                "duration": duration,
                "isMute": isMute,
                "onHold": onHold
            ]
        }
    
}


