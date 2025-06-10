import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vbot_flutter_demo/vbot_phone_manager.dart';
import 'package:vbot_flutter_demo/sink.dart';

class CallPage extends StatefulWidget {
  const CallPage({super.key});

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  final vbotManager = VBotPhoneManager();
  late final StreamSubscription<VBotSink> _sub;

  @override
  void initState() {
    super.initState();

    _sub = vbotManager.callStateStream.listen(
      (vbotSink) {
        if (mounted) {
          setState(() {});
          if (vbotSink.state == 'disconnected') {
            Navigator.pop(context);
          }
        }
      },
      onError: (error) => print("Error in callStateStream: $error"),
    );
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Call")),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CallStateWidget(
                sink: vbotManager.currentSink,
              ),
            ],
          ),
        ));
  }
}

class CallStateWidget extends StatefulWidget {
  const CallStateWidget({super.key, this.sink});
  final VBotSink? sink;

  @override
  _CallStateWidgetState createState() => _CallStateWidgetState();
}

class _CallStateWidgetState extends State<CallStateWidget> {
  final vbotManager = VBotPhoneManager();
  Timer? _timer;
  DateTime? _startTime;
  final ValueNotifier<String> _callDuration = ValueNotifier("00:00:00");

  void muteMic() async {
    final _ = await vbotManager.mute();
  }

  void toggleSpeaker() async {
    final _ = await vbotManager.speaker();
  }

  void hangupCall() async {
    final _ = await vbotManager.hangup();
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
  void initState() {
    // TODO: implement initState
    super.initState();
    setupTimer(vbotManager.currentSink);
  }

  @override
  void didUpdateWidget(covariant CallStateWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    setupTimer(vbotManager.currentSink);
  }

  void setupTimer(VBotSink? callData) {
    final state = callData?.state;

    if (state == 'confirmed' && _startTime == null) {
      _startCallDuration();
    }

    if (state == 'disconnected') {
      _stopCallDuration();
      _startTime = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sink = widget.sink;

    if (sink == null) {
      return const Text('Chưa có trạng thái cuộc gọi.');
    }

    return Center(
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Text(
                  'Name: ${sink.name}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  'State: ${sink.state}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  'Incoming: ${sink.isIncoming}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  'Mute: ${sink.isMute}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  'On Hold: ${sink.onHold}',
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
                    if (sink.state == 'confirmed') ...[
                      FilledButton(
                        onPressed: muteMic,
                        child: Text(
                          sink.isMute ? "Unmute" : "Mute",
                        ),
                      ),
                      FilledButton(
                        onPressed: toggleSpeaker,
                        child: const Text("Speaker"),
                      ),
                    ],
                    if (sink.state == 'confirmed' || sink.state == 'calling')
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
  }

  @override
  void dispose() {
    _timer?.cancel();
    _callDuration.dispose();
    super.dispose();
  }
}
