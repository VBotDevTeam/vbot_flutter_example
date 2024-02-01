import Flutter
import UIKit
import VBotPhone
import VBotSIP
import MediaPlayer

enum ChannelName {
  static let VBOT_CHANNEL = "com.vpmedia.vbot-sdk-example-dev/vbot_phone"
  static let CALL_STATE_CHANNEL = "com.vpmedia.vbot-sdk-example-dev/call_state"
}

enum Methods: String {
    case CONNECT = "connect"
    case STARTCALL = "startcall"
    case GETHOTLINE = "gethotline"
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
      
        client.setup()
        setupObservers()

        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        
        let vbotChannel = FlutterMethodChannel(name: ChannelName.VBOT_CHANNEL, binaryMessenger: controller.binaryMessenger)
        vbotChannel.setMethodCallHandler(vbotPhoneMethodCall)
        
        let chargingChannel = FlutterEventChannel(name: ChannelName.CALL_STATE_CHANNEL,
                                                      binaryMessenger: controller.binaryMessenger)
            chargingChannel.setStreamHandler(self)
      
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func applicationWillTerminate(_ application: UIApplication) {
        removeObservers()
    }
    
    func vbotPhoneMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let mode = Methods(rawValue: call.method)
        switch mode {
        case .CONNECT:
            connect(call, result)
        case .STARTCALL:
            startCall(call, result)
        case .GETHOTLINE:
            return
        default:
            result(FlutterMethodNotImplemented)
            return
        }
        
    }
    
    
    func connect(_ call: FlutterMethodCall, _ result: @escaping FlutterResult)  {
        
          let token = ((call.arguments as? Dictionary<String, Any>)?["token"] as? String ?? "")
        
        client.connect(token: token) { [weak self] displayName, error in
            guard let self = self else { return }
            
            if let error = error as NSError? {
                result(FlutterError(code: "\(error.code)", message: error.localizedDescription, details: nil))
            }
            
            result(["displayName": displayName])
        }
    }
    
    func startCall(_ call: FlutterMethodCall, _ result: @escaping FlutterResult)  {
        
          let phoneNumber = ((call.arguments as? Dictionary<String, Any>)?["phoneNumber"] as? String ?? "")
            let hotline = ((call.arguments as? Dictionary<String, Any>)?["hotline"] as? String ?? "")
        
        checkMicrophonePermission { startCalling in
            if startCalling {
                self.client.startCall(hotline: hotline, phoneNumber: phoneNumber) { [weak self] error in
                    guard let self = self else { return }
                        
                    if let error = error as NSError? {
                        result(FlutterError(code: "\(error.code)", message: error.localizedDescription, details: nil))
                    }
                    
                    result(["phoneNumber": phoneNumber])
                   
                }
            } else {
                self.presentEnableMicrophoneAlert()
            }
        }
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
            return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
            return nil
    }
    
    private func sendCallStateEvent(call: VBotCall) {
        guard let eventSink = eventSink else {
          return
        }
        
        switch call.callState {
        case .calling:
            eventSink("calling")
        case .incoming:
            eventSink("incoming")
        case .early:
            eventSink("calling")
        case .connecting:
            eventSink("connecting")
        case .confirmed:
            eventSink(call.onHold ? "On hold" : "Connected")
        case .disconnected:
            eventSink("disconnected")
        default:
            eventSink("call ended")
        }
      }
}


extension AppDelegate {
    
    /// Hook up the observers that AppDelegate should listen to
    fileprivate func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.callStateChanged(_:)), name: NSNotification.Name.VBotCallStateChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(errorDuringCallSetup(_:)), name: Notification.Name.VBotCallErrorDuringSetupCall, object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(directlyShowActiveCallController(_:)),
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
        self.sendCallStateEvent(call: call)
    }
    
    @objc func errorDuringCallSetup(_ notification: NSNotification) {
//        let statusCode = notification.userInfo![VBotNotificationUserInfoErrorStatusCodeKey] as! String
//        
//        if statusCode != "407" { // == call being cancelled, this is technically not an error.
//            self.callGotAnError = true
//        }
    }
    
    @objc func directlyShowActiveCallController(_ notification: Notification) {
//        print("directlyShowActiveCallController")
//        let storyboard = UIStoryboard(name: "Main", bundle: nil)
//        if let callVC = storyboard.instantiateViewController(withIdentifier: "CallViewController") as? CallViewController {
//            callVC.modalPresentationStyle = .fullScreen
//            self.present(callVC, animated: true, completion: nil)
//        }
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
            return
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
