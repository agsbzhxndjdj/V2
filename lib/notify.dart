import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Notify {
  static final _p = FlutterLocalNotificationsPlugin();

  static Future init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _p.initialize(const InitializationSettings(android: android));
    try {
      await _p
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  static Future newMovies(int count, String channel) async {
    await _p.show(
      DateTime.now().millisecondsSinceEpoch ~/ 60000 % 100000,
      '🎬 أفلام جديدة وصلت!',
      '$count فيلم جديد من قناة $channel',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'new_movies', 'أفلام جديدة',
          channelDescription: 'تنبيه عند وصول أفلام جديدة',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }
}
