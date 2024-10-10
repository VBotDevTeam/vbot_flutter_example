import 'dart:async';
import 'package:flutter/services.dart';
import 'package:vbot_flutter_demo/sink.dart';

class CallStateManager {
  static final CallStateManager _instance = CallStateManager._internal();

  factory CallStateManager() => _instance;

  CallStateManager._internal();

  final _callStateController = StreamController<VBotSink>.broadcast();

  Stream<VBotSink> get callStateStream => _callStateController.stream;

  Future<void> initCallStateStream() async {
    print("Initializing call state stream");

    const EventChannel callStateChannel =
        EventChannel('com.vpmedia.vbot-sdk/call');
    callStateChannel.receiveBroadcastStream().listen(
      (event) {
        try {
          final Map<String, dynamic> eventMap =
              Map<String, dynamic>.from(event as Map);
          final VBotSink sink = VBotSink.fromMap(eventMap);
          _callStateController.add(sink); // Thêm sự kiện vào stream
          print("Parsed VBotSink: $sink");
        } catch (e, stackTrace) {
          print("Error parsing event: $e");
          print("Stack trace: $stackTrace");
        }
      },
      onError: (error) => print("Error in native stream: $error"),
      onDone: () => print("Native stream closed"),
    );

    print("Call state stream initialized");
  }

  void dispose() => _callStateController.close();
}
