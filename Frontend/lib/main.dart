import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'supabase_service.dart';
import 'screens/device_auth_gate.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase FIRST (required before any Firebase operations)
  await Firebase.initializeApp();
  print('Firebase initialized successfully');

  // Initialize Supabase
  await SupabaseService().initialize();

  // Initialize Notification Service
  await NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Colony Auth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E5631)),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const DeviceAuthGate(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEEF9E9), Color(0xFFE2F3D9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_on,
                size: 64,
                color: const Color(0xFF1B5A27),
              ),
              const SizedBox(height: 16),
              const Text(
                'Colony',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5A27),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                color: Color(0xFF1B5A27),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
