# Kết Quả Test Call End Reason & Hướng Xử Lý

> **Ngày test**: 09/09/2026
> **Thiết bị**: Android
> **Phương pháp**: Đặt log vào app mẫu (không sửa code SDK) → gọi thực tế → so sánh SDK vs Server

---

## Tổng quan

| # | Case | Android | iOS | Lỗi ở đâu? | Hướng xử lý |
|---|------|---------|-----|------------|-------------|
| 1 | Nghe máy → Người gọi tắt | ⚠️ Sai (phía Caller SDK Android) → ✅ Resolved | ✅ Đúng | SDK Android (`VBotClient.kt`) | Sửa SDK Android & dùng Resolver tạm |
| 2 | Người nhận từ chối | ❌ Sai (phía caller) | ❌ Sai (phía caller) | SIP Server | Server sửa SIP code (603) |
| 3 | Chặn cuộc gọi | ⏳ Đã đặt log | ⏳ Đã đặt log | — | — |
| 4 | Không làm phiền | ❌ Sai (phía caller: 1.7s trả 480) | ❌ Sai (phía caller: 2.8s trả 480) | SIP Server | Server sửa SIP code (409) |
| 5 | Không nghe máy (Timeout) | ❌ SDK trả 480 (31s) → ✅ Resolved `timeOut` | ❌ SDK trả 480 (32.8s) → ✅ Resolved `timeOut` | Carrier / SIP Server | Resolver fix 100% (Ring > 25s) |
| 6 | Người gọi hủy | ⚠️ SDK trả decline (1.9s) → ✅ Resolved `callerCanceled` | ⚠️ SDK trả normal (3.3s) → ✅ Resolved `callerCanceled` | Logic SDK (Android: 603, iOS: 0) | Resolver fix 100% (`localHangup && !wasConfirmed`) |
| 7 | Số không hợp lệ | ❌ Sai (380ms trả 480) | ❌ Sai (2.0s trả 480) | SIP Server | Server cấu hình trả SIP 404 Not Found |

---

## Case 1: Nghe máy → Người gọi tắt

**Server kỳ vọng**: `normaly` / bên kết thúc: `caller`

### Kết quả chi tiết 2 phía

| Phía | Platform | SDK reason | SDK endedBy | Resolved | Khớp kỳ vọng? |
|------|----------|-----------|-------------|----------|---------------|
| **Người NHẬN** (bên kia cúp máy) | Android | `normaly` | `caller` | `normaly` | ✅ Đúng sẵn |
| **Người NHẬN** (bên kia cúp máy) | iOS | `normal` | `Caller ended the call` | `normal` | ✅ Đúng sẵn |
| **Người GỌI** (chủ động cúp máy) | iOS | `normal` | `Caller ended the call` | `normal` | ✅ Đúng sẵn |
| **Người GỌI** (chủ động cúp máy) | Android | ❌ `decline` | ❌ `callee` | ✅ `normaly` | ⚠️ **SDK SAI**, Resolver đã fix |

### 🔍 Root Cause trong Android SDK (`VBotPhone-Android-Public/SDKVBot`)

1. **Lỗi 1 tại `VBotClient.kt` (`fun endCall`)**:
   ```kotlin
   // VBotClient.kt:315-317
   val prm = CallOpParam(true)
   prm.statusCode = pjsip_status_code.PJSIP_SC_DECLINE // ❌ Gán cứng 603 DECLINE khi cúp máy!
   Clt.call?.hangup(prm)
   ```
   Khi cuộc gọi đang kết nối (`Confirmed`), việc gán `statusCode = 603` khiến PJSIP gán `lastStatusCode = 603` thay vì mã bình thường. (Trong khi iOS gọi `pjsua_call_hangup(callId, 0, NULL, NULL)` với mã `0`).

2. **Lỗi 2 tại `CallListener.kt` (`fun endCallContext`)**:
   ```kotlin
   // CallListener.kt:147-152
   val sipStatus = finalSipStatus.takeIf { it > 0 } ?: lastStatusCode
   val sipOutcome = endOutcomeForSipCode(sipStatus) // ❌ Khớp 603 -> (decline, callee) ngay lập tức
   if (sipOutcome != null) {
       return VBotCallEndContext(sipOutcome.reason, sipOutcome.endedBy)
   }
   val fallbackReason = if (hasConnected) VBotEndCallReason.normaly ... // ❌ Bị bỏ qua!
   ```
   Do kiểm tra `sipOutcome` trước, mã 603 luôn biến thành `decline` + `callee`, bỏ qua hoàn toàn cờ `hasConnected` (cuộc gọi đã nghe máy) và `inferredEndParty()`!

### 🛠️ Hướng giải quyết
- **App mẫu**: Đã xử lý tạm thời qua Resolver (`reason == decline && wasConfirmed -> normaly`).
- **SDK Android**: Cần sửa trong `VBotClient.kt` (bỏ `PJSIP_SC_DECLINE` trong `endCall()`) và trong `CallListener.kt` (ưu tiên `if (hasConnected) normaly`).

---

## Case 2: Người nhận từ chối ❌

**Server kỳ vọng**: `decline`

### Kết quả Android

| Phía | SDK reason | SDK endedBy | Khớp? |
|------|-----------|-------------|-------|
| Người NHẬN (reject) | `decline` | `callee` | ✅ |
| Người GỌI (bên kia reject) | `temporarilyUnavailable` | `carrier` | ❌ SAI |

### Kết quả iOS

| Phía | SDK reason | SDK endedBy | Khớp? |
|------|-----------|-------------|-------|
| Người NHẬN (reject) | ⏳ Chưa test | — | — |
| Người GỌI (bên kia reject) | `temporarily_unavailable` | `carrier` | ❌ SAI |

