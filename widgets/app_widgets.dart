import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/firebase_service.dart';
import '../services/theme_service.dart';

class ModuleColors {
  static const mother = Color(0xFFE91E8C);
  static const motherLight = Color(0xFFFFE4F2);
  static const baby = Color(0xFF3B82F6);
  static const babyLight = Color(0xFFDBEAFE);
  static const records = Color(0xFF10B981);
  static const recordsLight = Color(0xFFD1FAE5);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF2A93B);

  static const profile = Color(0xFFEC4899);
  static const weight = Color(0xFF3B82F6);
  static const vaccination = Color(0xFF8B5CF6);
  static const milestone = Color(0xFFF59E0B);
  static const allergy = Color(0xFFEF4444);
  static const medical = Color(0xFF14B8A6);
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        return ValueListenableBuilder<bool>(
          valueListenable: FirestoreService.isOnline,
          builder: (context, online, _) {
            if (online) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              color: ModuleColors.warning
                  .withValues(alpha: theme.isDark ? 0.22 : 0.15),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 18, color: ModuleColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "You're offline — changes are saved and will sync automatically once you're back online.",
                      style: GoogleFonts.poppins(
                          fontSize: 12.5, color: theme.textPrimary),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class InlineStatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const InlineStatusBanner(
      {super.key, required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        final color = isError ? ModuleColors.danger : ModuleColors.records;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: theme.isDark ? 0.20 : 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: theme.textPrimary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class InfoBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  const InfoBanner(
      {super.key,
      required this.title,
      this.subtitle = '',
      required this.color});

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        return Card(
          color: theme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: color)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: theme.textSecondary)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class AppDateTile extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  final String label;
  final Color color;
  const AppDateTile({
    super.key,
    required this.date,
    required this.onTap,
    this.label = 'Select Date',
    this.color = ModuleColors.baby,
  });

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: theme.isDark ? 0.14 : 0.05),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: color.withValues(alpha: 0.35), width: 1.4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.calendar_month_rounded,
                      color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: theme.textSecondary)),
                      const SizedBox(height: 2),
                      Text(DateFormat('dd MMM yyyy').format(date),
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              color: theme.textPrimary)),
                    ],
                  ),
                ),
                Icon(Icons.edit_rounded, size: 18, color: color),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AppSectionField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color color;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  final int? maxLength;

  const AppSectionField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.color,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        return Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: theme.isDark ? 0.14 : 0.05),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: color.withValues(alpha: 0.35), width: 1.4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            crossAxisAlignment: maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(
                    top: maxLines > 1 ? 14 : 10, bottom: maxLines > 1 ? 0 : 10),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  maxLength: maxLength,
                  validator: validator,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: theme.textPrimary),
                  cursorColor: color,
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: hint,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    labelStyle: GoogleFonts.poppins(
                        fontSize: 12.5, color: theme.textSecondary),
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 13, color: theme.textSecondary),
                    counterStyle: GoogleFonts.poppins(
                        fontSize: 11, color: theme.textSecondary),
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

class AppSectionDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const AppSectionDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        return Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: theme.isDark ? 0.14 : 0.05),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: color.withValues(alpha: 0.35), width: 1.4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: value,
                  dropdownColor: theme.surface,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textPrimary),
                  items: items
                      .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e,
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textPrimary))))
                      .toList(),
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    labelText: label,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    labelStyle: GoogleFonts.poppins(
                        fontSize: 12.5, color: theme.textSecondary),
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

class AppSubmitButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final String label;
  final Color color;
  const AppSubmitButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.label,
    this.color = ModuleColors.mother,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white))
            : Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
      ),
    );
  }
}

class AppRecordCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final bool pendingSync;

  const AppRecordCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onDelete,
    this.onEdit,
    this.pendingSync = false,
  });

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        return Card(
          color: theme.isDark
              ? Color.alphaBlend(color.withValues(alpha: 0.10), theme.surface)
              : theme.surface,
          child: ListTile(
            leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.16),
                child: Icon(icon, color: color)),
            title: Text(title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: theme.textPrimary)),
            subtitle: Text(subtitle,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: theme.textSecondary)),
            isThreeLine: subtitle.contains('\n'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pendingSync)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Tooltip(
                      message: 'Waiting to sync',
                      child: Icon(Icons.sync_rounded,
                          size: 18, color: theme.textSecondary),
                    ),
                  ),
                if (onEdit != null)
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: color),
                    tooltip: 'Edit record',
                    onPressed: onEdit,
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: ModuleColors.danger),
                  tooltip: 'Delete record',
                  onPressed: () => _confirmDelete(context, theme),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, AppThemeColors theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title:
            Text('Delete record?', style: TextStyle(color: theme.textPrimary)),
        content: Text('This action cannot be undone.',
            style: TextStyle(color: theme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('Delete',
                style: TextStyle(color: ModuleColors.danger)),
          ),
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? iconAsset;
  final Color? accentColor;

  const AppEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.iconAsset,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        final color = accentColor ?? theme.textSecondary;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: theme.isDark ? 0.16 : 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: iconAsset != null
                      ? Image.asset(
                          iconAsset!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Icon(icon, size: 32, color: color),
                        )
                      : Icon(icon, size: 32, color: color),
                ),
                const SizedBox(height: 14),
                Text(message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        color: theme.textSecondary, fontSize: 13.5)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ModuleHeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const ModuleHeaderCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HealthMenuTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const HealthMenuTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: color.withValues(alpha: 0.22), width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: theme.isDark ? 0.18 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14)),
                      child: Icon(icon, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                  color: theme.textPrimary)),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: theme.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: color),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class BabyProfileCard extends StatelessWidget {
  final String name;
  final String gender;
  final String bloodGroup;
  final DateTime dob;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const BabyProfileCard({
    super.key,
    required this.name,
    required this.gender,
    required this.bloodGroup,
    required this.dob,
    required this.onTap,
    this.color = ModuleColors.profile,
    this.onDelete,
    this.onEdit,
  });

  static String _ageString(DateTime dob) {
    final now = DateTime.now();
    int months = (now.year - dob.year) * 12 + (now.month - dob.month);
    if (now.day < dob.day) months -= 1;
    if (months < 1) {
      final days = now.difference(dob).inDays;
      return days <= 0 ? 'Newborn' : '$days day${days == 1 ? '' : 's'} old';
    }
    if (months < 24) return '$months month${months == 1 ? '' : 's'} old';
    final years = months ~/ 12;
    return '$years yr${years == 1 ? '' : 's'} old';
  }

  @override
  Widget build(BuildContext context) {
    final isGirl = gender.toLowerCase().startsWith('f');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.72)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: Icon(isGirl ? Icons.girl_rounded : Icons.boy_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? 'Unnamed Baby' : name,
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (gender.isNotEmpty) gender,
                          _ageString(dob),
                          if (bloodGroup.isNotEmpty) bloodGroup,
                        ].join(' • '),
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.92)),
                      ),
                    ],
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    onPressed: onEdit,
                    tooltip: 'Edit profile',
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    onPressed: onDelete,
                    tooltip: 'Delete profile',
                  ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const AppChoiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.9))),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ComingSoonScreen extends StatelessWidget {
  final String title;
  const ComingSoonScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        return Scaffold(
          backgroundColor: theme.bg,
          appBar: AppBar(
            backgroundColor: theme.surface,
            elevation: 0,
            title: Text(title, style: TextStyle(color: theme.textPrimary)),
          ),
          body: Center(
            child: AppEmptyState(
              message: '$title is coming soon',
              icon: Icons.hourglass_empty_rounded,
            ),
          ),
        );
      },
    );
  }
}

class AppRecordStreamList extends StatefulWidget {
  final String collection;
  final String? babyId;
  final String emptyMessage;
  final IconData emptyIcon;
  final String? emptyIconAsset;
  final Color? emptyAccentColor;
  final bool descending;
  final String orderByField;
  final Widget Function(
    BuildContext context,
    Map<String, dynamic> data,
    String id,
    bool pendingSync,
  ) itemBuilder;

  const AppRecordStreamList({
    super.key,
    required this.collection,
    required this.itemBuilder,
    this.babyId,
    this.emptyMessage = 'No records yet',
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyIconAsset,
    this.emptyAccentColor,
    this.descending = true,
    this.orderByField = 'createdAt',
  });

  @override
  State<AppRecordStreamList> createState() => _AppRecordStreamListState();
}

class _AppRecordStreamListState extends State<AppRecordStreamList> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _buildStream();
  }

  @override
  void didUpdateWidget(covariant AppRecordStreamList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collection != widget.collection ||
        oldWidget.babyId != widget.babyId ||
        oldWidget.orderByField != widget.orderByField ||
        oldWidget.descending != widget.descending) {
      _stream = _buildStream();
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStream() {
    return widget.babyId != null
        ? FirestoreService.streamByBaby(widget.collection, widget.babyId!)
        : FirestoreService.stream(
            widget.collection,
            orderBy: widget.orderByField,
            descending: widget.descending,
          );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppEmptyState(
            message: 'Could not load records: ${snapshot.error}',
            icon: Icons.error_outline_rounded,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snapshot.data!.docs.toList();
        if (docs.isEmpty) {
          return AppEmptyState(
            message: widget.emptyMessage,
            icon: widget.emptyIcon,
            iconAsset: widget.emptyIconAsset,
            accentColor: widget.emptyAccentColor,
          );
        }
        if (widget.babyId != null) {
          docs = FirestoreService.sortByField(
              docs, widget.orderByField, widget.descending);
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = Map<String, dynamic>.from(doc.data());
            return widget.itemBuilder(
              context,
              data,
              doc.id,
              doc.metadata.hasPendingWrites,
            );
          },
        );
      },
    );
  }
}
