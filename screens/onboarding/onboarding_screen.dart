import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onboarding_page1.dart';
import 'onboarding_page2.dart';
import 'onboarding_page3.dart';
import 'onboarding_page4.dart';
import 'onboarding_page5.dart';
import '../../utils/onboarding_style.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();

  int _currentPage = 0;

  final List<Widget> _pages = const [
    OnboardingPage1(),
    OnboardingPage2(),
    OnboardingPage3(),
    OnboardingPage4(),
    OnboardingPage5(),
  ];

  OnboardingColorScheme get _scheme =>
      OnboardingStyle.pageSchemes[_currentPage];

  bool get _isLastPage => _currentPage == _pages.length - 1;

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      'isFirstTime',
      false,
    );

    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      '/login',
    );
  }

  void _onNextPressed() {
    if (_isLastPage) {
      _finishOnboarding();
    } else {
      _controller.nextPage(
        duration: const Duration(
          milliseconds: 380,
        ),
        curve: Curves.easeOutCubic,
      );
    }
  }

  double _clamp(
    double value,
    double min,
    double max,
  ) {
    return value.clamp(min, max).toDouble();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scheme.background.last,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            final isLandscape = width > height;
            final isSmallHeight = height < 650;

            final contentWidth = _clamp(
              width * 0.88,
              300,
              560,
            );

            final horizontalPadding = _clamp(
              width * 0.05,
              16,
              30,
            );
            final bottomPadding = isSmallHeight ? 22.0 : 34.0;

            final buttonHeight = isSmallHeight ? 48.0 : 54.0;

            return AnimatedContainer(
              duration: const Duration(
                milliseconds: 250,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _scheme.background,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        PageView(
                          controller: _controller,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          children: _pages,
                        ),
                        Positioned(
                          top: isLandscape ? 4 : 8,
                          right: horizontalPadding,
                          child: AnimatedOpacity(
                            opacity: _isLastPage ? 0.0 : 1.0,
                            duration: const Duration(
                              milliseconds: 300,
                            ),
                            child: IgnorePointer(
                              ignoring: _isLastPage,
                              child: TextButton(
                                onPressed: _finishOnboarding,
                                style: TextButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.55),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: _clamp(
                                      width * 0.045,
                                      16,
                                      22,
                                    ),
                                    vertical: 10,
                                  ),
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(
                                    milliseconds: 300,
                                  ),
                                  style: GoogleFonts.poppins(
                                    color: _scheme.title,
                                    fontWeight: FontWeight.w700,
                                    fontSize: _clamp(
                                      width * 0.042,
                                      15,
                                      19,
                                    ),
                                  ),
                                  child: const Text('Skip'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      isLandscape ? 6 : 10,
                      horizontalPadding,
                      bottomPadding,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _pages.length,
                                (index) {
                                  final selected = _currentPage == index;

                                  return AnimatedContainer(
                                    duration: const Duration(
                                      milliseconds: 250,
                                    ),
                                    margin: EdgeInsets.symmetric(
                                      horizontal: _clamp(
                                        width * 0.01,
                                        3,
                                        5,
                                      ),
                                    ),
                                    width: selected
                                        ? _clamp(
                                            width * 0.06,
                                            20,
                                            28,
                                          )
                                        : _clamp(
                                            width * 0.02,
                                            7,
                                            10,
                                          ),
                                    height: _clamp(
                                      height * 0.012,
                                      6,
                                      9,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: selected
                                          ? LinearGradient(
                                              colors: _scheme.ring,
                                            )
                                          : null,
                                      color: selected
                                          ? null
                                          : _scheme.ring[0].withValues(
                                              alpha: 0.22,
                                            ),
                                      borderRadius: BorderRadius.circular(
                                        5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(
                              height: isLandscape
                                  ? 8
                                  : _clamp(
                                      height * 0.018,
                                      10,
                                      18,
                                    ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              height: buttonHeight,
                              child: OnboardingStyle.gradientButton(
                                label: _isLastPage ? 'Get Started' : 'Next',
                                onPressed: _onNextPressed,
                                colors: _scheme.ring,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
