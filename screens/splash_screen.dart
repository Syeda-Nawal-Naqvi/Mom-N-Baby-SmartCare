import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/app_notification_service.dart';
import '../services/notification_sound_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _loadingController;

  late Animation<double> _fadeAnim;
  late Animation<double> _loadingAnim;

  final String mainQuote = 'Every new beginning\nis filled with love!';
  final String subQuote = "Let's walk this beautiful journey\ntogether";

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
        const AssetImage('assets/images/splash_bg.jpg'),
        context,
      );
    });

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );

    _loadingAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );

    _startSequence();
  }

  void _startSequence() async {
    _fadeController.forward();
    _loadingController.forward();

    await Future.delayed(const Duration(milliseconds: 6000));

    if (mounted) {
      _navigate();
    }
  }

  Future<void> _navigate() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('isFirstTime') ?? true;

    if (!mounted) return;

    if (isFirstTime) {
      Navigator.pushReplacementNamed(context, '/onboarding');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final online = FirestoreService.isOnline.value;

    try {
      if (online) {
        await user.reload();
        await AuthService().syncEmailAfterVerification();
      }
      if (!mounted) return;

      final freshUser = FirebaseAuth.instance.currentUser ?? user;

      if (!freshUser.emailVerified) {
        Navigator.pushReplacementNamed(context, '/verify_email');
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(freshUser.uid)
          .get(GetOptions(
              source: online ? Source.serverAndCache : Source.cache));

      if (!mounted) return;
      if (online && doc.exists && (doc.data()?['blocked'] == true)) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final role = doc.exists ? (doc.data()?['role'] ?? 'mother') : 'mother';

      if (!doc.exists && online) {
        await AuthService().ensureUserDoc();
      }

      if (!mounted) return;
      AppNotificationService().hasUnreadNotifications().then((hasUnread) {
        if (hasUnread) NotificationSoundService().playPopIfEnabled();
      });

      if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFFDE8EF),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/splash_bg.jpg',
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
            errorBuilder: (_, __, ___) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFDE8EF),
                      Color(0xFFF9C8D8),
                      Color(0xFFF5B8CC),
                    ],
                  ),
                ),
              );
            },
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xEEFDE8EF),
                  Color(0xAAF9C8D8),
                  Color(0x44F5B8CC),
                ],
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 440.w),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 24.h),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: 28.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Text(
                              'Mother And Baby SmartCare',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: GoogleFonts.baloo2(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE91E8C),
                                letterSpacing: 0.3,
                                height: 1.15,
                              ),
                            ),
                          ),
                          SizedBox(height: 35.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 28.w),
                            child: Column(
                              children: [
                                Text(
                                  mainQuote,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 34.sp,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        const Color.fromARGB(255, 134, 2, 75),
                                    height: 1.1,
                                    shadows: [
                                      Shadow(
                                        color:
                                            Colors.white.withValues(alpha: 0.8),
                                        blurRadius: 8,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 18.h),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        subQuote,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w400,
                                          color: const Color(0xFF5C3040),
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      '❤️',
                                      style: TextStyle(fontSize: 16.sp),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 35.h),
                          Text(
                            'loading...',
                            style: GoogleFonts.dancingScript(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFD81B6A)
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 90.w),
                            child: AnimatedBuilder(
                              animation: _loadingAnim,
                              builder: (_, __) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(4.r),
                                  child: LinearProgressIndicator(
                                    value: _loadingAnim.value,
                                    backgroundColor: Colors.pink.shade100
                                        .withValues(alpha: 0.6),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      Color(0xFFE91E8C),
                                    ),
                                    minHeight: 3.h,
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 28.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
