import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/firebase_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_widgets.dart';
import '../../models/baby_tracker_models.dart';
import 'baby_tracker_widgets.dart';

const double _kgPerLb = 0.45359237;

class BabyWeightScreen extends StatefulWidget {
  final String babyId;
  final String babyName;
  const BabyWeightScreen(
      {super.key, required this.babyId, required this.babyName});
  @override
  State<BabyWeightScreen> createState() => _BabyWeightScreenState();
}

enum _WeightUnit { kg, lb }

class _BabyWeightScreenState extends State<BabyWeightScreen> {
  final _formKey = GlobalKey<FormState>();
  final weightController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  _WeightUnit unit = _WeightUnit.kg;
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
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final wasOffline = !FirestoreService.isOnline.value;

    setState(() => isLoading = true);
    try {
      final entered = double.parse(weightController.text.trim());
      final kg = unit == _WeightUnit.kg ? entered : entered * _kgPerLb;
      await FirestoreService.add(
        'baby_weight',
        BabyWeightModel(
          babyId: widget.babyId,
          weight: kg,
          enteredUnit: unit == _WeightUnit.kg ? 'kg' : 'lb',
          date: selectedDate,
        ).toMap(),
      );
      if (!mounted) return;
      _showStatus(
        wasOffline
            ? 'Saved offline — will sync automatically once you\'re back online'
            : 'Baby weight saved',
      );
      weightController.clear();
      setState(() => selectedDate = DateTime.now());
    } catch (e) {
      if (!mounted) return;
      _showStatus('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _delete(String id) => FirestoreService.delete('baby_weight', id);

  @override
  void dispose() {
    weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        final accent = ThemeService.solidOf(ThemeService.weightGradient);
        return Scaffold(
          backgroundColor: theme.bg,
          appBar: AppBar(
            backgroundColor: theme.surface,
            elevation: 0,
            title: Text('${widget.babyName} — Weight',
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
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: weightController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      style:
                                          TextStyle(color: theme.textPrimary),
                                      decoration: InputDecoration(
                                        labelText:
                                            'Weight (${unit == _WeightUnit.kg ? 'kg' : 'lb'})',
                                        labelStyle: TextStyle(
                                            color: theme.textSecondary),
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Image.asset(
                                            'assets/icons/weight.png',
                                            width: 22,
                                            height: 22,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => Icon(
                                                Icons.monitor_weight_rounded,
                                                color: accent,
                                                size: 22),
                                          ),
                                        ),
                                        prefixIconConstraints:
                                            const BoxConstraints(
                                                minWidth: 44, minHeight: 44),
                                        filled: true,
                                        fillColor: theme.surfaceAlt,
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: theme.border)),
                                        enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: theme.border)),
                                        focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: accent, width: 1.6)),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Enter weight';
                                        }
                                        final parsed =
                                            double.tryParse(v.trim());
                                        if (parsed == null) {
                                          return 'Enter a valid number';
                                        }
                                        final kgEquivalent =
                                            unit == _WeightUnit.kg
                                                ? parsed
                                                : parsed * _kgPerLb;
                                        if (kgEquivalent <= 0 ||
                                            kgEquivalent > 60) {
                                          return 'Enter a realistic weight';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _UnitToggle(
                                    theme: theme,
                                    accent: accent,
                                    unit: unit,
                                    onChanged: (u) => setState(() => unit = u),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _DateTile(
                                theme: theme,
                                accent: accent,
                                date: selectedDate,
                                onTap: _pickDate,
                              ),
                              const SizedBox(height: 18),
                              _GradientButton(
                                isLoading: isLoading,
                                onPressed: _save,
                                label: 'Save Weight',
                                gradient: ThemeService.weightGradient,
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
                          collection: 'baby_weight',
                          babyId: widget.babyId,
                          orderByField: 'date',
                          emptyMessage:
                              'No weight records yet for ${widget.babyName}',
                          emptyIcon: Icons.monitor_weight_rounded,
                          emptyIconAsset: 'assets/icons/weight.png',
                          emptyAccentColor: accent,
                          itemBuilder: (context, data, id, pending) {
                            final date = DateTime.tryParse(
                                    data['date']?.toString() ?? '') ??
                                DateTime.now();
                            final kg =
                                (data['weight'] as num?)?.toDouble() ?? 0;
                            final lb = kg / _kgPerLb;
                            return _ThemedRecordCard(
                              theme: theme,
                              iconAsset: 'assets/icons/weight.png',
                              fallbackIcon: Icons.monitor_weight_rounded,
                              accent: accent,
                              title:
                                  '${kg.toStringAsFixed(2)} kg  •  ${lb.toStringAsFixed(2)} lb',
                              subtitle: DateFormat('dd MMM yyyy').format(date),
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

class _UnitToggle extends StatelessWidget {
  final AppThemeColors theme;
  final Color accent;
  final _WeightUnit unit;
  final ValueChanged<_WeightUnit> onChanged;

  const _UnitToggle({
    required this.theme,
    required this.accent,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, _WeightUnit value) {
      final selected = unit == value;
      return GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? ThemeService.weightGradient : null,
            color: selected ? null : theme.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : theme.textSecondary)),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('Kg', _WeightUnit.kg),
          seg('Lb', _WeightUnit.lb),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final AppThemeColors theme;
  final Color accent;
  final DateTime date;
  final VoidCallback onTap;
  const _DateTile(
      {required this.theme,
      required this.accent,
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
            Text(DateFormat('dd MMM yyyy').format(date),
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
