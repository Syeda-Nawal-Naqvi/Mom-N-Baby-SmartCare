import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import '../../widgets/country_picker.dart';
import '../../utils/countries.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _name = '';
  String _email = '';
  String _selectedRole = 'mother';
  String _country = '';
  String _createdAt = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _changed = false;

  static const Color _babyPinkBg = Color(0xFFFFF1F6);
  static const Color _headingPink = Color(0xFFD6478E);
  static const Color _fieldPink = Color(0xFFEC4899);
  static const Color _inputPink = Color(0xFFEC4899);
  static const double _maxContentWidth = 560;

  final List<Map<String, String>> _roles = [
    {'value': 'mother', 'label': 'Mother'},
    {'value': 'father', 'label': 'Father / Husband'},
    {'value': 'caretaker', 'label': 'Caretaker'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        if (mounted) {
          setState(() {
            _email = _auth.currentUser?.email ?? '';
            _name = _auth.currentUser?.displayName ??
                _auth.currentUser?.email?.split('@')[0] ??
                'User';
            _isLoading = false;
          });
        }
        return;
      }

      final doc = await _firestore.collection('users').doc(uid).get();
      if (!mounted) return;

      if (doc.exists) {
        final rawRole = doc['role'] ?? 'mother';

        final normalisedRole = rawRole == 'father/husband' ? 'father' : rawRole;

        setState(() {
          _name = doc['name'] ?? '';
          _email = _auth.currentUser?.email ?? '';
          _selectedRole = normalisedRole;
          _country = (doc.data()?['country'] ?? '').toString();
          final ts = doc['createdAt'];
          if (ts != null) {
            final dt = (ts as dynamic).toDate() as DateTime;
            _createdAt = '${dt.day}/${dt.month}/${dt.year}';
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _name = _auth.currentUser?.displayName ??
              _auth.currentUser?.email?.split('@')[0] ??
              'User';
          _email = _auth.currentUser?.email ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _name = _auth.currentUser?.displayName ??
              _auth.currentUser?.email?.split('@')[0] ??
              'User';
          _email = _auth.currentUser?.email ?? '';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveField({
    required String field,
    required String value,
  }) async {
    if (value.trim().isEmpty) {
      _showToast('Field cannot be empty', isSuccess: false);
      return;
    }

    // Extra safety: block numbers in name even if inputFormatters is bypassed
    if (field == 'name' && RegExp(r'[0-9]').hasMatch(value)) {
      _showToast('Name cannot contain numbers', isSuccess: false);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      await _firestore.collection('users').doc(uid).set(
        {field: value.trim()},
        SetOptions(merge: true),
      );

      if (field == 'name') {
        try {
          await _auth.currentUser?.updateDisplayName(value.trim());
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        if (field == 'name') _name = value.trim();
        if (field == 'role') _selectedRole = value.trim();
        if (field == 'country') _country = value.trim();
        _isSaving = false;
        _changed = true;
      });
      _showToast('Updated successfully!', isSuccess: true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showToast('Failed to save. Try again.', isSuccess: false);
      }
    }
  }

  Future<void> _showNameDialog(AppThemeColors theme) async {
    final ctrl = TextEditingController(text: _name);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Update Name',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: theme.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Maximum 30 characters allowed. Numbers are not allowed.',
              style:
                  GoogleFonts.poppins(fontSize: 12, color: theme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLength: 30,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
              ],
              style: GoogleFonts.poppins(fontSize: 14, color: _inputPink),
              decoration: InputDecoration(
                hintText: 'Enter your full name',
                hintStyle: GoogleFonts.poppins(
                    color: theme.textSecondary, fontSize: 13),
                counterStyle: GoogleFonts.poppins(
                    fontSize: 11, color: theme.textSecondary),
                filled: true,
                fillColor: theme.surfaceAlt,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.accent, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = ctrl.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(ctx);
              await _saveField(field: 'name', value: value);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child:
                Text('Save', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCountry(AppThemeColors theme) async {
    final picked = await showCountryPicker(
      context,
      currentValue: _country.isEmpty ? null : _country,
      title: 'Select your country',
    );
    if (picked == null || picked == _country) return;
    await _saveField(field: 'country', value: picked);
  }

  Future<bool?> _confirmRoleChange(AppThemeColors theme, String newLabel) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Change role to "$newLabel"?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: theme.textPrimary)),
        content: Text(
          'Your account role will be updated everywhere in the app, '
          'including the admin dashboard. You may need to restart the '
          'app afterwards to see the new dashboard.',
          style: GoogleFonts.poppins(fontSize: 13, color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: theme.accent),
            child:
                Text('Change', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onEmailTap() {
    _showToast('To change email, go to Settings → Change Email',
        isSuccess: false);
  }

  void _showToast(String message, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style:
                      GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: isSuccess ? ThemeService.success : ThemeService.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String get _roleLabel {
    final found = _roles.firstWhere(
      (r) => r['value'] == _selectedRole,
      orElse: () => {'value': _selectedRole, 'label': _selectedRole},
    );
    return found['label'] ?? _selectedRole;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeNotifier>();
    final isDark = context.read<ThemeNotifier>().isDarkMode;
    final theme = AppThemeColors(isDark);

    final screenBg = isDark ? theme.bg : _babyPinkBg;
    final headingColor = isDark ? theme.textPrimary : _headingPink;
    final fieldColor = isDark ? theme.textPrimary : _fieldPink;

    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_rounded, color: theme.accent, size: 20),
          onPressed: () => Navigator.pop(context, _changed),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.accent))
          : SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: _maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'My Profile',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: headingColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your personal information',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: theme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF7A2790),
                                Color(0xFFD44FC2),
                                Color(0xFFE91E8C),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B2FA0)
                                    .withValues(alpha: 0.40),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _name.isNotEmpty ? _name : 'User',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.35)),
                                ),
                                child: Text(
                                  _roleLabel,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _sectionLabel(
                              'ACCOUNT DETAILS', theme.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        _buildInfoCard(
                          label: 'FULL NAME',
                          accentColor: const Color(0xFF10B981),
                          theme: theme,
                          isDark: isDark,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _name.isNotEmpty ? _name : '—',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: fieldColor,
                                  ),
                                ),
                              ),
                              _isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF10B981),
                                      ),
                                    )
                                  : GestureDetector(
                                      onTap: () => _showNameDialog(theme),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981)
                                              .withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.edit_rounded,
                                          color: Color(0xFF10B981),
                                          size: 18,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildInfoCard(
                          label: 'EMAIL ADDRESS',
                          accentColor: theme.accent,
                          theme: theme,
                          isDark: isDark,
                          child: GestureDetector(
                            onTap: _onEmailTap,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _email.isNotEmpty ? _email : '—',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: fieldColor,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: theme.accent,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildInfoCard(
                          label: 'ROLE',
                          accentColor: ThemeService.infoBlue(isDark),
                          theme: theme,
                          isDark: isDark,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedRole,
                              isExpanded: true,
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: ThemeService.infoBlue(isDark),
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: fieldColor,
                              ),
                              dropdownColor: theme.surface,
                              items: _roles.map((role) {
                                return DropdownMenuItem<String>(
                                  value: role['value'],
                                  child: Text(
                                    role['label']!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: theme.textPrimary,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) async {
                                if (value == null || value == _selectedRole) {
                                  return;
                                }
                                final newLabel = _roles.firstWhere(
                                    (r) => r['value'] == value)['label']!;
                                final confirmed =
                                    await _confirmRoleChange(theme, newLabel);
                                if (confirmed != true) return;
                                setState(() => _selectedRole = value);
                                await _saveField(field: 'role', value: value);
                                if (!mounted) return;
                                _showToast(
                                  'Role updated to $newLabel. Restart the app '
                                  'to see the matching dashboard.',
                                  isSuccess: true,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildInfoCard(
                          label: 'COUNTRY',
                          accentColor: const Color(0xFF8B5CF6),
                          theme: theme,
                          isDark: isDark,
                          child: GestureDetector(
                            onTap: _isSaving ? null : () => _pickCountry(theme),
                            child: Row(
                              children: [
                                Text(
                                  countryByName(_country).flag.isEmpty
                                      ? '🏳️'
                                      : countryByName(_country).flag,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _country.isNotEmpty ? _country : 'Not set',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: fieldColor,
                                    ),
                                  ),
                                ),
                                _isSaving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                      )
                                    : Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6)
                                              .withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.edit_rounded,
                                          color: Color(0xFF8B5CF6),
                                          size: 18,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                        if (_createdAt.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _buildInfoCard(
                            label: 'MEMBER SINCE',
                            accentColor: const Color(0xFF66BB6A),
                            theme: theme,
                            isDark: isDark,
                            child: Text(
                              _createdAt,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: fieldColor,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required Widget child,
    required Color accentColor,
    required AppThemeColors theme,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.24 : 0.16),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.24 : 0.14),
            blurRadius: 18,
            spreadRadius: 0.4,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accentColor,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
