# Tóm Tắt Thay Đổi Android SDK (Commit `ffb4738`, `ef2e7f3`, `a223c0d`)

> **Nhánh:** `nam-dev` | **Commit mới nhất:** [`ffb4738`](file:///Users/namhoang/Documents/GitHub/VBotPhone-Android-Public) (`fix(call): auto detect network reconnection and terminate zombie calls`)

---

## 1. Thực Tế Các Thay Đổi Vừa Sửa (Chỉ gồm 4 điểm chính)

1. **Sửa lệnh cúp máy `endCall()` (Case 1)**:
   - Bỏ hardcode mã `DECLINE` (SIP 603) trong `endCall()`. Giờ PJSIP tự gửi `BYE` (nếu đã nghe máy) hoặc `CANCEL` (nếu đang gọi chưa nghe).
   - Trong `CallListener`: ưu tiên kiểm tra `hasConnected == true` ➔ luôn trả `normaly`.
2. **Xử lý Case 6 (Caller Cancel)**:
   - Trong `CallListener`: nếu `userDidHangUp && !isIncoming` ➔ trả chính xác `reason = callerCanceled`, `endedBy = caller`.
3. **Triệt tiêu cuộc gọi treo (Zombie Call khi rớt mạng)**:
   - Tự động đăng ký `NetworkCallback`. Khi có mạng lại: gọi `handleIpChange()`, gửi re-INVITE probe, bắt SIP 481 và hẹn giờ 1.5s gọi API đối soát `checkCallExistByTrans` để tự ngắt cuộc gọi nếu đối phương đã cúp.
4. **Chống crash PJSIP Native**:
   - Thêm `ensureThreadRegistered()` tại các hàm public của PJSIP.
   - Bỏ `delete()` trong `finalize()` của `CallListener` tránh JVM `FinalizerDaemon` gây crash `SIGABRT`.

---

## 2. Chi Tiết Thay Đổi Theo Các File

| File | Nội dung thay đổi |
|---|---|
| [VBotClient.kt](file:///Users/namhoang/Documents/GitHub/VBotPhone-Android-Public/SDKVBot/src/main/java/com/vpmedia/sdkvbot/client/VBotClient.kt) | - Bỏ hardcode `PJSIP_SC_DECLINE` trong `endCall()`.<br>- Tự động đăng ký `NetworkCallback`, kích hoạt `handleNetworkReconnected()`.<br>- Thêm hàm `checkCallExistOnServer` gọi Retrofit sau 1.5s.<br>- Thêm `ensureThreadRegistered()` bảo vệ luồng native. |
| [CallListener.kt](file:///Users/namhoang/Documents/GitHub/VBotPhone-Android-Public/SDKVBot/src/main/java/com/vpmedia/sdkvbot/client/CallListener.kt) | - Ưu tiên `hasConnected` (Case 1 ➔ `normaly`).<br>- Thêm kiểm tra `userDidHangUp && !isIncoming` (Case 6 ➔ `callerCanceled`).<br>- Bắt SIP 481 từ INVITE transaction để gán `remoteDidHangUp`.<br>- Bỏ `delete()` trong `finalize()`. |
| [AService.kt](file:///Users/namhoang/Documents/GitHub/VBotPhone-Android-Public/SDKVBot/src/main/java/com/vpmedia/sdkvbot/domain/api/AService.kt) | - Khai báo endpoint `@GET("api/sdk/checkCallExistByTrans")`. |
| [SipCallCoordinator.kt](file:///Users/namhoang/Documents/GitHub/VBotPhone-Android-Public/SDKVBot/src/main/java/com/vpmedia/sdkvbot/domain/manager/SipCallCoordinator.kt) | - Thêm hàm `handleIpChange()` cập nhật interface mạng cho PJSIP. |
| [VBotSipLogWriter.kt](file:///Users/namhoang/Documents/GitHub/VBotPhone-Android-Public/SDKVBot/src/main/java/com/vpmedia/sdkvbot/client/VBotSipLogWriter.kt) | - Đếm lỗi RTP khi mất mạng và phát hiện chuỗi cảnh báo PJSIP. |
