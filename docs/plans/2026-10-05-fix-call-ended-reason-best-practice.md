# Chuẩn Hóa Xử Lý Lý Do Kết Thúc Cuộc Gọi (Call Ended Reason Best Practice)

> **For Antigravity:** REQUIRED SUB-SKILL: Load `executing-plans` to implement this plan task-by-task.

**Goal:** Khắc phục triệt để lỗi cuộc gọi đi luôn trả về `endedReason: normal`, chuẩn hóa logic phân giải lý do kết thúc cuộc gọi trên iOS SDK, Android SDK và Flutter Example theo mô hình kiến trúc một nguồn chân lý (Single Source of Truth), kèm Unit Test và không suy đoán qua thời gian.

**Architecture:** 
1. Tách toàn bộ logic phân giải lý do kết thúc cuộc gọi từ SIP Code và trạng thái cuộc gọi thành một **Pure Function** (`resolveEndCallContext`), độc lập với CallKit/PJSIP để có thể Unit Test 100%.
2. Loại bỏ việc dùng trạng thái CallKit (`CXCall.hasConnected`) để xác định trạng thái đàm thoại SIP; tách biệt hoàn toàn báo cáo vòng đời UI CallKit với trạng thái kết nối VoIP thực tế.
3. Chuẩn hóa hợp đồng dữ liệu giữa Native (iOS/Android) và Flutter bằng `key` chuẩn (snake_case), loại bỏ hoàn toàn các chuỗi text hiển thị tiếng Anh/tiếng Việt ở tầng bridge.

**Tech Stack:** Swift, Objective-C, Kotlin, Dart/Flutter, PJSIP, CallKit, XCTest.

---

### Task 1: Bật Logging Chẩn Đoán Mã SIP Thô trong Flutter Example

**Files:**
- Modify: `vbot_flutter_example/ios/Runner/AppDelegate.swift:308-335`

**Step 1: Cập nhật log chi tiết mã SIP thô và cấu hình debug logging của SDK**

Đảm bảo `AppDelegate` in rõ `reason.rawValue`, `endedBy.rawValue`, và gọi `client.enableDebugLogging(true)` khi khởi tạo để ghi nhận chính xác gói tin SIP Server phản hồi trong case 40.6s.

Trong `AppDelegate.swift`:
```swift
// Trong application(_:didFinishLaunchingWithOptions:):
self.client.enableDebugLogging(true)
```

**Step 2: Chạy kiểm tra ứng dụng iOS để xác nhận log debug hiển thị**

Run:
```bash
flutter run -d <iOS_Device_ID>
```
Expected: Log console Xcode xuất hiện các dòng SIP nhận được từ PBX Gateway (ví dụ: `SIP/2.0 480 Temporarily Unavailable` hoặc `SIP/2.0 408 Request Timeout`).

**Step 3: Commit**

```bash
git add ios/Runner/AppDelegate.swift
git commit -m "chore(ios): enable verbose SIP debug logging in Flutter example"
```

---

### Task 2: Viết Unit Test & Pure Function Phân Giải Lý Do Kết Thúc Trên iOS SDK

**Files:**
- Modify: `VBotPhone-iOS-Public/VBotPhoneSDK/Helpers/VBotEndCallReason.swift`
- Create / Modify: `VBotPhone-iOS-Public/Example/VBotPhoneSDKTests/VBotEndCallReasonTests.swift`

**Step 1: Viết Unit Test thất bại (Failing Test)**

Tạo file `VBotPhone-iOS-Public/Example/VBotPhoneSDKTests/VBotEndCallReasonTests.swift`:

