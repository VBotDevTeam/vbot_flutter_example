# Hướng dẫn tích hợp VBot iOS và VBot Android SDK vào app Flutter

# Thêm SDK vào project

Để tích hợp VBot vào app Flutter thì đầu tiên phải thực hiện thêm VBot SDK của từng platform theo tài liệu của mỗi loại

## Với iOS

Mở **ios/Runner.xcworkspace** bằng **xCode**

Tham khảo mục “**Cấu hình Push Notification**” và “**Cài đặt SDK**” để thêm VBot iOS SDK

## Với Android

Mở thư mục **android** bằng **Android Studio**

tham khảo mục “**Thêm VBot SDK vào Project**” và “**Thêm firebase vào Project**” để thêm VBot Android SDK

---

# Sử dụng VBot SDK

Để chạy được VBot SDK trong dự án Flutter chúng ta cần sử dụng **Platform Channel**

Dùng **FlutterMethodChannel** để gọi hàm và dùng **FlutterEventChannel**

## Tham khảo code demo tại [https://github.com/VBotDevTeam/vbot_flutter_example](https://github.com/VBotDevTeam/vbot_flutter_example)
