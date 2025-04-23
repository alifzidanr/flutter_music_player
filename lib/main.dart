// lib/main.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MusicPlayerApp());
}

class MusicPlayerApp extends StatelessWidget {
  const MusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MP3 Music Player',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PermissionHandler(child: HomeScreen()),
    );
  }
}

// Widget to handle permissions before showing the main screen
class PermissionHandler extends StatefulWidget {
  final Widget child;

  const PermissionHandler({super.key, required this.child});

  @override
  State<PermissionHandler> createState() => _PermissionHandlerState();
}

class _PermissionHandlerState extends State<PermissionHandler> {
  bool _hasPermission = false;
  bool _isCheckingPermission = true;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  // Check and request storage permissions
  Future<void> _checkAndRequestPermissions() async {
    bool hasPermission = false;

    // For Android 13+ (API level 33)
    if (await Permission.audio.request().isGranted) {
      hasPermission = true;
    }
    // For older Android versions
    else if (await Permission.storage.request().isGranted) {
      hasPermission = true;
    }

    // For iOS
    if (!hasPermission && await Permission.mediaLibrary.request().isGranted) {
      hasPermission = true;
    }

    if (mounted) {
      setState(() {
        _hasPermission = hasPermission;
        _isCheckingPermission = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPermission) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_hasPermission) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              "Storage Permission Required",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                "This app needs access to your storage to find and play MP3 files.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                await _checkAndRequestPermissions();

                // If still no permission, open app settings
                if (!_hasPermission) {
                  await openAppSettings();
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text(
                "Grant Permission",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