```swift
import XCTest
@testable import VBotPhoneSDK

final class VBotEndCallReasonTests: XCTestCase {

    // Test Case 1: Đã đàm thoại (confirmed) -> luôn trả normaly
    func testConfirmedCall_ReturnsNormaly() {
        let outcome = VBotEndCallReason.resolve(
            hasConnected: true,
            userDidHangUp: true,
            isIncoming: false,
            sipCode: 200
        )
        XCTAssertEqual(outcome.reason, .normaly)
        XCTAssertEqual(outcome.endedBy, .caller)
    }

    // Test Case 6: Người gọi tự dập máy khi chuông đang reo -> callerCanceled
    func testCallerCancelBeforeConnect_ReturnsCallerCanceled() {
        let outcome = VBotEndCallReason.resolve(
            hasConnected: false,
            userDidHangUp: true,
            isIncoming: false,
            sipCode: 0
        )
        XCTAssertEqual(outcome.reason, .callerCanceled)
        XCTAssertEqual(outcome.endedBy, .caller)
    }

    // Test Case 5: Hết thời gian chờ (SIP 408) -> timeOut
    func testSip408_ReturnsTimeOut() {
        let outcome = VBotEndCallReason.resolve(
            hasConnected: false,
            userDidHangUp: false,
            isIncoming: false,
            sipCode: 408
        )
        XCTAssertEqual(outcome.reason, .timeOut)
        XCTAssertEqual(outcome.endedBy, .server)
    }

    // Test Case: Chưa bắt máy, nhận SIP 480 -> temporarilyUnavailable (không đoán mò normaly)
    func testSip480Unanswered_ReturnsTemporarilyUnavailable() {
        let outcome = VBotEndCallReason.resolve(
            hasConnected: false,
            userDidHangUp: false,
            isIncoming: false,
            sipCode: 480
        )
        XCTAssertEqual(outcome.reason, .temporarilyUnavailable)
        XCTAssertEqual(outcome.endedBy, .carrier)
    }

    // Test Case: Chưa bắt máy, mã SIP không xác định (0 hoặc rác) -> unknownError, KHÔNG fallback normaly
    func testUnknownSipCodeUnanswered_ReturnsUnknownError() {
        let outcome = VBotEndCallReason.resolve(
            hasConnected: false,
            userDidHangUp: false,
            isIncoming: false,
            sipCode: 0
        )
        XCTAssertEqual(outcome.reason, .unknownError)
        XCTAssertEqual(outcome.endedBy, .unknown)
    }
}
```

**Step 2: Chạy test để xác nhận test lỗi (do hàm `resolve` chưa tồn tại)**

Run:
```bash
xcodebuild test \
  -workspace Example/VBotPhoneSDK_Example.xcworkspace \
  -scheme VBotPhoneSDK_Example \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:VBotPhoneSDKTests/VBotEndCallReasonTests
```
Expected: FAIL với lỗi compile `Type 'VBotEndCallReason' has no member 'resolve'`.

**Step 3: Triển khai hàm `resolve` trong `VBotEndCallReason.swift`**

Thêm vào `VBotPhone-iOS-Public/VBotPhoneSDK/Helpers/VBotEndCallReason.swift`:

```swift
public struct VBotCallEndResolution {
    public let reason: VBotEndCallReason
    public let endedBy: VBotCallEndParty
    
    public init(reason: VBotEndCallReason, endedBy: VBotCallEndParty) {
        self.reason = reason
        self.endedBy = endedBy
    }
}

extension VBotEndCallReason {
    /// Pure function phân giải lý do kết thúc cuộc gọi duy nhất của SDK
    public static func resolve(
        hasConnected: Bool,
        userDidHangUp: Bool,
        isIncoming: Bool,
        sipCode: Int
    ) -> VBotCallEndResolution {
        // 1. Nếu cuộc gọi đã từng kết nối thành công (Confirmed) -> normaly
        if hasConnected {
            let endParty: VBotCallEndParty = userDidHangUp 
                ? (isIncoming ? .callee : .caller)
                : (isIncoming ? .caller : .callee)
            return VBotCallEndResolution(reason: .normaly, endedBy: endParty)
        }

        // 2. Người gọi chủ động hủy trước khi kết nối (Case 6)
        if userDidHangUp && !isIncoming {
            return VBotCallEndResolution(reason: .callerCanceled, endedBy: .caller)
        }

        // 3. Mapping từ mã phản hồi SIP chuẩn
        if sipCode > 0, let outcome = endOutcome(sipCode: sipCode) {
            return VBotCallEndResolution(reason: outcome.reason, endedBy: outcome.endedBy)
        }

        // 4. Tuyệt đối KHÔNG đoán mò normaly khi chưa kết nối
        return VBotCallEndResolution(reason: .unknownError, endedBy: .unknown)
    }
}
```

