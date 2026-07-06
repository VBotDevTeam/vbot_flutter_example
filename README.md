# VBot Flutter SDK Demo

Dự án ví dụ tích hợp VBot Phone SDK cho cả iOS và Android trên nền tảng Flutter.

## 1. Cài đặt SDK vào Flutter Project

### iOS

> **Lưu ý:** VBot SDK cho iOS chỉ hoạt động trên thiết bị thật, không dùng trên iOS Simulator.

Mở tệp `Podfile` trong thư mục `ios` và thực hiện các thay đổi sau:

1. Thêm Pod của VBot SDK:
```ruby
pod 'VBotPhoneSDKiOS-Public', '1.1.7'
```

2. Thêm cấu hình build settings bắt buộc trong khối `post_install`:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
     target.build_configurations.each do |config|
      # Bắt buộc
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
    end
  end
end
```

Tệp `Podfile` mẫu hoàn chỉnh sẽ tương tự như sau:
```ruby
platform :ios, '13.5'
source "https://github.com/CocoaPods/Specs.git"

target 'Runner' do
  use_frameworks! :linkage => :static

  pod 'VBotPhoneSDKiOS-Public', '1.1.7'

  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
     target.build_configurations.each do |config|
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
    end
  end
end
```

Sau khi thay đổi Podfile, bạn chạy lệnh sau tại thư mục `ios`:
```bash
pod install
```

---

### Android

1. Thêm JitPack repository vào tệp `settings.gradle` (hoặc `build.gradle` ở thư mục gốc của dự án):
```groovy
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven { url 'https://jitpack.io' }
    }
}
```

2. Thêm SDK và các thư viện phụ thuộc bắt buộc vào tệp `android/app/build.gradle`:
```groovy
dependencies {
    // Các thư viện phụ thuộc bắt buộc để SDK hoạt động ổn định
    implementation 'io.reactivex.rxjava2:rxjava:2.2.21'
    implementation 'com.google.code.gson:gson:2.11.0'
    implementation 'com.squareup.retrofit2:retrofit:2.11.0'
    implementation 'com.squareup.retrofit2:converter-gson:2.11.0'
    implementation 'com.squareup.retrofit2:adapter-rxjava2:2.11.0'
    implementation 'org.reactivestreams:reactive-streams:1.0.4'
    implementation 'com.squareup.okhttp3:okhttp:5.0.0-alpha.14'
    implementation 'com.jakewharton.timber:timber:5.0.1'
    implementation 'com.squareup.okhttp3:okhttp-dnsoverhttps:4.9.0'

    // VBot Phone SDK Android Public
    implementation 'com.github.VBotDevTeam:VBotPhoneSDKAndroid-Public:1.0.12'
}
```

---

## 2. Hướng dẫn sử dụng

Dự án mẫu này sử dụng các kênh Flutter MethodChannel và EventChannel để giao tiếp trực tiếp với native SDK (Kotlin trên Android, Swift trên iOS).

Vui lòng tham khảo mã nguồn chi tiết tại:
- **Flutter Manager:** [lib/vbot_phone_manager.dart](lib/vbot_phone_manager.dart)
- **Native Android Runner:** [android/app/src/main/kotlin/com/vpmedia/vbotsdksample/MainActivity.kt](android/app/src/main/kotlin/com/vpmedia/vbotsdksample/MainActivity.kt)
- **Native iOS Runner:** [ios/Runner/AppDelegate.swift](ios/Runner/AppDelegate.swift)