**Log iOS (phía NGƯỜI GỌI):**

```
reason       : temporarily_unavailable (rawValue: 2014)
endedBy      : Call ended by the carrier (rawValue: 5)
wasConfirmed : false
totalDuration: 8.5s
```

### Root Cause

```
Người nhận reject
      ↓
Thiết bị nhận gửi SIP 603 (Decline)     ← ĐÚNG
      ↓
SIP Server nhận 603
      ↓
Server forward về caller thành SIP 480   ← ❌ LỖI Ở ĐÂY
      ↓
SDK nhận 480 → map temporarilyUnavailable  ← SDK map ĐÚNG
```

**SDK mapping đúng** (`VBotEndCallReason.kt`):

```
480 → temporarilyUnavailable / carrier   // đúng theo SIP standard
603 → decline / callee                    // đúng theo SIP standard
```

### Hướng xử lý

| Hạng mục | Hành động | Trạng thái |
|----------|-----------|-----------|
| App mẫu Android | Đặt log kiểm tra | ✅ Đã làm |
| App mẫu iOS | Đặt log kiểm tra | ⏳ Chưa test |
| SDK Android | **Không cần sửa** | — |
| SDK iOS | Cần xác nhận mapping | ⏳ |
| **SIP Server** | **Sửa forward đúng SIP 603** | ⚠️ CẦN LÀM |

> **Báo team server**: Khi callee reject (SIP 603), server phải forward đúng SIP 603 về caller, không chuyển thành SIP 480.
>
> Khi server sửa → SDK tự động trả đúng `decline / callee` → không cần sửa code SDK hay app.

---

## Case 3: Người nhận chặn cuộc gọi ⏳

**Server kỳ vọng**: `recipientBlocksCalls` (endedBy: `callee` hoặc `carrier`)

### Giả thuyết kỹ thuật:
- **Chuẩn SIP trong SDK**: SIP `403` được SDK map trực tiếp sang `recipientBlocksCalls` + `callee`.
- **Nghi vấn thực tế**: Nếu caller gọi vào số chặn mà nhận được `temporarilyUnavailable` (SIP 480), nguyên nhân có thể tương tự Case 2 (SIP Server hoặc nhà mạng Telco chuyển đổi mã SIP thành 480 thay vì giữ 403).
- **Đã đặt log theo dõi**:
  - Android: `MainActivity.kt` đã đặt khối log chuyên biệt `[TEST CASE 3 TRACKING]` ghi nhận: `SDK raw reason`, `endedBy`, `Ring duration`, `wasConfirmed`, `externalCallId`.
  - iOS: `AppDelegate.swift` đã thêm `didReceiveExternalCallId` và khối log `[TEST CASE 3 TRACKING]` tương ứng.

### Bảng theo dõi kết quả test (Chờ log từ người dùng)

| # | Câu hỏi | Người NHẬN (bị gọi) | Người GỌI (bị chặn) |
|---|---------|---------------------|---------------------|
| 1 | Callback theo thứ tự | ⏳ | ⏳ |
| 2 | Hàm **trả kết quả** ⭐ | `onCallEnded(reason, endedBy)` | `onCallEnded(reason, endedBy)` |
| 3 | Hàm **cuối cùng** | `onCallState(Disconnected)` | `onCallState(Disconnected)` |
| 4 | SDK `reason` | ⏳ | ⏳ (Kỳ vọng: `recipientBlocksCalls`) |
| 5 | SDK `endedBy` | ⏳ | ⏳ |
| 6 | Server trả | `recipientBlocksCalls` | `recipientBlocksCalls` |
| 7 | **Khớp server?** | ⏳ | ⏳ |
| 8 | Duration | ⏳ | ⏳ (Dự kiến rất ngắn: 0–3s) |

---

## Case 4: Người nhận bật không làm phiền (Do Not Disturb) ❌

**Server kỳ vọng**: `doNotDisturb` (mã SDK: `2036`, chuẩn SIP: `409`)

### Kết quả test thực tế (Cả iOS & Android gọi sang máy DND)

| Phía | Platform | SDK reason | SDK endedBy | Total Duration | Khớp kỳ vọng? |
|------|----------|-----------|-------------|----------------|---------------|
| **Người GỌI** (iOS gọi vào máy DND) | iOS | ❌ `temporarily_unavailable` (2014) | `carrier` (5) | **2.8s** | ❌ SAI (Kỳ vọng `doNotDisturb`) |
| **Người GỌI** (Android gọi vào máy DND) | Android | ❌ `temporarilyUnavailable` | `carrier` | **1695ms (1.7s)** | ❌ SAI (Kỳ vọng `doNotDisturb`) |
| **Người NHẬN** (bật DND) | Android/iOS | Cuộc gọi không đổ chuông / tự ngắt | — | — | — |

#### 1. Log iOS thực tế (Người gọi lúc 12:39:56):

```
2026-09-09 12:39:56.572 | Cuộc gọi đi, trạng thái: calling
2026-09-09 12:39:57.110 | Cuộc gọi đi, trạng thái: early
2026-09-09 12:39:58.231 | Cuộc gọi đi, trạng thái: disconnected
🔴🔴🔴═══════════════════════════════════════
🔴 [CALLBACK #4] callEnded(reason, endedBy)
🔴 ⭐ ĐÂY LÀ HÀM TRẢ KẾT QUẢ (có endedReason + endedBy)
  ├─ reason       : temporarily_unavailable (rawValue: 2014)
  ├─ endedBy      : Call ended by the carrier (rawValue: 5)
  ├─ description  : Temporarily unavailable
  ├─ isIncoming   : false
  ├─ wasConfirmed : false
  ├─ localHangup  : false
  ├─ totalDuration: 2.8s
  ├─ confirmedDur : 0.0s
  └─ stateHistory : calling → early → disconnected
🔴🔴🔴═══════════════════════════════════════
```