**Step 4: Chạy lại test để xác nhận tất cả test đều PASS**

Run:
```bash
xcodebuild test \
  -workspace Example/VBotPhoneSDK_Example.xcworkspace \
  -scheme VBotPhoneSDK_Example \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:VBotPhoneSDKTests/VBotEndCallReasonTests
```
Expected: **TEST SUCCEEDED**.

**Step 5: Commit**

```bash
cd /Users/namhoang/Documents/GitHub/VBot/VBotPhone-iOS-Public
git add VBotPhoneSDK/Helpers/VBotEndCallReason.swift Example/VBotPhoneSDKTests/VBotEndCallReasonTests.swift
git commit -m "feat(sdk): add pure resolveEndCallContext function with 100% unit tests"
```

---

### Task 3: Tích Hợp `resolve` Vào Vòng Đời Cuộc Gọi iOS SDK & Sửa Bug CallKit

**Files:**
- Modify: `VBotPhone-iOS-Public/VBotPhoneSDK/VBotPhone.swift:550-615`

**Step 1: Xóa báo nhầm `connectedAt` cho CallKit khi chưa kết nối**

Trong file `VBotPhone.swift`:
```swift
        case .disconnected:
            addVBotCallLog(.CALL_STATE_DISCONNECTED, from: "callStateChanged")
            
            // ⭐ 1. Khôi phục lại cache lý do kết thúc cuộc gọi
            cacheEndCallContext(for: call)
            
            sendCallState(method: .UN_READY_CALL, callId: "", message: "Call ended (2)")
            resetCallTimer()
           
            if !call.connected {
                VBotLogger.debug(filter: "🍀 VBot", "Cuộc gọi chưa được nghe máy, ở trạng thái DISCONNECTED, callid: \(call.uuid)")
                // ❌ XÓA: callKitProviderDelegate?.provider.reportOutgoingCall(with: call.uuid, connectedAt: Date())
                callKitProviderDelegate?.provider.reportCall(with: call.uuid, endedAt: nil, reason: CXCallEndedReason.unanswered)
            } else if !call.userDidHangUp {
                VBotLogger.debug(filter: "🍀 VBot", "Cuộc gọi kết thúc ở đầu kia, ở trạng thái DISCONNECTED, callid: \(call.uuid)")
                callKitProviderDelegate?.provider.reportCall(with: call.uuid, endedAt: nil, reason: CXCallEndedReason.remoteEnded)
            } else {
                VBotLogger.debug(filter: "🍀 VBot", "Cuộc gọi kết thúc không xác định, ở trạng thái DISCONNECTED, callid: \(call.uuid)")
                callKitProviderDelegate?.provider.reportCall(with: call.uuid, endedAt: nil, reason: CXCallEndedReason.remoteEnded)
            }
            disconnectTimeCount = 0
            rtpErrorCount = 0
```

**Step 2: Cập nhật `cacheEndCallContext` dùng hàm `resolve` chuẩn**

```swift
    private func cacheEndCallContext(for call: VBotCall) {
        let sipCode = call.finalSipStatus > 0 ? call.finalSipStatus : call.lastStatus
        let resolution = VBotEndCallReason.resolve(
            hasConnected: call.connected, // Dùng cờ VoIP thực tế, KHÔNG dùng CallKit CXCall
            userDidHangUp: call.userDidHangUp,
            isIncoming: call.isIncoming,
            sipCode: sipCode
        )

        let context = VBotCallEndContext(
            reason: resolution.reason,
            endedBy: resolution.endedBy
        )
        endCallContexts[call.uuid] = context
        VBotLogger.info(filter: "🍀 VBot", "Resolved Call End Context: reason=\(resolution.reason.key) (raw=\(resolution.reason.rawValue)), endedBy=\(resolution.endedBy.key), SIP: \(sipCode), callId: \(call.uuid)")
    }
```

**Step 3: Cập nhật fallback trong `callObserver` để phòng ngừa race condition**

