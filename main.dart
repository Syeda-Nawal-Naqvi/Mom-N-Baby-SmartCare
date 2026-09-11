import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'firebase_options.dart';
import 'services/theme_service.dart';
import 'services/firebase_service.dart';
import 'services/local_notification_service.dart';
import 'services/session_guard_service.dart';

import 'screens/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/auth/set_password_screen.dart';
import 'screens/auth/security_alert_screen.dart';
import 'screens/auth/need_help_screen.dart';

import 'screens/userdashboard/home_screen.dart';
import 'screens/userdashboard/profile_screen.dart';
import 'screens/userdashboard/settings_screen.dart';
import 'screens/Notifications/notifications_screen.dart';
import 'screens/feedback/my_feedback_screen.dart';

import 'screens/Motherhealthtracker/mother_health_screen.dart';
import 'screens/Babyhealthtracker/baby_list_screen.dart';
import 'screens/RecordsAndGraphs/records_and_graphs_screen.dart';
import 'screens/ShareRecords/share_records_screen.dart';

import 'screens/Shop/shop_screen.dart';

import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_users_screen.dart';
import 'screens/admin/admin_mothers_screen.dart';
import 'screens/admin/admin_babies_screen.dart';
import 'screens/admin/admin_feedback_screen.dart';
import 'screens/admin/admin_send_notification_screen.dart';
import 'screens/admin/admin_settings_screen.dart';
import 'screens/admin/admin_notifications_screen.dart';
import 'screens/admin/admin_help_requests_screen.dart';

import 'utils/app_lifecycle_observer.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<bool> appIsResumed = ValueNotifier<bool>(false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirestoreService.init();

  await LocalNotificationService().init();

  SessionGuardService().start();

  final themeNotifier = ThemeNotifier();
  await themeNotifier.loadSavedPrefs();

  WidgetsBinding.instance.addObserver(AppLifecycleObserver(
    onStateChanged: (resumed) {
      appIsResumed.value = resumed;
    },
  ));

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(
    ChangeNotifierProvider.value(
      value: themeNotifier,
      child: const MotherAndBabySmartCare(),
    ),
  );
}

class MotherAndBabySmartCare extends StatelessWidget {
  const MotherAndBabySmartCare({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();

    final themeData = themeNotifier.themeData;

    final appTheme = themeNotifier.isDarkMode
        ? ThemeData.dark(useMaterial3: true).copyWith(
            textTheme: GoogleFonts.poppinsTextTheme(
              themeData.textTheme,
            ),
            colorScheme: themeData.colorScheme,
            scaffoldBackgroundColor: themeData.scaffoldBackgroundColor,
            cardColor: themeData.cardColor,
            appBarTheme: themeData.appBarTheme,
            switchTheme: themeData.switchTheme,
            dividerColor: themeData.dividerColor,
            inputDecorationTheme: themeData.inputDecorationTheme,
            dialogTheme: themeData.dialogTheme,
          )
        : ThemeData.light(useMaterial3: true).copyWith(
            textTheme: GoogleFonts.poppinsTextTheme(
              themeData.textTheme,
            ),
            colorScheme: themeData.colorScheme,
            scaffoldBackgroundColor: themeData.scaffoldBackgroundColor,
            cardColor: themeData.cardColor,
            appBarTheme: themeData.appBarTheme,
            switchTheme: themeData.switchTheme,
            dividerColor: themeData.dividerColor,
            inputDecorationTheme: themeData.inputDecorationTheme,
            dialogTheme: themeData.dialogTheme,
          );

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Mother And Baby SmartCare',
          theme: appTheme,
          darkTheme: appTheme,
          themeMode: ThemeMode.light,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/forgot_password': (context) => const ForgotPasswordScreen(),
            '/need_help': (context) => const NeedHelpScreen(),
            '/verify_email': (context) => const VerifyEmailScreen(),
            '/dashboard': (context) => const HomeScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/notifications': (context) => const NotificationsScreen(),
            '/my_feedback': (context) => const MyFeedbackScreen(),
            '/mother_tracker': (context) => const MotherHealthScreen(),
            // Baby Health Tracker now opens straight to the Baby
            // Profiles list -- the old intermediate BabyHealthScreen
            // (which just had one "Baby Profiles" menu tile) was
            // removed, so this route goes directly where that tile
            // used to lead.
            '/baby_tracker': (context) => const BabyListScreen(),
            '/records': (context) => const RecordsGraphsScreen(),
            '/share_records': (context) => const ShareRecordsScreen(),
            '/shop': (context) => const ShopScreen(),
            '/admin_dashboard': (context) => const AdminDashboardScreen(),
            '/admin_users': (context) => const AdminUsersScreen(),
            '/admin_mothers': (context) => const AdminMothersScreen(),
            '/admin_babies': (context) => const AdminBabiesScreen(),
            '/admin_feedback': (context) => const AdminFeedbackScreen(),
            '/admin_notifications': (context) =>
                const AdminNotificationsScreen(),
            '/admin_settings': (context) => const AdminSettingsScreen(),
            '/admin_send_notification': (context) =>
                const AdminSendNotificationScreen(),
            '/admin_help_requests': (context) =>
                const AdminHelpRequestsScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/set_password') {
              final role = settings.arguments is String
                  ? settings.arguments as String
                  : 'mother';
              return MaterialPageRoute(
                builder: (_) => SetPasswordScreen(role: role),
                settings: settings,
              );
            }
            if (settings.name == '/security_alert') {
              final args = settings.arguments;
              String? sessionId;
              String? notificationId;
              if (args is Map) {
                sessionId = args['sessionId']?.toString();
                notificationId = args['notificationId']?.toString();
              }
              return MaterialPageRoute(
                builder: (_) => SecurityAlertScreen(
                  sessionId: sessionId,
                  notificationId: notificationId,
                ),
                settings: settings,
              );
            }
            return null;
          },
        );
      },
    );
  }
}