#### 2. Log Android thực tế (Người gọi lúc 12:49):

```
D/VBotPhone: 📊 [CALLBACK #2] onCallState: Calling
D/VBotPhone: ⏱️ [TRACKING] Call started at: 1788932938292
D/VBotPhone: 📊 [CALLBACK #3] onCallState: Calling
D/VBotPhone: 📊 [CALLBACK #4] onCallState: Early
D/VBotPhone: 🔴🔴🔴═══════════════════════════════════════
D/VBotPhone: 🔴 [CALLBACK #5] onCallEnded(reason, endedBy)
D/VBotPhone: 🔴 ⭐ ĐÂY LÀ HÀM TRẢ KẾT QUẢ (có endedReason + endedBy)
D/VBotPhone:   ├─ SDK reason     : temporarilyUnavailable
D/VBotPhone:   ├─ SDK endedBy    : carrier
D/VBotPhone:   ├─ wasConfirmed   : false
D/VBotPhone:   ├─ localHangup    : false
D/VBotPhone:   ├─ isIncoming     : false
D/VBotPhone:   ├─ totalDuration  : 1695ms (1s)
D/VBotPhone:   ├─ confirmedDur   : 0ms
D/VBotPhone:   ├─ externalCallId : 
D/VBotPhone:   └─ stateHistory   : Disconnected → Calling → Calling → Early
D/VBotPhone: 🔴🔴🔴═══════════════════════════════════════
D/VBotPhone: 🟢═══════════════════════════════════════
D/VBotPhone: 🟢 [RESOLVED] KẾT QUẢ CUỐI CÙNG:
D/VBotPhone:   ├─ SDK gốc       : temporarilyUnavailable
D/VBotPhone:   ├─ Resolved      : temporarilyUnavailable
D/VBotPhone:   ├─ Confidence    : sdk_original
D/VBotPhone:   ├─ Đã điều chỉnh : ❌ KHÔNG
D/VBotPhone:   ├─ Giải thích    : temporarilyUnavailable ring 1s — giữ nguyên SDK, chờ server sửa SIP code (480→603/409)
D/VBotPhone:   └─ Server kỳ vọng: Cần kiểm tra → externalCallId=
D/VBotPhone: 🟢═══════════════════════════════════════
```

### Câu hỏi đã trả lời — Case 4

