import Flutter
import MediaPlayer
import UIKit
import VBotPhonePublic

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

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    let client = VBotPhone.sharedInstance
   
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
      
        let config = VBotConfig(
            iconTemplateImageData: UIImage(named: "callkit-icon")?.pngData()
        )
        
        VBotPhone.sharedInstance.setup(with: config)
        VBotPhone.sharedInstance.addDelegate(self)
        
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        
        let vbotChannel = FlutterMethodChannel(name: ChannelName.VBOT_CHANNEL, binaryMessenger: controller.binaryMessenger)
        vbotChannel.setMethodCallHandler(self.methodCall)
        
        let chargingChannel = FlutterEventChannel(name: ChannelName.CALL_STATE_CHANNEL,
                                                  binaryMessenger: controller.binaryMessenger)
        chargingChannel.setStreamHandler(self)
      
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func applicationWillTerminate(_ application: UIApplication) {}
    
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
        let token = ((call.arguments as? [String: Any])?["token"] as? String ?? "")
        
        self.client.connect(token: token) { displayName, error in
            
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
        
        self.client.startOutgoingCall(name: name, number: phoneNumber, hotline: hotline) { [weak self] resultAPI in
            guard let self = self else { return }
            switch resultAPI {
            case .success():
                result(["phoneNumber": phoneNumber])
            case .failure(let error):
                
                if let error = error as NSError? {
                    result(FlutterError(code: "\(error.code)", message: error.localizedDescription, details: nil))
                }
                return
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
        self.client.muteCall()
    }
    
    func speaker(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        self.client.onOffSpeaker()
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
        guard let eventSink = eventSink else {
            return
        }
        eventSink(CallSink(state, name: self.client.getCallName()).toMap)
    }
    
    func callMuteStateDidChange(muted: Bool) {
        guard let eventSink = eventSink else {
            return
        }
        let callState = VBotPhone.sharedInstance.getCallState()
        eventSink(CallSink(callState, name: self.client.getCallName()).toMap)
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
    
    init(_ callState: VBotCallState, name: String) {
        self.name = name
        self.state = CallSink.getCallState(callState)
        self.isIncoming = VBotPhone.sharedInstance.isIncomingCall()
        self.isMute = VBotPhone.sharedInstance.isCallMute()
        self.onHold = VBotPhone.sharedInstance.isCallHold()
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
        return [
            "name": self.name,
            "state": self.state,
            "isIncoming": self.isIncoming,
            "isMute": self.isMute,
            "onHold": self.onHold
        ]
    }
}
