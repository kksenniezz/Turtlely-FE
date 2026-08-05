import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 기존 import들
import 'style.dart';
import 'splash.dart';
import 'home.dart';
import 'alarm.dart';
import 'exercise.dart';
import 'report.dart';
import 'mypage.dart';

// 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("백그라운드 메시지 수신: ${message.messageId}");
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 전역에서 안 읽은 알림 상태를 관리하는 ValueNotifier
final ValueNotifier<bool> hasUnreadNotification = ValueNotifier<bool>(false);

// ★ 프론트 단독 알림을 담아둘 전역 리스트 ★
final List<Map<String, dynamic>> localNotifications = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await _setupNotification();

  await initializeDateFormatting('ko_KR', null);
  await Hive.initFlutter();

  runApp(const TurtlelyApp());
}

Future<void> _setupNotification() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('알림 권한 상태: ${settings.authorizationStatus}');

  try {
    String? token = await FirebaseMessaging.instance.getToken();
    print("FCM Token: $token");
  } catch (e) {
    print("FCM 토큰 발급 일시 실패 (설정 확인 필요): $e");
  }

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: '거북목 자세 경고 알림 채널입니다.',
    importance: Importance.max,
  );

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(channel);
  }

  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) {
      print("Notification tapped: ${details.payload}");
    },
  );

  // Foreground 푸시 수신 시 즉시 빨간 점 활성화
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      hasUnreadNotification.value = true;

      _showLocalNotification(
        message.notification!.title ?? "알림",
        message.notification!.body ?? "",
      );
    }
  });
}

// 서버 및 로컬 안 읽은 알림이 있는지 확인하는 함수
Future<void> checkInitialUnreadStatus() async {
  // 로컬 알림 중 안 읽은 항목이 있으면 점 활성화
  if (localNotifications.any((n) => n['is_read'] != true)) {
    hasUnreadNotification.value = true;
    return;
  }

  try {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'accessToken');
    if (token == null || token.isEmpty) return;

    final response = await http.get(
      Uri.parse(
        "http://54.144.66.35.nip.io:8080/api/notifications?page=0&size=50",
      ),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final list = json['result']['notification_list'] as List<dynamic>;
      final hasUnread =
          list.any((n) => n['is_read'] != true) ||
          localNotifications.any((n) => n['is_read'] != true);
      hasUnreadNotification.value = hasUnread;
    }
  } catch (e) {
    print("알림 상태 확인 실패: $e");
  }
}

void _showLocalNotification(String title, String body) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidDetails,
  );

  int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

  await flutterLocalNotificationsPlugin.show(
    id: notificationId,
    title: title,
    body: body,
    notificationDetails: platformChannelSpecifics,
  );
}

class TurtlelyApp extends StatelessWidget {
  const TurtlelyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: TColor.white,
      ),
      home: const Splash(),
    );
  }
}

class TurtlelyMainPage extends StatefulWidget {
  const TurtlelyMainPage({super.key});

  @override
  State<TurtlelyMainPage> createState() => _TurtlelyMainPageState();
}

class _TurtlelyMainPageState extends State<TurtlelyMainPage> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = const [
      HomeViewContent(),
      ReportView(),
      ExerciseView(),
      MyPageView(),
    ];

    // 메인 페이지 진입 즉시 안 읽은 알림 상태 조회
    checkInitialUnreadStatus();
  }

  // 상단 뒤로가기 화살표가 제거된 깔끔한 종료 다이얼로그
  Future<bool> _showExitConfirmDialog(BuildContext context) async {
    final bool? shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const Text(
                  "앱을 종료하시겠습니까?",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE0E0E0),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text(
                            "취소",
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF91A88C),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(dialogContext).pop(true);
                          },
                          child: const Text(
                            "확인",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;

        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return;
        }

        final bool shouldExit = await _showExitConfirmDialog(context);
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: _selectedIndex == 1
            ? null
            : AppBar(
                toolbarHeight: 80,
                backgroundColor: TColor.white,
                elevation: 0,
                centerTitle: true,
                automaticallyImplyLeading: false,
                title: Text("Turtlely", style: TText.logo),
                actions: [
                  ValueListenableBuilder<bool>(
                    valueListenable: hasUnreadNotification,
                    builder: (context, hasUnread, child) {
                      return Stack(
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AlarmView(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.notifications_none,
                              color: TColor.black,
                              size: 26,
                            ),
                          ),
                          if (hasUnread)
                            Positioned(
                              right: 10,
                              top: 14,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE24B4A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: Container(
          height: 80,
          decoration: const BoxDecoration(
            color: TColor.white,
            border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, "Home", 0),
              _buildNavItem(Icons.bar_chart_rounded, "Report", 1),
              _buildNavItem(Icons.fitness_center, "Exercise", 2),
              _buildNavItem(Icons.person_outline, "MyPage", 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? TColor.buttonGreen
                  : TColor.black.withOpacity(0.4),
              size: 28,
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? TColor.buttonGreen
                    : TColor.black.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
