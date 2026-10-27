# 📋 Call End Reason — Log Chẩn Đoán Các Case

> **Ngày test**: 09/09/2026  
> **Thiết bị**: Android & iOS  
> **Phương pháp**: Đặt log vào app mẫu → gọi thực tế → ghi nhận SDK trả về → đối chiếu server

---

## Bảng Tổng Hợp Kết Quả Test

| # | Case | SDK Android (phía Caller) | SDK iOS (phía Caller) | Server kỳ vọng | Lỗi ở đâu? | Trạng thái test |
|:-:|------|--------------------------|----------------------|----------------|-------------|:---------------:|
| 1 | Nghe máy → Người gọi tắt | ❌ `decline` / `callee` | ✅ `normal` / `caller` | `normaly` / `caller` | **SDK Android** | ✅ Đã test |
| 2 | Người nhận từ chối | ❌ `temporarilyUnavailable` / `carrier` | ❌ `temporarily_unavailable` / `carrier` | `decline` / `callee` | **SIP Server** | ✅ Đã test |
| 3 | Chặn cuộc gọi | ⏳ | ⏳ | `recipientBlocksCalls` | Dự kiến **SIP Server** | ⏳ Chưa test |
| 4 | Không làm phiền (DND) | ❌ `temporarilyUnavailable` / `carrier` | ❌ `temporarily_unavailable` / `carrier` | `doNotDisturb` | **SIP Server** | ✅ Đã test |
| 5 | Không nghe máy (Timeout) | ❌ `temporarilyUnavailable` / `carrier` (31s) | ❌ `temporarily_unavailable` / `carrier` (32.8s) | `timeOut` | **Carrier / SIP Server** | ✅ Đã test |
| 6 | Người gọi hủy trước khi bắt máy | ❌ `decline` / `callee` (1.9s) | ⚠️ `normal` / `caller` (3.3s) | `callerCanceled` | **SDK Android + iOS** | ✅ Đã test |
| 7 | Số không tồn tại | ❌ `temporarilyUnavailable` / `carrier` (380ms) | ❌ `temporarily_unavailable` / `carrier` (2.0s) | `destinationNotFound` | **SIP Server** | ✅ Đã test |

---

## Chi Tiết Từng Case

---

### Case 1 — Nghe máy → Người gọi tắt máy

**Kỳ vọng server**: `normaly` / `caller`

#### Kết quả test

| Phía | Platform | SDK reason | SDK endedBy | Duration | Đúng? |
|------|----------|-----------|-------------|----------|:-----:|
| Người NHẬN | Android | `normaly` | `caller` | — | ✅ |
| Người NHẬN | iOS | `normal` | `Caller ended the call` | — | ✅ |
| Người GỌI | iOS | `normal` (1000) | `Caller ended the call` (0) | 12.6s | ✅ |
| **Người GỌI** | **Android** | **`decline`** | **`callee`** | 7.9s | ❌ |

#### Lỗi ở đâu: **SDK Android**

2 bug trong source SDK (`VBotPhone-Android-Public/SDKVBot`):

1. **`VBotClient.kt` dòng 315**: `endCall()` hardcode `prm.statusCode = PJSIP_SC_DECLINE` (SIP 603) khi cúp máy — kể cả đang đàm thoại Confirmed. Trong khi iOS gọi `pjsua_call_hangup(callId, 0, ...)` với mã `0`.
2. **`CallListener.kt` dòng 147**: `endCallContext()` check `sipOutcome` (SIP code) trước `hasConnected`, nên mã 603 luôn map thành `decline`/`callee`, bỏ qua logic `if (hasConnected) → normaly`.

#### Log Android (phía Người GỌI — SAI)

```
🔴 onCallEnded:
  ├─ SDK reason     : decline          ← ❌ SAI (phải là normaly)
  ├─ SDK endedBy    : callee           ← ❌ SAI (phải là caller)
  ├─ wasConfirmed   : true             ← Đã bắt máy!
  ├─ localHangup    : true
  ├─ totalDuration  : 7952ms
  └─ confirmedDur   : 2558ms
```

#### Log iOS (phía Người GỌI — ĐÚNG)

