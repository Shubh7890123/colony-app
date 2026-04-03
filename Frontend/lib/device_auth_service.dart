import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_id_service.dart';
import 'supabase_service.dart';
import 'username_generator.dart';

class DeviceAuthService {
  static final DeviceAuthService _instance = DeviceAuthService._internal();
  factory DeviceAuthService() => _instance;
  DeviceAuthService._internal();

  final SupabaseClient _client = SupabaseService().client;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  static const _kUsername = 'device_auth.username';
  static const _kEmail = 'device_auth.email';
  static const _kPassword = 'device_auth.password';
  static const _kPin = 'device_auth.pin';

  // We keep a "hidden email" behind the scenes for Supabase Auth.
  // The user never sees it; they interact with username + 4-digit PIN.
  static const String _emailDomain = 'colony.local';

  Future<String?> getSavedUsername() => _secure.read(key: _kUsername);

  Future<bool> hasSavedCredentials() async {
    final email = await _secure.read(key: _kEmail);
    final password = await _secure.read(key: _kPassword);
    return (email != null && email.isNotEmpty) && (password != null && password.isNotEmpty);
  }

  String _pinToPassword(String pin) {
    // Supabase password min length is 6. We keep it deterministic.
    // Example: 1234 -> 12341234
    return '$pin$pin';
  }

  Future<AuthResponse> signInWithSavedCredentials() async {
    final email = await _secure.read(key: _kEmail);
    final password = await _secure.read(key: _kPassword);
    if (email == null || password == null) {
      throw Exception('No saved credentials');
    }
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOutAndClearLocal() async {
    await _client.auth.signOut();
    await _secure.delete(key: _kUsername);
    await _secure.delete(key: _kEmail);
    await _secure.delete(key: _kPassword);
    await _secure.delete(key: _kPin);
  }

  String _newUsername() {
    final gen = UsernameGenerator();
    // Base like "ninjasparks"
    final base = gen.generate();
    // Add a tiny suffix to reduce collision risk without looking like "guest3478"
    // e.g. ninjasparks-42
    final suffix = DateTime.now().millisecondsSinceEpoch % 97;
    return suffix == 0 ? base : '$base-$suffix';
  }

  /// First install flow: creates an account, stores credentials securely,
  /// and links current device_id in profiles.
  Future<String> createAccountAndLogin({
    required String pin,
  }) async {
    final password = _pinToPassword(pin);
    final deviceId = await DeviceIdService().getDeviceId();

    // NOTE: We can't query `profiles` before auth exists (would be 401).
    // So we generate a username and retry on rare collisions.
    AuthResponse? resp;
    late String username;
    late String email;
    for (var attempt = 0; attempt < 10; attempt++) {
      username = _newUsername();
      email = '$username@$_emailDomain';
      resp = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'display_name': username,
          'device_id': deviceId,
        },
      );

      // If user is created, we can stop.
      if (resp.user != null) break;
    }

    // Persist local secrets for auto-login
    await _secure.write(key: _kUsername, value: username);
    await _secure.write(key: _kEmail, value: email);
    await _secure.write(key: _kPassword, value: password);
    await _secure.write(key: _kPin, value: pin);

    // If Supabase requires email confirmation, session may be null. We still try to sign in.
    // IMPORTANT: For a device-only app, disable "Confirm email" in Supabase Auth settings,
    // otherwise session can be null and client-side DB writes will fail.
    if (resp!.session == null) {
      await _client.auth.signInWithPassword(email: email, password: password);
    }
    // We rely on the DB trigger `handle_new_user` (SECURITY DEFINER) to create profiles.

    return username;
  }

  /// Login on another device: user enters their username + 4-digit PIN.
  Future<void> loginWithUsernamePin({
    required String username,
    required String pin,
  }) async {
    final email = '$username@$_emailDomain';
    final password = _pinToPassword(pin);
    await _client.auth.signInWithPassword(email: email, password: password);

    final deviceId = await DeviceIdService().getDeviceId();
    final user = _client.auth.currentUser;
    if (user != null) {
      await _client.from('profiles').update({
        'device_id': deviceId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);
    }

    await _secure.write(key: _kUsername, value: username);
    await _secure.write(key: _kEmail, value: email);
    await _secure.write(key: _kPassword, value: password);
    await _secure.write(key: _kPin, value: pin);
  }

  Future<bool> verifyLocalPin(String pin) async {
    final saved = await _secure.read(key: _kPin);
    return saved != null && saved == pin;
  }
}

