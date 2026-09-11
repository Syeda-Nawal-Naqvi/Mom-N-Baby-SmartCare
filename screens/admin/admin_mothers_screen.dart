import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/admin_service.dart';
import '../../services/theme_service.dart';

/// Admin-only screen: lists every mother profile in the app, with a live
/// count, and lets the admin drill into a profile's details or delete it
/// entirely.
///
/// Mother profiles live at `users/{uid}/mother_profile/{docId}` (one per
/// user), NOT in a top-level `mothers` collection — so this screen streams
/// via `AdminService.streamAllMothers()`, which uses a `collectionGroup`
/// query to pull every user's mother profile in one go. Deleting removes
/// the profile document only — associated health records (weight, BP,
/// glucose, medical history) live in their own per-user collections and
/// are not cascade-deleted, matching the same pattern used for baby
/// profiles.
class AdminMothersScreen extends StatefulWidget {
  const AdminMothersScreen({super.key});

  @override
  State<AdminMothersScreen> createState() => _AdminMothersScreenState();
}

class _AdminMothersScreenState extends State<AdminMothersScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _confirmDelete(
      AppThemeColors theme, DocumentReference ref, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete mother profile?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: theme.textPrimary)),
        content: Text(
          'This permanently removes "$name"\'s profile. Their health '
          'records (weight, blood pressure, glucose, medical history) are '
          'kept separately and are not deleted automatically.',
          style: GoogleFonts.poppins(fontSize: 13, color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _adminService.deleteMotherProfile(ref);
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('"$name" deleted.')));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.danger),
            child:
                Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDetails(AppThemeColors theme, Map<String, dynamic> data) {
    final name = (data['name'] ?? 'Unknown').toString();
    final age = (data['age'] ?? '-').toString();
    final bloodGroup = (data['bloodGroup'] ?? '-').toString();
    final deliveries = (data['deliveries'] as List?) ?? const [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: theme.accent.withValues(alpha: 0.14),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.poppins(
                          color: theme.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: theme.textPrimary)),
                        Text('Mother profile',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: theme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _detailRow(theme, Icons.cake_rounded, 'Age', '$age years'),
              _detailRow(
                  theme, Icons.bloodtype_rounded, 'Blood Group', bloodGroup),
              _detailRow(
                  theme,
                  Icons.child_friendly_rounded,
                  'Deliveries',
                  deliveries.isEmpty
                      ? 'None recorded'
                      : '${deliveries.length}'),
              if (deliveries.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Delivery History',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary)),
                const SizedBox(height: 8),
                ...deliveries.map((d) {
                  final map = d as Map;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: theme.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text((map['label'] ?? '').toString(),
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: theme.textPrimary)),
                        ),
                        Text((map['date'] ?? '').toString(),
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: theme.textSecondary)),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
      AppThemeColors theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.accent),
          const SizedBox(width: 10),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: theme.textSecondary)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.textPrimary)),
        ],
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
            iconTheme: IconThemeData(color: theme.accent),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Mother Profiles',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.accent)),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: theme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by name...',
                    hintStyle: GoogleFonts.poppins(color: theme.textSecondary),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 20, color: theme.accent),
                    filled: true,
                    fillColor: theme.surfaceAlt,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: theme.accent, width: 1.4)),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                  stream: _adminService.streamAllMothers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child:
                              CircularProgressIndicator(color: theme.accent));
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('Could not load mother profiles.',
                              style: GoogleFonts.poppins(
                                  color: theme.textSecondary)));
                    }
                    var docs = snapshot.data ?? [];
                    final totalCount = docs.length;
                    if (_query.isNotEmpty) {
                      docs = docs.where((d) {
                        final data = d.data();
                        final name =
                            (data['name'] ?? '').toString().toLowerCase();
                        return name.contains(_query);
                      }).toList();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: Text(
                            'Total mother profiles: $totalCount',
                            style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.accentLight),
                          ),
                        ),
                        Expanded(
                          child: docs.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 84,
                                        height: 84,
                                        decoration: BoxDecoration(
                                          color: theme.accent
                                              .withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                            Icons.pregnant_woman_rounded,
                                            size: 40,
                                            color: theme.accent),
                                      ),
                                      const SizedBox(height: 12),
                                      Text('No mother profiles found',
                                          style: GoogleFonts.poppins(
                                              color: theme.textSecondary,
                                              fontSize: 14)),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                  itemCount: docs.length,
                                  itemBuilder: (context, index) {
                                    final doc = docs[index];
                                    final data = doc.data();
                                    final name =
                                        (data['name'] ?? 'Unknown').toString();
                                    final age = (data['age'] ?? '-').toString();
                                    final bloodGroup =
                                        (data['bloodGroup'] ?? '-').toString();

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: theme.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: theme.accent
                                                .withValues(alpha: 0.14)),
                                        boxShadow: [
                                          BoxShadow(
                                              color: theme.accent.withValues(
                                                  alpha: theme.isDark
                                                      ? 0.14
                                                      : 0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4)),
                                        ],
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 6),
                                        onTap: () => _showDetails(theme, data),
                                        leading: CircleAvatar(
                                          backgroundColor: theme.accent
                                              .withValues(alpha: 0.14),
                                          child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                                color: theme.accent,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        title: Text(name,
                                            style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: theme.textPrimary)),
                                        subtitle: Text(
                                            'Age $age  ·  Blood Group $bloodGroup',
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: theme.textSecondary)),
                                        trailing: IconButton(
                                          icon: Icon(
                                              Icons.delete_outline_rounded,
                                              color: theme.danger),
                                          onPressed: () => _confirmDelete(
                                              theme, doc.reference, name),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
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
