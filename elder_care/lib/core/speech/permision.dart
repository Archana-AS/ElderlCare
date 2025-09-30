import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../screens/test.dart';

class PermissionCheckerScreen extends StatefulWidget {
  const PermissionCheckerScreen({super.key});

  @override
  State<PermissionCheckerScreen> createState() => _PermissionCheckerScreenState();
}

class _PermissionCheckerScreenState extends State<PermissionCheckerScreen> {
  bool _isPermissionGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermission();
  }

  // Function to check and request Microphone permission
  Future<void> _checkAndRequestPermission() async {
    // 1. Check current status
    var status = await Permission.microphone.status;

    if (status.isGranted) {
      _isPermissionGranted = true;
    }

    // 2. Request permission if not granted
    if (status.isDenied || status.isRestricted) {
      status = await Permission.microphone.request();
    }

    if (status.isGranted) {
      _isPermissionGranted = true;
      // IMPORTANT: We do NOT start the VoiceService here.
      // It is now started in the PhoneCallScreen's lifecycle via the Provider.
    } else if (status.isPermanentlyDenied) {
      _showPermanentlyDeniedDialog();
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showPermanentlyDeniedDialog() {
    // Your existing dialog logic
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Microphone Access Required', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'This application requires continuous microphone access to function as a hands-free chatbot. Please enable the Microphone permission in your app settings.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Go to Settings'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isPermissionGranted) {
      // Navigate to your main screen
      return const ChatScreen();
    } else {
      // Show permission denial UI
      return Scaffold(
        appBar: AppBar(title: const Text('Permission Required')),
        body: Center(
          child: ElevatedButton.icon(
            onPressed: _checkAndRequestPermission,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ),
      );
    }
  }
}
