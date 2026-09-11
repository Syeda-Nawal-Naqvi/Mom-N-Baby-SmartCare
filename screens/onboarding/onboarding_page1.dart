import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/onboarding_style.dart';

class OnboardingPage1 extends StatelessWidget {
  const OnboardingPage1({super.key});

  static const _scheme = OnboardingStyle.roseCombo;

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
                ? _clamp(width * 0.28, 150, 210)
                : _clamp(width * 0.52, 170, 240);

            final titleSize = _clamp(width * 0.060, 20, 28);

            final bodySize = _clamp(width * 0.035, 13, 16);

            final imageGap = isSmallHeight ? 16.0 : 26.0;
            final titleGap = isSmallHeight ? 12.0 : 18.0;
            final bodyGap = isSmallHeight ? 8.0 : 12.0;

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
                            'assets/icons/onboarding1.png',
                            ringColors: _scheme.ring,
                            size: imageSize,
                          ),
                          SizedBox(height: imageGap),
                          OnboardingStyle.underline(
                            _scheme.ring,
                          ),
                          SizedBox(height: titleGap),
                          Text(
                            'Mother Health Tracking',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: titleSize,
                              fontWeight: FontWeight.bold,
                              color: _scheme.title,
                            ),
                          ),
                          SizedBox(height: bodyGap),
                          Text(
                            'Create a mother profile and easily monitor health records including BP, glucose, weight and history in one secure place.',
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
