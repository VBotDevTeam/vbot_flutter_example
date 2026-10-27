# Bảng Tổng Hợp SIP Code & VBotEndCallReason

> [!NOTE]
> Tổng hợp từ source code iOS SDK (swift interface), Android SDK (README, CHANGELOG), và tài liệu Flutter example.
> Tên case và mã số **giống hệt** giữa iOS và Android SDK.

---

## 1. Bảng SIP Code → VBotEndCallReason & EndedBy

Đây là bảng mapping SIP response code mà SDK nhận từ SIP server → reason + endedBy trả về qua callback `onCallEnded(reason, endedBy)`.

| SIP Code | VBotEndCallReason | endedBy | Ý nghĩa SIP |
|:--------:|-------------------|:-------:|-------------|
| 400 | `incorrectInformation` | `server` | Bad Request — thông tin không chính xác |
| 401 | `unauthenticated` | `server` | Unauthorized — chưa xác thực |
| 402 | `insufficientBalance` | `server` | Payment Required — số dư không đủ |
| 403 | `recipientBlocksCalls` | `callee` | Forbidden — người nhận chặn cuộc gọi |
| 404 | `destinationNotFound` | `carrier` | Not Found — không tìm thấy số đích |
| 405 | `callIntervalNotAllowed` | `server` | Method Not Allowed — không được gọi trong khung giờ này |
| 406 | `memberNotActivated` | `server` | Not Acceptable — thành viên chưa kích hoạt |
| 407 | `memberNotInProject` | `server` | Proxy Auth Required — thành viên không thuộc dự án |
| 408 | `timeOut` | `server` | Request Timeout — hết thời gian chờ kết nối |
| 409 | `doNotDisturb` | `callee` | Conflict — người nhận bật không làm phiền (DND) |
| 410 | `destinationGone` | `carrier` | Gone — số đích không còn tồn tại |
| 411 | `recipientAbsent` | `callee` | Length Required — người nhận vắng mặt |
| 412 | `packageExpired` | `server` | Conditional Failed — gói cước đã hết hạn |
| 413 | `hotlineTelcoNotSupported` | `server` | Entity Too Large — hotline không hỗ trợ nhà mạng |
| 414 | `telcoNotFound` | `carrier` | URI Too Long — không tìm thấy nhà mạng |
| 415 | `invalidParameter` | `system` | Unsupported Media — tham số không hợp lệ |
| 416 | `projectExpired` | `server` | Range Not Satisfiable — dự án đã hết hạn |
| 417 | `userNotInGroup` | `server` | Expectation Failed — người dùng không có trong nhóm này |
| 419 | `doNotCall` | `callee` | Do Not Call — người nhận chặn cuộc gọi quảng cáo |
| 480 | `temporarilyUnavailable` | `carrier` | Temporarily Unavailable — tạm thời không liên lạc được |
| 486 | `busy` | `callee` | Busy Here — máy bận |
| 487 | `callerCanceled` | `caller` | Request Terminated — người gọi đã hủy |
| 500 | `connectionError` | `server` | Server Internal Error — lỗi kết nối |
| 502 | `transmissionError` | `carrier` | Bad Gateway — lỗi đường truyền |
| 603 | `decline` | `callee` | Decline — từ chối cuộc gọi |

> [!TIP]
> **Quy luật nhóm `endedBy`:**
> - **`server`**: 400–402, 405–408, 412–413, 416–417, 500
> - **`callee`**: 403, 409, 411, 419, 486, 603
> - **`carrier`**: 404, 410, 414, 480, 502
> - **`system`**: 415
> - **`caller`**: 487

---

## 2. Bảng Toàn Bộ VBotEndCallReason (theo rawValue/code)

Đây là danh sách **đầy đủ** tất cả reason, bao gồm cả các mã **không liên quan đến SIP** (lỗi SDK nội bộ, lỗi hệ thống).