```
🔴 callEnded:
  ├─ reason       : normal (rawValue: 1000)     ← ✅
  ├─ endedBy      : Caller ended the call (0)   ← ✅
  ├─ wasConfirmed : true
  ├─ localHangup  : true
  ├─ totalDuration: 12.6s
  └─ confirmedDur : 7.7s
```

---

### Case 2 — Người nhận từ chối (Decline)

**Kỳ vọng server**: `decline` / `callee`

#### Kết quả test

| Phía | Platform | SDK reason | SDK endedBy | Duration | Đúng? |
|------|----------|-----------|-------------|----------|:-----:|
| Người NHẬN | Android | `decline` | `callee` | Ngắn | ✅ |
| **Người GỌI** | **Android** | **`temporarilyUnavailable`** | **`carrier`** | **8.4s** | ❌ |
| **Người GỌI** | **iOS** | **`temporarily_unavailable`** (2014) | **`carrier`** (5) | **8.5s** | ❌ |

#### Lỗi ở đâu: **SIP Server**

```
Callee reject → Thiết bị gửi SIP 603 (đúng)
    → SIP Server nhận 603
    → Server forward về Caller thành SIP 480  ← ❌ LỖI
    → SDK nhận 480 → map temporarilyUnavailable (mapping đúng theo chuẩn SIP)
```

SDK mapping đúng: `480 → temporarilyUnavailable`, `603 → decline`. Lỗi do Server đổi 603 thành 480.

#### Log Android (phía Người GỌI — SAI)

```
🔴 onCallEnded:
  ├─ SDK reason     : temporarilyUnavailable    ← ❌ (phải là decline)
  ├─ SDK endedBy    : carrier                   ← ❌ (phải là callee)
  ├─ wasConfirmed   : false
  ├─ localHangup    : false
  ├─ totalDuration  : 8384ms
  └─ stateHistory   : Calling → Calling
```

---

### Case 3 — Chặn cuộc gọi (Block)

**Kỳ vọng server**: `recipientBlocksCalls` — SIP `403 Forbidden`

#### Kết quả test: ⏳ CHƯA TEST

Đã đặt log tracking `[TEST CASE 3 TRACKING]` trên cả Android và iOS, sẵn sàng test.

#### Giả thuyết

- Nếu Server trả SIP 403 → SDK tự map `recipientBlocksCalls` ✅
- Nếu Server gom thành SIP 480 (như Case 2, 4, 7) → SDK trả `temporarilyUnavailable` ❌

#### Cách test

1. Máy nhận → chặn số caller
2. Từ thiết bị test → gọi đến số đã chặn
3. Thu log: Android `Logcat tag:VBotPhone`, iOS `Xcode Console`
4. Lấy `externalCallId` đối chiếu server

---

### Case 4 — Không làm phiền (DND)

**Kỳ vọng server**: `doNotDisturb` — SIP `409 Conflict`

#### Kết quả test

| Phía | Platform | SDK reason | SDK endedBy | Duration | Đúng? |
|------|----------|-----------|-------------|----------|:-----:|
| **Người GỌI** | **iOS** | **`temporarily_unavailable`** (2014) | `carrier` (5) | **2.8s** | ❌ |
| **Người GỌI** | **Android** | **`temporarilyUnavailable`** | `carrier` | **1.7s** | ❌ |
| Người NHẬN | Cả 2 | Cuộc gọi không đổ chuông / tự ngắt | — | — | — |

#### Lỗi ở đâu: **SIP Server**

```
Callee DND → Hệ thống ngắt tức thì (1.7-2.8s)
    → SIP Server gửi SIP 480 về Caller  ← ❌ LỖI (phải là SIP 409)
    → SDK nhận 480 → temporarilyUnavailable (mapping đúng)
```

SDK đã có sẵn mapping: `SIP 409 → doNotDisturb / callee`. Lỗi do Server gửi 480 thay vì 409.

#### Log iOS (phía Người GỌI)

```
🔴 callEnded:
  ├─ reason       : temporarily_unavailable (rawValue: 2014)  ← ❌ (phải là doNotDisturb)
  ├─ endedBy      : Call ended by the carrier (rawValue: 5)
  ├─ wasConfirmed : false
  ├─ localHangup  : false
  ├─ totalDuration: 2.8s
  └─ stateHistory : calling → early → disconnected
```

