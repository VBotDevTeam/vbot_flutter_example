import 'package:flutter/services.dart';
import 'dart:io';

class VBotPhone {
  final String _methodConnect = "connect";
  final String _methodStartCall = "startcall";

  final MethodChannel _channel =
      const MethodChannel('com.vpmedia.vbot-sdk-example-dev/vbot_phone');

  Future<String> connect(String token) async {
    if (!Platform.isIOS) {
      print("connect function can only be run on iOS platform");
      return "";
    }
    try {
      final result =
          await _channel.invokeMethod(_methodConnect, <String, dynamic>{
        'token': token,
      });
      final res = result as Map;
      return res["displayName"];
    } catch (e) {
      print("connect exception: $e");
      rethrow;
    }
  }

  Future<String> startCall(
    String hotline,
    String phoneNumber,
  ) async {
    if (!Platform.isIOS) {
      print("connect function can only be run on iOS platform");
      return "";
    }
    try {
      final result =
          await _channel.invokeMethod(_methodStartCall, <String, dynamic>{
        'phoneNumber': phoneNumber,
        'hotline': hotline,
      });
      final res = result as Map;
      return res["phoneNumber"];
    } catch (e) {
      print("startCall exception: $e");
      rethrow;
    }
  }
}
