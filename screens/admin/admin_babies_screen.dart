import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';
import '../../services/theme_service.dart';

/// Admin-only screen: lists every baby profile in the app, with a live
/// count, and lets the admin drill into a profile's details or delete it
/// entirely.
///
/// Baby profiles live at `users/{uid}/babies/{docId}`, NOT in a top-level
/// `babies` collection — so this screen streams via
/// `AdminService.streamAllBabies()`, which uses a `collectionGroup` query
/// to pull every user's babies in one go. Deleting removes the profile
/// document only — associated health records (weight, vaccinations,
/// milestones, allergies, medical history) live in their own per-user
/// collections and are not cascade-deleted, matching the same pattern
/// used for mother profiles (see AdminMothersScreen / AdminService's
/// deleteBabyProfile doc comment for details).
class AdminBabiesScreen extends StatefulWidget {
  const AdminBabiesScreen({super.key});

  @override
  State<AdminBabiesScreen> createState() => _AdminBabiesScreenState();
}

class _AdminBabiesScreenState extends State<AdminBabiesScreen> {
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
        title: Text('Delete baby profile?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: theme.textPrimary)),
        content: Text(
          'This permanently removes "$name"\'s profile. Their health '
          'records (weight, vaccinations, milestones, allergies, medical '
          'history) are kept separately and are not deleted automatically.',
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
                await _adminService.deleteBabyProfile(ref);
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

  String _ageLabel(DateTime dob) {
    final now = DateTime.now();
    int months = (now.year - dob.year) * 12 + (now.month - dob.month);
    if (now.day < dob.day) months--;
    if (months < 0) months = 0;
    if (months < 1) return 'Newborn';
    if (months < 24) return '$months mo';
    return '${(months / 12).floor()} yr';
  }

  void _showDetails(
      AppThemeColors theme, Map<String, dynamic> data, DateTime dob) {
    final name = (data['name'] ?? 'Unknown').toString();
    final gender = (data['gender'] ?? '-').toString();
    final bloodGroup = (data['bloodGroup'] ?? '-').toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      'assets/icons/baby.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.child_care_rounded, color: theme.accent),
                    ),
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
                      Text('Baby profile',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: theme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow(theme, Icons.wc_rounded, 'Gender', gender),
            _detailRow(theme, Icons.cake_rounded, 'Date of Birth',
                DateFormat('dd/MM/yyyy').format(dob)),
            _detailRow(
                theme, Icons.hourglass_bottom_rounded, 'Age', _ageLabel(dob)),
            _detailRow(
                theme, Icons.bloodtype_rounded, 'Blood Group', bloodGroup),
            const SizedBox(height: 8),
          ],
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
            title: Text('Baby Profiles',
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
                  stream: _adminService.streamAllBabies(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child:
                              CircularProgressIndicator(color: theme.accent));
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('Could not load baby profiles.',
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
                            'Total baby profiles: $totalCount',
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
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Image.asset(
                                            'assets/icons/baby.png',
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => Icon(
                                                Icons.child_care_rounded,
                                                size: 40,
                                                color: theme.accent),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text('No baby profiles found',
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
                                    final gender =
                                        (data['gender'] ?? '-').toString();
                                    final bloodGroup =
                                        (data['bloodGroup'] ?? '-').toString();
                                    final dob = DateTime.tryParse(
                                            data['dob']?.toString() ?? '') ??
                                        DateTime.now();

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
                                        onTap: () =>
                                            _showDetails(theme, data, dob),
                                        leading: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: theme.accent
                                                .withValues(alpha: 0.14),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Image.asset(
                                              'assets/icons/baby.png',
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(Icons.child_care_rounded,
                                                      color: theme.accent),
                                            ),
                                          ),
                                        ),
                                        title: Text(name,
                                            style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: theme.textPrimary)),
                                        subtitle: Text(
                                            '$gender  ·  ${_ageLabel(dob)}  ·  Blood Group $bloodGroup',
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: theme.textSecondary)),
                                        trailing: IconButton(
                                          icon: Icon(
                                              Icons.delete_outline_rounded,
                                              color: theme.danger),
                                          tooltip: 'Delete baby profile',
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
