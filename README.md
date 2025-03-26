# VBot Flutter SDK

# 1. Hướng dẫn thêm SDK vào Flutter Project

## iOS

---

> VBot SDK chỉ chạy trên thiết bị thật, không dùng trên iOS Simulator

Mở **podfile** trong thư mục iOS và thực hiện các thay đổi sau:

- Thêm pod của VBot SDK:

```swift
pod 'VBotPhoneSDKiOS-Public', '1.0.1'
```

- Thêm build settings config:

```swift
post_install do |installer|
  installer.pods_project.targets.each do |target|
   target.build_configurations.each do |config|
     # Bắt buộc
     config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
    end
  end
end
```

Podfile sau đấy sẽ giống như sau:

```swift
platform :ios, '13.5'

target 'Runner' do
  use_frameworks! :linkage => :static

  pod 'VBotPhoneSDKiOS-Public', '1.0.1'

  target 'RunnerTests' do
    inherit! :search_paths
    # Pods for testing
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
   target.build_configurations.each do |config|
     # Bắt buộc
     config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
    end
  end
end
```

Cuối cùng chạy **pod install**

## Android

---

Thêm JitPack vào project Android

```kotlin
allprojects {
    repositories {
        mavenCentral()
+       maven { url 'https://jitpack.io' }
    }
}
```

Mở app/build.gradle thêm VBot SDK

```kotlin
dependencies {
+		implementation 'com.github.VBotDevTeam:VBot_SDK_Android:1.0.1'
}
```

# 2. Hướng dẫn sử dụng SDK

Tham khảo code demo