```swift
    // Trong callObserver(callChanged:):
    let context = consumeEndCallContext(for: call.uuid)
    let finalReason = context.reason ?? (call.hasConnected ? .normaly : .unknownError)
    notifyDelegateEndCall(finalReason, endedBy: context.endedBy, from: "callObserver")
```

**Step 4: Chạy build script để kiểm tra framework biên dịch thành công**

Run:
```bash
cd /Users/namhoang/Documents/GitHub/VBot/VBotPhone-iOS-Public
./build.sh
```
Expected: `VBotPhoneSDK.xcframework` được tạo thành công, không có cảnh báo/lỗi biên dịch.

**Step 5: Commit**

```bash
git add VBotPhoneSDK/VBotPhone.swift
git commit -m "fix(call): integrate pure resolve function, restore cache context and fix CallKit connectedAt leak"
```

---

### Task 4: Khắc Phục Lỗi Thứ Tự Phân Giải Trên Android SDK (`CallListener.kt`)

**Files:**
- Modify: `VBotPhone-Android-Public/SDKVBot/src/main/java/com/vpmedia/sdkvbot/client/CallListener.kt:150-180`

**Step 1: Điều chỉnh thứ tự kiểm tra trong `endCallContext`**

Đưa kiểm tra `userDidHangUp && !isIncoming` lên TRƯỚC `lastStatusCode == PJSIP_SC_OK` để lệnh CANCEL nhận 200 OK không đè mất `callerCanceled`.

```kotlin
    private fun endCallContext(lastStatusCode: Int): VBotCallEndContext {
        val sipStatus = finalSipStatus.takeIf { it > 0 } ?: lastStatusCode
        if (sipStatus == pjsip_status_code.PJSIP_SC_CALL_TSX_DOES_NOT_EXIST || lastStatusCode == pjsip_status_code.PJSIP_SC_CALL_TSX_DOES_NOT_EXIST) {
            markRemoteDidHangUp()
        }

        // 1. Cuộc gọi đã từng Confirmed (đã nghe máy đàm thoại) -> luôn kết thúc bình thường
        if (hasConnected) {
            return VBotCallEndContext(VBotEndCallReason.normaly, inferredEndParty())
        }

        // 2. Người gọi chủ động hủy trước khi bắt máy (Case 6)
        // PHẢI đặt trước kiểm tra PJSIP_SC_OK vì SIP server phản hồi 200 OK cho bản tin CANCEL
        if (userDidHangUp && !isIncoming) {
            return VBotCallEndContext(VBotEndCallReason.callerCanceled, VBotCallEndParty.caller)
        }

        // 3. Mapping mã phản hồi SIP
        val sipOutcome = endOutcomeForSipCode(sipStatus)
        if (sipOutcome != null) {
            return VBotCallEndContext(sipOutcome.reason, sipOutcome.endedBy)
        }

        // 4. Nếu kết thúc bình thường ở trạng thái ngắt (chỉ khi có tín hiệu BYE OK rõ ràng)
        if (lastStatusCode == pjsip_status_code.PJSIP_SC_OK) {
            return VBotCallEndContext(VBotEndCallReason.normaly, inferredEndParty())
        }

        return VBotCallEndContext(VBotEndCallReason.unknownError, inferredEndParty())
    }
```

**Step 2: Chạy build SDK Android**

Run:
```bash
cd /Users/namhoang/Documents/GitHub/VBot/VBotPhone-Android-Public
./gradlew :SDKVBot:assembleRelease
```
Expected: **BUILD SUCCESSFUL**.

**Step 3: Commit**

```bash
git add SDKVBot/src/main/java/com/vpmedia/sdkvbot/client/CallListener.kt
git commit -m "fix(call): check userDidHangUp before PJSIP_SC_OK to prevent cancel being marked as normaly"
```

---

### Task 5: Chuẩn Hóa Bridge Contract Trên Flutter Example (`vbot_flutter_example`)

**Files:**
- Modify: `vbot_flutter_example/ios/Runner/AppDelegate.swift:370-440`
- Modify: `vbot_flutter_example/android/app/src/main/kotlin/com/vpmedia/vbotsdksample/MainActivity.kt:440-515`
- Modify: `vbot_flutter_example/lib/sink.dart:1-35`

