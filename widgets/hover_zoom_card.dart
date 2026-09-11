import 'package:flutter/material.dart';

/// Wraps [child] with the same press/hover "lift and zoom" interaction
/// used by the Home screen's health-tracker module cards — a small scale
/// + upward lift on hover (desktop/web), and a brief pop-out scale on tap
/// before [onTap] fires. Purely cosmetic; layout of [child] is untouched.
class HoverZoomCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const HoverZoomCard({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
  });

  @override
  State<HoverZoomCard> createState() => _HoverZoomCardState();
}

class _HoverZoomCardState extends State<HoverZoomCard> {
  bool _hover = false;
  bool _pressed = false;
  bool _opening = false;

  Future<void> _handleTap() async {
    setState(() {
      _pressed = false;
      _opening = true;
    });
    await Future.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    widget.onTap();
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _opening
        ? 1.06
        : _pressed
            ? 0.96
            : 1.0;
    final lift = _hover && !_pressed && !_opening ? -3.0 : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => _handleTap(),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: Duration(milliseconds: _opening ? 180 : 140),
          curve: _opening ? Curves.easeOutBack : Curves.easeOut,
          transform: Matrix4.identity()
            ..scaleByDouble(scale, scale, 1.0, 1.0)
            ..translateByDouble(0.0, lift, 0.0, 1.0),
          transformAlignment: Alignment.center,
          clipBehavior: Clip.none,
          child: widget.child,
        ),
      ),
    );
  }
}
