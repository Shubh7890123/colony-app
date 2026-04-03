import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  
  late final SupabaseService _supabase;
  late final StreamSubscription<AuthState> _authSubscription;
  
  AuthService._internal() {
    _supabase = SupabaseService();
    _initAuthListener();
  }

  // Stream to notify about user authentication changes
  final StreamController<User?> _userStreamController = 
      StreamController<User?>.broadcast();
  Stream<User?> get userStream => _userStreamController.stream;

  // Current user (nullable)
  User? get currentUser => _supabase.client.auth.currentUser;
  
  // Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  // Initialize auth state listener
  void _initAuthListener() {
    _authSubscription = _supabase.client.auth.onAuthStateChange.listen((event) {
      _userStreamController.add(event.session?.user);
    });
  }

  // Sign up with email and password
    Future<AuthResult> signUp({
      required String email,
      required String password,
      String? fullName,
      String? username,
    }) async {
      try {
        final response = await _supabase.client.auth.signUp(
          email: email,
          password: password,
          data: {
            if (fullName != null) 'display_name': fullName,
            if (fullName != null) 'full_name': fullName,
            if (username != null) 'username': username,
          },
        );
  
        if (response.user != null) {
          return AuthResult(
            success: true,
            user: response.user,
            message: 'Account created successfully!',
          );
        }
  
        return AuthResult(
          success: false,
          message: 'Sign up failed. Please try again.',
        );
      } on AuthException catch (e) {
        return AuthResult(
          success: false,
          message: _getErrorMessage(e.message),
        );
      } catch (e) {
        return AuthResult(
          success: false,
          message: 'An unexpected error occurred. Please try again.',
        );
      }
    }
  
    // Sign in with email or username and password
    Future<AuthResult> signIn({
      required String emailOrUsername,
      required String password,
    }) async {
      try {
        String email = emailOrUsername;
        
        // Check if input is a username (doesn't contain @)
        if (!emailOrUsername.contains('@')) {
          // Try to find user by username in profiles table
          final response = await _supabase.client
              .from('profiles')
              .select('email')
              .eq('username', emailOrUsername)
              .maybeSingle();
          
          if (response != null && response['email'] != null) {
            email = response['email'];
          } else {
            return AuthResult(
              success: false,
              message: 'Username not found. Please check your username or use your email.',
            );
          }
        }
  
        final authResponse = await _supabase.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
  
        if (authResponse.user != null) {
          return AuthResult(
            success: true,
            user: authResponse.user,
            message: 'Login successful!',
          );
        }
  
        return AuthResult(
          success: false,
          message: 'Login failed. Please try again.',
        );
      } on AuthException catch (e) {
        return AuthResult(
          success: false,
          message: _getErrorMessage(e.message),
        );
      } catch (e) {
        return AuthResult(
          success: false,
          message: 'An unexpected error occurred. Please try again.',
        );
      }
    }

  // Sign out
  Future<AuthResult> signOut() async {
    try {
      await _supabase.client.auth.signOut();
      return AuthResult(
        success: true,
        message: 'Logged out successfully!',
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to logout. Please try again.',
      );
    }
  }

  // Reset password
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _supabase.client.auth.resetPasswordForEmail(email);
      return AuthResult(
        success: true,
        message: 'Password reset email sent! Please check your inbox.',
      );
    } on AuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getErrorMessage(e.message),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to send reset email. Please try again.',
      );
    }
  }

  // Update user profile
  Future<AuthResult> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      final response = await _supabase.client.auth.updateUser(
        UserAttributes(
          data: {
            if (displayName != null) 'display_name': displayName,
            if (avatarUrl != null) 'avatar_url': avatarUrl,
          },
        ),
      );
      
      if (response.user != null) {
        return AuthResult(
          success: true,
          user: response.user,
          message: 'Profile updated successfully!',
        );
      }
      
      return AuthResult(
        success: false,
        message: 'Failed to update profile.',
      );
    } on AuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getErrorMessage(e.message),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred.',
      );
    }
  }

  // Get user display name
  String? get displayName {
    final user = currentUser;
    if (user == null) return null;
    return user.userMetadata?['display_name'] ?? user.email?.split('@')[0];
  }

  // Get user avatar URL
  String? get avatarUrl {
    final user = currentUser;
    if (user == null) return null;
    return user.userMetadata?['avatar_url'];
  }

  // Get user email
  String? get email => currentUser?.email;

  // Get user ID
  String? get userId => currentUser?.id;

  // Helper to parse error messages
  String _getErrorMessage(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Invalid email or password. Please try again.';
    } else if (message.contains('Email not confirmed')) {
      return 'Please verify your email address first.';
    } else if (message.contains('User already registered')) {
      return 'An account with this email already exists.';
    } else if (message.contains('Password should be at least')) {
      return 'Password must be at least 6 characters long.';
    } else if (message.contains('Invalid email')) {
      return 'Please enter a valid email address.';
    }
    return message;
  }

  // Dispose stream controller
  void dispose() {
    _authSubscription.cancel();
    _userStreamController.close();
  }
}

// Result class for auth operations
class AuthResult {
  final bool success;
  final User? user;
  final String message;

  AuthResult({
    required this.success,
    this.user,
    required this.message,
  });
}
