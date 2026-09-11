import 'package:flutter/material.dart';

const Color babyTrackerBrightBlue = Color(0xFF129BFF);
const Color babyTrackerDeepBlue = Color(0xFF0077E6);
const Color babyTrackerSkyBlue = Color(0xFF63D3FF);

String genderFeetAsset(String gender) {
  switch (gender.trim().toLowerCase()) {
    case 'female':
    case 'girl':
      return 'assets/icons/girl_feet.png';
    case 'transgender':
      return 'assets/icons/transgender_feet.png';
    case 'male':
    case 'boy':
    default:
      return 'assets/icons/boy_feet.png';
  }
}

class BabyTrackerZoomCard extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final BorderRadius borderRadius;
  final double restBlur;
  final double restAlpha;
  final double activeAlpha;
  final VoidCallback? onTap;

  const BabyTrackerZoomCard({
    super.key,
    required this.child,
    required this.glowColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.restBlur = 18,
    this.restAlpha = 0.30,
    this.activeAlpha = 0.62,
    this.onTap,
  });

  @override
  State<BabyTrackerZoomCard> createState() => _BabyTrackerZoomCardState();
}

class _BabyTrackerZoomCardState extends State<BabyTrackerZoomCard> {
  bool _hover = false;
  bool _pressed = false;

  bool get _active => _hover || _pressed;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.975 : (_hover ? 1.025 : 1.0);
    final shadowColor = widget.glowColor.withValues(
      alpha: _active ? widget.activeAlpha : widget.restAlpha,
    );

    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => _hover = true);
      },
      onExit: (_) {
        if (mounted) {
          setState(() {
            _hover = false;
            _pressed = false;
          });
        }
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (mounted) setState(() => _pressed = true);
        },
        onTapUp: (_) {
          if (mounted) setState(() => _pressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () {
          if (mounted) setState(() => _pressed = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..scaleByDouble(scale, scale, 1.0, 1.0)
            ..translateByDouble(
              0.0,
              _hover && !_pressed ? -4.0 : 0.0,
              0.0,
              1.0,
            ),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius:
                    _active ? widget.restBlur * 2.45 : widget.restBlur * 1.55,
                spreadRadius: _active ? 2.8 : 1.2,
                offset: _active ? const Offset(0, 12) : const Offset(0, 8),
              ),
              BoxShadow(
                color: widget.glowColor.withValues(
                  alpha: _active ? 0.22 : 0.14,
                ),
                blurRadius: _active ? 18 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class BabyTrackerIconBadge extends StatelessWidget {
  final String iconAsset;
  final IconData fallbackIcon;
  final Color accent;
  final double size;
  final bool isDark;

  const BabyTrackerIconBadge({
    super.key,
    required this.iconAsset,
    required this.fallbackIcon,
    required this.accent,
    this.size = 44,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final safeSize = size.clamp(36.0, 72.0);

    return SizedBox(
      width: safeSize,
      height: safeSize,
      child: Container(
        padding: EdgeInsets.all(safeSize * 0.18),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isDark ? 0.28 : 0.18),
          borderRadius: BorderRadius.circular(safeSize * 0.27),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.62 : 0.48),
              blurRadius: safeSize * 0.30,
              spreadRadius: 1.0,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.24 : 0.18),
              blurRadius: safeSize * 0.18,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Image.asset(
          iconAsset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => FittedBox(
            child: Icon(fallbackIcon, color: accent),
          ),
        ),
      ),
    );
  }
}
