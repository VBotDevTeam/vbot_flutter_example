import 'package:flutter/material.dart';
import 'package:vbot_flutter_demo/call_state_manager.dart';
import 'package:vbot_flutter_demo/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CallStateManager().initCallStateStream();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'VBot Phone Example'),
    );
  }
}