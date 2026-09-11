import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/theme_service.dart';
import '../../widgets/app_widgets.dart';
import 'mother_records_graphs_screen.dart';
import 'baby_records_graphs_screen.dart';

/// Landing screen for Records & Graphs.
///
/// The Mother/Baby choice cards use the same compact dimensions and
/// icon sizing as the Share PDF choice cards.
class RecordsGraphsScreen extends StatelessWidget {
  const RecordsGraphsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        return Scaffold(
          backgroundColor: theme.bg,
          appBar: AppBar(
            backgroundColor: theme.surface,
            elevation: 0,
            iconTheme: IconThemeData(color: theme.accent),
            title: Text(
              'Records & Graphs',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What would you like to view?',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose whose health records and progress you want to explore.',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: theme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _RecordsChoiceCard(
                        height: 138,
                        title: 'Mother Records',
                        subtitle:
                            'Weight · Blood Pressure · Glucose · Medical History',
                        iconPath: 'assets/icons/woman.png',
                        fallbackIcon: Icons.pregnant_woman_rounded,
                        gradientColors: const [
                          Color(0xFF7A2790),
                          Color(0xFFD44FC2),
                          Color(0xFFE91E8C),
                        ],
                        glowColor: const Color(0xFFE91E8C),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MotherRecordsGraphsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _RecordsChoiceCard(
                        height: 138,
                        title: 'Baby Records',
                        subtitle:
                            'Pick a baby to view weight, vaccinations & more',
                        iconPath: 'assets/icons/baby.png',
                        fallbackIcon: Icons.child_care_rounded,
                        gradientColors: const [
                          Color(0xFF0E4C92),
                          Color(0xFF1E88C7),
                          Color(0xFF3EE0C9),
                        ],
                        glowColor: const Color(0xFF1E88C7),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BabyRecordsGraphsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecordsChoiceCard extends StatefulWidget {
  final double height;
  final String title;
  final String subtitle;
  final String iconPath;
  final IconData fallbackIcon;
  final List<Color> gradientColors;
  final Color glowColor;
  final VoidCallback onTap;

  const _RecordsChoiceCard({
    required this.height,
    required this.title,
    required this.subtitle,
    required this.iconPath,
    required this.fallbackIcon,
    required this.gradientColors,
    required this.glowColor,
    required this.onTap,
  });

  @override
  State<_RecordsChoiceCard> createState() => _RecordsChoiceCardState();
}

class _RecordsChoiceCardState extends State<_RecordsChoiceCard> {
  bool _hover = false;
  bool _pressed = false;
  bool _opening = false;

  bool get _active => _hover || _pressed || _opening;

  Future<void> _handleTap() async {
    if (_opening) return;

    setState(() {
      _pressed = false;
      _opening = true;
    });

    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final scale =
        _opening ? 1.015 : (_pressed ? 0.985 : (_hover ? 1.008 : 1.0));

    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => _hover = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _hover = false);
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (mounted) setState(() => _pressed = true);
        },
        onTapUp: (_) => _handleTap(),
        onTapCancel: () {
          if (mounted) setState(() => _pressed = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: widget.height,
          transform: Matrix4.identity()
            ..scaleByDouble(scale, scale, 1.0, 1.0)
            ..translateByDouble(
              0.0,
              _hover && !_pressed ? -2.0 : 0.0,
              0.0,
              1.0,
            ),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(
                  alpha: _active ? 0.48 : 0.32,
                ),
                blurRadius: _active ? 24 : 15,
                offset: const Offset(0, 7),
                spreadRadius: _active ? 1.5 : 0.5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned(
                  right: -28,
                  top: -34,
                  child: Container(
                    width: 105,
                    height: 105,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  left: -22,
                  bottom: -36,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: Image.asset(
                          widget.iconPath,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => Icon(
                            widget.fallbackIcon,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.subtitle,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.90),
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white.withValues(
                          alpha: _active ? 1.0 : 0.90,
                        ),
                        size: 17,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