**Step 1: Chuẩn hóa iOS `AppDelegate.swift` gửi `key` đồng nhất**

Truyền `reason.key` và `endedBy.key` (thay vì description):

```swift
    func callEnded(reason: VBotEndCallReason, endedBy: VBotCallEndParty) {
        callbackCounter += 1
        let now = Date()
        let totalDuration = callStartTime != nil ? now.timeIntervalSince(callStartTime!) : 0
        let confirmedDuration = (wasConfirmed && callConfirmedTime != nil) ? now.timeIntervalSince(callConfirmedTime!) : 0

        guard let eventSink = eventSink else {
            resetCallTracking()
            return
        }

        let message = "🔴 [callEnded] \(reason.key), endedBy: \(endedBy.key), dur: \(String(format: "%.1f", totalDuration))s"
        
        eventSink(CallSink.ended(
            name: self.lastCallName,
            endedReason: reason.key,       // snake_case: "normal", "time_out", "caller_canceled", "temporarily_unavailable"
            endedBy: endedBy.key,           // snake_case: "caller", "callee", "carrier", "server", "unknown"
            message: message
        ).toMap)

        resetCallTracking()
    }
```

**Step 2: Chuẩn hóa Android `MainActivity.kt` gửi `key` đồng nhất**

Truyền `reason.key` và `endedBy.key` (thay vì `.name`):

```kotlin
    val callSink = CallSink(
        name = nameCall,
        state = "disconnected",
        isIncoming = isIncoming,
        isMute = isMute,
        onHold = onHold,
        endedReason = resolvedReason.key, // Dùng key: "normal", "time_out", "caller_canceled", "temporarily_unavailable"
        endedBy = endedBy.key,             // Dùng key: "caller", "callee", "carrier", "server", "unknown"
        message = "🔴 [onCallEnded] ${resolvedReason.key}, endedBy: ${endedBy.key}"
    )
    events?.success(callSink.toMap())
```

**Step 3: Cập nhật `VBotSink` trong Flutter để parse chính xác**

Đảm bảo `sink.dart` đọc đúng dữ liệu contract đã chuẩn hóa.

**Step 4: Chạy phân tích tĩnh Flutter**

Run:
```bash
cd /Users/namhoang/Documents/GitHub/VBot/vbot_flutter_example
flutter analyze
```
Expected: `No issues found!`.

**Step 5: Commit**

```bash
git add ios/Runner/AppDelegate.swift android/app/src/main/kotlin/com/vpmedia/vbotsdksample/MainActivity.kt lib/sink.dart
git commit -m "refactor(bridge): standardize endedReason and endedBy keys across iOS and Android"
```

---

### Task 6: Đặc Tả Yêu Cầu Kỹ Thuật Gửi Đội Ngũ SIP Server (PBX Gateway)

**Files:**
- Create: `vbot_flutter_example/docs/sip_server_requirements.md`

**Step 1: Tạo tài liệu kiến nghị kỹ thuật chuẩn RFC cho PBX Server**

Nội dung bao gồm:
1. **Dừng SIP Masquerading**: Không gom tất cả lỗi timeout, dnd, decline về `480 Temporarily Unavailable`.
2. **Tuân thủ chuẩn RFC 3261**:
   - Callee bấm từ chối: Trả về `603 Decline`.
   - Timeout không nghe máy (hết Timer B/C): Trả về `408 Request Timeout`.
   - Chế độ không làm phiền (DND): Trả về `409 Conflict` hoặc `486 Busy Here`.
3. **Bổ sung RFC 3326 Reason Header**:
   Trong trường hợp Gateway nhà mạng bắt buộc trả mã 480 hoặc 503, Gateway PBX cần đính kèm header:
   `Reason: Q.850;cause=16;text="Normal call clearing"` hoặc `Reason: Q.850;cause=19;text="No answer from user"`.

**Step 2: Commit**

```bash
git add docs/sip_server_requirements.md
git commit -m "docs: create RFC-compliant SIP server requirements for PBX team"
```