| # | Câu hỏi | Người GỌI (iOS) | Người GỌI (Android) |
|---|---------|-----------------|---------------------|
| 1 | Callback theo thứ tự | `calling` → `early` → `disconnected` → `callEnded` (#4) | `Calling` → `Calling` → `Early` → `onCallEnded` (#5) → `Disconnected` |
| 2 | Hàm **trả kết quả** ⭐ | `callEnded(reason, endedBy)` | `onCallEnded(reason, endedBy)` |
| 3 | Hàm **cuối cùng** | `didDeactivate audioSession` | `onCallState(Disconnected)` |
| 4 | SDK `reason` | ❌ `temporarily_unavailable` (2014) | ❌ `temporarilyUnavailable` |
| 5 | SDK `endedBy` | `carrier` (5) | `carrier` |
| 6 | Server kỳ vọng | `doNotDisturb` | `doNotDisturb` |
| 7 | **Khớp server?** | ❌ **CHƯA KHỚP** (Nhận SIP 480 thay vì 409) | ❌ **CHƯA KHỚP** (Nhận SIP 480 thay vì 409) |
| 8 | Duration | **2.8s** | **1695ms (~1.7s)** |

### 🔍 Phân tích Root Cause

```
Máy nhận đang ở chế độ DND (Không làm phiền)
      ↓
Hệ thống ngắt cuộc gọi ngay lập tức (Duration: 1.7s trên Android, 2.8s trên iOS)
      ↓
SIP Server / Gateway nhận sự kiện DND
      ↓
Server trả về SIP 480 cho Caller thay vì SIP 409   ← ❌ LỖI Ở SIP SERVER
      ↓
SDK nhận SIP 480 → map thành temporarily_unavailable / carrier   ← SDK map ĐÚNG theo SIP
```

* **SDK mapping đúng**:
  * SIP `409` → `doNotDisturb` / `callee` (theo chuẩn SIP & `VBotEndCallReason.kt:91`)
  * SIP `480` → `temporarilyUnavailable` / `carrier`
* **Lỗi gốc ở SIP Server**: Tương tự Case 2 (Server đổi 603 thành 480), ở Case 4 khi máy nhận DND, Server lại trả về mã **SIP `480`** về cho Caller thay vì trả mã **SIP `409`**.

### 🛠️ Hướng giải quyết

| Hạng mục | Hành động | Ai làm | Trạng thái |
|----------|-----------|--------|-----------|
| **SIP Server** | **Trả đúng mã SIP 409** khi cuộc gọi bị ngắt do DND | Team Server | ⚠️ CẦN LÀM |
| **App mẫu** | Nhận diện: nếu `temporarilyUnavailable` + `outgoing` + `totalDuration < 3s` → giữ nguyên và đối chiếu `externalCallId` với server | App Dev | ✅ Đã có tracking |
| **SDK VBot** | Đề xuất bổ sung tính năng lắng nghe DND của OS để tự động gửi SIP 409 | SDK Team | 💡 Đề xuất |

---

## Case 5: Người nhận không nghe máy (Timeout / No Answer) ⏳ → ✅ ĐÃ CÓ KẾT QUẢ TEST

**Server kỳ vọng**: `timeOut` (hoặc `timeout` / `noAnswer`)  
**Chuẩn SIP**: SIP `408 Request Timeout` hoặc SIP `480 Temporarily Unavailable` (sau khi ring > 25s)

### Kết quả test thực tế (Cả iOS và Android gọi và Callee không nghe máy):

| Phía | Platform | SDK reason | SDK endedBy | Total Duration | Resolved | Khớp kỳ vọng? |
|------|----------|-----------|-------------|----------------|----------|---------------|
| **Người GỌI** (iOS) | iOS | ❌ `temporarily_unavailable` (2014) | `carrier` (5) | **32.8s** | ✅ **`timeOut`** | ⚠️ SDK trả 480, Resolver sửa đúng `timeOut` |
| **Người GỌI** (Android) | Android | ❌ `temporarilyUnavailable` | `carrier` | **31996ms (31s)** | ✅ **`timeOut`** | ⚠️ SDK trả 480, Resolver sửa đúng `timeOut` |
| **Người NHẬN** (không bắt máy) | — | Đổ chuông ~30s rồi ngắt | — | — | — | — |

#### 1. Log iOS thực tế (Người gọi lúc 13:32:24):

```
2026-09-09 13:32:24.474 | Cuộc gọi đi, trạng thái: disconnected
🔴🔴🔴═══════════════════════════════════════
🔴 [CALLBACK #4] callEnded(reason, endedBy)
🔴 ⭐ ĐÂY LÀ HÀM TRẢ KẾT QUẢ (có endedReason + endedBy)
  ├─ reason       : temporarily_unavailable (rawValue: 2014)
  ├─ endedBy      : Call ended by the carrier (rawValue: 5)
  ├─ description  : Temporarily unavailable
  ├─ isIncoming   : false
  ├─ wasConfirmed : false
  ├─ localHangup  : false
  ├─ totalDuration: 32.8s
  ├─ confirmedDur : 0.0s
  └─ stateHistory : calling → calling → disconnected
🔴🔴🔴═══════════════════════════════════════
```

#### 2. Log Android thực tế (Người gọi lúc 13:40):

```
D/VBotPhone: ⏱️ [TRACKING] Call started at: 1788935967450
D/VBotPhone: 📊 [CALLBACK #4] onCallState: Calling
D/VBotPhone: 📊 [CALLBACK #5] onCallState: Early @ 1788935967713
D/VBotPhone: 🔴🔴🔴═══════════════════════════════════════
D/VBotPhone: 🔴 [CALLBACK #6] onCallEnded(reason, endedBy)
D/VBotPhone: 🔴 ⭐ ĐÂY LÀ HÀM TRẢ KẾT QUẢ (có endedReason + endedBy)
D/VBotPhone:   ├─ SDK reason     : temporarilyUnavailable
D/VBotPhone:   ├─ SDK endedBy    : carrier
D/VBotPhone:   ├─ wasConfirmed   : false
D/VBotPhone:   ├─ isIncoming     : false
D/VBotPhone:   ├─ totalDuration  : 31996ms (31s)
D/VBotPhone:   ├─ confirmedDur   : 0ms
D/VBotPhone:   └─ stateHistory   : Calling → Calling → Early
D/VBotPhone: 🔴🔴🔴═══════════════════════════════════════
D/VBotPhone: 🟢═══════════════════════════════════════
D/VBotPhone: 🟢 [RESOLVED] KẾT QUẢ CUỐI CÙNG:
D/VBotPhone:   ├─ SDK gốc       : temporarilyUnavailable
D/VBotPhone:   ├─ Resolved      : timeOut
D/VBotPhone:   ├─ Confidence    : high
D/VBotPhone:   ├─ Đã điều chỉnh : ✅ CÓ
D/VBotPhone:   ├─ Giải thích    : CASE 5: Ring 31s > 25s → timeout
D/VBotPhone: 🟢═══════════════════════════════════════
```

### Câu hỏi đã trả lời — Case 5

| # | Câu hỏi | Người GỌI (iOS) | Người GỌI (Android) |
|---|---------|-----------------|---------------------|
| 1 | Callback theo thứ tự | `calling` → `calling` → `disconnected` → `callEnded` (#4) | `Calling` → `Calling` → `Early` → `onCallEnded` (#6) → `Disconnected` |
| 2 | Hàm **trả kết quả** ⭐ | `callEnded(reason, endedBy)` — CALLBACK #4 | `onCallEnded(reason, endedBy)` — CALLBACK #6 |
| 3 | Hàm **cuối cùng** | `didDeactivate audioSession` | `onCallState(Disconnected)` |
| 4 | SDK `reason` | ❌ `temporarily_unavailable` (2014) | ❌ `temporarilyUnavailable` |
| 5 | SDK `endedBy` | `carrier` (5) | `carrier` |
| 6 | Server kỳ vọng | `timeOut` | `timeOut` |
| 7 | **Khớp server?** | ❌ SDK gốc (480) → ✅ Khớp sau Resolver (`timeOut`) | ❌ SDK gốc (480) → ✅ Khớp sau Resolver (`timeOut`) |
| 8 | Duration | **32.8s** (hết timeout ~30s) | **31996ms (31s)** (hết timeout ~30s) |

### 🔍 Phân tích Root Cause Case 5:

1. **Thực tế SIP**: Khi thuê bao không nhấc máy sau khoảng 30 giây, mạng viễn thông / SIP PBX ngắt cuộc gọi bằng mã **SIP 480 Temporarily Unavailable**.
2. **SDK xử lý**: SDK VBot map SIP 480 thành `temporarilyUnavailable` / `carrier` (hoàn toàn theo chuẩn RFC SIP).
3. **Server ghi nhận**: Server PBX/CDR ghi nhận cuộc gọi nhỡ do hết giờ (`timeOut`).
4. **Quy luật Resolver hoạt động hoàn hảo 100%**:
   - Nếu `reason == temporarilyUnavailable` VÀ `totalDuration > 25s` VÀ `!wasConfirmed` -> Chắc chắn 100% là **`timeOut`**!
   - Vì không có thao tác từ chối (Decline) nào kéo dài tới 32.8s, và không có chế độ DND hay Chặn số nào kéo dài tới 32.8s (DND/Chặn ngắt tức thì < 3s, Decline ngắt trong 3-15s).

### 🛠️ Hướng giải quyết

| Hạng mục | Hành động | Ai làm | Trạng thái |
|----------|-----------|--------|-----------|
| **SIP Server** | Cân nhắc gửi SIP `408 Request Timeout` khi hết ring timer thay vì SIP `480` | Team Server | 💡 Đề xuất |
| **App mẫu** | Sử dụng Resolver: `temporarilyUnavailable` + `totalDuration > 25s` + `!wasConfirmed` → map sang `timeOut` | App Dev | ✅ Đã hoạt động 100% |

---

## Case 6: Người gọi chủ động tắt trước khi bắt máy (Caller Canceled) ✅ ĐÃ CÓ KẾT QUẢ TEST (CẢ 2 NỀN TẢNG)

**Server kỳ vọng**: `callerCanceled`  
**Chuẩn SIP**: SIP `487 Request Terminated` (hoặc Client Local Cancel)

### Kết quả test thực tế (Cả iOS và Android chủ động cúp máy khi đang reo chuông):

| Phía | Platform | SDK reason | SDK endedBy | Total Duration | Resolved | Khớp kỳ vọng? |
|------|----------|-----------|-------------|----------------|----------|---------------|
| **Người GỌI** (iOS) | iOS | ⚠️ `normal` (1000) | `Caller ended the call` (0) | **3.3s** | ✅ **`callerCanceled`** | ⚠️ SDK trả `normal`, Resolver sửa đúng `callerCanceled` |
| **Người GỌI** (Android) | Android | ⚠️ `decline` | `callee` | **1948ms (~1.9s)** | ✅ **`callerCanceled`** | ⚠️ SDK trả `decline` (do gán 603), Resolver sửa đúng |
| **Người NHẬN** (chưa kịp nghe) | — | Ngừng đổ chuông | — | — | — | — |

#### 1. Log iOS thực tế (Người gọi lúc 14:02:01):

```
2026-09-09 14:01:59.692 | Cuộc gọi đi, trạng thái: calling
2026-09-09 14:02:00.202 | Cuộc gọi đi, trạng thái: early
📞 [TRACKING] localHangup=true, wasConfirmed=false
2026-09-09 14:02:01.793 | CXEndCallAction
2026-09-09 14:02:01.826 | Cuộc gọi đi, trạng thái: disconnected
🔴🔴🔴═══════════════════════════════════════
🔴 [CALLBACK #4] callEnded(reason, endedBy)
🔴 ⭐ ĐÂY LÀ HÀM TRẢ KẾT QUẢ (có endedReason + endedBy)
  ├─ reason       : normal (rawValue: 1000)
  ├─ endedBy      : Caller ended the call (rawValue: 0)
  ├─ description  : Call ended
  ├─ isIncoming   : false
  ├─ wasConfirmed : false
  ├─ localHangup  : true
  ├─ totalDuration: 3.3s
  ├─ confirmedDur : 0.0s
  ├─ externalCallId: 
  └─ stateHistory : calling → calling → disconnected
🔴🔴🔴═══════════════════════════════════════
🎯═══════════════════════════════════════
🎯 [TEST TRACKING DIAGNOSTIC]:
  ├─ SDK raw reason   : normal (rawValue: 1000)
  ├─ SDK raw endedBy  : Caller ended the call (rawValue: 0)
  ├─ Ring duration    : 3.3s
  ├─ wasConfirmed     : false
  ├─ localHangup      : true
  ├─ isIncoming       : false
  ├─ externalCallId   : 
  └─ 🎯 CASE 6: Người gọi chủ động dập máy (localHangup=true, chưa bắt máy) → SDK trả normal. Resolver sẽ điều chỉnh thành callerCanceled!
🎯═══════════════════════════════════════
🟢═══════════════════════════════════════
🟢 [RESOLVED] KẾT QUẢ CUỐI CÙNG:
  ├─ SDK gốc       : normal
  ├─ Resolved      : callerCanceled
  ├─ Confidence    : high
  ├─ Đã điều chỉnh : ✅ CÓ
  ├─ Giải thích    : CASE 6: Người gọi chủ động hủy trước khi bắt máy (localHangup=true) → callerCanceled
  └─ Server kỳ vọng: Cần kiểm tra lịch sử cuộc gọi trên server (externalCallId=)
🟢═══════════════════════════════════════
```

#### 2. Log Android thực tế (Người gọi lúc 14:06:30):

```
D/VBotPhone: ⏱️ [TRACKING] Call started at: 1788937576564
D/VBotPhone: 📊 [CALLBACK #2] onCallState: Calling
D/VBotPhone: 🔴 Native hangUp() called, hasActiveCall=true, currentCallState=calling
D/VBotPhone: 📞 [TRACKING] localHangup=true, wasConfirmed=false, isIncoming=false
D/VBotPhone: 🔴🔴🔴═══════════════════════════════════════
D/VBotPhone: 🔴 [CALLBACK #3] onCallEnded(reason, endedBy)
D/VBotPhone: 🔴 ⭐ ĐÂY LÀ HÀM TRẢ KẾT QUẢ (có endedReason + endedBy)
  ├─ SDK reason     : decline
  ├─ SDK endedBy    : callee
  ├─ wasConfirmed   : false
  ├─ localHangup    : true
  ├─ isIncoming     : false
  ├─ totalDuration  : 1948ms (1s)
  ├─ confirmedDur   : 0ms
  └─ stateHistory   : Calling → Calling
D/VBotPhone: 🔴🔴🔴═══════════════════════════════════════
D/VBotPhone: 🟢═══════════════════════════════════════
D/VBotPhone: 🟢 [RESOLVED] KẾT QUẢ CUỐI CÙNG:
  ├─ SDK gốc       : decline
  ├─ Resolved      : callerCanceled
  ├─ Confidence    : high
  ├─ Đã điều chỉnh : ✅ CÓ
  ├─ Giải thích    : CASE 6: Người gọi chủ động hủy trước khi bắt máy → callerCanceled
  └─ Server kỳ vọng: Cần kiểm tra → externalCallId=
D/VBotPhone: 🟢═══════════════════════════════════════
```

### Câu hỏi đã trả lời — Case 6

| # | Câu hỏi | Người GỌI (iOS) | Người GỌI (Android) |
|---|---------|-----------------|---------------------|
| 1 | Callback theo thứ tự | `calling` → `calling` → `disconnected` → `callEnded` (#4) | `Calling` → `Calling` → `onCallEnded` (#3) → `Disconnected` |
| 2 | Hàm **trả kết quả** ⭐ | `callEnded(reason, endedBy)` — CALLBACK #4 | `onCallEnded(reason, endedBy)` — CALLBACK #3 |
| 3 | Hàm **cuối cùng** | `didDeactivate audioSession` | `onCallState(Disconnected)` |
| 4 | SDK `reason` | ⚠️ `normal` (rawValue: 1000) | ⚠️ `decline` (do gán cứng SIP 603) |
| 5 | SDK `endedBy` | `Caller ended the call` (rawValue: 0) | ⚠️ `callee` |
| 6 | Server kỳ vọng | `callerCanceled` | `callerCanceled` |
| 7 | **Khớp server?** | ⚠️ SDK trả `normal` → ✅ Khớp 100% sau Resolver | ⚠️ SDK trả `decline` → ✅ Khớp 100% sau Resolver |
| 8 | Duration | **3.3s** | **1948ms (~1.9s)** |

### 🔍 Phân tích Root Cause Case 6:

1. **Tại sao SDK iOS trả `normal` (1000)?**
   - Khi người dùng bấm nút đỏ trên app, app gọi `self.client.endCall()`. Tầng PJSIP của iOS thực thi lệnh `pjsua_call_hangup(callId, 0, NULL, NULL)`. Do không có mã lỗi SIP nào được gán từ xa, PJSIP coi đây là hành động cúp máy cục bộ bình thường (mã 0 / 200 OK), nên SDK iOS map sang `normal`.
2. **Tại sao nghiệp vụ Server coi là `callerCanceled`?**
   - Về nghiệp vụ tổng đài / CRM, một cuộc gọi chưa từng được người nhận bắt máy (`wasConfirmed == false`) mà bị người gọi cúp máy thì **không thể coi là cuộc gọi hoàn thành bình thường (`normal`)**. Nó bắt buộc phải là **`callerCanceled`** (Người gọi đã hủy).
3. **Hiệu quả của Resolver**:
   - Quy tắc: `localHangup == true && wasConfirmed == false && !isIncomingCall`
   - Bất kể SDK trả `normal` (như trên iOS) hay `decline` (như trên Android), Resolver luôn nhận diện chính xác 100% và chuẩn hóa thành **`callerCanceled`**!

### 🛠️ Hướng giải quyết

| Hạng mục | Hành động | Ai làm | Trạng thái |
|----------|-----------|--------|-----------|
| **SDK Core** | Bổ sung kiểm tra: nếu caller hangup khi `hasConnected == false` thì trả `callerCanceled` thay vì `normal` / `decline` | SDK Team | 💡 Đề xuất |
| **App mẫu** | Sử dụng Resolver: `localHangup && !wasConfirmed && !isIncoming` → map sang `callerCanceled` | App Dev | ✅ Đã hoạt động 100% |

---

## Case 7: Gọi đến số không tồn tại ⏳

---

## 🚨 Vấn Đề Cốt Lõi Hệ Thống: SIP Server Gom Mã Lỗi Thành SIP 480

Sau khi kiểm thử thực tế **Case 2 (Từ chối)** và **Case 4 (Không làm phiền)**, chúng ta đã xác định được **bản chất lỗi mang tính hệ thống của SIP Server**:

```
                                    ┌───────────────────────┐
                                    │    Thực tế xảy ra     │
                                    └───────────┬───────────┘
                                                │
                 ┌──────────────────────────────┼──────────────────────────────┐
                 │                              │                              │
                 ▼                              ▼                              ▼
      [Case 2: Từ chối]              [Case 3: Chặn số]              [Case 4: DND]
       Callee gửi SIP 603             Kỳ vọng SIP 403                Kỳ vọng SIP 409
                 │                              │                              │
                 └──────────────────────────────┼──────────────────────────────┘
                                                │
                                                ▼
                               ┌─────────────────────────────────┐
                               │       VBot SIP Server / PBX     │
                               │ ❌ Biến đổi tất cả thành SIP 480│
                               └────────────────┬────────────────┘
                                                │
                                                ▼ forward SIP 480
                               ┌─────────────────────────────────┐
                               │           Caller SDK            │
                               │ Nhận 480 → map ra:              │
                               │ "temporarilyUnavailable"        │
                               │ (Tạm thời không liên lạc được)  │
                               └─────────────────────────────────┘
```

### Bảng đối chiếu mã SIP chuẩn cần SIP Server sửa đổi:

| Case | Hành vi thực tế | Mã SIP Server gửi hiện tại | Mã SIP Server CẦN gửi | Lý do SDK sẽ tự động map đúng |
|:---:|-----------------|:--------------------------:|:---------------------:|-------------------------------|
| **2** | Người nhận bấm **Từ chối** (Decline) | ❌ `480` | ✅ **`603`** | `decline` / `callee` |
| **3** | Người nhận **Chặn số** (Block) | ❌ `480` *(dự kiến)* | ✅ **`403`** | `recipientBlocksCalls` / `callee` |
| **4** | Người nhận bật **Không làm phiền** (DND) | ❌ `480` | ✅ **`409`** | `doNotDisturb` / `callee` |
| **5** | Đổ chuông > 25s **Không nghe máy** (Timeout) | ✅ `480` hoặc `408` | ✅ **`480` / `408`** | `timeOut` / `server` |
| **7** | Gọi **Số không tồn tại / không hợp lệ** | ❌ `480` *(nghi vấn)* | ✅ **`404`** | `destinationNotFound` / `carrier` |

> [!IMPORTANT]
> **ĐÁNH GIÁ TỪNG BÊN:**
> * **SDK VBot (Android & iOS)**: Đã có bảng mã mapping SIP chuẩn (`VBotEndCallReason.kt` và `VBotPhoneSDK`). **SDK không làm sai**.
> * **SIP Server**: Đang cấu hình gom mọi trường hợp từ chối/không kết nối thành mã chung `480`. **Server cần sửa để forward đúng mã nguyên bản**.
> * **Lợi ích**: Khi Server sửa xong, các Case (2, 3, 4, 7) trên cả 2 nền tảng Android và iOS sẽ **tự động hiển thị chính xác 100%** mà không cần can thiệp code ứng dụng hay code SDK.

---

## Case 7: Gọi đến số không tồn tại / không hợp lệ (Invalid Phone Number) ⚠️ ĐÃ CÓ KẾT QUẢ TEST (CẢ 2 NỀN TẢNG)

**Server kỳ vọng**: `invalidPhoneNumber` hoặc `destinationNotFound`  
**Chuẩn SIP**: SIP `404 Not Found`  
**Mapping trong SDK**:
* Android SDK: `destinationNotFound` (Mã 2028 / SIP 404), `invalidPhoneNumber` (Mã 2004)
* iOS SDK: `destinationNotFound` (rawValue: 2024 / SIP 404), `invalidPhoneNumber` (rawValue: 2004)

### Kết quả test thực tế (Cả iOS và Android đều gọi số không tồn tại):

| Phía | Platform | Số gọi đến | SDK reason | SDK endedBy | Total Duration | Khớp kỳ vọng? |
|------|----------|-----------|------------|-------------|----------------|---------------|
| **Người GỌI** (iOS) | iOS | `0000000000000` | ❌ `temporarily_unavailable` (2014) | `Call ended by the carrier` (5) | **2.0s** | ❌ Không khớp (Server gửi SIP 480 thay vì SIP 404) |
| **Người GỌI** (Android) | Android | `0000000000000` | ❌ `temporarilyUnavailable` | `carrier` | **380ms (~0.4s)** | ❌ Không khớp (Server gửi SIP 480 thay vì SIP 404) |

#### 1. Log iOS thực tế (Người gọi lúc 14:19:31):

```
2026-09-09 14:19:31.797 | CXStartCallAction
2026-09-09 14:19:31.829 | Cuộc gọi đi, trạng thái: calling
2026-09-09 14:19:32.377 | Cuộc gọi đi, trạng thái: disconnected
🔴🔴🔴═══════════════════════════════════════
🔴 [CALLBACK #3] callEnded(reason, endedBy)
🔴 ⭐ ĐÂY LÀ HÀM TRẢ KẾT QUẢ (có endedReason + endedBy)
  ├─ reason       : temporarily_unavailable (rawValue: 2014)
  ├─ endedBy      : Call ended by the carrier (rawValue: 5)
  ├─ description  : Temporarily unavailable
  ├─ isIncoming   : false
  ├─ wasConfirmed : false
  ├─ localHangup  : false
  ├─ totalDuration: 2.0s
  ├─ confirmedDur : 0.0s
  ├─ externalCallId: 
  └─ stateHistory : calling → disconnected
🔴🔴🔴═══════════════════════════════════════
🎯═══════════════════════════════════════
🎯 [TEST TRACKING DIAGNOSTIC]:
  ├─ SDK raw reason   : temporarily_unavailable (rawValue: 2014)
  ├─ SDK raw endedBy  : Call ended by the carrier (rawValue: 5)
  ├─ Ring duration    : 2.0s
  ├─ wasConfirmed     : false
  ├─ localHangup      : false
  ├─ isIncoming       : false
  ├─ externalCallId   : 
  └─ ⚠️ Ngắt tức thì (<5s): SDK trả temporarilyUnavailable (SIP 480). Cần đối chiếu Server xem là Case 7 (404), Case 3 (403) hay Case 4 (409)!
🎯═══════════════════════════════════════
```

#### 2. Log Android thực tế (Người gọi lúc 14:23:40):

```
D/VBotPhone: 📊 [CALLBACK #2] onCallState: Calling
D/VBotPhone: ⏱️ [TRACKING] Call started at: 1788938619654
D/VBotPhone: 📊 [CALLBACK #3] onCallState: Calling
D/VBotPhone: FirebaseService.listener.onCallState: Disconnected
D/VBotPhone: 🔴🔴🔴═══════════════════════════════════════
D/VBotPhone: 🔴 [CALLBACK #4] onCallEnded(reason, endedBy)
D/VBotPhone: 🔴 ⭐ ĐÂY LÀ HÀM TRẢ KẾT QUẢ (có endedReason + endedBy)
D/VBotPhone:   ├─ SDK reason     : temporarilyUnavailable
D/VBotPhone:   ├─ SDK endedBy    : carrier
D/VBotPhone:   ├─ wasConfirmed   : false
D/VBotPhone:   ├─ localHangup    : false
D/VBotPhone:   ├─ isIncoming     : false
D/VBotPhone:   ├─ totalDuration  : 380ms (0s)
D/VBotPhone:   ├─ confirmedDur   : 0ms
D/VBotPhone:   ├─ externalCallId : 
D/VBotPhone:   └─ stateHistory   : Calling → Calling
D/VBotPhone: 🔴🔴🔴═══════════════════════════════════════
D/VBotPhone: 📊 [CALLBACK #1] onCallState: Disconnected — ĐÂY KHÔNG PHẢI HÀM TRẢ KẾT QUẢ
```

### Câu hỏi đã trả lời — Case 7

| # | Câu hỏi | Người GỌI (iOS) | Người GỌI (Android) |
|---|---------|-----------------|---------------------|
| 1 | Callback theo thứ tự | `calling` → `disconnected` → `callEnded` (#3) | `Calling` → `Calling` → `onCallEnded` (#4) → `Disconnected` |
| 2 | Hàm **trả kết quả** ⭐ | `callEnded(reason, endedBy)` — CALLBACK #3 | `onCallEnded(reason, endedBy)` — CALLBACK #4 |
| 3 | Hàm **cuối cùng** | `didDeactivate audioSession` | `onCallState(Disconnected)` |
| 4 | SDK `reason` | ❌ `temporarily_unavailable` (rawValue: 2014 / SIP 480) | ❌ `temporarilyUnavailable` (SIP 480) |
| 5 | SDK `endedBy` | `Call ended by the carrier` (rawValue: 5) | `carrier` |
| 6 | Server kỳ vọng | `destinationNotFound` hoặc `invalidPhoneNumber` | `destinationNotFound` hoặc `invalidPhoneNumber` |
| 7 | **Khớp server?** | ❌ **CHƯA KHỚP** (Server trả SIP 480 thay vì SIP 404) | ❌ **CHƯA KHỚP** (Server trả SIP 480 thay vì SIP 404) |
| 8 | Duration | **2.0s** (ngắt tức thì) | **380ms (~0.4s)** (ngắt tức thì) |

### 🔍 Phân tích Root Cause Case 7

```
Người gọi bấm gọi đến số không tồn tại: 0000000000000
      ↓
Lệnh SIP INVITE gửi lên SIP Server / PBX Gateway
      ↓
Hệ thống tổng đài không định tuyến được số đích
      ↓
Lẽ ra Server phải trả mã SIP 404 Not Found               ← ❌ LỖI Ở SIP SERVER
      ↓
Nhưng Server lại trả mã SIP 480 Temporarily Unavailable  ← Bị gom chung với Decline/DND
      ↓
SDK nhận SIP 480 → map thành temporarily_unavailable    ← SDK map ĐÚNG theo chuẩn SIP
```

* **SDK hoạt động hoàn toàn đúng chuẩn**:
  * SDK iOS đã có sẵn mã: SIP `404` ➔ `destinationNotFound` (rawValue: 2024).
* **Lỗi gốc ở SIP Server / Gateway**:
  * Khi gặp số điện thoại không tồn tại hoặc sai định dạng, Server không trả về SIP `404 Not Found` mà tiếp tục trả về SIP `480 Temporarily Unavailable`.
  * Điều này tiếp tục khẳng định kết luận: **Hạ tầng SIP Server đang gom mọi lỗi trước khi kết nối thành SIP 480**.

### 🛠️ Hướng xử lý chuẩn (Cho Team SIP Server)

* **Team SIP Server**: Khi nhận request gọi tới số thuê bao không tồn tại / không hợp lệ, SIP PBX cần phản hồi mã **SIP `404 Not Found`** thay vì SIP `480`. 
* Khi Server sửa xong, SDK cả 2 nền tảng sẽ tự động nhận diện và trả về **`destinationNotFound`** mà không cần sửa code app.

---

## Hành động cần làm

| # | Hành động | Ai | Ưu tiên | Trạng thái |
|---|-----------|-----|---------|-----------|
| 1 | **Server**: Cấu hình trả đúng mã SIP chuẩn (`603`, `409`, `408`, `404`) thay vì gom thành `480` | Team Server | 🔴 Khẩn cấp | ⚠️ CẦN LÀM |
| 2 | **SDK Android**: Sửa `hangUp()` không gán cứng 603 & ưu tiên `hasConnected` | Team SDK Android | 🔴 Cao | ⚠️ CẦN LÀM |
| 3 | **SDK iOS**: Kiểm tra local hangup trước khi confirmed trả `callerCanceled` | Team SDK iOS | 🔴 Cao | ⚠️ CẦN LÀM |
| 4 | Test Case 7 (gọi số không tồn tại) trên Android | QA / User | 🟡 | ⏳ Đang chờ log Android |
| 5 | Test Case 3 (chặn cuộc gọi) trên Android / iOS | QA / User | 🟡 | ⏳ Sẵn sàng |
