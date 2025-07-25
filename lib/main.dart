import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/login_page.dart';
import 'screens/obat_list_page.dart';
import 'screens/chatbot_page.dart';
import 'screens/obat_history_page.dart';
import 'package:medimate/services/alarm_service.dart';
import 'package:timezone/data/latest_all.dart' as tz; 
import 'package:timezone/timezone.dart' as tz;
//import 'package:flutter_native_timezone/flutter_native_timezone.dart';

// Constants
const String appTitle = 'MediMate - Pendamping Anda';
const Color primaryColor = Colors.teal;

// Route names
class AppRoutes {
  static const login = '/login';
  static const obatList = '/obat-list';
  static const chatbot = '/chatbot';
  static const obatHistory = '/obat-history';
}

// Deklarasikan instance plugin secara global agar bisa diakses oleh AlarmService
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---------------- TIMEZONE ----------------
  tz.initializeTimeZones(); // Inisialisasi data timezone

  // Dapatkan nama timezone dari sistem operasi native
  // final String currentTimeZone = await FlutterNativeTimezone.getLocalTimezone();
  // debugPrint('Native TimeZone: $currentTimeZone'); // Untuk verifikasi

  // Set tz.local ke timezone native yang ditemukan
  try {
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    debugPrint('tz.local set to: ${tz.local.name}'); // Konfirmasi lagi
  } catch (e) {
    debugPrint('Error mengatur tz.local ke Asia/Jakarta: $e');
    debugPrint('Falling back to default tz.local (which might be UTC). Current tz.local: ${tz.local.name}');
  }
  // ------------------------------------------

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  // const AndroidInitializationSettings initializationSettingsAndroid =
  //     AndroidInitializationSettings('@drawable/icon_medimate');
  // const AndroidInitializationSettings initializationSettingsAndroid =
  //      AndroidInitializationSettings('@drawable/icon_medimate');
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  try {
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        final String? payload = notificationResponse.payload;
        if (payload != null) {
          debugPrint('notification payload: $payload');
          // if (MyApp.navigatorKey.currentState != null) {
          //   MyApp.navigatorKey.currentState!.pushNamed(AppRoutes.obatList, arguments: payload);
          // }
        }
      },
      onDidReceiveBackgroundNotificationResponse: (NotificationResponse notificationResponse) async {
        debugPrint('notification background payload: ${notificationResponse.payload}');
      },
    );
    debugPrint('FlutterLocalNotificationsPlugin initialized successfully.');
  } catch (e) {
    debugPrint('Error initializing FlutterLocalNotificationsPlugin: $e');
  }

  // await AlarmService.initializeTimeZones();

  await initializeDateFormatting('id', null);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFDEFDE0), // 🌱 background soft green
        primaryColor: const Color(0xFFA8D5BA), // 🌿 pastel green
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFFA8D5BA),   // 🌿 pastel green
          secondary: const Color(0xFFB9FBC0), // 🍃 mint green
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFF388E3C), // 🌿 pastel green
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA8D5BA),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 18),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: Colors.black87,
              displayColor: Colors.black87,
            ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SessionChecker(),
      routes: {
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.obatList: (context) => const ObatListPage(),
        AppRoutes.chatbot: (context) => const ChatbotPage(),
        AppRoutes.obatHistory: (context) => const ObatHistoryPage(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
    );
  }
}

class SessionChecker extends StatefulWidget {
  const SessionChecker({super.key});

  @override
  State<SessionChecker> createState() => _SessionCheckerState();
}

class _SessionCheckerState extends State<SessionChecker> {
  bool _errorOccurred = false;

  @override
  void initState() {
    super.initState();
    debugPrint('SessionChecker: initState called');
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      debugPrint('SessionChecker: _checkSession started');
      await AlarmService.requestExactAlarmPermission();
      final prefs = await SharedPreferences.getInstance();
      
      debugPrint('SessionChecker: SharedPreferences instance obtained');
      //await prefs.clear();
      final nama = prefs.getString('nama');
      debugPrint('SessionChecker: nama from prefs: $nama');

      if (!mounted) {
        debugPrint('SessionChecker: Widget not mounted, returning.');
        return;
      }

      if (nama != null && nama.trim().isNotEmpty) {
        debugPrint('SessionChecker: Navigating to ObatListPage');
        Navigator.pushReplacementNamed(context, AppRoutes.obatList);
      } else {
        debugPrint('SessionChecker: Navigating to LoginPage');
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } catch (e) {
      if (!mounted) {
        debugPrint('SessionChecker: Error occurred but widget not mounted, returning.');
        return;
      }
      setState(() => _errorOccurred = true);
      debugPrint('Session check error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _errorOccurred
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Gagal memuat data', style: TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _checkSession,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memeriksa sesi...'),
                ],
              ),
      ),
    );
  }
}