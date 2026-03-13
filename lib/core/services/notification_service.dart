import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../models/app_notification.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage _) async {}

class NotificationService {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static const _channelId = 'wysebrix_high';
  static const _channelName = 'WyseBrix Notifications';

  final _fcm = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final _db = FirebaseFirestore.instance;

  String? _currentUid;
  String? _pendingToken;

  Future<void> init() async {
    // Background handler (separate isolate)
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Request permission
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // iOS foreground presentation
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Create Android notification channel
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Project and contract updates from WyseBrix',
          importance: Importance.high,
        ),);

    // Init flutter_local_notifications
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (details) =>
          _routeFromPayload(details.payload),
    );

    // Foreground FCM → show local banner
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Background tap → navigate
    FirebaseMessaging.onMessageOpenedApp.listen((m) => routeFromData(m.data));

    // Terminated tap → navigate after mount
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => routeFromData(initial.data),
      );
    }

    // Initial token — may throw on iOS simulator (no APNS); safe to skip.
    try {
      final token = await _fcm.getToken();
      if (token != null) _pendingToken = token;
    } catch (e) {
      debugPrint('NotificationService: FCM token unavailable — $e');
    }

    // Token refresh
    _fcm.onTokenRefresh.listen((t) {
      _pendingToken = t;
      if (_currentUid != null) _saveToken(_currentUid!, t);
    });
  }

  /// Call once after AuthService is initialized. Saves/clears FCM token
  /// automatically whenever the signed-in user changes.
  void listenToAuth(AuthService auth) {
    auth.addListener(() {
      final uid = auth.currentUser?.uid;
      if (uid != null && uid != _currentUid) {
        _currentUid = uid;
        if (_pendingToken != null) _saveToken(uid, _pendingToken!);
      } else if (uid == null && _currentUid != null) {
        _clearToken(_currentUid!);
        _currentUid = null;
      }
    });
  }

  Future<void> _saveToken(String uid, String token) => _db
      .collection('users')
      .doc(uid)
      .set({'fcmToken': token}, SetOptions(merge: true));

  Future<void> _clearToken(String uid) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .update({'fcmToken': FieldValue.delete()});
    } catch (_) {
      // Silently ignore — user may already be signed out and lack Firestore
      // permission; the stale token is harmless since it is bound to the device.
    }
  }

  void _showLocalNotification(RemoteMessage msg) {
    final n = msg.notification;
    if (n == null) return;
    _local.show(
      msg.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: _encodePayload(msg.data),
    );
  }

  String _encodePayload(Map<String, dynamic> data) =>
      '${data['type'] ?? ''}|${data['projectId'] ?? ''}';

  // ── Notification inbox ───────────────────────────────────────────────────────

  /// Stream of the user's last 50 notifications, newest first.
  Stream<List<AppNotification>> notificationsStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => AppNotification.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Stream of unread chat message notification count.
  Stream<int> unreadChatCountStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('data.type', isEqualTo: 'chat_message')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// Stream of unread notification count.
  Stream<int> unreadCountStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.size);
  }

  /// Mark a single notification as read.
  Future<void> markRead(String uid, String notifId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notifId)
        .update({'read': true});
  }

  // ── Notification preferences ─────────────────────────────────────────────

  static const Map<String, bool> defaultPrefs = {
    'project_updates': true,
    'phase_changes': true,
    'cost_entries': true,
    'deletion_requests': true,
    'contracts': true,
    'assignment': true,
    // P3 additions
    'quote_responses': true,
    'site_inspections': true,
    'snag_list': true,
    'change_orders': true,
    'chat_messages': true,
    'budget_alerts': true,
    // Collaboration
    'task_comments': true,
    // Construction monitoring
    'issue_reports': true,
    'safety_incidents': true,
  };

  /// Stream the user's notification preferences map.
  Stream<Map<String, bool>> prefsStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) {
      final raw = snap.data()?['notificationPrefs'];
      if (raw is Map) {
        return Map<String, bool>.from(
          defaultPrefs.map(
            (k, v) => MapEntry(k, raw[k] as bool? ?? v),
          ),
        );
      }
      return Map<String, bool>.from(defaultPrefs);
    });
  }

  /// Persist the user's notification preferences to Firestore.
  Future<void> savePrefs(String uid, Map<String, bool> prefs) {
    return _db
        .collection('users')
        .doc(uid)
        .set({'notificationPrefs': prefs}, SetOptions(merge: true));
  }

  /// Write a notification document to the given user's inbox.
  Future<void> createNotification({
    required String uid,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic> data = const {},
  }) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .add({
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  /// Mark all unread notifications as read.
  Future<void> markAllRead(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // ── Routing ──────────────────────────────────────────────────────────────────

  void _routeFromPayload(String? payload) {
    if (payload == null) return;
    final parts = payload.split('|');
    routeFromData({
      'type': parts.elementAtOrNull(0) ?? '',
      'projectId': parts.elementAtOrNull(1) ?? '',
    });
  }

  void routeFromData(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    final projectId = data['projectId'] as String? ?? '';
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    try {
      if (type == 'contract_new') {
        GoRouter.of(ctx).push('/account/contracts/pending');
      } else if (projectId.isNotEmpty) {
        GoRouter.of(ctx).push('/projects/$projectId');
      }
    } catch (_) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Could not open this notification.')),
      );
    }
  }
}
