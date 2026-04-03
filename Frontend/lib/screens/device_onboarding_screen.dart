import 'package:flutter/material.dart';

import '../device_auth_service.dart';

class DeviceOnboardingScreen extends StatefulWidget {
  const DeviceOnboardingScreen({super.key});

  @override
  State<DeviceOnboardingScreen> createState() => _DeviceOnboardingScreenState();
}

class _DeviceOnboardingScreenState extends State<DeviceOnboardingScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _createdUsername;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  bool _isValidPin(String v) => RegExp(r'^\d{4}$').hasMatch(v);

  Future<void> _create() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (!_isValidPin(pin)) {
      setState(() => _error = 'Enter a 4-digit PIN');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PIN does not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final username = await DeviceAuthService().createAccountAndLogin(pin: pin);
      if (!mounted) return;
      setState(() => _createdUsername = username);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to create account: $e');
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
              const SizedBox(height: 16),
              const Text(
                'Welcome',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF14471E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set a 4-digit PIN to secure your account.\nWe’ll create a unique profile name for you.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (_createdUsername != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F6E8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your profile name',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF14471E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _createdUsername!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF14471E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Use this name + PIN to login on another phone.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
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
              _pinField('Set PIN', _pinController),
              const SizedBox(height: 12),
              _pinField('Confirm PIN', _confirmPinController),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _create,
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
                          'Continue',
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

  Widget _pinField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 4,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

