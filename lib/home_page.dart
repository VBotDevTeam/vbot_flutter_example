import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vbot_flutter_demo/call_screen.dart';
import 'package:vbot_flutter_demo/call_state_manager.dart';
import 'package:vbot_flutter_demo/client.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String get title => widget.title;

  @override
  void initState() {
    super.initState();

    CallStateManager().callStateStream.listen(
      (vbotSink) {
        if (vbotSink.state == 'connecting' && vbotSink.isIncoming) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CallPage()),
          );
        }

        if (vbotSink.state == 'calling' && !vbotSink.isIncoming) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CallPage()),
          );
        }
      },
      onError: (error) => print("Error in callStateStream: $error"),
    );
  }

  @override
  void dispose() {
    CallStateManager().dispose();
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

    _checkConnect();

    tokenController.text =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJWYWx1ZSI6IjU0ODctNDU2Ny0xNTYtMjU3In0.tLdNNKfBZLr8MYEDDxfYORIsmbT9FUtiLgGDDetS3yg';
  }

  void _checkConnect() async {
    bool result = await client.isUserConnected();
    String userDisplayName = await client.userDisplayName();
    if (result) {
      setState(() {
        displayName = userDisplayName;
        isConnected = true;
      });

      _getHotlines();
    }
  }

  // Hàm kết nối
  void _connect() async {
    setState(() {
      isLoading = true; // Hiển thị loading
    });

    if (tokenController.text.isEmpty) {
      setState(() {
        isLoading = false; // Ẩn loading
      });
      return;
    }

    try {
      final result = await client.connect(tokenController.text);

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
        isLoading = false; // Ẩn loading
      });
    }
  }

  void _getHotlines() async {
    var hotlines = await client.getHotlines();
    if (hotlines != null && hotlines.isNotEmpty) {
      setState(() {
        this.hotlines = hotlines;
        selectedHotline = hotlines[0];
      });
    }
  }

  // Hàm ngắt kết nối
  void _disconnect() async {
    setState(() {
      isLoading = true; // Hiển thị loading
    });

    try {
      final isDisconnected = await client.disconnect();
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
        isLoading = false; // Ẩn loading
      });
    }
  }

  void _call() async {
    setState(() {
      isCalling = true; // Show loading indicator
    });

    if (phoneController.text.isEmpty) {
      setState(() {
        isCalling = false; // Hide loading indicator
      });
      return;
    }
    try {
      String hotlineNumber =
          hotlineController.text != "" ? selectedHotline!.phoneNumber : '';
      final calleeName =
          await client.startCall(hotlineNumber, phoneController.text);
      callee = calleeName ?? "Error";
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
