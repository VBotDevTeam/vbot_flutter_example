# Tài Liệu Yêu Cầu Kỹ Thuật: Chuẩn Hóa Phản Hồi SIP Server Cho VBot VoIP Gateway

> **Đối tượng áp dụng**: Đội ngũ phát triển SIP Server / PBX Core Gateway (FreeSWITCH / Asterisk / Kamailio / OpenSIPS).  
> **Mục tiêu**: Loại bỏ hiện tượng SIP Masquerading (tất cả lỗi đều biến thành SIP 480), trả đúng mã SIP chuẩn RFC 3261 hoặc đính kèm RFC 3326 Reason Header để Client SDK nhận diện chính xác lý do kết thúc cuộc gọi.

---

## 1. Vấn Đề Hiện Tại (Current Problem)

Hiện tại, khi thực hiện cuộc gọi đi (outbound call) từ ứng dụng VBot, SIP Server / PBX Gateway đang chuyển đổi (masquerade) hầu hết mọi tình huống ngắt cuộc gọi về mã:
```text
SIP/2.0 480 Temporarily Unavailable
```

Cụ thể:
1. **Người nhận từ chối cuộc gọi (Decline)**: PBX Gateway nhận được mã từ chối từ nhà mạng hoặc thiết bị nhận (thường là SIP 603 / SIP 486), nhưng chuyển tiếp về phía Client cuộc gọi bằng mã **`480`**.
2. **Hết thời gian chờ (Timeout - Ringing > 30s/40s không nghe máy)**: Timer kết thúc, nhưng thay vì trả về **`408 Request Timeout`**, PBX Gateway gửi về mã **`480`**.
3. **Chế độ không làm phiền (Do Not Disturb - DND)**: PBX Gateway gửi về mã **`480`** thay vì **`409 Conflict`** hoặc **`486 Busy Here`**.
4. **Số điện thoại không tồn tại**: Một số nhà mạng trả 404 nhưng PBX forward về Client là **`480`**.

### Hệ quả:
Client SDK (iOS / Android) nhận được mã `480` nên chỉ có thể hiển thị `temporarilyUnavailable` ("Không liên lạc được") cho mọi trường hợp. Ứng dụng không thể phân biệt được khách hàng từ chối, máy bận hay không nghe máy, làm sai lệch báo cáo thống kê cuộc gọi (Call Analytics).

---

## 2. Yêu Cầu Chuẩn Hóa Theo Chuẩn RFC 3261

PBX Gateway cần chuyển tiếp hoặc phản hồi chính xác mã SIP theo tiêu chuẩn RFC 3261 sau:

| Tình huống thực tế | Mã SIP Yêu Cầu | Tên SIP | Hành vi kỳ vọng của PBX |
|-------------------|:--------------:|---------|-------------------------|
| **Người nhận bấm từ chối** | **`603`** | `Decline` | Khi nhận mã từ chối từ Callee hoặc telco ISDN cause 21, chuyển tiếp nguyên vẹn mã `603` về Caller. |
| **Không nghe máy (Timeout)** | **`408`** | `Request Timeout` | Khi hết Timer B hoặc Timer C (30s - 45s), PBX gửi bản tin `408 Request Timeout` về Caller thay vì `480`. |
| **Máy bận (Busy)** | **`486`** | `Busy Here` | Khi máy Callee đang có cuộc gọi hoặc bấm bận (ISDN cause 17), gửi `486 Busy Here`. |
| **Không làm phiền (DND)** | **`409`** hoặc **`486`** | `Conflict` / `Busy Here` | Thiết bị bật DND cần trả về mã tương ứng. |
| **Số không tồn tại / Thuê bao khóa** | **`404`** | `Not Found` | Thuê bao không tồn tại trên hệ thống hoặc mạng viễn thông báo Unallocated Number (cause 1). |
| **Số dư tài khoản không đủ** | **`402`** | `Payment Required` | Kiểm tra balance trước khi gọi ra, nếu hết hạn mức trả về `402`. |
| **Cuộc gọi ngoài khung giờ** | **`405`** | `Method Not Allowed` | Hệ thống chặn gọi ngoài giờ hành chính. |

---

## 3. Khuyến Nghị Áp Dụng RFC 3326 (Reason Header)

Trong môi trường kết nối viễn thông (PSTN / E1 / SIP Trunking), một số nhà mạng trung gian bắt buộc trả về mã `480` hoặc `503`. Để giải quyết triệt để vấn đề này, PBX Gateway **phải đính kèm Header `Reason` theo chuẩn RFC 3326** vào bản tin SIP gửi về Client:

### Cú pháp mẫu:
```text
SIP/2.0 480 Temporarily Unavailable
Via: SIP/2.0/UDP 192.168.1.100:5060;branch=z9hG4bK...
From: <sip:caller@vbot.vn>;tag=12345
To: <sip:callee@vbot.vn>;tag=67890
Call-ID: c123456789@vbot.vn
CSeq: 102 INVITE
Reason: Q.850;cause=19;text="No answer from user"
Content-Length: 0
```

### Bảng mapping mã nguyên nhân Q.850 khuyến nghị:
- **`Q.850;cause=16`**: Normal call clearing (Cúp máy bình thường)
- **`Q.850;cause=17`**: User busy (Máy bận) ➔ Client ánh xạ sang `busy`
- **`Q.850;cause=18`**: No user responding (Không có phản hồi) ➔ Client ánh xạ sang `timeOut`
- **`Q.850;cause=19`**: No answer from user (Chuông reo không ai nhấc máy) ➔ Client ánh xạ sang `timeOut`
- **`Q.850;cause=21`**: Call rejected (Từ chối cuộc gọi) ➔ Client ánh xạ sang `decline`
- **`Q.850;cause=1`**: Unallocated (unassigned) number ➔ Client ánh xạ sang `destinationNotFound`

---

## 4. Kế Hoạch Triển Khai Kiểm Thử

1. **Bước 1**: Đội ngũ PBX cấu hình chuyển tiếp đúng mã `603` và `408` trên môi trường Staging/Dev.
2. **Bước 2**: Thực hiện cuộc gọi mẫu đến số test không nhấc máy (>35s) và số test bấm từ chối.
3. **Bước 3**: Bắt gói tin Wireshark / SIP Trace tại Gateway và xác nhận Client SDK nhận đúng mã final response.
