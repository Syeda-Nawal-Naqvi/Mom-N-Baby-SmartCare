import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/firebase_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_widgets.dart';
import '../../models/baby_tracker_models.dart';
import 'baby_tracker_widgets.dart';

const Color _dayBg = Color(0xFFF1F8FF);

const double _maxContentWidth = 640;

class _FieldLimits {
  static const diseaseName = 50;
  static const treatment = 60;
  static const doctorNotes = 350;
}

class BabyMedicalHistoryScreen extends StatefulWidget {
  final String babyId;
  final String babyName;
  const BabyMedicalHistoryScreen(
      {super.key, required this.babyId, required this.babyName});
  @override
  State<BabyMedicalHistoryScreen> createState() =>
      _BabyMedicalHistoryScreenState();
}

class _BabyMedicalHistoryScreenState extends State<BabyMedicalHistoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final diseaseController = TextEditingController();
  final treatmentController = TextEditingController();
  final notesController = TextEditingController();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final wasOffline = !FirestoreService.isOnline.value;

    setState(() => isLoading = true);
    try {
      await FirestoreService.add(
        'baby_medical_history',
        BabyMedicalHistoryModel(
          babyId: widget.babyId,
          disease: diseaseController.text.trim(),
          treatment: treatmentController.text.trim(),
          notes: notesController.text.trim(),
        ).toMap(),
      );
      if (!mounted) return;
      _showStatus(
        wasOffline
            ? 'Saved offline — will sync automatically once you\'re back online'
            : 'Record saved',
      );
      diseaseController.clear();
      treatmentController.clear();
      notesController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      _showStatus('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _delete(String id) =>
      FirestoreService.delete('baby_medical_history', id);

  @override
  void dispose() {
    diseaseController.dispose();
    treatmentController.dispose();
    notesController.dispose();
    super.dispose();
  }

  InputDecoration _dec(
    AppThemeColors theme,
    Color accent,
    String label,
    String iconAsset,
    IconData fallbackIcon,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: theme.textSecondary),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(10),
        child: Image.asset(
          iconAsset,
          width: 22,
          height: 22,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Icon(fallbackIcon, color: accent, size: 22),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        final accent = ThemeService.solidOf(ThemeService.medicalGradient);
        final pageBg = theme.isDark ? theme.bg : _dayBg;

        return Scaffold(
          backgroundColor: pageBg,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            backgroundColor: theme.isDark ? theme.surface : Colors.white,
            elevation: 0,
            title: Text('${widget.babyName} — Medical History',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, color: theme.textPrimary)),
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: _maxContentWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: diseaseController,
                                    maxLength: _FieldLimits.diseaseName,
                                    style: TextStyle(color: theme.textPrimary),
                                    decoration: _dec(
                                        theme,
                                        accent,
                                        'Disease Name',
                                        'assets/icons/medical_report.png',
                                        Icons.healing_rounded),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Enter disease name';
                                      }
                                      if (v.trim().length >
                                          _FieldLimits.diseaseName) {
                                        return 'Max ${_FieldLimits.diseaseName} characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: treatmentController,
                                    maxLength: _FieldLimits.treatment,
                                    style: TextStyle(color: theme.textPrimary),
                                    decoration: _dec(
                                        theme,
                                        accent,
                                        'Treatment / Medicine',
                                        'assets/icons/medical_report.png',
                                        Icons.medication_rounded),
                                    validator: (v) {
                                      if (v != null &&
                                          v.trim().length >
                                              _FieldLimits.treatment) {
                                        return 'Max ${_FieldLimits.treatment} characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: notesController,
                                    maxLines: 3,
                                    maxLength: _FieldLimits.doctorNotes,
                                    style: TextStyle(color: theme.textPrimary),
                                    decoration: _dec(
                                        theme,
                                        accent,
                                        'Doctor Notes',
                                        'assets/icons/medical_report.png',
                                        Icons.note_alt_rounded),
                                    validator: (v) {
                                      if (v != null &&
                                          v.trim().length >
                                              _FieldLimits.doctorNotes) {
                                        return 'Max ${_FieldLimits.doctorNotes} characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: ThemeService.medicalGradient,
                                      boxShadow: [
                                        BoxShadow(
                                            color:
                                                accent.withValues(alpha: 0.32),
                                            blurRadius: 16,
                                            offset: const Offset(0, 8)),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: isLoading ? null : _save,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 15),
                                          child: Center(
                                            child: isLoading
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color:
                                                                Colors.white))
                                                : const Text('Save Record',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14.5,
                                                        fontWeight:
                                                            FontWeight.w700)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_statusMessage != null)
                                    InlineStatusBanner(
                                      message: _statusMessage!,
                                      isError: _statusIsError,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 360,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: AppRecordStreamList(
                                  collection: 'baby_medical_history',
                                  babyId: widget.babyId,
                                  emptyMessage:
                                      'No records found for ${widget.babyName}',
                                  emptyIcon: Icons.healing_rounded,
                                  emptyIconAsset:
                                      'assets/icons/medical_report.png',
                                  emptyAccentColor: accent,
                                  itemBuilder: (context, data, id, pending) {
                                    final cardColor = theme.isDark
                                        ? Color.alphaBlend(
                                            accent.withValues(alpha: 0.10),
                                            theme.surface)
                                        : theme.surface;
                                    return BabyTrackerZoomCard(
                                      glowColor: accent,
                                      borderRadius: BorderRadius.circular(16),
                                      restBlur: 10,
                                      restAlpha: theme.isDark ? 0.22 : 0.14,
                                      activeAlpha: 0.40,
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: accent.withValues(
                                                  alpha: 0.25)),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            BabyTrackerIconBadge(
                                              iconAsset:
                                                  'assets/icons/medical_report.png',
                                              fallbackIcon:
                                                  Icons.healing_rounded,
                                              accent: accent,
                                              size: 44,
                                              isDark: theme.isDark,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(data['disease'] ?? '',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 13.5,
                                                          color: theme
                                                              .textPrimary)),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                      'Treatment: ${data['treatment'] ?? '-'}\nNotes: ${data['notes'] ?? '-'}',
                                                      style: TextStyle(
                                                          color: theme
                                                              .textSecondary,
                                                          fontSize: 12)),
                                                  if (pending) ...[
                                                    const SizedBox(height: 4),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: ThemeService
                                                            .warning
                                                            .withValues(
                                                                alpha: 0.16),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: const Text(
                                                          'Syncing…',
                                                          style: TextStyle(
                                                              fontSize: 9.5,
                                                              color:
                                                                  ThemeService
                                                                      .warning,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600)),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: ThemeService.danger,
                                                  size: 20),
                                              onPressed: () => _delete(id),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
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
