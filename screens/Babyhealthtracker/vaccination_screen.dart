import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/firebase_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_widgets.dart';
import '../../models/baby_tracker_models.dart';
import 'baby_tracker_widgets.dart';

class VaccinationScreen extends StatefulWidget {
  final String babyId;
  final String babyName;
  const VaccinationScreen(
      {super.key, required this.babyId, required this.babyName});
  @override
  State<VaccinationScreen> createState() => _VaccinationScreenState();
}

class _VaccinationScreenState extends State<VaccinationScreen> {
  final _formKey = GlobalKey<FormState>();
  final vaccineController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  String status = 'Pending';
  bool isLoading = false;

  String? _statusMessage;
  bool _statusIsError = false;

  void _showStatus(String message, {bool isError = false}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
    Future.delayed(Duration(seconds: isError ? 4 : 3), () {
      if (!mounted) return;
      if (_statusMessage == message) {
        setState(() => _statusMessage = null);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final wasOffline = !FirestoreService.isOnline.value;

    setState(() => isLoading = true);
    try {
      await FirestoreService.add(
        'vaccinations',
        VaccinationModel(
          babyId: widget.babyId,
          vaccineName: vaccineController.text.trim(),
          vaccinationDate: selectedDate,
          status: status,
        ).toMap(),
      );
      if (!mounted) return;
      _showStatus(
        wasOffline
            ? 'Saved offline — will sync automatically once you\'re back online'
            : 'Vaccination saved',
      );
      vaccineController.clear();
      setState(() {
        selectedDate = DateTime.now();
        status = 'Pending';
      });
    } catch (e) {
      if (!mounted) return;
      _showStatus('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _delete(String id) =>
      FirestoreService.delete('vaccinations', id);

  @override
  void dispose() {
    vaccineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        final accent = ThemeService.solidOf(ThemeService.vaccinationGradient);
        return Scaffold(
          backgroundColor: theme.bg,
          appBar: AppBar(
            backgroundColor: theme.surface,
            elevation: 0,
            title: Text('${widget.babyName} — Vaccination',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, color: theme.textPrimary)),
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: Column(
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _Field(
                                theme: theme,
                                accent: accent,
                                controller: vaccineController,
                                label: 'Vaccine Name',
                                iconAsset: 'assets/icons/vaccination.png',
                                fallbackIcon: Icons.vaccines_rounded,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Enter vaccine name'
                                        : null,
                              ),
                              const SizedBox(height: 12),
                              _DateTile(
                                theme: theme,
                                accent: accent,
                                label: 'Vaccination Date',
                                date: selectedDate,
                                onTap: _pickDate,
                              ),
                              const SizedBox(height: 12),
                              _StatusToggle(
                                theme: theme,
                                accent: accent,
                                status: status,
                                onChanged: (v) => setState(() => status = v),
                              ),
                              const SizedBox(height: 18),
                              _GradientButton(
                                isLoading: isLoading,
                                onPressed: _save,
                                label: 'Save Vaccination',
                                gradient: ThemeService.vaccinationGradient,
                              ),
                              if (_statusMessage != null)
                                InlineStatusBanner(
                                  message: _statusMessage!,
                                  isError: _statusIsError,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AppRecordStreamList(
                          collection: 'vaccinations',
                          babyId: widget.babyId,
                          orderByField: 'vaccinationDate',
                          emptyMessage:
                              'No vaccination records for ${widget.babyName}',
                          emptyIcon: Icons.vaccines_rounded,
                          emptyIconAsset: 'assets/icons/vaccination.png',
                          emptyAccentColor: accent,
                          itemBuilder: (context, data, id, pending) {
                            final vDate = DateTime.tryParse(
                                data['vaccinationDate']?.toString() ?? '');
                            return _ThemedRecordCard(
                              theme: theme,
                              iconAsset: 'assets/icons/vaccination.png',
                              fallbackIcon: Icons.vaccines_rounded,
                              accent: accent,
                              title: data['vaccineName'] ?? '',
                              subtitle:
                                  'Date: ${vDate != null ? DateFormat('dd MMM yyyy').format(vDate) : '-'}   •   Status: ${data['status'] ?? '-'}',
                              onDelete: () => _delete(id),
                              pendingSync: pending,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusToggle extends StatelessWidget {
  final AppThemeColors theme;
  final Color accent;
  final String status;
  final ValueChanged<String> onChanged;
  const _StatusToggle(
      {required this.theme,
      required this.accent,
      required this.status,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(String label) {
      final selected = status == label;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: selected ? ThemeService.vaccinationGradient : null,
              color: selected ? null : theme.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : theme.textSecondary)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Row(children: [
        seg('Pending'),
        const SizedBox(width: 4),
        seg('Completed')
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final AppThemeColors theme;
  final Color accent;
  final TextEditingController controller;
  final String label;
  final String iconAsset;
  final IconData fallbackIcon;
  final String? Function(String?)? validator;

  const _Field({
    required this.theme,
    required this.accent,
    required this.controller,
    required this.label,
    required this.iconAsset,
    required this.fallbackIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: theme.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.textSecondary),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset(iconAsset,
              width: 22,
              height: 22,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(fallbackIcon, color: accent, size: 22)),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 44),
        filled: true,
        fillColor: theme.surfaceAlt,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accent, width: 1.6)),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final AppThemeColors theme;
  final Color accent;
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateTile(
      {required this.theme,
      required this.accent,
      required this.label,
      required this.date,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: theme.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: accent, size: 20),
            const SizedBox(width: 10),
            Text('$label: ${DateFormat('dd MMM yyyy').format(date)}',
                style: TextStyle(color: theme.textPrimary)),
          ],
        ),
      ),
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
    final accent = ThemeService.solidOf(gradient);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 8)),
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
                          strokeWidth: 2, color: Colors.white))
                  : Text(label,
                      style: const TextStyle(
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
    return BabyTrackerZoomCard(
      glowColor: accent,
      borderRadius: BorderRadius.circular(16),
      restBlur: 10,
      restAlpha: 0.30,
      activeAlpha: 0.62,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            BabyTrackerIconBadge(
              iconAsset: iconAsset,
              fallbackIcon: fallbackIcon,
              accent: accent,
              size: 44,
              isDark: theme.isDark,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: theme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(color: theme.textSecondary, fontSize: 12)),
                  if (pendingSync) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: ThemeService.warning.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Syncing…',
                          style: TextStyle(
                              fontSize: 9.5,
                              color: ThemeService.warning,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: ThemeService.danger, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
