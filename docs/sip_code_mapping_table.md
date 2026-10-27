# Toàn Bộ Bảng Mã SIP & Hệ Thống Mã Lý Do Kết Thúc Cuộc Gọi (VBot Phone SDK)

> **Tài liệu tham chiếu chuẩn xác & toàn diện nhất**: Dành cho Developers, QA, Kỹ sư Viễn thông VoIP & Đội ngũ Hạ tầng SIP Server / Tổng đài VBot PBX.  
> **Phiên bản tích hợp**: Android SDK `1.1.2+`, iOS SDK `1.1.8+`, Core VoIP PJSIP `2.x`.  
> **Tiêu chuẩn**: RFC 3261 (SIP - Session Initiation Protocol), RFC 3398, RFC 3262, RFC 4488 & Hệ thống mã nghiệp vụ VBot.

---

## Mục Lục
1. [Tổng Quan Kiến Trúc Tín Hiệu Cuộc Gọi](#1-tổng-quan-kiến-trúc-tín-hiệu-cuộc-gọi)
2. [Phần I: Toàn Bộ Mã Trạng Thái SIP Chuẩn (PJSIP / RFC 3261)](#2-phần-i-toàn-bộ-mã-trạng-thái-sip-chuẩn-pjsip--rfc-3261)
   - [Dải 1xx: Thông tin tạm thời (Provisional)](#dải-1xx-thông-tin-tạm-thời-provisional)
   - [Dải 2xx: Thành công (Success)](#dải-2xx-thành-công-success)
   - [Dải 3xx: Chuyển hướng (Redirection)](#dải-3xx-chuyển-hướng-redirection)
   - [Dải 4xx: Lỗi phía Client / Yêu cầu không hợp lệ (Client Failure)](#dải-4xx-lỗi-phía-client--yêu-cầu-không-hợp-lệ-client-failure)
   - [Dải 5xx: Lỗi phía Server / Tổng đài (Server Failure)](#dải-5xx-lỗi-phía-server--tổng-đài-server-failure)
   - [Dải 6xx: Lỗi toàn cục / Từ chối tuyệt đối (Global Failure)](#dải-6xx-lỗi-toàn-cục--từ-chối-tuyệt-đối-global-failure)
3. [Phần II: Toàn Bộ Mã `VBotEndCallReason` Trong SDK (44 Mã Nghiệp Vụ)](#3-phần-ii-toàn-bộ-mã-vbotendcallreason-trong-sdk-44-mã-nghiệp-vụ)
4. [Phần III: Bảng Ma Trận Ánh Xạ: Mã SIP ➔ `VBotEndCallReason` & `endedBy`](#4-phần-iii-bảng-ma-trận-ánh-xạ-mã-sip--vbotendcallreason--endedby)
5. [Phần IV: Bảng Đối Chiếu Hiện Trạng SIP Server vs Chuẩn Cần Sửa](#5-phần-iv-bảng-đối-chiếu-hiện-trạng-sip-server-vs-chuẩn-cần-sửa)

---

## 1. Tổng Quan Kiến Trúc Tín Hiệu Cuộc Gọi

Khi một cuộc gọi qua VBot Phone SDK kết thúc, diễn biến xử lý tín hiệu như sau:

```mermaid
flowchart TD
    PBX["Hạ tầng SIP Server / Softswitch"] -->|Gửi gói tin SIP Response\n(Status Code 1xx - 6xx)| CORE["Tầng Core VoIP Engine\n(PJSIP C/C++ Library)"]
    CORE -->|Đọc SIP Code / BYE| SDK_WRAPPER["VBot SDK Logic Layer\n(Android: CallListener.kt / iOS: VBotCall.m)"]
    SDK_WRAPPER -->|Ánh xạ thành Enum| EVENT["Callback Trả Về Ứng Dụng:\nonCallEnded(reason, endedBy)\ncallEnded(reason, endedBy)"]
```

---

## 2. Phần I: Toàn Bộ Mã Trạng Thái SIP Chuẩn (PJSIP / RFC 3261)

Dưới đây là **toàn bộ các mã trạng thái SIP** được định nghĩa trong Core Engine PJSIP (`pjsip_status_code` trong file header `sip_msg.h`):

### Dải 1xx: Thông tin tạm thời (Provisional)
*Các mã này xảy ra trong quá trình thiết lập cuộc gọi trước khi có quyết định cuối cùng:*

| Mã SIP | Hằng số PJSIP | Ý nghĩa chuẩn RFC |
|:---:|---|---|
| **`100`** | `PJSIP_SC_TRYING` | Đang cố gắng kết nối tới trạm kế tiếp |
| **`180`** | `PJSIP_SC_RINGING` | Thuê bao đích đang đổ chuông (Ringing) |
| **`181`** | `PJSIP_SC_CALL_BEING_FORWARDED` | Cuộc gọi đang được chuyển hướng tiếp |
| **`182`** | `PJSIP_SC_QUEUED` | Cuộc gọi đang ở trong hàng đợi tổng đài |
| **`183`** | `PJSIP_SC_PROGRESS` | Tiến trình phiên đàm thoại (Early Media / Nhạc chờ) |
| **`199`** | `PJSIP_SC_EARLY_DIALOG_TERMINATED` | Thoả thuận phiên sớm đã kết thúc |

---

### Dải 2xx: Thành công (Success)
*Cuộc gọi hoặc yêu cầu đã được chấp nhận và xử lý thành công:*

| Mã SIP | Hằng số PJSIP | Ý nghĩa chuẩn RFC | Tác động trong VBot SDK |
|:---:|---|---|---|
| **`200`** | `PJSIP_SC_OK` | Yêu cầu thành công (Bắt máy / Cúp máy bình thường) | Map sang **`normaly`** (1000) |
| **`202`** | `PJSIP_SC_ACCEPTED` | Yêu cầu đã được chấp thuận xử lý | Xử lý nội bộ |
| **`204`** | `PJSIP_SC_NO_NOTIFICATION` | Thành công không kèm thông báo | Xử lý nội bộ |

---

### Dải 3xx: Chuyển hướng (Redirection)
*Yêu cầu cần thêm bước định tuyến để hoàn tất:*

| Mã SIP | Hằng số PJSIP | Ý nghĩa chuẩn RFC |
|:---:|---|---|
| **`300`** | `PJSIP_SC_MULTIPLE_CHOICES` | Có nhiều địa chỉ đích để lựa chọn |
| **`301`** | `PJSIP_SC_MOVED_PERMANENTLY` | Thuê bao đã đổi địa chỉ vĩnh viễn |
| **`302`** | `PJSIP_SC_MOVED_TEMPORARILY` | Thuê bao tạm thời đổi địa chỉ chuyển tiếp |
| **`305`** | `PJSIP_SC_USE_PROXY` | Bắt buộc phải thông qua Proxy chỉ định |
| **`380`** | `PJSIP_SC_ALTERNATIVE_SERVICE` | Dịch vụ thay thế khả dụng |

---

### Dải 4xx: Lỗi phía Client / Yêu cầu không hợp lệ (Client Failure)
*Lỗi phát sinh do thông tin gọi, thuê bao đích từ chối hoặc mạng không đáp ứng:*

| Mã SIP | Hằng số PJSIP | Ý nghĩa chuẩn RFC 3261 | Ánh xạ sang VBot SDK | Bên dập máy (`endedBy`) |
|:---:|---|---|---|:---:|
| **`400`** | `PJSIP_SC_BAD_REQUEST` | Cú pháp SIP INVITE không hợp lệ | `incorrectInformation` | `server` |
| **`401`** | `PJSIP_SC_UNAUTHORIZED` | Chưa xác thực tài khoản SIP | `unauthenticated` | `server` |
| **`402`** | `PJSIP_SC_PAYMENT_REQUIRED` | Yêu cầu thanh toán cước | `insufficientBalance` | `server` |
| **`403`** | `PJSIP_SC_FORBIDDEN` | Bị cấm truy cập / Bị chặn cuộc gọi | `recipientBlocksCalls` | `callee` |
| **`404`** | `PJSIP_SC_NOT_FOUND` | Không tìm thấy số đích / Số không tồn tại | `destinationNotFound` | `carrier` |
| **`405`** | `PJSIP_SC_METHOD_NOT_ALLOWED` | Phương thức gọi không được phép | `callIntervalNotAllowed` | `server` |
| **`406`** | `PJSIP_SC_NOT_ACCEPTABLE` | Yêu cầu không được chấp nhận | `memberNotActivated` | `server` |
| **`407`** | `PJSIP_SC_PROXY_AUTHENTICATION_REQUIRED` | Cần xác thực qua Proxy | `memberNotInProject` | `server` |
| **`408`** | `PJSIP_SC_REQUEST_TIMEOUT` | Hết thời gian chờ kết nối (Ring Timeout) | `timeOut` | `server` |
| **`409`** | `PJSIP_SC_CONFLICT` | Xung đột trạng thái (Bật Không làm phiền) | `doNotDisturb` | `callee` |
| **`410`** | `PJSIP_SC_GONE` | Số thuê bao đích đã bị huỷ vĩnh viễn | `destinationGone` | `carrier` |
| **`411`** | `PJSIP_SC_LENGTH_REQUIRED` | Thiếu Content-Length | `recipientAbsent` | `callee` |
| **`412`** | `PJSIP_SC_CONDITIONAL_REQUEST_FAILED` | Điều kiện tiên quyết thất bại | `packageExpired` | `server` |
| **`413`** | `PJSIP_SC_REQUEST_ENTITY_TOO_LARGE` | Gói tin SIP quá lớn | `hotlineTelcoNotSupported` | `server` |
| **`414`** | `PJSIP_SC_REQUEST_URI_TOO_LONG` | Địa chỉ SIP URI quá dài | `telcoNotFound` | `carrier` |
| **`415`** | `PJSIP_SC_UNSUPPORTED_MEDIA_TYPE` | Định dạng âm thanh/video không hỗ trợ | `invalidParameter` | `system` |
| **`416`** | `PJSIP_SC_UNSUPPORTED_URI_SCHEME` | Scheme URI không hỗ trợ | `projectExpired` | `server` |
| **`417`** | `PJSIP_SC_UNKNOWN_RESOURCE_PRIORITY` | Người dùng không có trong nhóm này | `userNotInGroup` | `server` |
| **`419`** | `PJSIP_SC_DO_NOT_CALL` | Người nhận chặn cuộc gọi quảng cáo | `doNotCall` | `callee` |
| **`420`** | `PJSIP_SC_BAD_EXTENSION` | Extension SIP không hợp lệ | `unknownError` | `server` |
| **`421`** | `PJSIP_SC_EXTENSION_REQUIRED` | Yêu cầu Extension cụ thể | `unknownError` | `server` |
| **`422`** | `PJSIP_SC_SESSION_TIMER_TOO_SMALL` | Session Timer quá ngắn | `unknownError` | `server` |
| **`423`** | `PJSIP_SC_INTERVAL_TOO_BRIEF` | Thời gian đăng ký quá ngắn | `unknownError` | `server` |
| **`424`** | `PJSIP_SC_BAD_LOCATION_INFORMATION` | Thông tin định vị sai | `unknownError` | `server` |
| **`428`** | `PJSIP_SC_USE_IDENTITY_HEADER` | Yêu cầu Identity Header | `unknownError` | `server` |
| **`429`** | `PJSIP_SC_PROVIDE_REFERRER_HEADER` | Yêu cầu Referrer Header | `unknownError` | `server` |
| **`430`** | `PJSIP_SC_FLOW_FAILED` | Luồng kết nối thất bại | `connectionError` | `server` |
| **`433`** | `PJSIP_SC_ANONIMITY_DISALLOWED` | Không cho phép gọi ẩn danh | `unknownError` | `server` |
| **`436`** | `PJSIP_SC_BAD_IDENTITY_INFO` | Thông tin định danh sai | `unknownError` | `server` |
| **`437`** | `PJSIP_SC_UNSUPPORTED_CERTIFICATE` | Chứng chỉ SSL/TLS không hỗ trợ | `connectionError` | `server` |
| **`438`** | `PJSIP_SC_INVALID_IDENTITY_HEADER` | Header định danh không hợp lệ | `unknownError` | `server` |
| **`439`** | `PJSIP_SC_FIRST_HOP_LACKS_OUTBOUND_SUPPORT` | Trạm đầu tiên không hỗ trợ outbound | `connectionError` | `server` |
| **`440`** | `PJSIP_SC_MAX_BREADTH_EXCEEDED` | Vượt quá giới hạn phân nhánh song song | `unknownError` | `server` |
| **`469`** | `PJSIP_SC_BAD_INFO_PACKAGE` | Gói tin INFO sai | `unknownError` | `server` |
| **`470`** | `PJSIP_SC_CONSENT_NEEDED` | Cần có sự đồng thuận của thuê bao | `unknownError` | `server` |
| **`480`** | `PJSIP_SC_TEMPORARILY_UNAVAILABLE` | Thuê bao tạm thời không liên lạc được | `temporarilyUnavailable` | `carrier` |
| **`481`** | `PJSIP_SC_CALL_TSX_DOES_NOT_EXIST` | Phiên giao dịch cuộc gọi không tồn tại | `connectionError` | `server` |
| **`482`** | `PJSIP_SC_LOOP_DETECTED` | Phát hiện vòng lặp định tuyến cuộc gọi | `connectionError` | `server` |
| **`483`** | `PJSIP_SC_TOO_MANY_HOPS` | Cuộc gọi chuyển tiếp qua quá nhiều trạm | `connectionError` | `server` |
| **`484`** | `PJSIP_SC_ADDRESS_INCOMPLETE` | Số điện thoại / Địa chỉ chưa đủ ký tự | `invalidPhoneNumber` | `carrier` |
| **`485`** | `PJSIP_AC_AMBIGUOUS` | Địa chỉ mơ hồ, nhiều khả năng trùng lặp | `destinationNotFound` | `carrier` |
| **`486`** | `PJSIP_SC_BUSY_HERE` | Máy bận (Thuê bao đang có cuộc gọi khác) | `busy` | `callee` |
| **`487`** | `PJSIP_SC_REQUEST_TERMINATED` | Cuộc gọi bị hủy bởi bên gọi (Cancel) | `callerCanceled` | `caller` |
| **`488`** | `PJSIP_SC_NOT_ACCEPTABLE_HERE` | Codec đàm thoại không tương thích | `invalidParameter` | `system` |
| **`489`** | `PJSIP_SC_BAD_EVENT` | Sự kiện Event không hợp lệ | `unknownError` | `server` |
| **`490`** | `PJSIP_SC_REQUEST_UPDATED` | Yêu cầu đã được cập nhật | `unknownError` | `server` |
| **`491`** | `PJSIP_SC_REQUEST_PENDING` | Có yêu cầu khác đang chờ xử lý | `anotherCallInProgress` | `system` |
| **`493`** | `PJSIP_SC_UNDECIPHERABLE` | Không thể giải mã nội dung S/MIME | `unknownError` | `server` |
| **`494`** | `PJSIP_SC_SECURITY_AGREEMENT_NEEDED` | Cần thiết lập thoả thuận bảo mật | `unauthenticated` | `server` |

---

### Dải 5xx: Lỗi phía Server / Tổng đài (Server Failure)
*Lỗi do máy chủ SIP hoặc hạ tầng nhà mạng gặp sự cố:*

| Mã SIP | Hằng số PJSIP | Ý nghĩa chuẩn RFC | Ánh xạ sang VBot SDK | Bên dập máy (`endedBy`) |
|:---:|---|---|---|:---:|
| **`500`** | `PJSIP_SC_INTERNAL_SERVER_ERROR` | Lỗi nội bộ máy chủ tổng đài PBX | `connectionError` | `server` |
| **`501`** | `PJSIP_SC_NOT_IMPLEMENTED` | Chức năng chưa được máy chủ hỗ trợ | `connectionError` | `server` |
| **`502`** | `PJSIP_SC_BAD_GATEWAY` | Cổng kết nối Gateway viễn thông bị lỗi | `transmissionError` | `carrier` |
| **`503`** | `PJSIP_SC_SERVICE_UNAVAILABLE` | Dịch vụ tổng đài tạm ngừng / Quá tải | `transmissionError` | `server` |
| **`504`** | `PJSIP_SC_SERVER_TIMEOUT` | Máy chủ cổng hết thời gian chờ phản hồi | `timeOut` | `server` |
| **`505`** | `PJSIP_SC_VERSION_NOT_SUPPORTED` | Phiên bản giao thức SIP không hỗ trợ | `connectionError` | `server` |
| **`513`** | `PJSIP_SC_MESSAGE_TOO_LARGE` | Kích thước gói tin UDP vượt giới hạn | `transmissionError` | `carrier` |
| **`555`** | `PJSIP_SC_PUSH_NOTIFICATION_SERVICE_NOT_SUPPORTED` | Dịch vụ Push Notification không hỗ trợ | `noPushToken` | `server` |
| **`580`** | `PJSIP_SC_PRECONDITION_FAILURE` | Thất bại điều kiện tiền đề chất lượng cuộc gọi | `transmissionError` | `server` |

---

### Dải 6xx: Lỗi toàn cục / Từ chối tuyệt đối (Global Failure)
*Thuê bao đích từ chối trên mọi thiết bị và mọi trạm:*

| Mã SIP | Hằng số PJSIP | Ý nghĩa chuẩn RFC | Ánh xạ sang VBot SDK | Bên dập máy (`endedBy`) |
|:---:|---|---|---|:---:|
| **`600`** | `PJSIP_SC_BUSY_EVERYWHERE` | Thuê bao bận trên tất cả các máy nhánh | `busy` | `callee` |
| **`603`** | `PJSIP_SC_DECLINE` | Thuê bao chủ động TỪ CHỐI cuộc gọi | `decline` | `callee` |
| **`604`** | `PJSIP_SC_DOES_NOT_EXIST_ANYWHERE` | Thuê bao hoàn toàn không tồn tại | `destinationNotFound` | `carrier` |
| **`606`** | `PJSIP_SC_NOT_ACCEPTABLE_ANYWHERE` | Không thể chấp nhận phiên cuộc gọi | `invalidParameter` | `callee` |
| **`607`** | `PJSIP_SC_UNWANTED` | Cuộc gọi bị đánh dấu Spam / Không mong muốn | `recipientBlocksCalls` | `callee` |
| **`608`** | `PJSIP_SC_REJECTED` | Cuộc gọi bị từ chối bởi bộ lọc nhà mạng | `recipientBlocksCalls` | `carrier` |

---

## 3. Phần II: Toàn Bộ Mã `VBotEndCallReason` Trong SDK (44 Mã Nghiệp Vụ)

Đây là **toàn bộ 44 giá trị enum** có mặt trong mã nguồn của cả hai nền tảng Android (`com.vpmedia.sdkvbot.en.VBotEndCallReason`) và iOS (`VBotEndCallReason`):

| # | Enum Identifier (`key`) | Mã Android | Mã iOS | Nhóm phân loại | Mô tả nghiệp vụ |
|:---:|---|:---:|:---:|:---:|---|
| 1 | `normaly` | 1000 | 1000 | Hoàn thành | Cuộc gọi đàm thoại kết thúc bình thường |
| 2 | `busy` | 1001 | 1001 | Trạng thái máy | Máy bận (Đang có cuộc gọi khác) |
| 3 | `timeOut` | 1004 | 1004 | Thời gian chờ | Hết thời gian chờ kết nối (Đổ chuông không nghe) |
| 4 | `noPushToken` | 1018 | 1018 | Cấu hình | Chưa đăng ký push notification |
| 5 | `notReadyForStartCall` | 2002 | 2002 | Khởi tạo | Chưa sẵn sàng để gọi đi / Khởi tạo thất bại |
| 6 | `invalidPhoneNumber` | 2004 | 2004 | Dữ liệu gọi | Số điện thoại không hợp lệ (sai định dạng/rỗng) |
| 7 | `noDataFromServer` | 2005 | 2005 | Kết nối API | Không có dữ liệu phản hồi từ máy chủ |
| 8 | `endCallBeforeServerStartCall` | 2006 | 2006 | Vòng đời gọi | Cuộc gọi kết thúc trước khi kết nối tới máy chủ |
| 9 | `noCallCreated` | 2007 | 2007 | Khởi tạo PJSIP | Lỗi khi khởi tạo phiên cuộc gọi |
| 10 | `dataInvalid` | 2008 | 2008 | Dữ liệu API | Dữ liệu cấu hình trả về từ server bị sai |
| 11 | `noVBotUser` | 2009 | 2009 | Tài khoản | Không tìm thấy thông tin tài khoản người dùng |
| 12 | `authenticatedFailed` | 2010 | 2010 | Xác thực | Xác thực tài khoản / Token thất bại |
| 13 | `anotherCallInProgress` | 2011 | 2011 | Trạng thái máy | Đang có cuộc gọi khác đang diễn ra |
| 14 | `decline` | 2013 | 2013 | Phản hồi Callee | Người nhận chủ động từ chối cuộc gọi |
| 15 | `temporarilyUnavailable` | 2014 | 2014 | Mạng viễn thông | Tạm thời không liên lạc được |
| 16 | `reportNewIncomingCallFailed` | 2016 | 2016 | CallKit/Hệ điều hành | Không thể hiển thị giao diện tiếp nhận cuộc gọi đến |
| 17 | `alertDataNotFound` | 2017 | 2017 | Push Payload | Dữ liệu payload thông báo không hợp lệ |
| 18 | `setupEndpointFailed` | 2019 | 2019 | Core VoIP | Khởi tạo dịch vụ SIP Endpoint thất bại |
| 19 | `requestCallKitActionFailed` | 2020 | 2020 | CallKit | Thực thi hành động CallKit thất bại |
| 20 | `noAccount` | 2022 | 2022 | Cấu hình | Tài khoản SIP chưa được cấu hình |
| 21 | `incomingCallTimeout` | 2023 | 2023 | Thời gian chờ | Cuộc gọi đến hết thời gian chờ tiếp nhận (20s) |
| 22 | `destinationNotFound` | 2028 | 2024 | Nhà mạng | Không tìm thấy số đích (SIP 404) |
| 23 | `projectExpired` | 2039 | 2025 | Nghiệp vụ CRM | Dự án VBot đã hết hạn dịch vụ |
| 24 | `callerCanceled` | 2040 | 2026 | Phản hồi Caller | Người gọi chủ động hủy cuộc gọi trước khi bắt máy |
| 25 | `connectionError` | 2041 | 2027 | Máy chủ | Lỗi kết nối tới máy chủ tổng đài |
| 26 | `transmissionError` | 2042 | 2028 | Nhà mạng | Lỗi đường truyền viễn thông |
| 27 | `incorrectInformation` | 2024 | 2029 | Dữ liệu gọi | Thông tin cuộc gọi không chính xác |
| 28 | `unauthenticated` | 2025 | 2030 | Xác thực | Chưa xác thực quyền thực hiện cuộc gọi |
| 29 | `insufficientBalance` | 2026 | 2031 | Nghiệp vụ cước | Số dư tài khoản không đủ để thực hiện cuộc gọi |
| 30 | `recipientBlocksCalls` | 2027 | 2032 | Phản hồi Callee | Người nhận chặn cuộc gọi này |
| 31 | `callIntervalNotAllowed` | 2029 | 2033 | Nghiệp vụ CRM | Không được phép gọi trong khung giờ này |
| 32 | `memberNotActivated` | 2030 | 2034 | Nghiệp vụ CRM | Thành viên chưa được kích hoạt trên hệ thống |
| 33 | `memberNotInProject` | 2031 | 2035 | Nghiệp vụ CRM | Thành viên không thuộc dự án này |
| 34 | `doNotDisturb` | 2032 | 2036 | Phản hồi Callee | Người nhận đang bật chế độ Không làm phiền |
| 35 | `destinationGone` | 2033 | 2037 | Nhà mạng | Số đích không còn tồn tại trên mạng |
| 36 | `recipientAbsent` | 2034 | 2038 | Trạng thái Callee | Người nhận vắng mặt |
| 37 | `packageExpired` | 2035 | 2039 | Nghiệp vụ cước | Gói cước dịch vụ đã hết hạn |
| 38 | `hotlineTelcoNotSupported` | 2036 | 2040 | Hạ tầng viễn thông | Hotline không hỗ trợ gọi tới nhà mạng này |
| 39 | `telcoNotFound` | 2037 | 2041 | Hạ tầng viễn thông | Không tìm thấy thông tin nhà mạng của số đích |
| 40 | `invalidParameter` | 2038 | 2042 | Dữ liệu gọi | Tham số cuộc gọi không hợp lệ |
| 41 | `userNotInGroup` | - | 2043 | Nghiệp vụ CRM | Người dùng không có trong nhóm này |
| 42 | `doNotCall` | - | 2044 | Chặn quảng cáo | Người nhận chặn cuộc gọi quảng cáo |
| 43 | `unknownError` | 9996 | 9996 | Ngoại lệ | Lỗi không xác định |
| 44 | `microphonePermissionDenied` | 9999 | 9999 | Quyền thiết bị | Người dùng từ chối cấp quyền Microphone |

---

## 4. Phần III: Bảng Ma Trận Ánh Xạ: Mã SIP ➔ `VBotEndCallReason` & `endedBy`

Bảng định tuyến cốt lõi được cấu hình trong Core SDK để chuyển hóa mã SIP mạng thành trạng thái cuộc gọi hiển thị:

| Dải Mã SIP | Mã SIP cụ thể | Ánh xạ sang `VBotEndCallReason` | Quy về Bên kết thúc (`endedBy`) |
|---|:---:|---|:---:|
| **Thành công** | `200` | `normaly` | `caller` (nếu bên gọi cúp) / `callee` (nếu bên nhận cúp) |
| **Từ chối / Bận** | `603` | `decline` | `callee` |
| | `486`, `600` | `busy` | `callee` |
| **Không làm phiền**| `409` | `doNotDisturb` | `callee` |
| **Chặn cuộc gọi** | `403`, `607`, `608` | `recipientBlocksCalls` | `callee` |
| | `419` | `doNotCall` | `callee` |
| **Người gọi hủy** | `487` | `callerCanceled` | `caller` |
| **Hết giờ chờ** | `408`, `504` | `timeOut` | `server` |
| **Số không tồn tại**| `404`, `485`, `604` | `destinationNotFound` | `carrier` |
| **Số đã huỷ** | `410` | `destinationGone` | `carrier` |
| **Không liên lạc** | `480` | `temporarilyUnavailable` | `carrier` |
| **Sai số điện thoại**| `484` | `invalidPhoneNumber` | `carrier` |
| **Cước / Gói** | `402` | `insufficientBalance` | `server` |
| | `412` | `packageExpired` | `server` |
| | `416` | `projectExpired` | `server` |
| **Xác thực** | `401`, `494` | `unauthenticated` | `server` |
| **Phân quyền CRM** | `405` | `callIntervalNotAllowed` | `server` |
| | `406` | `memberNotActivated` | `server` |
| | `407` | `memberNotInProject` | `server` |
| | `417` | `userNotInGroup` | `server` |
| **Nhà mạng** | `413` | `hotlineTelcoNotSupported` | `server` |
| | `414` | `telcoNotFound` | `carrier` |
| **Lỗi máy chủ** | `500`, `501`, `505` | `connectionError` | `server` |
| **Lỗi đường truyền**| `502`, `503`, `513` | `transmissionError` | `carrier` |
| **Tham số sai** | `400` | `incorrectInformation` | `server` |
| | `415`, `488` | `invalidParameter` | `system` |

---

## 5. Phần IV: Bảng Đối Chiếu Hiện Trạng SIP Server vs Chuẩn Cần Sửa

Dùng bảng này làm căn cứ kỹ thuật để làm việc với đội ngũ quản trị SIP Softswitch:

| Trường hợp thực tế | Mã SIP Server gửi HIỆN TẠI (SAI) ❌ | Kết quả hiển thị hiện tại (SAI) ❌ | Mã SIP Server PHẢI GỬI (ĐÚNG) ✅ | Kết quả SDK sẽ tự động hiển thị (ĐÚNG) ✅ |
|---|:---:|---|:---:|---|
| **Người nhận bấm BẬN / TỪ CHỐI** | ❌ **`480`** | `temporarilyUnavailable` *(Tạm thời không liên lạc được)* | ✅ **`603 Decline`** | `decline` / `callee`<br>*(Từ chối cuộc gọi)* |
| **Người nhận BẬT KHÔNG LÀM PHIỀN (DND)** | ❌ **`480`** | `temporarilyUnavailable` *(Tạm thời không liên lạc được)* | ✅ **`409 Conflict`** | `doNotDisturb` / `callee`<br>*(Người nhận không làm phiền)* |
| **Người nhận CHẶN CUỘC GỌI NÀY** | ❌ **`480`** | `temporarilyUnavailable` *(Tạm thời không liên lạc được)* | ✅ **`403 Forbidden`** | `recipientBlocksCalls` / `callee`<br>*(Người nhận chặn cuộc gọi)* |
| **GỌI ĐẾN SỐ KHÔNG TỒN TẠI / SAI ĐỊNH DẠNG**| ❌ **`480`** | `temporarilyUnavailable` *(Tạm thời không liên lạc được)* | ✅ **`404 Not Found`** | `destinationNotFound` / `carrier`<br>*(Không tìm thấy số đích)* |
| **ĐỔ CHUÔNG HẾT GIỜ (>25s) KHÔNG AI NGHE** | ⚠️ **`480`** | `temporarilyUnavailable` *(Tạm thời không liên lạc được)* | ✅ **`408 Request Timeout`** | `timeOut` / `server`<br>*(Hết thời gian chờ kết nối)* |

> [!TIP]
> **Kết luận then chốt:**
> Toàn bộ 44 mã `VBotEndCallReason` và hơn 70 mã SIP RFC 3261 đã được cài đặt đầy đủ trong SDK. Việc ứng dụng bị nhận sai là do **SIP Server đang thực hiện quy tắc gom tất cả các mã 603, 409, 403, 404 thành mã duy nhất 480**. Chỉ cần phía Server trả đúng mã SIP như bảng trên thì toàn bộ hệ thống sẽ tự động đồng bộ và hoạt động chính xác 100%.
