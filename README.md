# VBot Flutter SDK

# 1. Hướng dẫn thêm SDK vào Flutter Project

## iOS

---

> VBot SDK chỉ chạy trên thiết bị thật, không dùng trên iOS Simulator

Mở **podfile** trong thư mục iOS và thực hiện các thay đổi sau:

- Thay thế “**use_frameworks!**” bằng “**use_frameworks! :linkage => :static**”

```swift
**use_frameworks! :linkage => :static**
```

- Thêm pod của VBot SDK:

```swift
pod 'VBotPhoneSDK', :git => 'https://github.com/VBotDevTeam/VBotPhoneSDK.git'
```

- Thêm build settings config:

```swift
config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.5'
config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
```

Podfile sau đấy sẽ giống như sau:

```swift
# Uncomment this line to define a global platform for your project
# platform :ios, '12.0'
source 'https://github.com/CocoaPods/Specs.git'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
- **~~use_frameworks!~~**
+ use_frameworks! :linkage => :static
  use_modular_headers!

+	pod 'VBotPhoneSDK', :git => 'https://github.com/VBotDevTeam/VBotPhoneSDK.git'

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
  installer.generated_projects.each do |project|
    project.targets.each do |target|
        target.build_configurations.each do |config|
+           config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.5'
+           config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
+ 			    config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
         end
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
