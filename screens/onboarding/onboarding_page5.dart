import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/onboarding_style.dart';

class OnboardingPage5 extends StatelessWidget {
  const OnboardingPage5({super.key});

  static const _scheme = OnboardingStyle.emeraldCombo;

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
                : _clamp(width * 0.51, 170, 235);

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
                            'assets/icons/onboarding5.png',
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
                            'Cloud Sync & Security',
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
                            'Keep your health records securely stored and synchronized through the cloud. Access your data safely across devices anytime while ensuring full protection of your information.',
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
