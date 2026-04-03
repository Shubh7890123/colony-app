import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Note: SupabaseService is initialized in `main.dart` before app UI starts.
  // We still avoid capturing the client in a field initializer to prevent any
  // accidental "uninitialized client" issues during app startup.
  SupabaseClient get _client => SupabaseService().client;

  // Get current position
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable location services.');
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied. Please grant location permission.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied forever. Please enable in settings.');
    }

    // Get current position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Get address from coordinates (reverse geocoding)
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        // Format: "Colony Name, Area, City"
        List<String> parts = [];
        
        // Add sublocality (colony/area)
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          parts.add(place.subLocality!);
        }
        
        // Add locality (city area)
        if (place.locality != null && place.locality!.isNotEmpty) {
          parts.add(place.locality!);
        }
        
        // Add subAdministrativeArea (district)
        if (place.subAdministrativeArea != null && 
            place.subAdministrativeArea!.isNotEmpty &&
            !parts.contains(place.subAdministrativeArea)) {
          parts.add(place.subAdministrativeArea!);
        }

        if (parts.isEmpty) {
          // Fallback to administrative area
          if (place.administrativeArea != null) {
            parts.add(place.administrativeArea!);
          }
        }

        return parts.isNotEmpty 
            ? parts.join(', ').toUpperCase()
            : 'Unknown Location';
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return 'Unknown Location';
  }

  // Update user location in database
  Future<void> updateUserLocation({
    required double latitude,
    required double longitude,
    required String locationText,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      // `profiles.email` is NOT NULL in the migration.
      throw Exception('User email is required to save location');
    }

    await _client.from('profiles').upsert({
      'id': user.id,
      'email': email,
      'latitude': latitude,
      'longitude': longitude,
      'location_text': locationText,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // Fetch and update location (combines all steps)
  Future<LocationResult> fetchAndUpdateLocation() async {
    try {
      // Get current position
      final position = await getCurrentPosition();
      if (position == null) {
        return LocationResult(
          success: false,
          errorMessage: 'Could not get current position',
        );
      }
      
      // Get address from coordinates
      String address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // Update in database
      await updateUserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        locationText: address,
      );

      return LocationResult(
        success: true,
        latitude: position.latitude,
        longitude: position.longitude,
        locationText: address,
      );
    } catch (e) {
      return LocationResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Get user's current location from database
  Future<UserLocation?> getUserLocation() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select('latitude, longitude, location_text')
          .eq('id', user.id)
          .single();

      if (response != null && response['latitude'] != null) {
        return UserLocation(
          latitude: response['latitude'],
          longitude: response['longitude'],
          locationText: response['location_text'] ?? 'Unknown',
        );
      }
    } catch (e) {
      print('Error fetching user location: $e');
    }
    return null;
  }

  // Stream of user location changes
  Stream<UserLocation?> getUserLocationStream() {
    final user = _client.auth.currentUser;
    if (user == null) return Stream.value(null);

    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .map((events) {
          if (events.isEmpty) return null;
          final data = events.first;
          if (data['latitude'] == null) return null;
          return UserLocation(
            latitude: data['latitude'],
            longitude: data['longitude'],
            locationText: data['location_text'] ?? 'Unknown',
          );
        });
  }
}

class LocationResult {
  final bool success;
  final double? latitude;
  final double? longitude;
  final String? locationText;
  final String? errorMessage;

  LocationResult({
    required this.success,
    this.latitude,
    this.longitude,
    this.locationText,
    this.errorMessage,
  });
}

class UserLocation {
  final double latitude;
  final double longitude;
  final String locationText;

  UserLocation({
    required this.latitude,
    required this.longitude,
    required this.locationText,
  });
}
