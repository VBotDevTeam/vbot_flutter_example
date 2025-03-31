import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vbot_flutter_demo/call_state_manager.dart';
import 'package:vbot_flutter_demo/client.dart';
import 'package:vbot_flutter_demo/sink.dart';

class CallPage extends StatefulWidget {
  const CallPage({super.key});

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  @override
  void initState() {
    super.initState();

    CallStateManager().callStateStream.listen(
      (vbotSink) {
        if (vbotSink.state == 'disconnected') {
          if (mounted) {
            Navigator.pop(context);
          }
        }
      },
      onError: (error) => print("Error in callStateStream: $error"),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Call")),
        body: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              CallStateWidget(),
            ],
          ),
        ));
  }
}

class CallStateWidget extends StatefulWidget {
  const CallStateWidget({super.key});

  @override
  _CallStateWidgetState createState() => _CallStateWidgetState();
}

class _CallStateWidgetState extends State<CallStateWidget> {
  Timer? _timer;
  DateTime? _startTime;
  final ValueNotifier<String> _callDuration = ValueNotifier("00:00:00");

  void muteMic() async {
    final _ = await client.mute();
  }

  void onoffSpeaker() async {
    final _ = await client.speaker();
  }

  void hangupCall() async {
    final _ = await client.hangup();
  }

  void _startCallDuration() {
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentTime = DateTime.now();
      final difference = currentTime.difference(_startTime!);
      final hours = difference.inHours.toString().padLeft(2, '0');
      final minutes = (difference.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (difference.inSeconds % 60).toString().padLeft(2, '0');
      _callDuration.value = "$hours:$minutes:$seconds";
    });
  }

  void _stopCallDuration() {
    _timer?.cancel();
    _callDuration.value = "00:00:00";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VBotSink>(
      stream: CallStateManager().callStateStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container();
        }

        if (snapshot.hasError) {
          return Text('Có lỗi xảy ra: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Text('Chưa có trạng thái cuộc gọi.');
        }

        final VBotSink? callState = snapshot.data;

        if (callState!.state == 'confirmed' && _startTime == null) {
          _startCallDuration();
        } else if (callState.state == 'disconnected') {
          _stopCallDuration();
          _startTime = null;
        }

        return Center(
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Text(
                      'Name: ${callState.name}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      'State: ${callState.state}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      'Incoming: ${callState.isIncoming}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      'Mute: ${callState.isMute}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      'On Hold: ${callState.onHold}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16.0),
                    ValueListenableBuilder<String>(
                      valueListenable: _callDuration,
                      builder: (context, value, child) {
                        return Text(
                          'Call Duration: $value',
                          style: Theme.of(context).textTheme.bodyLarge,
                        );
                      },
                    ),
                    const SizedBox(height: 16.0),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: [
                        if (callState.state == 'confirmed') ...[
                          FilledButton(
                            onPressed: muteMic,
                            child: Text(
                              callState.isMute ? "Unmute" : "Mute",
                            ),
                          ),
                          FilledButton(
                            onPressed: onoffSpeaker,
                            child: const Text("Speaker"),
                          ),
                        ],
                        if (callState.state == 'confirmed' ||
                            callState.state == 'calling')
                          FilledButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all<Color>(
                                  Theme.of(context).colorScheme.error),
                            ),
                            onPressed: hangupCall,
                            child: const Text("Hangup"),
                          ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _callDuration
        .dispose(); // Hủy lắng nghe của ValueNotifier khi widget bị dispose
    super.dispose();
  }
}
