import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/firebase_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_widgets.dart';

/// ═══════════════════════════════════════════════════════════════════
/// Mother Records & Graphs
/// ───────────────────────────────────────────────────────────────────
/// CHANGES IN THIS VERSION:
/// - Card content (icon tile + title) is now explicitly centered both
///   horizontally and vertically inside every square card.
/// - Dark-mode glow shadow is brighter at rest (not just on hover) so
///   Weight / Blood Pressure / Glucose Level / Medical History cards
///   all read clearly against the dark background.
/// - The grid is now shrink-wrapped and placed inside a Center +
///   SingleChildScrollView, and capped to a max content width, so the
///   whole card group sits centered both vertically AND horizontally
///   on the screen instead of sticking to the top.
/// ═══════════════════════════════════════════════════════════════════
class MotherRecordsGraphsScreen extends StatelessWidget {
  const MotherRecordsGraphsScreen({super.key});

  static const double _kMaxContentWidth = 640;

  static final List<_MotherModule> _modules = [
    _MotherModule(
      title: 'Weight',
      iconPath: 'assets/icons/weight.png',
      fallbackIcon: Icons.monitor_weight_rounded,
      color: const Color.fromARGB(255, 20, 228, 96),
      collection: 'mother_weight',
      field: 'weight',
      unit: 'kg',
    ),
    _MotherModule(
      title: 'Blood Pressure',
      iconPath: 'assets/icons/blood_pressure.png',
      fallbackIcon: Icons.monitor_heart_rounded,
      color: const Color.fromARGB(255, 237, 53, 154),
      collection: 'blood_pressure',
      field: 'systolic',
      unit: '',
      isBloodPressure: true,
    ),
    _MotherModule(
      title: 'Glucose Level',
      iconPath: 'assets/icons/glucose.png',
      fallbackIcon: Icons.bloodtype_rounded,
      color: const Color(0xFF3B82F6),
      collection: 'glucose',
      field: 'glucoseLevel',
      unit: 'mg/dL',
    ),
    _MotherModule(
      title: 'Medical History',
      iconPath: 'assets/icons/medical_report.png',
      fallbackIcon: Icons.healing_rounded,
      color: const Color.fromARGB(255, 255, 221, 0),
      collection: 'medical_history',
      field: 'diseaseName',
      unit: '',
      isNumber: false,
    ),
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
              'Mother Records & Graphs',
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
                // Center vertically + horizontally. SingleChildScrollView
                // is the safety valve: if the grid ever grows taller than
                // the screen (more modules added later, small device),
                // it scrolls instead of overflowing.
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: _kMaxContentWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: GridView.builder(
                          // shrinkWrap + NeverScrollableScrollPhysics so the
                          // grid only takes as much height as its content
                          // needs — that's what lets Center() actually
                          // center it instead of the grid claiming full
                          // height and pinning items to the top.
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1,
                          ),
                          itemCount: _modules.length,
                          itemBuilder: (context, index) {
                            final m = _modules[index];
                            return _SquareModuleCard(
                              title: m.title,
                              iconPath: m.iconPath,
                              fallbackIcon: m.fallbackIcon,
                              accentColor: m.color,
                              theme: theme,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      _MotherModuleDetailScreen(module: m),
                                ),
                              ),
                            );
                          },
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

// ═══════════════════════════════════════════════════════════════════
// Module data
// ═══════════════════════════════════════════════════════════════════
class _MotherModule {
  final String title;
  final String iconPath;
  final IconData fallbackIcon;
  final Color color;
  final String collection;
  final String field;
  final String unit;
  final bool isNumber;
  final bool isBloodPressure;

  const _MotherModule({
    required this.title,
    required this.iconPath,
    required this.fallbackIcon,
    required this.color,
    required this.collection,
    required this.field,
    required this.unit,
    this.isNumber = true,
    this.isBloodPressure = false,
  });
}

