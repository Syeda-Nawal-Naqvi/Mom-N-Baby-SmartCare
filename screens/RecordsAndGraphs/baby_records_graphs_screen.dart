import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/firebase_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_widgets.dart';

/// ═══════════════════════════════════════════════════════════════════
/// Baby Records & Graphs
/// ───────────────────────────────────────────────────────────────────
/// Every card/tile reads `theme.surface` / `theme.surfaceAlt` from the
/// ACTIVE palette. In dark mode, each card is ALWAYS washed with a
/// soft tint of its own accent color and carries an accent-colored
/// glow shadow at rest — hover/press/tap simply intensifies both
/// instead of introducing them from a flat, untinted box.
/// ═══════════════════════════════════════════════════════════════════
class BabyRecordsGraphsScreen extends StatelessWidget {
  const BabyRecordsGraphsScreen({super.key});

  static const List<Color> _babyPalette = [
    Color(0xFFE91E8C),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF7C3AED),
    Color(0xFF06B6D4),
  ];

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        return Scaffold(
          backgroundColor: theme.bg,
          appBar: AppBar(
            backgroundColor: theme.surface,
            elevation: 0,
            iconTheme: IconThemeData(color: theme.accent),
            title: Text(
              'Baby Records & Graphs',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreService.stream('babies'),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(color: theme.accent),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const AppEmptyState(
                        message:
                            'No baby profiles yet.\nCreate one from the Baby Health Tracker first.',
                        icon: Icons.child_care_rounded,
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(18),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.92,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final name = (data['name'] ?? '').toString().isEmpty
                            ? 'Baby'
                            : data['name'].toString();
                        final gender = (data['gender'] ?? '').toString();
                        final color = _babyPalette[index % _babyPalette.length];
                        return _BabyChoiceCard(
                          name: name,
                          gender: gender,
                          accentColor: color,
                          theme: theme,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _BabyModulesScreen(
                                babyId: doc.id,
                                babyName: name,
                                accentColor: color,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Baby picker card — square, contrasting accent color per baby.
// ───────────────────────────────────────────────────────────────────
// Resting state (dark mode): fill = theme.surface blended with a
// light wash of the baby's own accent color; shadow = that same
// accent color at low opacity. Hover / press / tap only turn the
// intensity UP — they are not what introduces the tint or glow.
// ═══════════════════════════════════════════════════════════════════
class _BabyChoiceCard extends StatefulWidget {
  final String name;
  final String gender;
  final Color accentColor;
  final AppThemeColors theme;
  final VoidCallback onTap;

  const _BabyChoiceCard({
    required this.name,
    required this.gender,
    required this.accentColor,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_BabyChoiceCard> createState() => _BabyChoiceCardState();
}

class _BabyChoiceCardState extends State<_BabyChoiceCard> {
  bool _hover = false;
  bool _pressed = false;
  bool _opening = false;

  bool get _active => _hover || _pressed || _opening;

  Future<void> _handleTap() async {
    setState(() {
      _pressed = false;
      _opening = true;
    });
    await Future.delayed(const Duration(milliseconds: 190));
    if (!mounted) return;
    widget.onTap();
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _opening = false);
  }

  IconData get _genderIcon {
    final g = widget.gender.toLowerCase();
    if (g.startsWith('m')) return Icons.boy_rounded;
    if (g.startsWith('f')) return Icons.girl_rounded;
    return Icons.child_care_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final scale = _opening ? 1.08 : (_pressed ? 0.96 : 1.0);
    final isDark = widget.theme.isDark;

    // Resting fill: always tinted with the baby's own accent color in
    // dark mode, not a flat gray box waiting for interaction.
    final restColor = isDark
        ? Color.alphaBlend(
            widget.accentColor.withValues(alpha: 0.10),
            widget.theme.surface,
          )
        : Colors.white;
    final activeColor = isDark
        ? Color.alphaBlend(
            widget.accentColor.withValues(alpha: 0.22),
            widget.theme.surface,
          )
        : Color.alphaBlend(
            widget.accentColor.withValues(alpha: 0.09),
            Colors.white,
          );
    final baseColor = _active ? activeColor : restColor;
    final tileColor = isDark ? widget.theme.surfaceAlt : Colors.white;

    // Resting shadow: a subtle accent-colored glow (dark mode) instead
    // of a flat black shadow — always present, brighter on hover/press.
    final shadowColor = isDark
        ? widget.accentColor.withValues(
            alpha: _active ? (_opening ? 0.55 : 0.42) : 0.16,
          )
        : (_active
            ? widget.accentColor.withValues(alpha: _opening ? 0.55 : 0.42)
            : Colors.black.withValues(alpha: 0.10));

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => _handleTap(),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: Duration(milliseconds: _opening ? 190 : 150),
          curve: _opening ? Curves.easeOutBack : Curves.easeOut,
          transform: Matrix4.identity()
            ..scaleByDouble(scale, scale, 1.0, 1.0)
            ..translateByDouble(
                0.0, _hover && !_pressed && !_opening ? -3.0 : 0.0, 0.0, 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: _opening ? 34 : (_active ? 26 : 16),
                offset: _active ? const Offset(0, 10) : const Offset(0, 6),
                spreadRadius: _opening ? 3 : (_active ? 2 : 0.5),
              ),
            ],
            border: Border.all(
              color: _active
                  ? widget.accentColor.withValues(alpha: 0.4)
                  : (isDark
                      ? widget.accentColor.withValues(alpha: 0.14)
                      : Colors.transparent),
              width: 1.4,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _active ? 66 : 60,
                  height: _active ? 66 : 60,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.34),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                        spreadRadius: 0.5,
                      ),
                    ],
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: Image.asset(
                    'assets/icons/baby.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Icon(_genderIcon, color: widget.accentColor, size: 26),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  widget.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: widget.accentColor,
                  ),
                ),
                if (widget.gender.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.gender,
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Per-baby module data
// ═══════════════════════════════════════════════════════════════════
class _BabyModule {
  final String title;
  final String iconPath;
  final IconData fallbackIcon;
  final Color color;
  final String collection;
  final String field;
  final String unit;
  final bool isNumber;
  final String dateField;

  const _BabyModule({
    required this.title,
    required this.iconPath,
    required this.fallbackIcon,
    required this.color,
    required this.collection,
    required this.field,
    required this.unit,
    this.isNumber = false,
    this.dateField = 'createdAt',
  });
}

// ═══════════════════════════════════════════════════════════════════
// Per-baby module grid — Weight, Vaccination, Allergy, Milestone,
// Medical History as square hoverable cards.
// ═══════════════════════════════════════════════════════════════════
class _BabyModulesScreen extends StatelessWidget {
  final String babyId;
  final String babyName;
  final Color accentColor;

  const _BabyModulesScreen({
    required this.babyId,
    required this.babyName,
    required this.accentColor,
  });

  List<_BabyModule> get _modules => [
        _BabyModule(
          title: 'Weight',
          iconPath: 'assets/icons/weight.png',
          fallbackIcon: Icons.monitor_weight_rounded,
          color: const Color.fromARGB(255, 20, 228, 96),
          collection: 'baby_weight',
          field: 'weight',
          unit: 'kg',
          isNumber: true,
          dateField: 'date',
        ),
        _BabyModule(
          title: 'Vaccination',
          iconPath: 'assets/icons/vaccine.png',
          fallbackIcon: Icons.vaccines_rounded,
          color: const Color(0xFF2F6690),
          collection: 'vaccinations',
          field: 'vaccineName',
          unit: '',
        ),
        _BabyModule(
          title: 'Allergy',
          iconPath: 'assets/icons/allergy.png',
          fallbackIcon: Icons.warning_amber_rounded,
          color: const Color(0xFFB33A4A),
          collection: 'allergies',
          field: 'allergyName',
          unit: '',
        ),
        _BabyModule(
          title: 'Milestone',
          iconPath: 'assets/icons/milestone.png',
          fallbackIcon: Icons.star_rounded,
          color: const Color(0xFF1B8A7C),
          collection: 'milestones',
          field: 'title',
          unit: '',
        ),
        _BabyModule(
          title: 'Medical History',
          iconPath: 'assets/icons/medical_report.png',
          fallbackIcon: Icons.healing_rounded,
          color: const Color.fromARGB(255, 255, 221, 0),
          collection: 'baby_medical_history',
          field: 'disease',
          unit: '',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        final modules = _modules;
        return Scaffold(
          backgroundColor: theme.bg,
          appBar: AppBar(
            backgroundColor: theme.surface,
            elevation: 0,
            iconTheme: IconThemeData(color: accentColor),
            title: Text(
              '$babyName — Records',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(18),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1,
                  ),
                  itemCount: modules.length,
                  itemBuilder: (context, index) {
                    final m = modules[index];
                    return _SquareModuleCard(
                      title: m.title,
                      iconPath: m.iconPath,
                      fallbackIcon: m.fallbackIcon,
                      accentColor: m.color,
                      theme: theme,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _BabyModuleDetailScreen(
                            module: m,
                            babyId: babyId,
                            babyName: babyName,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Square hoverable module card (self-contained copy for this file).
// ───────────────────────────────────────────────────────────────────
// Same always-on accent tint + glow behaviour as the baby picker
// card and the mother-screen module card above.
// ═══════════════════════════════════════════════════════════════════
class _SquareModuleCard extends StatefulWidget {
  final String title;
  final String iconPath;
  final IconData fallbackIcon;
  final Color accentColor;
  final AppThemeColors theme;
  final VoidCallback onTap;

  const _SquareModuleCard({
    required this.title,
    required this.iconPath,
    required this.fallbackIcon,
    required this.accentColor,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_SquareModuleCard> createState() => _SquareModuleCardState();
}

class _SquareModuleCardState extends State<_SquareModuleCard> {
  bool _hover = false;
  bool _pressed = false;
  bool _opening = false;

  bool get _active => _hover || _pressed || _opening;

  Future<void> _handleTap() async {
    setState(() {
      _pressed = false;
      _opening = true;
    });
    await Future.delayed(const Duration(milliseconds: 190));
    if (!mounted) return;
    widget.onTap();
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _opening ? 1.10 : (_pressed ? 0.96 : 1.0);
    final isDark = widget.theme.isDark;

    // Resting fill: always tinted with the module's own accent color
    // in dark mode, not a flat gray box waiting for interaction.
    final restColor = isDark
        ? Color.alphaBlend(
            widget.accentColor.withValues(alpha: 0.10),
            widget.theme.surface,
          )
        : Colors.white;
    final activeColor = isDark
        ? Color.alphaBlend(
            widget.accentColor.withValues(alpha: 0.20),
            widget.theme.surface,
          )
        : Color.alphaBlend(
            widget.accentColor.withValues(alpha: 0.08),
            Colors.white,
          );
    final baseColor = _active ? activeColor : restColor;
    final tileColor = isDark ? widget.theme.surfaceAlt : Colors.white;

    // Resting shadow: a subtle accent-colored glow (dark mode) instead
    // of a flat black shadow — always present, brighter on hover/press.
    final shadowColor = isDark
        ? widget.accentColor.withValues(
            alpha: _active ? (_opening ? 0.55 : 0.42) : 0.16,
          )
        : (_active
            ? widget.accentColor.withValues(alpha: _opening ? 0.55 : 0.42)
            : Colors.black.withValues(alpha: 0.10));

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => _handleTap(),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: Duration(milliseconds: _opening ? 190 : 150),
          curve: _opening ? Curves.easeOutBack : Curves.easeOut,
          transform: Matrix4.identity()
            ..scaleByDouble(scale, scale, 1.0, 1.0)
            ..translateByDouble(
                0.0, _hover && !_pressed && !_opening ? -3.0 : 0.0, 0.0, 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: _opening ? 34 : (_active ? 26 : 16),
                offset: _active ? const Offset(0, 10) : const Offset(0, 6),
                spreadRadius: _opening ? 3 : (_active ? 2 : 0.5),
              ),
            ],
            border: Border.all(
              color: _active
                  ? widget.accentColor.withValues(alpha: 0.35)
                  : (isDark
                      ? widget.accentColor.withValues(alpha: 0.14)
                      : Colors.transparent),
              width: 1.4,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _active ? 68 : 62,
                  height: _active ? 68 : 62,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.32),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                        spreadRadius: 0.5,
                      ),
                    ],
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: Image.asset(
                    widget.iconPath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      widget.fallbackIcon,
                      color: widget.accentColor,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Detail screen: trend graph (for numeric modules) + editable,
// hoverable record list, scoped to this baby.
// ═══════════════════════════════════════════════════════════════════
class _BabyModuleDetailScreen extends StatelessWidget {
  final _BabyModule module;
  final String babyId;
  final String babyName;

  const _BabyModuleDetailScreen({
    required this.module,
    required this.babyId,
    required this.babyName,
  });

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        return Scaffold(
          backgroundColor: theme.bg,
          appBar: AppBar(
            backgroundColor: theme.surface,
            elevation: 0,
            iconTheme: IconThemeData(color: module.color),
            title: Text(
              '$babyName · ${module.title}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (module.isNumber) ...[
                      Text(
                        'Trend',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ModuleTrendChart(
                        collection: module.collection,
                        field: module.field,
                        color: module.color,
                        theme: theme,
                        babyId: babyId,
                        dateField: module.dateField,
                      ),
                      const SizedBox(height: 22),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: module.color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: module.color.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: module.color, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${module.title} entries are text-based, so no trend graph is shown here.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: theme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    Text(
                      'Records',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 420,
                      child: AppRecordStreamList(
                        collection: module.collection,
                        babyId: babyId,
                        emptyMessage: 'No ${module.title} records yet',
                        emptyIcon: module.fallbackIcon,
                        itemBuilder: (context, data, id, pending) {
                          final createdAt = DateTime.tryParse(
                              data['createdAt']?.toString() ?? '');
                          final subtitle = createdAt != null
                              ? DateFormat('dd MMM yyyy, hh:mm a')
                                  .format(createdAt)
                              : '';
                          final valueText = module.unit.isNotEmpty
                              ? '${data[module.field] ?? ''} ${module.unit}'
                              : '${data[module.field] ?? ''}';

                          return _HoverRecordWrap(
                            accentColor: module.color,
                            child: AppRecordCard(
                              icon: module.fallbackIcon,
                              color: module.color,
                              title: '${module.title}: $valueText'.trim(),
                              subtitle: subtitle,
                              onEdit: () => _showEditRecordDialog(
                                context: context,
                                theme: theme,
                                title: module.title,
                                color: module.color,
                                fields: [
                                  _EditField(
                                    key: module.field,
                                    label: module.unit.isNotEmpty
                                        ? '${module.title} (${module.unit})'
                                        : module.title,
                                    initialValue:
                                        (data[module.field] ?? '').toString(),
                                    isNumber: module.isNumber,
                                  ),
                                ],
                                onSave: (values) => FirestoreService.update(
                                    module.collection, id, values),
                              ),
                              onDelete: () => FirestoreService.delete(
                                  module.collection, id),
                              pendingSync: pending,
                            ),
                          );
                        },
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

// ═══════════════════════════════════════════════════════════════════
// Hover wrapper for a single record card
// ═══════════════════════════════════════════════════════════════════
class _HoverRecordWrap extends StatefulWidget {
  final Widget child;
  final Color accentColor;
  const _HoverRecordWrap({required this.child, required this.accentColor});

  @override
  State<_HoverRecordWrap> createState() => _HoverRecordWrapState();
}

class _HoverRecordWrapState extends State<_HoverRecordWrap> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.98 : (_hover ? 1.02 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 10),
          transform: Matrix4.identity()
            ..scaleByDouble(scale, scale, 1.0, 1.0)
            ..translateByDouble(0.0, _hover ? -2.0 : 0.0, 0.0, 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:
                    widget.accentColor.withValues(alpha: _hover ? 0.30 : 0.0),
                blurRadius: 18,
                offset: const Offset(0, 6),
                spreadRadius: 1,
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Theme-aware trend chart (self-contained copy for this file)
// ═══════════════════════════════════════════════════════════════════
class _ModuleTrendChart extends StatelessWidget {
  final String collection;
  final String field;
  final Color color;
  final AppThemeColors theme;
  final String? babyId;
  final String dateField;

  const _ModuleTrendChart({
    required this.collection,
    required this.field,
    required this.color,
    required this.theme,
    this.babyId,
    this.dateField = 'createdAt',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.isDark;
    final stream = babyId != null
        ? FirestoreService.streamByBaby(collection, babyId!)
        : FirestoreService.stream(collection, descending: false);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator(color: color)),
          );
        }
        var docs = snapshot.data!.docs;
        if (babyId != null) {
          docs = FirestoreService.sortByField(docs, dateField, false);
        }
        final values = <double>[];
        final labels = <String>[];
        for (final d in docs) {
          final data = d.data();
          if (data[field] == null) continue;
          values.add(double.tryParse(data[field].toString()) ?? 0);
          final when = data[dateField] ?? data['createdAt'];
          DateTime? dt;
          if (when is Timestamp) dt = when.toDate();
          if (when is String) dt = DateTime.tryParse(when);
          labels.add(dt != null ? DateFormat('d MMM').format(dt) : '');
        }
        if (values.isEmpty) {
          return const AppEmptyState(
              message: 'No data yet', icon: Icons.show_chart_rounded);
        }
        return Container(
          height: 240,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.06),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.textSecondary,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval:
                        (values.length / 4).clamp(1, values.length).toDouble(),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          labels[index],
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  color: color,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                      show: true, color: color.withValues(alpha: 0.14)),
                  spots: [
                    for (int i = 0; i < values.length; i++)
                      FlSpot(i.toDouble(), values[i]),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Edit dialog — theme-aware (self-contained copy for this file)
// ═══════════════════════════════════════════════════════════════════
class _EditField {
  final String key;
  final String label;
  final String initialValue;
  final bool isNumber;
  const _EditField({
    required this.key,
    required this.label,
    required this.initialValue,
    this.isNumber = false,
  });
}

Future<void> _showEditRecordDialog({
  required BuildContext context,
  required AppThemeColors theme,
  required String title,
  required Color color,
  required List<_EditField> fields,
  required Future<void> Function(Map<String, dynamic> values) onSave,
}) async {
  final controllers = {
    for (final f in fields) f.key: TextEditingController(text: f.initialValue),
  };

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Edit $title',
        style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600, color: theme.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in fields) ...[
              TextField(
                controller: controllers[f.key],
                keyboardType: f.isNumber
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                style:
                    GoogleFonts.poppins(fontSize: 14, color: theme.textPrimary),
                decoration: InputDecoration(
                  labelText: f.label,
                  labelStyle: GoogleFonts.poppins(color: theme.textSecondary),
                  filled: true,
                  fillColor: theme.surfaceAlt,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: color, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel',
              style: GoogleFonts.poppins(color: theme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () async {
            final values = <String, dynamic>{};
            for (final f in fields) {
              final text = controllers[f.key]!.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('${f.label} cannot be empty')));
                return;
              }
              if (f.isNumber) {
                final parsed = double.tryParse(text);
                if (parsed == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('${f.label} must be a valid number')));
                  return;
                }
                values[f.key] = parsed;
              } else {
                values[f.key] = text;
              }
            }
            Navigator.pop(ctx);
            await onSave(values);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Save', style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    ),
  );
}
