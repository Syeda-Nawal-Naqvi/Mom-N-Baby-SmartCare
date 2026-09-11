import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:mother_and_baby_smartcare/models/mother_profile_model.dart';
import 'package:mother_and_baby_smartcare/services/mother_profile_service.dart';
import 'package:mother_and_baby_smartcare/services/theme_service.dart';

class _Palette {
  static const pink = Color(0xFFE91E8C);
  static const purple = Color(0xFF7A2790);
  static const purpleMid = Color(0xFFD44FC2);
}

class MotherProfileScreen extends StatefulWidget {
  final MotherProfileModel? existingProfile;
  const MotherProfileScreen({super.key, this.existingProfile});

  @override
  State<MotherProfileScreen> createState() => _MotherProfileScreenState();
}

class _MotherProfileScreenState extends State<MotherProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final MotherProfileService _service = MotherProfileService();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  String _bloodGroup = 'A+';
  List<DeliveryRecord> _deliveries = [];
  bool _saving = false;

  bool get _isEditing => widget.existingProfile != null;

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existingProfile;
    if (p != null) {
      _nameController.text = p.name;
      _ageController.text = p.age.toString();
      _bloodGroup = p.bloodGroup.isNotEmpty ? p.bloodGroup : 'A+';
      _deliveries = p.deliveries
          .map((d) => DeliveryRecord(label: d.label, date: d.date))
          .toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _addDelivery() {
    setState(() {
      _deliveries.add(
        DeliveryRecord(label: 'Baby ${_deliveries.length + 1}', date: ''),
      );
    });
  }

  void _removeDelivery(int index) {
    setState(() => _deliveries.removeAt(index));
  }

  Future<void> _pickDeliveryDate(int index, bool isDark) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: _Palette.pink,
                    onPrimary: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: _Palette.pink,
                    onPrimary: Colors.white,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _deliveries[index].date = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final missingDate = _deliveries.any((d) => d.date.isEmpty);
    if (missingDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please pick a date for every delivery entry.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final profile = MotherProfileModel(
        id: _isEditing ? widget.existingProfile!.id : null,
        name: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()) ?? 0,
        bloodGroup: _bloodGroup,
        deliveries: _deliveries,
      );

      await _service.saveProfile(profile);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _Palette.pink,
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(AppThemeColors theme, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          GoogleFonts.poppins(fontSize: 13.5, color: theme.textSecondary),
      filled: true,
      fillColor: theme.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        borderSide: const BorderSide(color: _Palette.pink, width: 1.6),
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
            iconTheme: const IconThemeData(color: _Palette.pink),
            title: Text(
              _isEditing ? 'Update Mother Profile' : 'Mother Profile Setup',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, color: theme.textPrimary),
            ),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_isEditing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _Palette.pink
                            .withValues(alpha: theme.isDark ? 0.16 : 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _Palette.pink.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Please complete this profile before using the health trackers.',
                        style: GoogleFonts.poppins(
                            color: theme.isDark
                                ? theme.textPrimary
                                : _Palette.purple,
                            fontSize: 12.5),
                      ),
                    ),
                  ),
                _fieldLabel('Mother Name'),
                TextFormField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                  ],
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: theme.textPrimary),
                  decoration: _fieldDecoration(theme, 'Enter mother\'s name'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name is required';
                    }
                    if (RegExp(r'[0-9]').hasMatch(v)) {
                      return 'Name cannot contain numbers';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                _fieldLabel('Age'),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: theme.textPrimary),
                  decoration: _fieldDecoration(theme, 'Enter age'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Age is required';
                    final age = int.tryParse(v.trim());
                    if (age == null || age <= 0 || age > 100) {
                      return 'Enter a valid age';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                _fieldLabel('Blood Group'),
                DropdownButtonFormField<String>(
                  initialValue: _bloodGroup,
                  dropdownColor: theme.surface,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: theme.textPrimary),
                  decoration: _fieldDecoration(theme, 'Select blood group'),
                  items: _bloodGroups
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _bloodGroup = v ?? _bloodGroup),
                ),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delivery Dates',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimary),
                    ),
                    TextButton.icon(
                      onPressed: _addDelivery,
                      style:
                          TextButton.styleFrom(foregroundColor: _Palette.pink),
                      icon: const Icon(Icons.add_rounded),
                      label: Text('Add Baby',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_deliveries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No delivery dates added yet. Tap "Add Baby" if applicable.',
                      style: GoogleFonts.poppins(
                          color: theme.textSecondary, fontSize: 12.5),
                    ),
                  ),
                for (int i = 0; i < _deliveries.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _Palette.pink.withValues(alpha: 0.25)),
                      boxShadow: [
                        BoxShadow(
                          color: _Palette.pink
                              .withValues(alpha: theme.isDark ? 0.14 : 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Label'),
                              TextFormField(
                                initialValue: _deliveries[i].label,
                                style: GoogleFonts.poppins(
                                    fontSize: 13, color: theme.textPrimary),
                                decoration:
                                    _fieldDecoration(theme, 'e.g. Baby 1')
                                        .copyWith(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                                onChanged: (v) => _deliveries[i].label = v,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Delivery Date'),
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _pickDeliveryDate(i, theme.isDark),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: theme.surfaceAlt,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: theme.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_month_rounded,
                                          size: 16,
                                          color: _Palette.pink
                                              .withValues(alpha: 0.7)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _deliveries[i].date.isEmpty
                                              ? 'Tap to pick date'
                                              : _deliveries[i].date,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: _deliveries[i].date.isEmpty
                                                ? theme.textSecondary
                                                : theme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.red),
                          onPressed: () => _removeDelivery(i),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [
                        _Palette.purple,
                        _Palette.purpleMid,
                        _Palette.pink
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _Palette.pink.withValues(alpha: 0.32),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _saving ? null : _save,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  _isEditing
                                      ? 'Update Profile'
                                      : 'Save Profile',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
