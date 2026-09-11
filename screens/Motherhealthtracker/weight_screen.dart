import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_widgets.dart';
import '../../models/mother_tracker_models.dart';

class _WeightTheme {
  static const parrot = Color(0xFFAED581);
  static const midGreen = Color(0xFF7CB342);
  static const darkGreen = Color(0xFF558B2F);

  static const gradient = LinearGradient(
    colors: [parrot, midGreen, darkGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class _MaxThreeDigitsFormatter extends TextInputFormatter {
  static final _pattern = RegExp(r'^\d{0,3}(\.\d{0,1})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    if (_pattern.hasMatch(newValue.text)) return newValue;
    return oldValue;
  }
}

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});
  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  final _formKey = GlobalKey<FormState>();
  final weightController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _WeightTheme.darkGreen, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    try {
      final weight = double.parse(weightController.text.trim());
      await FirestoreService.add(
        'mother_weight',
        MotherWeightModel(weight: weight, date: selectedDate).toMap(),
      );
      if (!mounted) return;
      showTopStatusBanner(context,
          message: 'Weight saved successfully: $weight kg',
          color: _WeightTheme.darkGreen,
          icon: Icons.scale_rounded);
      weightController.clear();
      setState(() => selectedDate = DateTime.now());
    } catch (e) {
      if (!mounted) return;
      showTopStatusBanner(context,
          message: 'Error: $e',
          color: const Color(0xFFEF4444),
          icon: Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _delete(String id) =>
      FirestoreService.delete('mother_weight', id);

  @override
  void dispose() {
    weightController.dispose();
    super.dispose();
  }

  InputDecoration _dec(AppThemeColors theme, String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.5)),
      labelStyle: const TextStyle(
          color: _WeightTheme.darkGreen, fontWeight: FontWeight.w600),
      floatingLabelStyle: const TextStyle(
          color: _WeightTheme.midGreen, fontWeight: FontWeight.w700),
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
          borderSide:
              const BorderSide(color: _WeightTheme.midGreen, width: 1.6)),
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
            iconTheme: const IconThemeData(color: _WeightTheme.darkGreen),
            title: Text('Weight Tracker',
                style: GoogleFonts.poppins(
                    color: _WeightTheme.midGreen, fontWeight: FontWeight.w700)),
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
                          controller: weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]')),
                            _MaxThreeDigitsFormatter(),
                          ],
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: theme.textPrimary),
                          decoration: _dec(theme, 'Weight (kg)', '55.5'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter weight';
                            }
                            final parsed = double.tryParse(v.trim());
                            if (parsed == null) {
                              return 'Enter a valid number';
                            }
                            if (parsed <= 0) {
                              return 'Enter a valid weight';
                            }
                            if (parsed >= 1000) {
                              return 'Weight must be under 1000 kg';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _ThemedDateTile(
                          theme: theme,
                          date: selectedDate,
                          label: 'Record Date',
                          accent: _WeightTheme.midGreen,
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 24),
                        _GradientButton(
                          isLoading: isLoading,
                          onPressed: _save,
                          label: 'Save Weight',
                          gradient: _WeightTheme.gradient,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 320,
                          child: AppRecordStreamList(
                            collection: 'mother_weight',
                            emptyMessage: 'No weight records yet',
                            emptyIcon: Icons.scale_rounded,
                            emptyIconAsset: 'assets/icons/weight.png',
                            emptyAccentColor: _WeightTheme.midGreen,
                            itemBuilder: (context, data, id, pending) {
                              final date = DateTime.tryParse(
                                      data['date']?.toString() ?? '') ??
                                  DateTime.now();
                              return _ThemedRecordCard(
                                theme: theme,
                                iconAsset: 'assets/icons/weight.png',
                                fallbackIcon: Icons.scale_rounded,
                                accent: _WeightTheme.midGreen,
                                title: '${data['weight']} kg',
                                subtitle:
                                    DateFormat('dd MMM yyyy').format(date),
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

class _ThemedDateTile extends StatelessWidget {
  final AppThemeColors theme;
  final DateTime date;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _ThemedDateTile({
    required this.theme,
    required this.date,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(label,
              style: GoogleFonts.poppins(
                  color: accent, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: theme.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 18, color: accent),
                const SizedBox(width: 10),
                Text(DateFormat('dd MMM yyyy').format(date),
                    style: GoogleFonts.poppins(
                        fontSize: 13.5, color: theme.textPrimary)),
              ],
            ),
          ),
        ),
      ],
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
