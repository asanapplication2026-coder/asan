import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles all FCM client setup: permission request, topic
/// subscription, and displaying notifications while the app is open.
///
/// Every signed-in device — admin, teacher, student — subscribes to the
/// same 'all_users' topic, so a single drill_events INSERT reaches
/// everyone without the app maintaining a token list itself.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // Brand color used to tint the small status-bar icon and notification
  // accents. Android forces the small icon itself to a flat white/mono
  // silhouette (OS-level restriction since Android 5.0) — this color is
  // as close as that icon can get to "branded".
  static const Color _brandColor = Color(0xFF7B1113);

  /// Set once from outside this file (see DrillNotificationRouter) to
  /// handle a tapped drill notification — either a foreground local
  /// notification tap or a background/terminated FCM tap, both funnel
  /// through here. This is a callback rather than a direct import of
  /// GetX/screen code so PushNotificationService stays a plain FCM
  /// wrapper with no navigation/UI dependencies.
  static void Function(String drillEventId)? onDrillNotificationTap;

  static const AndroidNotificationChannel _drillChannel =
  AndroidNotificationChannel(
    'drill_alerts',
    'Drill & Emergency Alerts',
    description: 'Notifications for drills and real emergencies',
    importance: Importance.max,
    playSound: true,
  );

  /// Call this once from AuthController after sign-in, before deciding
  /// whether to prompt for permission. Sets up the local notification
  /// channel and message listeners — none of this requires permission
  /// to have been granted, so it's safe to run unconditionally and
  /// silently (no system dialog, no user-facing UI).
  Future<void> initialize() async {
    // This must never throw — a resource/config problem here should not
    // be able to block permission request + topic subscription below.
    // That's exactly what happened before: a missing drawable crashed
    // this call, and the device never actually subscribed to 'all_users'.
    try {
      await _initLocalNotifications();
    } catch (e, st) {
      debugPrint('PushNotificationService: local notification init failed: $e');
      debugPrint('$st');
    }

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // App was opened from a terminated state by tapping the notification.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Current permission status without prompting. Use this to decide
  /// whether to show our own soft-ask UI before calling
  /// [requestPermissionAndSubscribe] — on iOS in particular, once the
  /// user has answered the system dialog once, asking again shows
  /// nothing, so this lets the caller branch on that.
  Future<AuthorizationStatus> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// The device's current FCM registration token, or null if
  /// permission hasn't been granted / APNs isn't ready yet on iOS.
  /// Callers (AuthController) persist this against profiles.fcm_token
  /// so section-scoped chat push can target specific recipients —
  /// this class stays a plain FCM wrapper and doesn't touch Supabase
  /// itself.
  Future<String?> getToken() => _messaging.getToken();

  /// Fires whenever FCM rotates the device token (app reinstall, data
  /// clear, token expiry). Callers should re-persist the new value.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Triggers the actual OS permission dialog (only shows anything if
  /// the user hasn't decided yet — otherwise it just returns the
  /// existing status) and, if granted, subscribes to the shared topic.
  /// Call this after the user has agreed via our own explanatory UI,
  /// not blindly on every app start.
  Future<bool> requestPermissionAndSubscribe() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    if (kDebugMode) {
      debugPrint(
        'PushNotificationService: permission status = '
            '${settings.authorizationStatus}',
      );
    }

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    if (granted) {
      try {
        await _messaging.subscribeToTopic('all_users');
        if (kDebugMode) {
          debugPrint("PushNotificationService: subscribed to 'all_users'");
          final token = await _messaging.getToken();
          debugPrint('PushNotificationService: FCM token = $token');
        }
      } catch (e, st) {
        // Don't let a subscription failure look like success — surface
        // it loudly, since this fails silently otherwise.
        debugPrint('PushNotificationService: subscribeToTopic FAILED: $e');
        debugPrint('$st');
      }
    } else if (kDebugMode) {
      debugPrint(
        'PushNotificationService: permission not granted, skipping '
            'topic subscription',
      );
    }

    return granted;
  }

  Future<void> _initLocalNotifications() async {
    // Custom status-bar glyph — a flat white-on-transparent PNG at
    // android/app/src/main/res/drawable-*dpi/ic_stat_wb_twighlight.png
    // (generate via Android Asset Studio's notification icon tool).
    // Android ignores any color in this asset and renders alpha only,
    // so it always shows as a plain white silhouette in the status bar
    // regardless of what color the source art was.
    const androidSettings = AndroidInitializationSettings(
      'ic_stat_wb_twighlight',
    );
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (details) {
        // details.payload carries the drill_event_id set in .show() below.
        final drillEventId = details.payload;
        if (drillEventId != null) {
          onDrillNotificationTap?.call(drillEventId);
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
    >()
        ?.createNotificationChannel(_drillChannel);
  }

  void _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    try {
      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _drillChannel.id,
            _drillChannel.name,
            channelDescription: _drillChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            color: _brandColor,
            // No largeIcon for now — flutter_local_notifications looks
            // up DrawableResourceAndroidBitmap specifically in the
            // `drawable` resource type, but the launcher icon lives in
            // `mipmap`, so it can't be reused here the way it was for
            // the small icon above. Skipping it entirely keeps this
            // simple; add a dedicated drawable-*dpi PNG later if you
            // want a large icon back.
          ),
          iOS: const DarwinNotificationDetails(presentSound: true),
        ),
        payload: message.data['drill_event_id'],
      );
    } catch (e, st) {
      // A display problem here should never take down the FCM message
      // listener itself — log and move on.
      debugPrint('PushNotificationService: failed to show notification: $e');
      debugPrint('$st');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final drillEventId = message.data['drill_event_id'];
    if (kDebugMode) {
      debugPrint('Notification tapped for drill_event_id: $drillEventId');
    }
    if (drillEventId != null) {
      onDrillNotificationTap?.call(drillEventId);
    }
  }
}

/// Required top-level background handler — must be a top-level or static
/// function (not a class method), and must be registered in main()
/// BEFORE runApp(), via:
///   FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
///
/// NOTE: notifications delivered while the app is backgrounded/killed are
/// auto-displayed by the OS from the FCM `notification` payload — this
/// code never runs for the icon/color/largeIcon shown in that case. That
/// styling comes from the `android.notification.icon` / `color` fields
/// set server-side, and does NOT support a large icon via that simple
/// payload path (only foreground notifications, above, get the full-color
/// large icon). Switch to data-only messages if you need the large icon
/// to also appear on background/terminated notifications.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Runs in a separate isolate when the app is backgrounded/killed.
  // Android shows the `notification` payload automatically in this case;
  // keep this handler light. Do heavy work only in response to the tap.
}