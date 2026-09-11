import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/theme_service.dart';
import '../utils/countries.dart';

/// Opens a searchable, Instagram-style country picker and returns the
/// chosen [Country.name], or null if the user backed out without
/// picking one.
///
/// Includes a "Use my current location" row at the top which asks for
/// location permission, resolves the device's current country via GPS +
/// reverse geocoding, and auto-selects it — the user never has to type
/// or scroll if they just want "wherever I am right now".
Future<String?> showCountryPicker(
  BuildContext context, {
  String? currentValue,
  String title = 'Select your country',
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CountryPickerSheet(
      title: title,
      initialSingle: currentValue,
    ),
  );
}

/// Same as [showCountryPicker] but lets the admin choose ANY NUMBER of
/// countries (used to scope shop categories/products to specific
/// regions). Returns the selected list, or null if backed out. An empty
/// list is a valid, meaningful result: "visible everywhere".
Future<List<String>?> showCountryMultiPicker(
  BuildContext context, {
  required List<String> currentValues,
  String title = 'Visible in these countries',
}) async {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CountryPickerSheet(
      title: title,
      multiSelect: true,
      initialMulti: currentValues,
    ),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  final String title;
  final bool multiSelect;
  final String? initialSingle;
  final List<String>? initialMulti;

  const _CountryPickerSheet({
    required this.title,
    this.multiSelect = false,
    this.initialSingle,
    this.initialMulti,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _locating = false;
  String? _locationError;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...?widget.initialMulti};
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Country> get _filtered {
    if (_query.trim().isEmpty) return kWorldCountries;
    final q = _query.trim().toLowerCase();
    return kWorldCountries
        .where((c) => c.name.toLowerCase().contains(q))
        .toList();
  }

  /// Requests location permission, gets the device position, and reverse
  /// geocodes it to a country. Handles every failure mode (permission
  /// denied, permanently denied, service disabled, geocoding failure)
  /// with a clear inline message instead of a silent no-op or crash —
  /// none of these are unusual/rare, so all are worth surfacing.
  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError =
            'Location services are turned off on this device. Please enable them and try again.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        setState(() => _locationError =
            'Location permission was denied. You can still search and pick your country manually below.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationError =
            'Location permission is permanently denied. Enable it from your device Settings, or pick your country manually below.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        setState(() => _locationError =
            'Could not determine your country from your location. Please pick it manually below.');
        return;
      }
      final iso = placemarks.first.isoCountryCode;
      final match = countryByCode(iso);
      if (match == null) {
        setState(() => _locationError =
            'Could not match your location to a country in our list. Please pick it manually below.');
        return;
      }
      if (!mounted) return;
      if (widget.multiSelect) {
        setState(() => _selected.add(match.name));
      } else {
        Navigator.pop(context, match.name);
      }
    } catch (e) {
      setState(() => _locationError =
          'Something went wrong detecting your location. Please pick your country manually below.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = AppThemeColors(isDark);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                  color: theme.border, borderRadius: BorderRadius.circular(3)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary)),
                  ),
                  if (widget.multiSelect)
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, _selected.toList()),
                      child: Text('Done',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: theme.accent)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style:
                    GoogleFonts.poppins(fontSize: 14, color: theme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search country',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 13, color: theme.textSecondary),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: theme.textSecondary),
                  filled: true,
                  fillColor: theme.surfaceAlt,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _locating ? null : _useCurrentLocation,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: theme.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      _locating
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: theme.accent),
                            )
                          : Icon(Icons.my_location_rounded,
                              color: theme.accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _locating
                              ? 'Detecting your location…'
                              : 'Use my current location',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_locationError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  _locationError!,
                  style:
                      GoogleFonts.poppins(fontSize: 11.5, color: theme.danger),
                ),
              ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final country = _filtered[i];
                  final isSelected = widget.multiSelect
                      ? _selected.contains(country.name)
                      : (widget.initialSingle == country.name);
                  return ListTile(
                    onTap: () {
                      if (widget.multiSelect) {
                        setState(() {
                          if (_selected.contains(country.name)) {
                            _selected.remove(country.name);
                          } else {
                            _selected.add(country.name);
                          }
                        });
                      } else {
                        Navigator.pop(context, country.name);
                      }
                    },
                    leading: Text(country.flag.isEmpty ? '🏳️' : country.flag,
                        style: const TextStyle(fontSize: 22)),
                    title: Text(country.name,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.textPrimary)),
                    trailing: widget.multiSelect
                        ? Icon(
                            isSelected
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            color:
                                isSelected ? theme.accent : theme.textSecondary,
                          )
                        : (isSelected
                            ? Icon(Icons.radio_button_checked_rounded,
                                color: theme.accent)
                            : Icon(Icons.radio_button_off_rounded,
                                color: theme.textSecondary)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
