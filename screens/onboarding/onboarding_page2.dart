import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/onboarding_style.dart';

class OnboardingPage2 extends StatelessWidget {
  const OnboardingPage2({super.key});

  static const _scheme = OnboardingStyle.skyCombo;

  double _clamp(
    double value,
    double min,
    double max,
  ) {
    return value.clamp(min, max).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStyle.pageBackground(
      scheme: _scheme,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            final isLandscape = width > height;
            final isSmallHeight = height < 650;

            final contentWidth = _clamp(
              width * 0.88,
              280,
              560,
            );

            final imageSize = isLandscape
                ? _clamp(width * 0.27, 150, 200)
                : _clamp(width * 0.50, 165, 230);

            final titleSize = _clamp(width * 0.060, 20, 28);
            final bodySize = _clamp(width * 0.035, 13, 16);

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: _clamp(width * 0.06, 20, 32),
                        vertical: 16,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OnboardingStyle.roundedImage(
                            'assets/icons/onboarding2.png',
                            ringColors: _scheme.ring,
                            size: imageSize,
                          ),
                          SizedBox(
                            height: isSmallHeight ? 16 : 26,
                          ),
                          OnboardingStyle.underline(
                            _scheme.ring,
                          ),
                          SizedBox(
                            height: isSmallHeight ? 12 : 18,
                          ),
                          Text(
                            'Baby Health Tracking',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: titleSize,
                              fontWeight: FontWeight.bold,
                              color: _scheme.title,
                            ),
                          ),
                          SizedBox(
                            height: isSmallHeight ? 8 : 12,
                          ),
                          Text(
                            'Manage multiple baby profiles with allergy information, weight tracking, milestone records, and complete medical history to support healthy growth.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: bodySize,
                              height: 1.55,
                              color: _scheme.body,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
