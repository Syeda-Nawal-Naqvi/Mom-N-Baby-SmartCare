import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/contact_links.dart';

/// "For Collaboration" banner shown on the Shop screen — the same
/// pink-to-purple gradient used elsewhere in the app (Home screen's
/// greeting card / shop banner), a short line, and two circular icon
/// buttons (Instagram + Gmail) that open those channels directly.
///
/// ICONS: expects `assets/icons/instagram.png` and `assets/icons/gmail.png`
/// (already declared under `assets/icons/` in pubspec.yaml). Falls back to
/// a Material icon automatically if a PNG is missing so the layout never
/// breaks.
class CollaborationCard extends StatelessWidget {
  const CollaborationCard({super.key});

  static const Gradient _brandGradient = LinearGradient(
    colors: [Color(0xFF7A2790), Color(0xFFD44FC2), Color(0xFFE91E8C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        gradient: _brandGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B2FA0).withValues(alpha: 0.36),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'For Collaboration',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reach out to us for partnerships and business inquiries.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _iconButton(
                onTap: () => ContactLinks.openInstagram(context),
                assetPath: 'assets/icons/instagram.png',
                fallbackIcon: Icons.camera_alt_rounded,
              ),
              const SizedBox(width: 18),
              _iconButton(
                onTap: () => ContactLinks.openGmail(context),
                assetPath: 'assets/icons/gmail.png',
                fallbackIcon: Icons.mail_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required VoidCallback onTap,
    required String assetPath,
    required IconData fallbackIcon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(11),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Icon(fallbackIcon, color: const Color(0xFF8B2FA0), size: 22),
        ),
      ),
    );
  }
}
