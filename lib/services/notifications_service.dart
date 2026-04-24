import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationsService {
  NotificationsService._();
  static final instance = NotificationsService._();

  final _local = FlutterLocalNotificationsPlugin();
  String? _registeredToken;
  bool _firebaseReady = false;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (_) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        _handleTapPayload(response.payload);
      },
    );

    FirebaseMessaging.onMessage.listen(_onForeground);

    // User tapped a notification while the app was backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _handleTapData(msg.data);
    });

    // App was cold-started by tapping a notification.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      // Defer so the first frame is rendered before we launch anything.
      Future.delayed(const Duration(milliseconds: 300), () {
        _handleTapData(initial.data);
      });
    }
  }

  Future<void> registerForUser() async {
    if (!_firebaseReady) return;
    final fm = FirebaseMessaging.instance;
    final settings = await fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    if (Platform.isIOS) {
      final apnsToken = await fm.getAPNSToken();
      if (apnsToken == null) return;
    }

    final token = await fm.getToken();
    if (token == null) return;
    await _sendTokenToServer(token);

    fm.onTokenRefresh.listen(_sendTokenToServer);
  }

  Future<void> unregister() async {
    if (!_firebaseReady) return;
    final token = _registeredToken;
    _registeredToken = null;
    if (token != null) {
      try {
        await ApiService.unregisterDevice(token);
      } catch (_) {}
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    if (_registeredToken == token) return;
    try {
      await ApiService.registerDevice(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
      _registeredToken = token;
    } catch (_) {}
  }

  Future<void> _onForeground(RemoteMessage msg) async {
    final n = msg.notification;
    if (n == null) return;
    // Serialise the data map so the tap handler can recover it when the
    // user taps the in-app notification.
    final payload = msg.data.isEmpty ? null : jsonEncode(msg.data);
    await _local.show(
      msg.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bestmart_orders',
          'Order updates',
          channelDescription: 'Order status updates from BestMart',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  void _handleTapPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _handleTapData(data.map((k, v) => MapEntry(k, v?.toString() ?? '')));
    } catch (_) {}
  }

  void _handleTapData(Map<String, dynamic> data) {
    final url = data['url']?.toString().trim();
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    // Open the link in the user's default browser / external app.
    unawaited(
      canLaunchUrl(uri).then((can) {
        if (can) launchUrl(uri, mode: LaunchMode.externalApplication);
      }),
    );
  }
}
