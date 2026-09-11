import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/firebase_service.dart';
import '../../services/mother_profile_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_widgets.dart';
import '../../models/mother_tracker_models.dart';

class _BPTheme {
  static const pink = Color(0xFFE91E8C);
  static const purple = Color(0xFF7A2790);
  static const purpleMid = Color(0xFFD44FC2);

  static const gradient = LinearGradient(
    colors: [purple, purpleMid, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class _Status {
  static const normal = Color(0xFF10B981);
  static const caution = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
}

class BloodPressureScreen extends StatefulWidget {
  const BloodPressureScreen({super.key});
  @override
  State<BloodPressureScreen> createState() => _BloodPressureScreenState();
}

class _BloodPressureScreenState extends State<BloodPressureScreen> {
  final _formKey = GlobalKey<FormState>();
  final systolicController = TextEditingController();
  final diastolicController = TextEditingController();
  bool isLoading = false;

  ({String label, String message, Color color}) _classifyBP(
      double systolic, double diastolic, int? age) {
    int normalSystolic = 120;
    int normalDiastolic = 80;
    if (age != null) {
      if (age >= 60) {
        normalSystolic = 140;
        normalDiastolic = 90;
      } else if (age >= 40) {
        normalSystolic = 130;
        normalDiastolic = 85;
      }
    }

    const buffer = 10;
    if (systolic >= 180 || diastolic >= 120) {
      return (
        label: 'Very High',
        message: 'Your BP is dangerously high ($systolic/$diastolic mmHg). '
            'Please seek medical attention immediately.',
        color: _Status.danger,
      );
    }

    if (systolic < 80 || diastolic < 50) {
      return (
        label: 'Very Low',
        message: 'Your BP is very low ($systolic/$diastolic mmHg). '
            'Please rest, stay hydrated, and consult your doctor if you '
            'feel dizzy or unwell.',
        color: _Status.danger,
      );
    }

    if (systolic < 90 || diastolic < 60) {
      return (
        label: 'Little Low',
        message: 'Your BP is a little low ($systolic/$diastolic mmHg). '
            'Rest and stay hydrated — keep an eye on it.',
        color: _Status.caution,
      );
    }

    if (systolic > normalSystolic + buffer ||
        diastolic > normalDiastolic + buffer) {
      return (
        label: 'Very High',
        message: 'Your BP is very high ($systolic/$diastolic mmHg). '
            'Please consult your doctor soon.',
        color: _Status.danger,
      );
    }

    if (systolic > normalSystolic || diastolic > normalDiastolic) {
      return (
        label: 'Little High',
        message: 'Your BP is a little high ($systolic/$diastolic mmHg). '
            'Worth mentioning at your next check-up.',
        color: _Status.caution,
      );
    }

    return (
      label: 'Normal',
      message: 'Your BP is normal ($systolic/$diastolic mmHg). Keep it up!',
      color: _Status.normal,
    );
  }

  Future<int?> _getMotherAge() async {
    try {
      final profile = await MotherProfileService()
          .streamProfile()
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      return profile?.age;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    try {
      final systolic = double.parse(systolicController.text.trim());
      final diastolic = double.parse(diastolicController.text.trim());

      await FirestoreService.add(
        'blood_pressure',
        BloodPressureModel(
          systolic: systolic.round(),
          diastolic: diastolic.round(),
        ).toMap(),
      );

      if (!mounted) return;

      final age = await _getMotherAge();
      if (!mounted) return;

      final result = _classifyBP(systolic, diastolic, age);
      showTopStatusBanner(context,
          message: result.message,
          color: result.color,
          icon: Icons.monitor_heart_rounded);

      systolicController.clear();
      diastolicController.clear();
    } catch (e) {
      if (!mounted) return;
      showTopStatusBanner(context,
          message: 'Error: $e',
          color: _Status.danger,
          icon: Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _delete(String id) =>
      FirestoreService.delete('blood_pressure', id);

  @override
  void dispose() {
    systolicController.dispose();
    diastolicController.dispose();
    super.dispose();
  }

  InputDecoration _dec(AppThemeColors theme, String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.5)),
      labelStyle:
          const TextStyle(color: _BPTheme.purple, fontWeight: FontWeight.w600),
      floatingLabelStyle:
          const TextStyle(color: _BPTheme.pink, fontWeight: FontWeight.w700),
      filled: true,
      fillColor: theme.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _BPTheme.pink, width: 1.6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        return Scaffold(
          backgroundColor: theme.bg,
          appBar: AppBar(
            backgroundColor: theme.surface,
            elevation: 0,
            iconTheme: const IconThemeData(color: _BPTheme.pink),
            title: Text('Blood Pressure',
                style: GoogleFonts.poppins(
                    color: _BPTheme.pink, fontWeight: FontWeight.w700)),
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: systolicController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: theme.textPrimary),
                          decoration: _dec(theme, 'Systolic (Upper)', '120'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter systolic value';
                            }
                            final parsed = double.tryParse(v.trim());
                            if (parsed == null) {
                              return 'Enter a valid number';
                            }
                            if (parsed <= 0) {
                              return 'Enter a valid value';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: diastolicController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: theme.textPrimary),
                          decoration: _dec(theme, 'Diastolic (Lower)', '80'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter diastolic value';
                            }
                            final parsed = double.tryParse(v.trim());
                            if (parsed == null) {
                              return 'Enter a valid number';
                            }
                            if (parsed <= 0) {
                              return 'Enter a valid value';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        _GradientButton(
                          isLoading: isLoading,
                          onPressed: _save,
                          label: 'Save Record',
                          gradient: _BPTheme.gradient,
                        ),
                        const SizedBox(height: 14),
                        Text('Full history is available in Records & Graphs',
                            style: GoogleFonts.poppins(
                                color: theme.textSecondary, fontSize: 12.5)),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 320,
                          child: AppRecordStreamList(
                            collection: 'blood_pressure',
                            emptyMessage: 'No blood pressure records yet',
                            emptyIcon: Icons.monitor_heart_rounded,
                            emptyIconAsset: 'assets/icons/blood_pressure.png',
                            emptyAccentColor: _BPTheme.pink,
                            itemBuilder: (context, data, id, pending) {
                              return _ThemedRecordCard(
                                theme: theme,
                                iconAsset: 'assets/icons/blood_pressure.png',
                                fallbackIcon: Icons.monitor_heart_rounded,
                                accent: _BPTheme.pink,
                                title:
                                    'BP: ${data['systolic']}/${data['diastolic']}',
                                subtitle: 'mmHg',
                                onDelete: () => _delete(id),
                                pendingSync: pending,
                              );
                            },
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
    );
  }
}

class _GradientButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final String label;
  final Gradient gradient;

  const _GradientButton({
    required this.isLoading,
    required this.onPressed,
    required this.label,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: (gradient as LinearGradient)
                .colors
                .last
                .withValues(alpha: 0.32),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isLoading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(label,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemedRecordCard extends StatelessWidget {
  final AppThemeColors theme;
  final String iconAsset;
  final IconData fallbackIcon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onDelete;
  final bool pendingSync;

  const _ThemedRecordCard({
    required this.theme,
    required this.iconAsset,
    required this.fallbackIcon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onDelete,
    this.pendingSync = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.isDark;
    final cardColor = isDark
        ? Color.alphaBlend(accent.withValues(alpha: 0.10), theme.surface)
        : theme.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.22 : 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
        border:
            Border.all(color: accent.withValues(alpha: isDark ? 0.20 : 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: theme.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              iconAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(fallbackIcon, color: accent, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: theme.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        color: theme.textSecondary, fontSize: 12)),
                if (pendingSync) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Syncing…',
                        style: TextStyle(
                            fontSize: 9.5,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.red, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

void showTopStatusBanner(BuildContext context,
    {required String message, required Color color, required IconData icon}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _TopBanner(
      message: message,
      color: color,
      icon: icon,
      onDismissed: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _TopBanner extends StatefulWidget {
  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onDismissed;

  const _TopBanner({
    required this.message,
    required this.color,
    required this.icon,
    required this.onDismissed,
  });

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _scheduleDismiss();
  }

  Future<void> _scheduleDismiss() async {
    await Future.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: widget.color.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(widget.icon, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(widget.message,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
