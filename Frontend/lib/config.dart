import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static String? _supabaseUrl;
  static String? _supabaseAnonKey;
  static bool _isInitialized = false;

  static Future<void> load() async {
    if (_isInitialized) return;

    try {
      // Load environment variables from .env file
      await dotenv.load(fileName: '.env');
      
      _supabaseUrl = dotenv.env['SUPABASE_URL'];
      _supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

      // Validate required environment variables
      if (_supabaseUrl == null || _supabaseUrl!.isEmpty) {
        throw Exception('SUPABASE_URL is not set in .env file');
      }
      if (_supabaseAnonKey == null || _supabaseAnonKey!.isEmpty) {
        throw Exception('SUPABASE_ANON_KEY is not set in .env file');
      }

      _isInitialized = true;
    } catch (e) {
      print('Error loading config: $e');
      rethrow;
    }
  }

  static String get supabaseUrl => _supabaseUrl ?? '';
  static String get supabaseAnonKey => _supabaseAnonKey ?? '';
}