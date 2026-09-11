import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/firebase_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_widgets.dart';
import '../../models/baby_tracker_models.dart';
import 'baby_tracker_widgets.dart';

class MilestoneScreen extends StatefulWidget {
  final String babyId;
  final String babyName;
  const MilestoneScreen(
      {super.key, required this.babyId, required this.babyName});
  @override
  State<MilestoneScreen> createState() => _MilestoneScreenState();
}

class _MilestoneScreenState extends State<MilestoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final milestoneController = TextEditingController();
  DateTime selectedDate = DateTime.now();
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
      await FirestoreService.add(
        'milestones',
        MilestoneModel(
          babyId: widget.babyId,
          title: milestoneController.text.trim(),
          milestoneDate: selectedDate,
        ).toMap(),
      );
      if (!mounted) return;
      _showStatus(
        wasOffline
            ? 'Saved offline — will sync automatically once you\'re back online'
            : 'Milestone saved',
      );
      milestoneController.clear();
      setState(() => selectedDate = DateTime.now());
    } catch (e) {
      if (!mounted) return;
      _showStatus('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _delete(String id) => FirestoreService.delete('milestones', id);

  @override
  void dispose() {
    milestoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        final accent = ThemeService.solidOf(ThemeService.milestoneGradient);
        return Scaffold(
          backgroundColor: theme.bg,
          appBar: AppBar(
            backgroundColor: theme.surface,
            elevation: 0,
            title: Text('${widget.babyName} — Milestones',
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
                              TextFormField(
                                controller: milestoneController,
                                style: TextStyle(color: theme.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Milestone (e.g. First Smile)',
                                  labelStyle:
                                      TextStyle(color: theme.textSecondary),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Image.asset(
                                        'assets/icons/milestone.png',
                                        width: 22,
                                        height: 22,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Icon(
                                            Icons.star_rounded,
                                            color: accent,
                                            size: 22)),
                                  ),
                                  prefixIconConstraints: const BoxConstraints(
                                      minWidth: 44, minHeight: 44),
                                  filled: true,
                                  fillColor: theme.surfaceAlt,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: theme.border)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: theme.border)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: accent, width: 1.6)),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Enter milestone'
                                        : null,
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: _pickDate,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: theme.surfaceAlt,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: theme.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_month_rounded,
                                          color: accent, size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                          DateFormat('dd MMM yyyy')
                                              .format(selectedDate),
                                          style: TextStyle(
                                              color: theme.textPrimary)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: ThemeService.milestoneGradient,
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
                                                        color: Colors.white))
                                            : const Text('Save Milestone',
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
                          collection: 'milestones',
                          babyId: widget.babyId,
                          orderByField: 'milestoneDate',
                          emptyMessage:
                              'No milestones found for ${widget.babyName}',
                          emptyIcon: Icons.star_rounded,
                          emptyIconAsset: 'assets/icons/milestone.png',
                          emptyAccentColor: accent,
                          itemBuilder: (context, data, id, pending) {
                            final date = DateTime.tryParse(
                                data['milestoneDate']?.toString() ?? '');
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
                                  border: Border.all(
                                      color: accent.withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  children: [
                                    BabyTrackerIconBadge(
                                      iconAsset: 'assets/icons/milestone.png',
                                      fallbackIcon: Icons.star_rounded,
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
                                          Text(data['title'] ?? '',
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13.5,
                                                  color: theme.textPrimary)),
                                          const SizedBox(height: 2),
                                          Text(
                                              date != null
                                                  ? 'Date: ${DateFormat('dd MMM yyyy').format(date)}'
                                                  : '',
                                              style: TextStyle(
                                                  color: theme.textSecondary,
                                                  fontSize: 12)),
                                          if (pending) ...[
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: ThemeService.warning
                                                    .withValues(alpha: 0.16),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text('Syncing…',
                                                  style: TextStyle(
                                                      fontSize: 9.5,
                                                      color:
                                                          ThemeService.warning,
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
            ],
          ),
        );
      },
    );
  }
}
