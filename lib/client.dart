import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vbot_flutter_demo/home_page.dart';

final client = VBotPhone();

class VBotPhone {
  final String _methodIsUserConnected = "isUserConnected";
  final String _methodUserDisplayName = "userDisplayName";
  final String _methodConnect = "connect";
  final String _methodDisconnect = "disconnect";
  final String _methodStartCall = "startCall";
  final String _methodGetHotlines = "getHotlines";
  final String _methodHangup = "hangup";
  final String _methodMute = "mute";
  final String _methodSpeaker = "speaker";

  final MethodChannel _channel =
      const MethodChannel('com.vpmedia.vbot-sdk/vbot_phone');

  Future<bool> isUserConnected() async {
    try {
      final result = await _channel.invokeMethod(_methodIsUserConnected);
      final res = result as Map;
      return res["isUserConnected"];
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
        ),
      );
      return false;
    }
  }

  Future<String> userDisplayName() async {
    try {
      final result = await _channel.invokeMethod(_methodUserDisplayName);
      final res = result as Map;
      return res["userDisplayName"];
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
        ),
      );
      return "";
    }
  }

  Future<String?> connect(String token) async {
    try {
      final result =
          await _channel.invokeMethod(_methodConnect, <String, dynamic>{
        'token': token,
      });
      final res = result as Map;
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

  Future<bool> disconnect() async {
    try {
      final result = await _channel.invokeMethod(_methodDisconnect);
      final res = result as Map;
      return res["disconnect"];
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
        ),
      );
      return false;
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

  Future<void> speaker() async {
    try {
      final _ = await _channel.invokeMapMethod(_methodSpeaker);
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
