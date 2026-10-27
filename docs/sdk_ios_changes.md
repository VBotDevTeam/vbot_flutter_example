# Tóm Tắt Thay Đổi iOS SDK (Commit `d6d707d`)

> **Nhánh:** `nam-example` | **Commit:** [`d6d707d`](file:///Users/namhoang/Documents/GitHub/VBotPhone-iOS-Public) (`fix(call): xử lý caller cancel, rớt mạng và triệt tiêu cuộc gọi treo`)

---

## 1. Thực Tế Các Thay Đổi Vừa Sửa (Chỉ gồm 5 điểm chính)

1. **Xử lý Case 6 (Caller Cancel)**:
   - Trong `cacheEndCallContext`: nếu `userDidHangUp && !isIncoming` ➔ trả chính xác `reason = .callerCanceled`, `endedBy = .caller`.
2. **Triệt tiêu cuộc gọi treo (Zombie Call qua SIP 481)**:
   - Trong PJSIP log & `onTxStateChange`: khi nhận mã `481 Call/Transaction Does Not Exist` ➔ gọi `markRemoteDidHangUp()` và tự kích hoạt `endCall()`.
3. **Cập nhật luồng âm thanh khi đổi mạng**:
   - Trong `VBotEndpoint.m`: bắt sự kiện `PJSUA_IP_CHANGE_OP_COMPLETED` ➔ tự động gửi `reinviteActiveCallsForAccount` cập nhật socket media.
4. **Không tự hủy SIP Account khi mạng chập chờn**:
   - Trong `VBotAccount.m`: bỏ lệnh `removeAccount` khi gặp timeout `408` hoặc `503`. Với lỗi `401/403`, chỉ xóa account nếu không có cuộc gọi active (`callsForAccount == 0`).
5. **Tiện ích & Bảo vệ API**:
   - Thêm hàm public `enableDebugLogging(_ enabled: Bool)` và tự bật log chi tiết ở `#if DEBUG`.
   - Trong `VBotAPI.swift`: thêm guard `transId.isEmpty` và đặt `timeoutInterval = 10.0s`.

---

## 2. Chi Tiết Thay Đổi Theo 5 File

| File | Nội dung thay đổi |
|---|---|
| [VBotPhone.swift](file:///Users/namhoang/Documents/GitHub/VBotPhone-iOS-Public/VBotPhoneSDK/VBotPhone.swift) | - Thêm `enableDebugLogging(Bool)`.<br>- Tự cấu hình log theo `#if DEBUG`.<br>- Case 6 (`callerCanceled`) trong `cacheEndCallContext`.<br>- Bắt chuỗi `481` trong log PJSIP để tự cúp cuộc gọi zombie.<br>- Trong `hanleInternetConnectionChanged`: thêm guard `transId` và cúp máy nếu server báo `false`. |
| [VBotEndpoint.m](file:///Users/namhoang/Documents/GitHub/VBotPhone-iOS-Public/VBotPhoneSDK/SIP/VBotEndpoint.m) | - Bắt `PJSUA_IP_CHANGE_OP_COMPLETED` để gửi re-INVITE.<br>- Bắt mã 481 trong `onTxStateChange` để gán `markRemoteDidHangUp`. |
| [VBotAccount.m](file:///Users/namhoang/Documents/GitHub/VBotPhone-iOS-Public/VBotPhoneSDK/SIP/VBotAccount.m) | - Bỏ `removeAccount` khi gặp lỗi 408/503 lúc mạng chập chờn.<br>- Chỉ cho phép xóa account khi không có cuộc gọi active. |
| [VBotAPI.swift](file:///Users/namhoang/Documents/GitHub/VBotPhone-iOS-Public/VBotPhoneSDK/API/VBotAPI.swift) | - Guard `transId.isEmpty` và thêm timeout `10.0` giây cho request `checkCallExistByTrans`. |
| [VBotNetworkMonitor.m](file:///Users/namhoang/Documents/GitHub/VBotPhone-iOS-Public/VBotPhoneSDK/SIP/VBotNetworkMonitor.m) | - Tách log `Reachable` vs `Unreachable`.<br>- Kiểm tra lại trạng thái kết nối sau debounce time. |

---

> [!WARNING]
> **Điểm cần sửa lại ngay trong [VBotPhone.swift](file:///Users/namhoang/Documents/GitHub/VBotPhone-iOS-Public/VBotPhoneSDK/VBotPhone.swift#L569):**  
> Dòng `cacheEndCallContext(for: call)` trong `case .disconnected:` vô tình bị xóa trong commit vừa rồi. Cần thêm lại dòng này để logic Case 6 và mapping SIP code ở trên thực sự chạy được khi cúp máy.
