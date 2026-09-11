import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/firebase_service.dart';
import '../../services/theme_service.dart';
import '../../services/baby_tracker_intro_banner_service.dart';
import '../../widgets/app_widgets.dart';
import '../../models/baby_profile_model.dart';
import 'baby_profile_detail_screen.dart';
import 'baby_tracker_widgets.dart';

class BabyListScreen extends StatefulWidget {
  const BabyListScreen({super.key});
  @override
  State<BabyListScreen> createState() => _BabyListScreenState();
}

class _BabyListScreenState extends State<BabyListScreen> {
  bool _showIntroBanner = false;

  @override
  void initState() {
    super.initState();
    _checkIntroBanner();
  }

  Future<void> _checkIntroBanner() async {
    final show = await BabyTrackerIntroBannerService.shouldShow();
    if (!mounted) return;
    setState(() => _showIntroBanner = show);
  }

  void _dismissIntroBanner() {
    setState(() => _showIntroBanner = false);
    BabyTrackerIntroBannerService.markDismissed();
  }

  void _openAddBabySheet({String? babyId, Map<String, dynamic>? initialData}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBabySheet(babyId: babyId, initialData: initialData),
    );
  }

  void _confirmDelete(
      BuildContext context, bool isDark, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.surface(isDark),
        title: Text('Delete baby profile?',
            style: TextStyle(color: ThemeService.textPrimary(isDark))),
        content: Text(
            'This removes $name\'s profile. Their weight, vaccination, milestone, allergy and medical history records are kept separately and are not deleted automatically.',
            style: TextStyle(color: ThemeService.textSecondary(isDark))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              FirestoreService.delete('babies', id);
            },
            child: const Text('Delete',
                style: TextStyle(color: ThemeService.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final bg = ThemeService.bg(isDark);
    final surface = ThemeService.surface(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        title: Text('Baby Profiles',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: textPrimary)),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: ThemeService.profileGradient,
          boxShadow: [
            BoxShadow(
                color: ThemeService.activeAccent(isDark).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => _openAddBabySheet(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Add Baby',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          if (_showIntroBanner)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _BabyTrackerIntroBanner(
                isDark: isDark,
                surface: surface,
                textSecondary: textSecondary,
                onDismiss: _dismissIntroBanner,
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.stream('babies'),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AppEmptyState(
                    message: 'Could not load baby profiles: ${snapshot.error}',
                    icon: Icons.error_outline_rounded,
                  );
                }
                if (!snapshot.hasData) {
                  return Center(
                      child: CircularProgressIndicator(
                          color: ThemeService.activeAccent(isDark)));
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return _EmptyBabiesPrompt(
                      isDark: isDark, onCreate: _openAddBabySheet);
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final dob =
                        DateTime.tryParse(data['dob']?.toString() ?? '') ??
                            DateTime.now();
                    final gender = (data['gender'] ?? '').toString();
                    return _BabyProfileCard(
                      isDark: isDark,
                      name: data['name'] ?? '',
                      gender: gender,
                      bloodGroup: data['bloodGroup'] ?? '',
                      dob: dob,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BabyProfileDetailScreen(
                            babyId: doc.id,
                            babyName: (data['name'] ?? '').toString().isEmpty
                                ? 'Baby'
                                : data['name'],
                            gender: gender,
                          ),
                        ),
                      ),
                      onEdit: () =>
                          _openAddBabySheet(babyId: doc.id, initialData: data),
                      onDelete: () => _confirmDelete(
                          context, isDark, doc.id, data['name'] ?? 'this baby'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBabiesPrompt extends StatelessWidget {
  final bool isDark;
  final VoidCallback onCreate;
  const _EmptyBabiesPrompt({required this.isDark, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                  gradient: ThemeService.profileGradient,
                  shape: BoxShape.circle),
              child: const Icon(Icons.child_care_rounded,
                  size: 42, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text('Create a Baby Profile to Get Started',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary)),
            const SizedBox(height: 8),
            Text(
              'You need at least one baby profile before you can record weight, vaccinations, milestones, allergies or medical history.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: textSecondary),
            ),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: ThemeService.profileGradient,
                boxShadow: [
                  BoxShadow(
                      color: ThemeService.activeAccent(isDark)
                          .withValues(alpha: 0.32),
                      blurRadius: 16,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onCreate,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    child: Text('Create Baby Profile',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BabyTrackerIntroBanner extends StatelessWidget {
  final bool isDark;
  final Color surface;
  final Color textSecondary;
  final VoidCallback onDismiss;

  static const Color _blue = babyTrackerBrightBlue;

  const _BabyTrackerIntroBanner({
    required this.isDark,
    required this.surface,
    required this.textSecondary,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _blue.withValues(alpha: isDark ? 0.32 : 0.24),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: isDark ? 0.32 : 0.20),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.info_outline_rounded, color: _blue, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add a baby profile below to get started. Each baby keeps '
              'their own separate Weight, Vaccination, Milestone, Allergy '
              'and Medical History records — this information is only '
              'used to tell each baby\'s records apart, and you can add '
              'more than one baby at any time.',
              style: GoogleFonts.poppins(
                  fontSize: 11.5, color: textSecondary, height: 1.35),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 18, color: textSecondary.withValues(alpha: 0.7)),
            splashRadius: 16,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _BabyProfileCard extends StatelessWidget {
  final bool isDark;
  final String name;
  final String gender;
  final String bloodGroup;
  final DateTime dob;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BabyProfileCard({
    required this.isDark,
    required this.name,
    required this.gender,
    required this.bloodGroup,
    required this.dob,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final surface = ThemeService.surface(isDark);
    final border = ThemeService.border(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);
    final cardAccent =
        isDark ? ThemeService.activeAccent(isDark) : babyTrackerBrightBlue;

    return BabyTrackerZoomCard(
      glowColor: cardAccent,
      borderRadius: BorderRadius.circular(20),
      restAlpha: 0.16,
      activeAlpha: 0.40,
      restBlur: 14,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: Image.asset(
                      genderFeetAsset(gender),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.child_care_rounded,
                        color: ThemeService.activeAccentLight(isDark),
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isEmpty ? 'Baby' : name,
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textPrimary)),
                        const SizedBox(height: 3),
                        Text(
                            '$gender  •  $bloodGroup  •  ${DateFormat('dd MMM yyyy').format(dob)}',
                            style: GoogleFonts.poppins(
                                fontSize: 11.5, color: textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_rounded,
                        color: ThemeService.activeAccentLight(isDark),
                        size: 20),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: ThemeService.danger, size: 20),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddBabySheet extends StatefulWidget {
  final String? babyId;

  final Map<String, dynamic>? initialData;

  const _AddBabySheet({this.babyId, this.initialData});

  bool get isEditing => babyId != null;

  @override
  State<_AddBabySheet> createState() => _AddBabySheetState();
}

class _AddBabySheetState extends State<_AddBabySheet> {
  final _formKey = GlobalKey<FormState>();
  late final nameController = TextEditingController(
      text: (widget.initialData?['name'] ?? '').toString());
  late String gender = _validGender(widget.initialData?['gender'] as String?);
  late String bloodGroup =
      _validBloodGroup(widget.initialData?['bloodGroup'] as String?);

  static const genderOptions = ['Male', 'Female', 'Transgender'];
  static const bloodGroupOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'Unknown',
  ];

  static String _validGender(String? value) {
    return genderOptions.contains(value) ? value! : 'Male';
  }

  static String _validBloodGroup(String? value) {
    return bloodGroupOptions.contains(value) ? value! : 'Unknown';
  }

  late DateTime selectedDOB =
      DateTime.tryParse(widget.initialData?['dob']?.toString() ?? '') ??
          DateTime.now();
  bool isLoading = false;

  String? _statusMessage;
  bool _statusIsError = false;

  void _showStatus(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<void> _pickDOB() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDOB,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => selectedDOB = picked);
  }

  Future<void> _saveBaby() async {
    if (!_formKey.currentState!.validate()) return;

    final wasOffline = !FirestoreService.isOnline.value;

    setState(() {
      isLoading = true;
      _statusMessage = null;
    });
    final data = BabyProfileModel(
      name: nameController.text.trim(),
      gender: gender,
      bloodGroup: bloodGroup,
      dob: selectedDOB,
    ).toMap();
    try {
      if (widget.isEditing) {
        await FirestoreService.update('babies', widget.babyId!, data);
      } else {
        await FirestoreService.add('babies', data);
      }
      if (!mounted) return;
      final baseMessage = widget.isEditing
          ? 'Baby profile updated successfully'
          : 'Baby profile created successfully';
      _showStatus(
        wasOffline
            ? 'Saved offline — will sync automatically once you\'re back online'
            : baseMessage,
      );
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showStatus('Error: $e', isError: true);
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  InputDecoration _dec(bool isDark, String label, IconData icon,
      {String? iconAsset}) {
    final accent =
        isDark ? ThemeService.activeAccentLight(isDark) : babyTrackerBrightBlue;
    return InputDecoration(
      labelText: label,
      prefixIcon: iconAsset != null
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                iconAsset,
                width: 22,
                height: 22,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Icon(icon, color: accent, size: 20),
              ),
            )
          : Icon(icon, color: accent, size: 20),
      prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
      labelStyle: TextStyle(color: ThemeService.textSecondary(isDark)),
      filled: true,
      fillColor: ThemeService.surfaceAlt(isDark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ThemeService.border(isDark))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ThemeService.border(isDark))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final surface = ThemeService.surface(isDark);
    final border = ThemeService.border(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: availableHeight * 0.96,
          ),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              24 + media.padding.bottom,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                          color: border,
                          borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                      widget.isEditing
                          ? 'Edit Baby Profile'
                          : 'New Baby Profile',
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                      widget.isEditing
                          ? 'Update this baby\'s details. Existing weight, vaccination, milestone, allergy and medical records are not affected.'
                          : 'This information is used to keep each baby\'s records separate.',
                      style: GoogleFonts.poppins(
                          fontSize: 12.5, color: textSecondary)),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: nameController,
                    style: TextStyle(color: textPrimary),
                    decoration: _dec(isDark, 'Baby Name', Icons.badge_rounded,
                        iconAsset: 'assets/icons/baby_name.png'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter baby name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text('Gender',
                      style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: textSecondary)),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 390;
                      final itemWidth = compact
                          ? (constraints.maxWidth - 8) / 2
                          : (constraints.maxWidth - 16) / 3;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: genderOptions
                            .map(
                              (g) => SizedBox(
                                width: itemWidth,
                                child: _GenderChoiceTile(
                                  isDark: isDark,
                                  label: g,
                                  asset: genderFeetAsset(g),
                                  selected: gender == g,
                                  onTap: () => setState(() => gender = g),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickDOB,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: ThemeService.surfaceAlt(isDark),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/icons/calendar.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.calendar_month_rounded,
                                color: Color(0xFF5B9BD5),
                                size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'DOB: ${DateFormat('dd MMM yyyy').format(selectedDOB)}',
                            style: TextStyle(color: textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: bloodGroup,
                    dropdownColor: surface,
                    style: TextStyle(color: textPrimary),
                    decoration: _dec(
                        isDark, 'Blood Group', Icons.bloodtype_rounded,
                        iconAsset: 'assets/icons/blood_group.png'),
                    items: bloodGroupOptions
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => bloodGroup = v ?? bloodGroup),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: ThemeService.profileGradient,
                      boxShadow: [
                        BoxShadow(
                            color: ThemeService.activeAccent(isDark)
                                .withValues(alpha: 0.32),
                            blurRadius: 16,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: isLoading ? null : _saveBaby,
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
                                : Text(
                                    widget.isEditing
                                        ? 'Update Baby Profile'
                                        : 'Save Baby Profile',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
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
      ),
    );
  }
}

class _GenderChoiceTile extends StatelessWidget {
  final bool isDark;
  final String label;
  final String asset;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChoiceTile({
    required this.isDark,
    required this.label,
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceAlt = ThemeService.surfaceAlt(isDark);
    final border = ThemeService.border(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);
    final accentLight = ThemeService.activeAccentLight(isDark);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          gradient: selected ? ThemeService.profileGradient : null,
          color: selected ? null : surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? Colors.transparent : border, width: 1.2),
        ),
        child: Column(
          children: [
            Image.asset(
              asset,
              width: 26,
              height: 26,
              errorBuilder: (_, __, ___) => Icon(Icons.wc_rounded,
                  color: selected ? Colors.white : accentLight),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : textSecondary)),
          ],
        ),
      ),
    );
  }
}
