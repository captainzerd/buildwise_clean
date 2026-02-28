import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_notification.dart';
import 'auth_service.dart';
import '../../features/account/pending_contracts_page.dart';
import '../../features/project/project_details_page.dart';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage _) async {}

class NotificationService {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static const _channelId = 'buildwise_high';
  static const _channelName = 'BuildWise Notifications';

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
          description: 'Project and contract updates from BuildWise',
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

    // Initial token
    final token = await _fcm.getToken();
    if (token != null) _pendingToken = token;

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

  Future<void> _clearToken(String uid) => _db
      .collection('users')
      .doc(uid)
      .update({'fcmToken': FieldValue.delete()});

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
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    if (type == 'contract_new') {
      nav.push(MaterialPageRoute(
        builder: (_) => const PendingContractsPage(),
      ),);
    } else if (projectId.isNotEmpty) {
      nav.push(MaterialPageRoute(
        builder: (_) => ProjectDetailsPage(projectId: projectId),
      ),);
    }
  }
}
