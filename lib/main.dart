import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vbot_flutter_demo/phone.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'VBot Phone Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final tokenController = TextEditingController();

  final hotlineController = TextEditingController();
  final phoneController = TextEditingController();

  String displayName = "";
  final phone = VBotPhone();

  bool isLoading = false;
  bool isCalling = false;
  bool isConnected = false;

  String callState = "";
  String callee = "";

  static const EventChannel _eventChannel =
      EventChannel('com.vpmedia.vbot-sdk-example-dev/call_state');

  @override
  void initState() {
    super.initState();
    _eventChannel.receiveBroadcastStream().listen(_onEvent, onError: _onError);
  }

  void _onEvent(Object? event) {
    setState(() {
      callState = "$event";
    });
  }

  void _onError(Object error) {
    setState(() {
      callState = 'unknown';
    });
  }

  void _connect() async {
    setState(() {
      isLoading = true; // Show loading indicator
    });

    if (tokenController.text.isEmpty) {
      setState(() {
        isLoading = false; // Hide loading indicator
      });
      return;
    }

    try {
      final result = await VBotPhone().connect(tokenController.text);
      displayName = result;
      isConnected = true;
    } catch (e) {
      displayName = e.toString();
      isConnected = false;
    } finally {
      setState(() {
        isLoading = false; // Hide loading indicator
      });
    }
  }

  void _call() async {
    setState(() {
      isCalling = true; // Show loading indicator
    });

    try {
      final calleeName =
          await phone.startCall(hotlineController.text, phoneController.text);
      callee = calleeName;
    } catch (e) {
      print("call exception: $e");
    } finally {
      setState(() {
        isCalling = false; // Hide loading indicator
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: <Widget>[
            Row(
              children: [
                const Text(
                  'Display name: ',
                ),
                Text(displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Token',
              ),
            ),
            const SizedBox(height: 12),
            if (isLoading) ...[
              const CircularProgressIndicator()
            ] else ...[
              FilledButton(onPressed: _connect, child: const Text("Connect")),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: hotlineController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Hotline',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Phone',
              ),
            ),
            const SizedBox(height: 12),
            if (isCalling) ...[
              const CircularProgressIndicator()
            ] else ...[
              if (callState != "disconnected" && callState != "") ...[
                Text(callee),
                Text('Call state: $callState'),
              ] else ...[
                FilledButton(
                  onPressed: _call,
                  child: const Text("Call"),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
