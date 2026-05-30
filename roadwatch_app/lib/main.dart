import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/firebase_messaging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // IMPORTANT: Add your google-services.json (Android) and GoogleService-Info.plist (iOS)
  // before running. See README for setup instructions.
  await Firebase.initializeApp();

  // Initialize FCM push notifications
  await FirebaseMessagingService.instance.initialize();

  runApp(
    const ProviderScope(
      child: RoadWatchApp(),
    ),
  );
}