// ═══════════════════════════════════════════════════════════════════
// Square hoverable module card.
// ───────────────────────────────────────────────────────────────────
// Content (icon tile + title) is wrapped in a Center + centered Column
// so it always sits in the middle of the card regardless of card size.
// Dark-mode shadow is brighter at rest — a real glow, not a faint hint
// — and gets even brighter on hover/press/tap.
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
            widget.accentColor.withValues(alpha: 0.12),
            widget.theme.surface,
          )
        : Colors.white;
    final activeColor = isDark
        ? Color.alphaBlend(
            widget.accentColor.withValues(alpha: 0.24),
            widget.theme.surface,
          )
        : Color.alphaBlend(
            widget.accentColor.withValues(alpha: 0.08),
            Colors.white,
          );
    final baseColor = _active ? activeColor : restColor;
    final tileColor = isDark ? widget.theme.surfaceAlt : Colors.white;

    // Resting shadow: a brighter accent-colored glow in dark mode —
    // raised base opacity and blur so it reads clearly even at rest,
    // and intensifies further on hover/press/tap.
    final shadowColor = isDark
        ? widget.accentColor.withValues(
            alpha: _active ? (_opening ? 0.70 : 0.58) : 0.30,
          )
        : (_active
            ? widget.accentColor.withValues(alpha: _opening ? 0.55 : 0.42)
            : Colors.black.withValues(alpha: 0.10));
    final shadowBlur = isDark
        ? (_opening ? 40.0 : (_active ? 32.0 : 22.0))
        : (_opening ? 34.0 : (_active ? 26.0 : 16.0));
    final shadowSpread = isDark
        ? (_opening ? 4.0 : (_active ? 3.0 : 1.5))
        : (_opening ? 3.0 : (_active ? 2.0 : 0.5));

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
                blurRadius: shadowBlur,
                offset: _active ? const Offset(0, 10) : const Offset(0, 6),
                spreadRadius: shadowSpread,
              ),
            ],
            border: Border.all(
              color: _active
                  ? widget.accentColor.withValues(alpha: 0.4)
                  : (isDark
                      ? widget.accentColor.withValues(alpha: 0.20)
                      : Colors.transparent),
              width: 1.4,
            ),
          ),
          // Center wrapper ensures the icon tile + title always sit in
          // the exact middle of the card, both axes, at any card size.
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
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
                          color: widget.accentColor.withValues(
                            alpha: isDark ? 0.45 : 0.32,
                          ),
                          blurRadius: isDark ? 18 : 14,
                          offset: const Offset(0, 4),
                          spreadRadius: isDark ? 1.0 : 0.5,
                        ),
                      ],
                      border: Border.all(
                        color: widget.accentColor.withValues(
                          alpha: isDark ? 0.28 : 0.18,
                        ),
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Detail screen: trend graph (when numeric) + editable, hoverable
// record list.
// ═══════════════════════════════════════════════════════════════════
class _MotherModuleDetailScreen extends StatelessWidget {
  final _MotherModule module;
  const _MotherModuleDetailScreen({required this.module});

  static const double _kMaxContentWidth = 640;

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
              module.title,
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
                // Same centering treatment: cap width and center the
                // whole detail column horizontally on wide screens.
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: _kMaxContentWidth),
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
                                    'Medical history entries are text-based, so no trend graph is shown here.',
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
                            emptyMessage: 'No ${module.title} records yet',
                            emptyIcon: module.fallbackIcon,
                            itemBuilder: (context, data, id, pending) {
                              final createdAt = DateTime.tryParse(
                                  data['createdAt']?.toString() ?? '');
                              final subtitle = createdAt != null
                                  ? DateFormat('dd MMM yyyy, hh:mm a')
                                      .format(createdAt)
                                  : '';

                              if (module.isBloodPressure) {
                                return _HoverRecordWrap(
                                  accentColor: module.color,
                                  child: AppRecordCard(
                                    icon: module.fallbackIcon,
                                    color: module.color,
                                    title:
                                        'BP: ${data['systolic']}/${data['diastolic']}',
                                    subtitle: subtitle,
                                    onEdit: () => _showEditRecordDialog(
                                      context: context,
                                      theme: theme,
                                      title: 'Blood Pressure',
                                      color: module.color,
                                      fields: [
                                        _EditField(
                                          key: 'systolic',
                                          label: 'Systolic',
                                          initialValue: (data['systolic'] ?? '')
                                              .toString(),
                                          isNumber: true,
                                        ),
                                        _EditField(
                                          key: 'diastolic',
                                          label: 'Diastolic',
                                          initialValue:
                                              (data['diastolic'] ?? '')
                                                  .toString(),
                                          isNumber: true,
                                        ),
                                      ],
                                      onSave: (values) =>
                                          FirestoreService.update(
                                              module.collection, id, values),
                                    ),
                                    onDelete: () => FirestoreService.delete(
                                        module.collection, id),
                                    pendingSync: pending,
                                  ),
                                );
                              }

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
                                        initialValue: (data[module.field] ?? '')
                                            .toString(),
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
// Theme-aware trend chart — uses theme.surface, not a hardcoded gray.
// ═══════════════════════════════════════════════════════════════════
class _ModuleTrendChart extends StatelessWidget {
  final String collection;
  final String field;
  final Color color;
  final AppThemeColors theme;

  const _ModuleTrendChart({
    required this.collection,
    required this.field,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.isDark;
    final stream = FirestoreService.stream(collection, descending: false);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator(color: color)),
          );
        }
        final docs = snapshot.data!.docs;
        final values = <double>[];
        final labels = <String>[];
        for (final d in docs) {
          final data = d.data();
          if (data[field] == null) continue;
          values.add(double.tryParse(data[field].toString()) ?? 0);
          final when = data['createdAt'];
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
                color: color.withValues(alpha: isDark ? 0.30 : 0.18),
                blurRadius: isDark ? 22 : 16,
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
// Edit dialog — theme-aware
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
