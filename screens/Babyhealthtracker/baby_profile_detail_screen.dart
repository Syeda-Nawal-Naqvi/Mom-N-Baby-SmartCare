import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/theme_service.dart';
import '../../widgets/app_widgets.dart';
import 'allergy_screen.dart';
import 'baby_medical_history_screen.dart';
import 'baby_tracker_widgets.dart';
import 'baby_weight_screen.dart';
import 'milestone_screen.dart';
import 'vaccination_screen.dart';

const double _maxContentWidth = 760;

class BabyProfileDetailScreen extends StatelessWidget {
  final String babyId;
  final String babyName;
  final String gender;
  const BabyProfileDetailScreen({
    super.key,
    required this.babyId,
    required this.babyName,
    this.gender = 'Male',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final bg = ThemeService.bg(isDark);
    final surface = ThemeService.surface(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);

    final sections = [
      _Section(
        title: 'Weight',
        iconAsset: 'assets/icons/weight.png',
        fallbackIcon: Icons.monitor_weight_rounded,
        gradient: ThemeService.weightGradient,
        builder: () => BabyWeightScreen(babyId: babyId, babyName: babyName),
      ),
      _Section(
        title: 'Vaccination',
        iconAsset: 'assets/icons/vaccination.png',
        fallbackIcon: Icons.vaccines_rounded,
        gradient: ThemeService.vaccinationGradient,
        builder: () => VaccinationScreen(babyId: babyId, babyName: babyName),
      ),
      _Section(
        title: 'Milestones',
        iconAsset: 'assets/icons/milestone.png',
        fallbackIcon: Icons.star_rounded,
        gradient: ThemeService.milestoneGradient,
        builder: () => MilestoneScreen(babyId: babyId, babyName: babyName),
      ),
      _Section(
        title: 'Allergies',
        iconAsset: 'assets/icons/allergy.png',
        fallbackIcon: Icons.warning_amber_rounded,
        gradient: ThemeService.allergyGradient,
        builder: () => AllergyScreen(babyId: babyId, babyName: babyName),
      ),
      _Section(
        title: 'Medical History',
        iconAsset: 'assets/icons/medical_report.png',
        fallbackIcon: Icons.medical_information_rounded,
        gradient: ThemeService.medicalGradient,
        builder: () =>
            BabyMedicalHistoryScreen(babyId: babyId, babyName: babyName),
      ),
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(babyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, color: textPrimary)),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 18,
              height: 18,
              child: Image.asset(
                genderFeetAsset(gender),
                width: 18,
                height: 18,
                errorBuilder: (_, __, ___) => Icon(Icons.wc_rounded,
                    size: 18, color: babyTrackerBrightBlue),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ProfileHeaderCard(
                        isDark: isDark, babyName: babyName, gender: gender),
                    const SizedBox(height: 22),
                    Text('Trackers',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textPrimary)),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, gridConstraints) {
                        final w = gridConstraints.maxWidth;
                        final crossAxisCount =
                            w >= 900 ? 4 : (w >= 600 ? 3 : 2);
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio:
                                w >= 900 ? 1.08 : (w >= 600 ? 0.98 : 0.86),
                          ),
                          itemCount: sections.length,
                          itemBuilder: (context, index) {
                            final s = sections[index];
                            return _TrackerCard(
                              isDark: isDark,
                              section: s,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => s.builder()),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section {
  final String title;
  final String iconAsset;
  final IconData fallbackIcon;
  final Gradient gradient;
  final Widget Function() builder;

  _Section({
    required this.title,
    required this.iconAsset,
    required this.fallbackIcon,
    required this.gradient,
    required this.builder,
  });
}

class _ProfileHeaderCard extends StatelessWidget {
  final bool isDark;
  final String babyName;
  final String gender;
  const _ProfileHeaderCard({
    required this.isDark,
    required this.babyName,
    required this.gender,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ThemeService.profileGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: ThemeService.solidOf(ThemeService.profileGradient)
                  .withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          // Clean blue profile icon with NO circular/background asset.
          // Using a Material icon here also keeps the tint consistent
          // on every device and screen size.
          const SizedBox(
            width: 58,
            height: 58,
            child: Center(
              child: Icon(
                Icons.person_rounded,
                color: babyTrackerBrightBlue,
                size: 42,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(babyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: Image.asset(
                        genderFeetAsset(gender),
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.wc_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Growth, vaccinations, milestones and allergies',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackerCard extends StatefulWidget {
  final bool isDark;
  final _Section section;
  final VoidCallback onTap;
  const _TrackerCard(
      {required this.isDark, required this.section, required this.onTap});

  @override
  State<_TrackerCard> createState() => _TrackerCardState();
}

class _TrackerCardState extends State<_TrackerCard> {
  bool _hover = false;
  bool _pressed = false;
  bool _opening = false;

  bool get _active => _hover || _pressed || _opening;

  Future<void> _handleTap() async {
    setState(() {
      _pressed = false;
      _opening = true;
    });
    await Future.delayed(const Duration(milliseconds: 190));
    if (!mounted) return;
    widget.onTap();
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = ThemeService.solidOf(widget.section.gradient);
    final surface = ThemeService.surface(widget.isDark);
    final border = ThemeService.border(widget.isDark);
    final textPrimary = ThemeService.textPrimary(widget.isDark);

    final scale = _opening ? 1.06 : (_pressed ? 0.975 : (_hover ? 1.035 : 1.0));
    final restAlpha = widget.isDark ? 0.42 : 0.34;
    final activeAlpha = _opening ? 0.68 : 0.58;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => _handleTap(),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: Duration(milliseconds: _opening ? 190 : 150),
          curve: _opening ? Curves.easeOutBack : Curves.easeOut,
          transform: Matrix4.identity()
            ..scaleByDouble(scale, scale, 1.0, 1.0)
            ..translateByDouble(
                0.0, _hover && !_pressed && !_opening ? -3.0 : 0.0, 0.0, 1.0),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _active ? accent.withValues(alpha: 0.4) : border,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                  color: accent.withValues(
                      alpha: _active ? activeAlpha : restAlpha),
                  blurRadius: _opening ? 42 : (_active ? 34 : 24),
                  spreadRadius: _active ? 2.4 : 1.0,
                  offset: _active ? const Offset(0, 14) : const Offset(0, 9)),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availW =
                  constraints.maxWidth.isFinite ? constraints.maxWidth : 150.0;
              final baseIcon = (availW * 0.42).clamp(42.0, 64.0);
              final iconSize =
                  (_active ? baseIcon * 1.06 : baseIcon).clamp(42.0, 68.0);
              final titleSize = (availW * 0.115).clamp(11.5, 13.5);

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: iconSize,
                    height: iconSize,
                    padding: EdgeInsets.all(iconSize * 0.08),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(
                            alpha: _active ? 0.48 : 0.30,
                          ),
                          blurRadius: _active ? 22 : 15,
                          spreadRadius: _active ? 2.0 : 0.8,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      widget.section.iconAsset,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Icon(
                        widget.section.fallbackIcon,
                        color: accent,
                        size: iconSize * 0.52,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.section.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w600,
                          color: textPrimary)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