#### Log Android (phía Người GỌI)

```
🔴 onCallEnded:
  ├─ SDK reason     : temporarilyUnavailable    ← ❌ (phải là doNotDisturb)
  ├─ SDK endedBy    : carrier
  ├─ wasConfirmed   : false
  ├─ localHangup    : false
  ├─ totalDuration  : 1695ms (1s)
  └─ stateHistory   : Disconnected → Calling → Calling → Early
```

---

### Case 5 — Không nghe máy (Timeout)

**Kỳ vọng server**: `timeOut` — SIP `408 Request Timeout`

#### Kết quả test

| Phía | Platform | SDK reason | SDK endedBy | Duration | Đúng? |
|------|----------|-----------|-------------|----------|:-----:|
| **Người GỌI** | **iOS** | **`temporarily_unavailable`** (2014) | `carrier` (5) | **32.8s** | ❌ |
| **Người GỌI** | **Android** | **`temporarilyUnavailable`** | `carrier` | **31s** | ❌ |
| Người NHẬN | Cả 2 | Đổ chuông ~30s rồi ngắt | — | — | — |

#### Lỗi ở đâu: **Carrier / SIP Server**

- Sau ~30-32s ring, mạng viễn thông ngắt kết nối bằng SIP 480 (đây là hành vi phổ biến của carrier, không hoàn toàn là lỗi)
- SDK map 480 → `temporarilyUnavailable` (đúng chuẩn SIP)
- **Đặc điểm nhận biết**: Duration > 25s → chắc chắn là timeout (DND/Block ngắt < 3s, Decline ngắt 3-15s)

#### Log iOS (phía Người GỌI)

```
🔴 callEnded:
  ├─ reason       : temporarily_unavailable (rawValue: 2014)  ← ❌ (phải là timeOut)
  ├─ endedBy      : Call ended by the carrier (rawValue: 5)
  ├─ wasConfirmed : false
  ├─ localHangup  : false
  ├─ totalDuration: 32.8s                                     ← ⭐ > 25s = timeout
  └─ stateHistory : calling → calling → disconnected
```

#### Log Android (phía Người GỌI)

```
🔴 onCallEnded:
  ├─ SDK reason     : temporarilyUnavailable    ← ❌ (phải là timeOut)
  ├─ SDK endedBy    : carrier
  ├─ wasConfirmed   : false
  ├─ totalDuration  : 31996ms (31s)             ← ⭐ > 25s = timeout
  └─ stateHistory   : Calling → Calling → Early
```

---

### Case 6 — Người gọi hủy trước khi bắt máy (Caller Canceled)

**Kỳ vọng server**: `callerCanceled`

#### Kết quả test

| Phía | Platform | SDK reason | SDK endedBy | Duration | Đúng? |
|------|----------|-----------|-------------|----------|:-----:|
| **Người GỌI** | **iOS** | ⚠️ **`normal`** (1000) | `Caller ended the call` (0) | **3.3s** | ❌ |
| **Người GỌI** | **Android** | ❌ **`decline`** | **`callee`** | **1.9s** | ❌ |

#### Lỗi ở đâu: **SDK Android + SDK iOS**

- **iOS**: `endCall()` gọi `pjsua_call_hangup(callId, 0, ...)` → PJSIP coi cúp máy bình thường → trả `normal`. Nhưng cuộc gọi chưa confirmed → nghiệp vụ phải là `callerCanceled`.
- **Android**: Bug hardcode SIP 603 trong `endCall()` (giống Case 1) → trả `decline`/`callee`.
- **Cả 2 SDK** đều thiếu logic: khi caller hangup mà `hasConnected == false` → nên trả `callerCanceled`.

#### Log iOS (phía Người GỌI)

```
🔴 callEnded:
  ├─ reason       : normal (rawValue: 1000)         ← ❌ (phải là callerCanceled)
  ├─ endedBy      : Caller ended the call (0)
  ├─ wasConfirmed : false                            ← ⭐ Chưa bắt máy!
  ├─ localHangup  : true                             ← ⭐ Người gọi chủ động cúp
  ├─ totalDuration: 3.3s
  └─ stateHistory : calling → calling → disconnected
```

