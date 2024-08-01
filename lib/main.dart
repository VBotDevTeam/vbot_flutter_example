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

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class _MyHomePageState extends State<MyHomePage> {
  final tokenController = TextEditingController();
  final phoneController = TextEditingController();
  final hotlineController = TextEditingController();

  String displayName = "";
  final phone = VBotPhone();

  bool isLoading = false;
  bool isCalling = false;
  bool isConnected = false;

  String callState = "";
  String callee = "";

  VBotHotline? selectedHotline;
  List<VBotHotline> hotlines = [];

  // static const EventChannel _eventChannel =
  //     EventChannel('com.vpmedia.vbot-sdk/call');

  Stream<VBotSink> streamCallStateFromNative() {
    const callStateChannel = EventChannel('com.vpmedia.vbot-sdk/call');
    return callStateChannel.receiveBroadcastStream().map((event) {
      return VBotSink.fromMap(Map<String, dynamic>.from(event));
    });
  }

  @override
  void initState() {
    super.initState();
    tokenController.text =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJWYWx1ZSI6IjU0ODctNDU2Ny0xNTYtMTk3In0.cy4pzmqY-Lc22qQhUsQ6tMQ6bEYBh5yZ4DrM9di8qWA';
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
      final result = await phone.connect(tokenController.text);

      displayName = result ?? "Error";
      isConnected = true;
      var hotlines = await phone.getHotlines();
      if (hotlines != null) {
        this.hotlines = hotlines;
        selectedHotline = hotlines[0];
      }
    } catch (e) {
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
          await phone.startCall(hotlineNumber, phoneController.text);
      callee = calleeName ?? "Error";
    } catch (e) {
      print("call exception: $e");
    } finally {
      setState(() {
        isCalling = false; // Hide loading indicator
      });
    }
  }

  Widget _callView() {
    return StreamBuilder<VBotSink>(
      stream: streamCallStateFromNative(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          if (snapshot.data!.state != 'disconnected') {
            return Column(
              children: [
                Text(
                  snapshot.data!.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  snapshot.data!.state == 'confirmed'
                      ? snapshot.data!.duration
                      : snapshot.data!.state,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: [
                    if (snapshot.data!.state == 'confirmed') ...[
                      FilledButton(
                        onPressed: muteMic,
                        child: Text(snapshot.data!.isMute ? "Unmute" : "Mute"),
                      ),
                      FilledButton(
                        onPressed: onoffSpeaker,
                        child: const Text("Speaker"),
                      ),
                    ],
                    if (snapshot.data!.state == 'confirmed' ||
                        snapshot.data!.state == 'calling')
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
            );
          } else {
            return const SizedBox();
          }
        } else {
          return const SizedBox();
        }
      },
    );
  }

  void muteMic() async {
    final _ = await phone.mute();
  }

  void onoffSpeaker() {}

  void hangupCall() async {
    final _ = await phone.hangup();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: ScaffoldMessenger(
        key: scaffoldMessengerKey,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text(widget.title),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Display name: ',
                      ),
                      Expanded(
                        child: Text(displayName,
                            maxLines: 2,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            )),
                      ),
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
                    FilledButton(
                        onPressed: _connect, child: const Text("Connect")),
                  ],
                  const SizedBox(height: 20),
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
                        items: hotlines.map<DropdownMenuItem<VBotHotline>>(
                            (VBotHotline value) {
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
                  FilledButton(
                    onPressed: _call,
                    child: const Text("Call"),
                  ),
                  const SizedBox(height: 20),
                  _callView(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
