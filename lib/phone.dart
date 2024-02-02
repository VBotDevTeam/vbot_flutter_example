import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vbot_flutter_demo/main.dart';

class VBotPhone {
  final String _methodConnect = "connect";
  final String _methodStartCall = "startCall";
  final String _methodGetHotlines = "getHotlines";
  final String _methodHangup = "hangup";
  final String _methodMute = "mute";

  final MethodChannel _channel =
      const MethodChannel('com.vpmedia.vbot-sdk/vbot_phone');

  Future<String?> connect(String token) async {
    try {
      final result =
          await _channel.invokeMethod(_methodConnect, <String, dynamic>{
        'token': token,
      });
      final res = result as Map;
      print(res);
      return res["displayName"];
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
        ),
      );
      return null;
    }
  }

  Future<String?> startCall(String hotline, String phoneNumber) async {
    try {
      final result =
          await _channel.invokeMethod(_methodStartCall, <String, dynamic>{
        'phoneNumber': phoneNumber,
        'hotline': hotline,
      });
      final res = result as Map;
      return res["phoneNumber"];
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
        ),
      );
      return null;
    }
  }

  Future<List<VBotHotline>?> getHotlines() async {
    try {
      final result = await _channel.invokeMethod(_methodGetHotlines);
      final res = result as List;
      final hotlines = res
          .map((e) => VBotHotline.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      return hotlines;
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
        ),
      );
      return null;
    }
  }

  Future<void> hangup() async {
    try {
      final _ = await _channel.invokeMethod(_methodHangup);
      return;
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
        ),
      );
      return;
    }
  }

  Future<void> mute() async {
    try {
      final _ = await _channel.invokeMethod(_methodMute);
      return;
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
        ),
      );
      return;
    }
  }
}

class VBotHotline {
  final String name;
  final String phoneNumber;

  VBotHotline({required this.name, required this.phoneNumber});

  factory VBotHotline.fromMap(Map<String, dynamic> map) {
    return VBotHotline(
      name: map['name'],
      phoneNumber: map['phoneNumber'],
    );
  }
}

class VBotSink {
  final String name;
  final String state;
  final String duration;
  final bool isMute;
  final bool onHold;

  VBotSink({
    required this.name,
    required this.state,
    required this.duration,
    required this.isMute,
    required this.onHold,
  });

  factory VBotSink.fromMap(Map<String, dynamic> map) {
    return VBotSink(
      name: map['name'],
      state: map['state'],
      duration: map['duration'],
      isMute: map['isMute'],
      onHold: map['onHold'],
    );
  }
}