#### Log Android (phía Người GỌI)

```
🔴 onCallEnded:
  ├─ SDK reason     : decline                        ← ❌ (phải là callerCanceled)
  ├─ SDK endedBy    : callee                         ← ❌ (phải là caller)
  ├─ wasConfirmed   : false                          ← ⭐ Chưa bắt máy!
  ├─ localHangup    : true                           ← ⭐ Người gọi chủ động cúp
  ├─ totalDuration  : 1948ms
  └─ stateHistory   : Calling → Calling
```

---

### Case 7 — Gọi đến số không tồn tại

**Kỳ vọng server**: `invalidPhoneNumber` / `destinationNotFound` — SIP `404 Not Found`

#### Kết quả test

| Phía | Platform | Số gọi | SDK reason | SDK endedBy | Duration | Đúng? |
|------|----------|--------|-----------|-------------|----------|:-----:|
| **Người GỌI** | **iOS** | `0000000000000` | **`temporarily_unavailable`** (2014) | `carrier` (5) | **2.0s** | ❌ |
| **Người GỌI** | **Android** | `0000000000000` | **`temporarilyUnavailable`** | `carrier` | **380ms** | ❌ |

#### Lỗi ở đâu: **SIP Server**

```
Gọi số không tồn tại → SIP INVITE lên PBX Gateway
    → PBX không định tuyến được
    → Server trả SIP 480 (SAI!) thay vì SIP 404 Not Found  ← ❌ LỖI
    → SDK nhận 480 → temporarilyUnavailable (mapping đúng)
```

SDK đã có sẵn mapping: `SIP 404 → destinationNotFound`. Lỗi do Server gửi 480 thay vì 404.

#### Log Android (phía Người GỌI)

```
🔴 onCallEnded:
  ├─ SDK reason     : temporarilyUnavailable    ← ❌ (phải là destinationNotFound)
  ├─ SDK endedBy    : carrier
  ├─ wasConfirmed   : false
  ├─ localHangup    : false
  ├─ totalDuration  : 380ms                     ← Ngắt tức thì
  └─ stateHistory   : Calling → Calling
```

---

## 🚨 Vấn Đề Cốt Lõi: SIP Server Gom Mã Lỗi

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SIP SERVER GOM MÃ LỖI THÀNH 480                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Case 2: Callee Reject  →  SIP 603  →  Server  →  SIP 480  →  SDK ❌  │
│  Case 3: Callee Block   →  SIP 403  →  Server  →  SIP 480  →  SDK ❌  │
│  Case 4: Callee DND     →  SIP 409  →  Server  →  SIP 480  →  SDK ❌  │
│  Case 7: Số không TT    →  SIP 404  →  Server  →  SIP 480  →  SDK ❌  │
│                                                                         │
│  → SDK mapping hoàn toàn chuẩn SIP — KHÔNG SAI                         │
│  → Server cần forward đúng mã SIP gốc về cho Caller                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Tổng Kết Lỗi Theo Thành Phần

### Lỗi SDK Android (2 case)

| Case | Lỗi | File | Dòng |
|:----:|------|------|:----:|
| 1, 6 | `endCall()` hardcode `PJSIP_SC_DECLINE` (SIP 603) khi cúp máy | `VBotClient.kt` | 315 |
| 1, 6 | `endCallContext()` check `sipOutcome` trước `hasConnected` | `CallListener.kt` | 147 |

### Lỗi SDK iOS (1 case)

| Case | Lỗi | Chi tiết |
|:----:|------|---------|
| 6 | `endCall()` trả `normal` khi caller cúp máy chưa confirmed | Thiếu logic `if (!hasConnected) → callerCanceled` |

### Lỗi SIP Server (4 case)

| Case | Sự kiện | Server gửi hiện tại | Server phải gửi |
|:----:|---------|:-------------------:|:---------------:|
| 2 | Callee từ chối | ❌ `480` | ✅ **`603`** |
| 3 | Callee chặn số | ❌ `480` *(dự kiến)* | ✅ **`403`** |
| 4 | Callee bật DND | ❌ `480` | ✅ **`409`** |
| 7 | Số không tồn tại | ❌ `480` | ✅ **`404`** |
