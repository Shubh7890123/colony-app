import 'package:flutter/material.dart';

import '../device_auth_service.dart';

class DeviceUnlockScreen extends StatefulWidget {
  const DeviceUnlockScreen({super.key});

  @override
  State<DeviceUnlockScreen> createState() => _DeviceUnlockScreenState();
}

class _DeviceUnlockScreenState extends State<DeviceUnlockScreen> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  bool _isValidPin(String v) => RegExp(r'^\d{4}$').hasMatch(v);

  Future<void> _unlock() async {
    final pin = _pinController.text.trim();
    if (!_isValidPin(pin)) {
      setState(() => _error = 'Enter a 4-digit PIN');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ok = await DeviceAuthService().verifyLocalPin(pin);
      if (!ok) {
        throw Exception('Wrong PIN');
      }
      await DeviceAuthService().signInWithSavedCredentials();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7ED),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Unlock',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF14471E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your 4-digit PIN to continue.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.25)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _unlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5A27),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Unlock',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