| code | Case name | Ý nghĩa | Nguồn |
|:----:|-----------|---------|:-----:|
| 1000 | `normaly` | Cuộc gọi kết thúc bình thường | SDK logic |
| 1001 | `busy` | Máy bận | SIP 486 |
| 1004 | `timeOut` | Hết thời gian chờ kết nối | SIP 408 / SDK logic |
| 1018 | `noPushToken` | Chưa đăng ký push notification | SDK logic |
| 2002 | `notReadyForStartCall` | Chưa sẵn sàng để gọi đi / khởi tạo không thành công | SDK logic |
| 2004 | `invalidPhoneNumber` | Số điện thoại không hợp lệ | SDK logic |
| 2005 | `noDataFromServer` | Không có dữ liệu từ máy chủ | SDK logic |
| 2006 | `endCallBeforeServerStartCall` | Cuộc gọi kết thúc khi chưa kết nối | SDK logic |
| 2007 | `noCallCreated` | Lỗi khi khởi tạo cuộc gọi | SDK logic |
| 2008 | `dataInvalid` | Dữ liệu không hợp lệ | SDK logic |
| 2009 | `noVBotUser` | Không tìm thấy thông tin tài khoản | SDK logic |
| 2010 | `authenticatedFailed` | Xác thực thất bại | SDK logic |
| 2011 | `anotherCallInProgress` | Đang có cuộc gọi khác | SDK logic |
| 2013 | `decline` | Từ chối cuộc gọi | SIP 603 |
| 2014 | `temporarilyUnavailable` | Không liên lạc được | SIP 480 |
| 2016 | `reportNewIncomingCallFailed` | Không thể tiếp nhận cuộc gọi đến (CallKit) | SDK logic |
| 2017 | `alertDataNotFound` | Dữ liệu thông báo không hợp lệ | SDK logic |
| 2019 | `setupEndpointFailed` | Khởi tạo dịch vụ gọi thất bại | SDK logic |
| 2020 | `requestCallKitActionFailed` | Thực thi hành động cuộc gọi thất bại | SDK logic |
| 2022 | `noAccount` | Tài khoản chưa được cấu hình | SDK logic |
| 2023 | `incomingCallTimeout` | Cuộc gọi đến hết thời gian chờ | SDK logic |
| 2024 | `destinationNotFound`★ | Không tìm thấy số đích | SIP 404 |
| 2025 | `projectExpired`★ | Dự án đã hết hạn | SIP 416 |
| 2026 | `callerCanceled`★ | Người gọi đã hủy | SIP 487 |
| 2027 | `connectionError`★ | Lỗi kết nối | SIP 500 |
| 2028 | `transmissionError`★ | Lỗi đường truyền | SIP 502 |
| 2029 | `incorrectInformation`★ | Thông tin không chính xác | SIP 400 |
| 2030 | `unauthenticated`★ | Chưa xác thực | SIP 401 |
| 2031 | `insufficientBalance`★ | Số dư không đủ | SIP 402 |
| 2032 | `recipientBlocksCalls`★ | Người nhận chặn cuộc gọi | SIP 403 |
| 2033 | `callIntervalNotAllowed`★ | Không được phép gọi trong khung giờ này | SIP 405 |
| 2034 | `memberNotActivated`★ | Thành viên chưa kích hoạt | SIP 406 |
| 2035 | `memberNotInProject`★ | Thành viên không thuộc dự án | SIP 407 |
| 2036 | `doNotDisturb`★ | Người nhận bật không làm phiền | SIP 409 |
| 2037 | `destinationGone`★ | Số đích không còn tồn tại | SIP 410 |
| 2038 | `recipientAbsent`★ | Người nhận vắng mặt | SIP 411 |
| 2039 | `packageExpired`★ | Gói cước đã hết hạn | SIP 412 |
| 2040 | `hotlineTelcoNotSupported`★ | Hotline không hỗ trợ nhà mạng | SIP 413 |
| 2041 | `telcoNotFound`★ | Không tìm thấy nhà mạng | SIP 414 |
| 2042 | `invalidParameter`★ | Tham số không hợp lệ | SIP 415 |
| 2043 | `userNotInGroup`★ | Người dùng không có trong nhóm này | SIP 417 |
| 2044 | `doNotCall`★ | Người nhận chặn cuộc gọi quảng cáo | SIP 419 |
| 9996 | `unknownError` | Lỗi chưa xác định | SDK logic |
| 9999 | `microphonePermissionDenied` | Chưa cấp quyền microphone | SDK logic |

> ★ = Reason mới thêm từ bản 1.1.2 (Android) / 1.1.8 (iOS)

---

## 3. Lưu Ý Về Các Case Đã Biết (Known Issues)

> [!WARNING]
> **SIP Server đang biến đổi một số mã SIP trước khi forward về caller:**

| Kịch bản thực tế | SIP kỳ vọng | SIP thực nhận | reason SDK trả | reason kỳ vọng |
|-------------------|:-----------:|:-------------:|----------------|----------------|
| Callee **từ chối** cuộc gọi | 603 | 480 | `temporarilyUnavailable` | `decline` |
| Callee bật **DND** (không làm phiền) | 409 | 480 | `temporarilyUnavailable` | `doNotDisturb` |
| Callee **chặn** số gọi | 403 | 480 (nghi vấn) | `temporarilyUnavailable` | `recipientBlocksCalls` |

**Root cause**: Lỗi ở SIP Server, không phải SDK. SDK mapping đúng theo chuẩn RFC SIP.

**Giải pháp**: Team Server cần sửa để forward đúng mã SIP gốc về caller.

---

## 4. VBotCallEndParty (Bên kết thúc cuộc gọi)

| Giá trị | Ý nghĩa |
|---------|---------|
| `caller` | Người gọi kết thúc |
| `callee` | Người nhận kết thúc / từ chối |
| `system` | Hệ thống (thiết bị) kết thúc |
| `server` | Server xử lý kết thúc |
| `carrier` | Nhà mạng / trung gian kết thúc |
| `unknown` | Không xác định |

---

## 5. Tham Chiếu Source Code

| Platform | File | Nội dung |
|----------|------|---------|
| iOS | [swiftinterface](file:///Users/namhoang/Documents/GitHub/VBotPhoneSDKiOS-Public/iOS/VBotPhoneSDK.xcframework/ios-arm64_x86_64-simulator/VBotPhoneSDK.framework/Modules/VBotPhoneSDK.swiftmodule/arm64-apple-ios-simulator.swiftinterface#L867-L920) | Enum `VBotEndCallReason` (lines 867–920) |
| iOS | [CHANGELOG.md](file:///Users/namhoang/Documents/GitHub/VBotPhoneSDKiOS-Public/CHANGELOG.md) | Bảng SIP → reason mới |
| Android | [README.md](file:///Users/namhoang/Documents/GitHub/VBotPhoneSDKAndroid-Public/README.md#L200-L260) | Bảng reason + SIP mapping |
| Android | [CHANGELOG.md](file:///Users/namhoang/Documents/GitHub/VBotPhoneSDKAndroid-Public/CHANGELOG.md#L13-L36) | Bảng SIP → reason mới |
| Docs | [call_end_reason_guide.md](file:///Users/namhoang/Documents/GitHub/vbot_flutter_example/docs/call_end_reason_guide.md) | Phân tích chi tiết từng case |
| Docs | [sip_code_api_integration_guide.md](file:///Users/namhoang/Documents/GitHub/vbot_flutter_example/docs/sip_code_api_integration_guide.md) | Đề xuất kiến trúc tích hợp API SIP Code động cho SDK |
