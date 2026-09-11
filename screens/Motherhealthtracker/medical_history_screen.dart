import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_widgets.dart';
import '../../models/mother_tracker_models.dart';

class _MedicalTheme {
  static const gold = Color(0xFFFBBF24);
  static const amber = Color(0xFFF59E0B);
  static const deepAmber = Color(0xFFB45309);

  static const gradient = LinearGradient(
    colors: [gold, amber, deepAmber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class _FieldLimits {
  static const diseaseName = 50;
  static const medicines = 60;
  static const doctorNotes = 350;
}

class MedicalHistoryScreen extends StatefulWidget {
  const MedicalHistoryScreen({super.key});
  @override
  State<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final diseaseController = TextEditingController();
  final medicineController = TextEditingController();
  final notesController = TextEditingController();
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
              primary: _MedicalTheme.deepAmber, onPrimary: Colors.white),
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
      await FirestoreService.add(
        'medical_history',
        MedicalHistoryModel(
          diseaseName: diseaseController.text.trim(),
          medicines: medicineController.text.trim(),
          doctorNotes: notesController.text.trim(),
          visitDate: selectedDate,
        ).toMap(),
      );
      if (!mounted) return;
      showTopStatusBanner(context,
          message: 'Medical history saved successfully',
          color: _MedicalTheme.deepAmber,
          icon: Icons.medical_information_rounded);
      diseaseController.clear();
      medicineController.clear();
      notesController.clear();
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
      FirestoreService.delete('medical_history', id);

  @override
  void dispose() {
    diseaseController.dispose();
    medicineController.dispose();
    notesController.dispose();
    super.dispose();
  }

  InputDecoration _dec(AppThemeColors theme, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
          color: _MedicalTheme.deepAmber, fontWeight: FontWeight.w600),
      floatingLabelStyle: const TextStyle(
          color: _MedicalTheme.amber, fontWeight: FontWeight.w700),
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
          borderSide: const BorderSide(color: _MedicalTheme.amber, width: 1.6)),
      counterStyle: TextStyle(
        color: theme.textSecondary,
        fontSize: 11,
      ),
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
            iconTheme: const IconThemeData(color: _MedicalTheme.deepAmber),
            title: Text('Medical History',
                style: GoogleFonts.poppins(
                    color: _MedicalTheme.deepAmber,
                    fontWeight: FontWeight.w700)),
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
                          controller: diseaseController,
                          maxLength: _FieldLimits.diseaseName,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                                _FieldLimits.diseaseName),
                          ],
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: theme.textPrimary),
                          decoration: _dec(theme, 'Disease Name'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter disease name';
                            }
                            if (v.trim().length > _FieldLimits.diseaseName) {
                              return 'Max ${_FieldLimits.diseaseName} characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: medicineController,
                          maxLength: _FieldLimits.medicines,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                                _FieldLimits.medicines),
                          ],
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: theme.textPrimary),
                          decoration: _dec(theme, 'Medicines'),
                          validator: (v) {
                            if (v != null &&
                                v.trim().length > _FieldLimits.medicines) {
                              return 'Max ${_FieldLimits.medicines} characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: notesController,
                          maxLines: 4,
                          maxLength: _FieldLimits.doctorNotes,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                                _FieldLimits.doctorNotes),
                          ],
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: theme.textPrimary),
                          decoration: _dec(theme, 'Doctor Notes'),
                          validator: (v) {
                            if (v != null &&
                                v.trim().length > _FieldLimits.doctorNotes) {
                              return 'Max ${_FieldLimits.doctorNotes} characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _ThemedDateTile(
                          theme: theme,
                          date: selectedDate,
                          label: 'Visit Date',
                          accent: _MedicalTheme.amber,
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 24),
                        _GradientButton(
                          isLoading: isLoading,
                          onPressed: _save,
                          label: 'Save Record',
                          gradient: _MedicalTheme.gradient,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 320,
                          child: AppRecordStreamList(
                            collection: 'medical_history',
                            emptyMessage: 'No medical history yet',
                            emptyIcon: Icons.medical_information_rounded,
                            emptyIconAsset: 'assets/icons/medical_report.png',
                            emptyAccentColor: _MedicalTheme.deepAmber,
                            orderByField: 'visitDate',
                            itemBuilder: (context, data, id, pending) {
                              final visit = DateTime.tryParse(
                                  data['visitDate']?.toString() ?? '');
                              return _ThemedRecordCard(
                                theme: theme,
                                iconAsset: 'assets/icons/medical_report.png',
                                fallbackIcon: Icons.medical_information_rounded,
                                accent: _MedicalTheme.deepAmber,
                                title: data['diseaseName'] ?? '',
                                subtitle:
                                    'Medicines: ${data['medicines'] ?? '-'}\nVisit: ${visit != null ? DateFormat('dd MMM yyyy').format(visit) : '-'}',
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
