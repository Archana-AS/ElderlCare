import 'package:elder_care/screens/test.dart';
import 'package:flutter/material.dart';
import '../core/api/urlfinder.dart';
import '../core/speech/permision.dart';
import 'homepage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String serverUrl = '';

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  Future<void> _startLoading() async {
    final minimumDisplayTime = Future.delayed(const Duration(seconds: 2));
    final urlFuture = getPublicUrl().then((url) {
      serverUrl = url;
    });

    await Future.wait([minimumDisplayTime, urlFuture]);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChatScreen()),//const HomePage(name: "Aravind")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    // The UI for the splash screen.
    return Scaffold(
      body: Container(
        // Use a container to hold the background color or image.
        color: Colors.white,
        child: Center(
          child: Image.asset(
            'assets/icon.png',
            height: 200,
          ),
        ),
      ),
    );
  }
}
