import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'package:http/http.dart' as http;

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final SupabaseClient _client = SupabaseService().client;

  bool _initialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Firebase should already be initialized in main.dart
      // Just verify it's available
      if (Firebase.apps.isEmpty) {
        print('Warning: Firebase not initialized. Call Firebase.initializeApp() in main.dart first');
        return;
      }

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Initialize local notifications
      await _initLocalNotifications();

      // Request permissions
      await _requestPermissions();

      // Get FCM token and save to database
      await _saveFcmToken();

      // Listen to token refresh
      _messaging.onTokenRefresh.listen((token) {
        _saveFcmTokenToDatabase(token);
      });

      // Listen to incoming messages
      _setupMessageListeners();

      _initialized = true;
      print('NotificationService initialized successfully');
    } catch (e) {
      print('Error initializing NotificationService: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }

    // Request local notification permissions
    await _localNotifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _saveFcmToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveFcmTokenToDatabase(token);
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  Future<void> _saveFcmTokenToDatabase(String token) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client.from('user_fcm_tokens').upsert({
        'user_id': user.id,
        'fcm_token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
      
      print('FCM token saved to database');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  void _setupMessageListeners() {
    // Listen to messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received foreground message: ${message.messageId}');
      _handleMessage(message, isInForeground: true);
    });

    // Listen to messages when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message opened from background: ${message.messageId}');
      _handleMessageTap(message);
    });

    // Check if app was opened from a notification
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('App opened from terminated state via notification');
        _handleMessageTap(message);
      }
    });
  }

  void _handleMessage(RemoteMessage message, {bool isInForeground = false}) {
    final data = message.data;
    final notification = message.notification;

    // Extract notification details
    final title = notification?.title ?? data['title'] ?? 'New Notification';
    final body = notification?.body ?? data['body'] ?? '';
    final type = data['type'] ?? 'unknown';
    final senderId = data['sender_id'];
    final senderName = data['sender_name'];
    final senderAvatar = data['sender_avatar'];

    // Show local notification with profile picture
    if (isInForeground) {
      _showLocalNotification(
        title: title,
        body: body,
        type: type,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        data: data,
      );
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String type,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    Map<String, dynamic>? data,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Download profile picture for large icon
    AndroidBitmap<Object>? largeIconBitmap;
    if (senderAvatar != null) {
      final bitmap = await _downloadBitmap(senderAvatar);
      if (bitmap != null) {
        largeIconBitmap = ByteArrayAndroidBitmap(bitmap);
      }
    }

    // Create notification channel for Android
    final androidDetails = AndroidNotificationDetails(
      _getChannelId(type),
      _getChannelName(type),
      channelDescription: _getChannelDescription(type),
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableLights: true,
      ledColor: const Color(0xFF1B5A27),
      largeIcon: largeIconBitmap,
      styleInformation: senderName != null
          ? BigTextStyleInformation(
              body,
              contentTitle: title,
              htmlFormatContentTitle: true,
              htmlFormatContent: true,
              summaryText: 'From $senderName',
            )
          : null,
    );

    const iOSSetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iOSSetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: jsonEncode(data ?? {}),
    );
  }

  String _getChannelId(String type) {
    switch (type) {
      case 'wave':
        return 'waves_channel';
      case 'message':
        return 'messages_channel';
      case 'call':
        return 'calls_channel';
      default:
        return 'general_channel';
    }
  }

  String _getChannelName(String type) {
    switch (type) {
      case 'wave':
        return 'Wave Requests';
      case 'message':
        return 'Messages';
      case 'call':
        return 'Calls';
      default:
        return 'General';
    }
  }

  String _getChannelDescription(String type) {
    switch (type) {
      case 'wave':
        return 'Notifications for new wave requests';
      case 'message':
        return 'Notifications for new messages';
      case 'call':
        return 'Notifications for incoming calls';
      default:
        return 'General notifications';
    }
  }

  Future<Uint8List?> _downloadBitmap(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      print('Error downloading bitmap: $e');
      return null;
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        _handleNotificationTap(data);
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    _handleNotificationTap(message.data);
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final senderId = data['sender_id'] as String?;
    final conversationId = data['conversation_id'] as String?;

    // Navigation will be handled by the app's navigation system
    // Store the data for later use when app is ready
    print('Notification tapped: type=$type, senderId=$senderId');
    
    // You can use a global navigator or event bus to navigate
    // For now, we'll just log it
    // In production, implement navigation to:
    // - Wave requests screen for type='wave'
    // - Chat screen for type='message' with conversationId
    // - Call screen for type='call'
  }

  /// Send notification to a specific user
  Future<void> sendNotificationToUser({
    required String targetUserId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      // Get sender's profile
      final senderProfile = await _client
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .eq('id', user.id)
          .single();

      final data = {
        'type': type,
        'sender_id': user.id,
        'sender_name': senderProfile['display_name'] ?? senderProfile['username'] ?? 'User',
        'sender_avatar': senderProfile['avatar_url'],
        ...?additionalData,
      };

      // Call Supabase Edge Function to send notification
      await _client.functions.invoke('send-notification', body: {
        'target_user_id': targetUserId,
        'title': title,
        'body': body,
        'data': data,
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  /// Send wave notification
  Future<void> sendWaveNotification(String targetUserId) async {
    await sendNotificationToUser(
      targetUserId: targetUserId,
      type: 'wave',
      title: 'New Wave Request',
      body: 'Someone wants to connect with you!',
    );
  }

  /// Send message notification
  Future<void> sendMessageNotification({
    required String targetUserId,
    required String conversationId,
    required String messagePreview,
  }) async {
    await sendNotificationToUser(
      targetUserId: targetUserId,
      type: 'message',
      title: 'New Message',
      body: messagePreview,
      additionalData: {
        'conversation_id': conversationId,
      },
    );
  }

  /// Send call notification
  Future<void> sendCallNotification({
    required String targetUserId,
    required String callId,
    required String callType,
  }) async {
    await sendNotificationToUser(
      targetUserId: targetUserId,
      type: 'call',
      title: 'Incoming ${callType == 'video' ? 'Video' : 'Voice'} Call',
      body: 'Tap to answer',
      additionalData: {
        'call_id': callId,
        'call_type': callType,
      },
    );
  }

  /// Subscribe to a topic for group notifications
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
