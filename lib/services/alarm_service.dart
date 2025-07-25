import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class AlarmService {
  static Future<void> initializeTimeZones() async {
    tz.initializeTimeZones();
    debugPrint('Initialized TimeZone Name: ${tz.local.name}'); // Seharusnya 'Asia/Jakarta' atau timezone lokal perangkat
  }

  static Future<void> requestExactAlarmPermission() async {
    if (await Permission.scheduleExactAlarm.status.isDenied) {
      await openAppSettings();
    }
  }

  static Future<void> setAlarm(String medicationName, int hour, int minute) async {
    int id = (medicationName.hashCode + hour + minute).abs(); 
    debugPrint('ID: $id');

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'medimate_alarm_channel_id',
      'Pengingat Minum Obat',
      channelDescription: 'Notifikasi untuk mengingatkan Anda minum obat sesuai jadwal.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
      icon: '@mipmap/ic_notification',
      // sound: RawResourceAndroidNotificationSound('optimus'),
      //icon: 'drawable/ic_notification',
      // smallIcon: 'drawable/ic_notification',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Waktunya minum obat!',
      'Saatnya minum $medicationName pada jam ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}.', // Isi notifikasi
      scheduledDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'medication_name:$medicationName,id:$id',
    );

    print('Alarm diatur untuk $medicationName pada ${scheduledDate.toIso8601String()} dengan ID: $id');
  }

  static Future<void> cancelAlarm(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    print('Alarm dengan ID $id dibatalkan.');
  }

  static Future<void> cancelAllAlarms() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    print('Semua alarm dibatalkan.');
  }
}