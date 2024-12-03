import 'package:flutter/material.dart';
import 'package:vbot_flutter_demo/client.dart';
import 'package:vbot_flutter_demo/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final tokenController = TextEditingController();

  bool isLoading = false;
  bool isConnected = false;
  bool isCalling = false;

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
      final result = await client.connect(tokenController.text);

      if (result != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const MyHomePage(
                    title: 'VBot Phone Example',
                  )),
        );
        // setState(() {
        //   displayName = result;
        //   isConnected = true;
        // });

        // _getHotlines();
      } else {
        // setState(() {
        //   displayName = "Error";
        //   isConnected = false;
        // });
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
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
              if (isLoading) const CircularProgressIndicator(),
              if (!isConnected)
                FilledButton(onPressed: _connect, child: const Text("Connect")),
            ],
          ),
        ),
      ),
    );
  }
}
