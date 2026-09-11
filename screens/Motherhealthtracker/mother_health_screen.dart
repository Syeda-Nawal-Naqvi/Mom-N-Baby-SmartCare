import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/mother_profile_model.dart';
import '../../services/mother_profile_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_widgets.dart';
import 'blood_pressure_screen.dart';
import 'glucose_screen.dart';
import 'weight_screen.dart';
import 'medical_history_screen.dart';
import 'mother_profile_screen.dart';

class _Palette {
  static const pink = Color(0xFFE91E8C);
  static const purple = Color(0xFF7A2790);
  static const purpleMid = Color(0xFFD44FC2);
  static const blue = Color(0xFF3B82F6);
  static const parrotGreen = Color(0xFF7CB342);
  static const yellowShadow = Color(0xFFFBBF24);
  static const darkYellowText = Color(0xFFB45309);
  static const mediumPink = Color(0xFFC2185B);
}

class MotherHealthScreen extends StatelessWidget {
  const MotherHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final bg = ThemeService.bg(isDark);
    final surface = ThemeService.surface(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: _Palette.pink),
        title: Text('Mother Health Tracker',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: textPrimary)),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: StreamBuilder<MotherProfileModel?>(
              stream: MotherProfileService().streamProfile(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _Palette.pink));
                }
                final profile = snapshot.data;
                if (profile == null) {
                  return _ProfileRequiredView(isDark: isDark);
                }
                return _TrackerMenu(profile: profile, isDark: isDark);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRequiredView extends StatelessWidget {
  final bool isDark;
  const _ProfileRequiredView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textSecondary = ThemeService.textSecondary(isDark);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_add_alt_1_rounded,
                size: 56, color: _Palette.pink),
            const SizedBox(height: 14),
            Text(
              'Set up the mother profile first',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _Palette.purple),
            ),
            const SizedBox(height: 6),
            Text(
              'Name, age, blood group and delivery dates are required '
              'before you can use blood pressure, glucose, weight or '
              'medical history tracking.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [_Palette.purple, _Palette.purpleMid, _Palette.pink],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                      color: _Palette.pink.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MotherProfileScreen()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    child: Text('Set Up Profile',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackerMenu extends StatelessWidget {
  final MotherProfileModel profile;
  final bool isDark;
  const _TrackerMenu({required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final trackers = [
      {
        'title': 'Blood Pressure',
        'icon': 'assets/icons/blood_pressure.png',
        'color': _Palette.pink,
        'route': const BloodPressureScreen(),
      },
      {
        'title': 'Glucose Level',
        'icon': 'assets/icons/glucose.png',
        'color': _Palette.blue,
        'route': const GlucoseScreen(),
      },
      {
        'title': 'Weight',
        'icon': 'assets/icons/weight.png',
        'color': _Palette.parrotGreen,
        'route': const WeightScreen(),
      },
      {
        'title': 'Medical History',
        'icon': 'assets/icons/medical_report.png',
        'color': _Palette.yellowShadow,
        'textColor': _Palette.darkYellowText,
        'route': const MedicalHistoryScreen(),
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ProfileSummaryCard(profile: profile),
        const SizedBox(height: 22),
        Text('Trackers',
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? ThemeService.textPrimary(isDark)
                    : _Palette.mediumPink)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1,
          ),
          itemCount: trackers.length,
          itemBuilder: (context, index) {
            final t = trackers[index];
            return _TrackerCard(
              title: t['title'] as String,
              iconPath: t['icon'] as String,
              accentColor: t['color'] as Color,
              textColor: isDark
                  ? ThemeService.textPrimary(true)
                  : ((t['textColor'] as Color?) ?? (t['color'] as Color)),
              isDark: isDark,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => t['route'] as Widget),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  final MotherProfileModel profile;
  const _ProfileSummaryCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_Palette.purple, _Palette.purpleMid, _Palette.pink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: _Palette.pink.withValues(alpha: 0.32),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MotherProfileScreen(existingProfile: profile),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset(
                    'assets/icons/edit_clr.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Age: ${profile.age}  •  Blood Group: ${profile.bloodGroup}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
          if (profile.deliveries.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Deliveries:',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 12.5)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: profile.deliveries
                  .map((d) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${d.label}: ${d.date}',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _Palette.purple)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackerCard extends StatefulWidget {
  final String title;
  final String iconPath;
  final Color accentColor;
  final Color textColor;
  final bool isDark;
  final VoidCallback onTap;

  const _TrackerCard({
    required this.title,
    required this.iconPath,
    required this.accentColor,
    required this.textColor,
    required this.isDark,
    required this.onTap,
  });

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
    final scale = _opening ? 1.10 : (_pressed ? 0.96 : 1.0);
    final baseSurface = ThemeService.surface(widget.isDark);
    final iconTileBg = widget.isDark
        ? ThemeService.darkTintedChip(widget.accentColor, amount: 0.22)
        : Colors.white;

    final restAlpha = widget.isDark ? 0.24 : 0.20;
    final activeAlpha = _opening ? 0.55 : 0.42;

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
          decoration: BoxDecoration(
            color: _active
                ? widget.accentColor
                    .withValues(alpha: widget.isDark ? 0.16 : 0.08)
                : baseSurface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor
                    .withValues(alpha: _active ? activeAlpha : restAlpha),
                blurRadius: _opening ? 34 : (_active ? 26 : 16),
                offset: _active ? const Offset(0, 10) : const Offset(0, 6),
                spreadRadius: _opening ? 3 : (_active ? 2 : 0.5),
              ),
            ],
            border: Border.all(
              color: _active
                  ? widget.accentColor.withValues(alpha: 0.35)
                  : widget.accentColor
                      .withValues(alpha: widget.isDark ? 0.20 : 0.0),
              width: 1.4,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availW = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 160.0;

                final baseIcon = (availW * 0.62).clamp(64.0, 100.0);
                final iconSize = _active ? baseIcon * 1.06 : baseIcon;
                final fontSize = (availW * 0.115).clamp(11.5, 14.5);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: iconSize,
                      height: iconSize,
                      padding: EdgeInsets.all(iconSize * 0.145),
                      decoration: BoxDecoration(
                        color: iconTileBg,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.45),
                            blurRadius: 22,
                            offset: const Offset(0, 6),
                            spreadRadius: 1.5,
                          ),
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.20),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: widget.accentColor.withValues(alpha: 0.22),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          widget.iconPath,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.health_and_safety_rounded,
                            color: widget.accentColor,
                            size: iconSize * 0.46,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: widget.textColor,
                        height: 1.3,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
