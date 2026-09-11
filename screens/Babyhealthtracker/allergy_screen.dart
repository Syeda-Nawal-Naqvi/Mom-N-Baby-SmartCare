import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/firebase_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_widgets.dart';
import '../../models/baby_tracker_models.dart';
import 'baby_tracker_widgets.dart';

const Color _dayBg = Color(0xFFF1F8FF);

const double _maxContentWidth = 640;

class AllergyScreen extends StatefulWidget {
  final String babyId;
  final String babyName;
  const AllergyScreen(
      {super.key, required this.babyId, required this.babyName});
  @override
  State<AllergyScreen> createState() => _AllergyScreenState();
}

class _AllergyScreenState extends State<AllergyScreen> {
  final _formKey = GlobalKey<FormState>();
  final allergyController = TextEditingController();
  final reactionController = TextEditingController();
  final adviceController = TextEditingController();
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

  static const int _nameMaxLength = 50;
  static const int _reactionMaxLength = 80;
  static const int _adviceMaxLength = 300;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final wasOffline = !FirestoreService.isOnline.value;

    setState(() => isLoading = true);
    try {
      await FirestoreService.add(
        'allergies',
        AllergyModel(
          babyId: widget.babyId,
          allergyName: allergyController.text.trim(),
          reaction: reactionController.text.trim(),
          advice: adviceController.text.trim(),
        ).toMap(),
      );
      if (!mounted) return;
      _showStatus(
        wasOffline
            ? 'Saved offline — will sync automatically once you\'re back online'
            : 'Allergy saved',
      );
      allergyController.clear();
      reactionController.clear();
      adviceController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      _showStatus('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _delete(String id) => FirestoreService.delete('allergies', id);

  @override
  void dispose() {
    allergyController.dispose();
    reactionController.dispose();
    adviceController.dispose();
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
        final accent = ThemeService.solidOf(ThemeService.allergyGradient);
        final pageBg = theme.isDark ? theme.bg : _dayBg;

        return Scaffold(
          backgroundColor: pageBg,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            backgroundColor: theme.isDark ? theme.surface : Colors.white,
            elevation: 0,
            title: Text('${widget.babyName} — Allergies',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, color: theme.textPrimary)),
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: _maxContentWidth),
                    child: Column(
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: allergyController,
                                    maxLength: _nameMaxLength,
                                    style: TextStyle(color: theme.textPrimary),
                                    decoration: _dec(
                                        theme,
                                        accent,
                                        'Allergy Name',
                                        'assets/icons/allergy.png',
                                        Icons.warning_amber_rounded),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Enter allergy name'
                                            : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: reactionController,
                                    maxLength: _reactionMaxLength,
                                    style: TextStyle(color: theme.textPrimary),
                                    decoration: _dec(
                                        theme,
                                        accent,
                                        'Reaction',
                                        'assets/icons/reaction.png',
                                        Icons.report_problem_rounded),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: adviceController,
                                    maxLines: 3,
                                    maxLength: _adviceMaxLength,
                                    style: TextStyle(color: theme.textPrimary),
                                    decoration: _dec(
                                        theme,
                                        accent,
                                        'Doctor Advice',
                                        'assets/icons/doctor_advice.png',
                                        Icons.medical_services_rounded),
                                  ),
                                  const SizedBox(height: 18),
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: ThemeService.allergyGradient,
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
                                                : const Text('Save Allergy',
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
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: AppRecordStreamList(
                              collection: 'allergies',
                              babyId: widget.babyId,
                              emptyMessage:
                                  'No allergy records for ${widget.babyName}',
                              emptyIcon: Icons.warning_amber_rounded,
                              emptyIconAsset: 'assets/icons/allergy.png',
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
                                  restAlpha: theme.isDark ? 0.36 : 0.30,
                                  activeAlpha: 0.66,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color:
                                              accent.withValues(alpha: 0.25)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        BabyTrackerIconBadge(
                                          iconAsset: 'assets/icons/allergy.png',
                                          fallbackIcon:
                                              Icons.warning_amber_rounded,
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
                                              Text(data['allergyName'] ?? '',
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13.5,
                                                      color:
                                                          theme.textPrimary)),
                                              const SizedBox(height: 2),
                                              Text(
                                                  'Reaction: ${data['reaction'] ?? '-'}\nAdvice: ${data['advice'] ?? '-'}',
                                                  style: TextStyle(
                                                      color:
                                                          theme.textSecondary,
                                                      fontSize: 12)),
                                              if (pending) ...[
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: ThemeService.warning
                                                        .withValues(
                                                            alpha: 0.16),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: const Text('Syncing…',
                                                      style: TextStyle(
                                                          fontSize: 9.5,
                                                          color: ThemeService
                                                              .warning,
                                                          fontWeight:
                                                              FontWeight.w600)),
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
