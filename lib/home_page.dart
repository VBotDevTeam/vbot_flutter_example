import 'package:flutter/material.dart';
import 'package:vbot_flutter_demo/call_screen.dart';
import 'package:vbot_flutter_demo/vbot_phone_manager.dart';
import 'dart:async';

import 'package:vbot_flutter_demo/sink.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final vbotManager = VBotPhoneManager();
  String get title => widget.title;
  bool _isCallPagePushed = false;
  late StreamSubscription<VBotSink> _callSubscription;

  @override
  void initState() {
    super.initState();

    vbotManager.init().then(
      (_) {
        vbotManager.callStateStream.listen(
          (sink) {
            if (_isCallPagePushed || !mounted) return;
            final isIncomingConfirmed =
                sink.state == 'confirmed' && sink.isIncoming;
            final isOutgoingCalling =
                sink.state == 'calling' && !sink.isIncoming;
            if (isIncomingConfirmed || isOutgoingCalling) {
              _isCallPagePushed = true;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CallPage()),
              ).then((_) {
                // Khi CallPage pop ra, reset biến lại để có thể push lại nếu cần
                _isCallPagePushed = false;
              });
            }
          },
          onError: (error) => print("Error in callStateStream: $error"),
        );
      },
    );
  }

  @override
  void dispose() {
    _callSubscription.cancel();
    vbotManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: scaffoldMessengerKey,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          appBar: AppBar(title: Text(title)),
          body: const SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ConnectViewWidget(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ConnectViewWidget extends StatefulWidget {
  const ConnectViewWidget({
    super.key,
  });

  @override
  State<ConnectViewWidget> createState() => _ConnectViewWidgetState();
}

class _ConnectViewWidgetState extends State<ConnectViewWidget> {
  final vbotManager = VBotPhoneManager();

  final tokenController = TextEditingController();
  final phoneController = TextEditingController();
  final hotlineController = TextEditingController();

  VBotHotline? selectedHotline;
  List<VBotHotline> hotlines = [];

  String displayName = "";
  bool isLoading = false;
  bool isConnected = false;
  bool isCalling = false;
  String callee = "";

  @override
  void initState() {
    super.initState();
    tokenController.text = "";
    _checkConnect();
  }

  void _checkConnect() async {
    bool result = await vbotManager.isUserConnected();
    String? userDisplayName = await vbotManager.userDisplayName();
    if (result) {
      setState(() {
        displayName = userDisplayName ?? "";
        isConnected = true;
      });

      _getHotlines();
    }
  }

  void _connect() async {
    setState(() {
      isLoading = true;
    });

    if (tokenController.text.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final result = await vbotManager.connect(tokenController.text);

      if (result != null) {
        setState(() {
          displayName = result;
          isConnected = true;
        });

        _getHotlines();
      } else {
        setState(() {
          displayName = "Error";
          isConnected = false;
        });
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _getHotlines() async {
    var hotlines = await vbotManager.getHotlines();
    if (hotlines != null && hotlines.isNotEmpty) {
      setState(() {
        this.hotlines = hotlines;
        selectedHotline = hotlines[0];
      });
    }
  }

  void _disconnect() async {
    setState(() {
      isLoading = true;
    });

    try {
      final isDisconnected = await vbotManager.disconnect();
      if (isDisconnected) {
        setState(() {
          isConnected = false;
          hotlines = [];
          selectedHotline = null;
          displayName = "";
        });
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _call() async {
    setState(() {
      isCalling = true;
    });

    if (phoneController.text.isEmpty) {
      setState(() {
        isCalling = false;
      });
      return;
    }
    try {
      String hotlineNumber =
          hotlineController.text != "" ? selectedHotline!.phoneNumber : '';
      final calleeName = await vbotManager.startCall(
          phoneController.text, phoneController.text, hotlineNumber);
      callee = calleeName ?? "Error";
    } catch (e) {
      print("call exception: $e");
    } finally {
      setState(() {
        isCalling = false;
      });
    }
  }

  @override
  void dispose() {
    tokenController.dispose();
    phoneController.dispose();
    hotlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Display name: ',
            ),
            Expanded(
              child: Text(
                displayName,
                maxLines: 2,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          minLines: 1,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          controller: tokenController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Token',
          ),
        ),
        const SizedBox(height: 12),
        if (isLoading) ...[
          const CircularProgressIndicator()
        ] else if (!isConnected) ...[
          FilledButton(onPressed: _connect, child: const Text("Connect")),
        ] else ...[
          FilledButton(onPressed: _disconnect, child: const Text("Disconnect")),
          Row(
            children: [
              const Text('Hotline: '),
              DropdownButton<VBotHotline>(
                value: selectedHotline,
                hint: const Text('Select Hotline'),
                onChanged: (VBotHotline? newValue) {
                  if (newValue != null) {
                    setState(() {
                      hotlineController.text = newValue.name;
                      selectedHotline = newValue;
                    });
                  }
                },
                items: hotlines
                    .map<DropdownMenuItem<VBotHotline>>((VBotHotline value) {
                  return DropdownMenuItem<VBotHotline>(
                    value: value,
                    child: Text(value.name),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: hotlineController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Hotline',
              suffixIcon: hotlineController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        hotlineController.clear();
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Phone',
              suffixIcon: phoneController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        phoneController.clear();
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _call,
            child: const Text("Call"),
          ),
        ],
      ],
    );
  }
}
