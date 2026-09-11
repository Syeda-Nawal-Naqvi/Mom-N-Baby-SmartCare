import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import '../../services/local_notification_service.dart';
import '../../services/app_notification_service.dart';
import '../../services/notification_sound_service.dart';
import '../../widgets/country_picker.dart';
import '../../utils/countries.dart';
import 'verify_email_screen.dart';
import 'login_screen.dart';
import 'set_password_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _selectedRole = 'mother';
  String _selectedCountry = '';
  String? _countryError;
  String? _errorMessage;

  static const String _noSpaceHelper =
      'Use letters, numbers, and symbols (- _ !) — no spaces. Not case sensitive.';

  static const String _iconEmail = 'assets/icons/email.png';
  static const String _iconLock = 'assets/icons/lock.png';
  static const String _iconEyeOpen = 'assets/icons/eye_open.png';
  static const String _iconEyeOff = 'assets/icons/eye_off.png';

  final List<Map<String, String>> _roles = [
    {'value': 'mother', 'label': 'Mother', 'icon': 'assets/icons/woman.png'},
    {
      'value': 'father',
      'label': 'Father / Husband',
      'icon': 'assets/icons/father.png'
    },
    {
      'value': 'caretaker',
      'label': 'Caretaker',
      'icon': 'assets/icons/caretaker.png'
    },
  ];

  static const Color _teal = Color(0xFF14B8A6);
  static const Color _tealDeep = Color(0xFF0B6E6E);
  static const Color _emerald = Color(0xFF22C55E);

  static const List<Color> _brandGradient = [
    _tealDeep,
    _teal,
    _emerald,
  ];
  static const Color _accent = _teal;
  static const Color _accentDeep = _tealDeep;
  static const Color _headingColor = Color(0xFF0B3D3D);
  static const Color _labelColor = Color(0xFF127373);
  static const Color _inputTextColor = Color(0xFF102A2A);
  static const Color _lightBorder = Color(0xFFBFEAE1);
  static const Color _screenBg = Color(0xFFF0FDFA);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _showToast(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor:
            isSuccess ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _navigateByRole(String role) {
    LocalNotificationService().requestPermission();

    AppNotificationService().hasUnreadNotifications().then((hasUnread) {
      if (hasUnread) NotificationSoundService().playPopIfEnabled();
    });

    if (role == 'admin') {
      AdminService().ensureAdminDirectoryEntry();
      Navigator.pushReplacementNamed(context, '/admin_dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPicker(
      context,
      currentValue: _selectedCountry.isEmpty ? null : _selectedCountry,
      title: 'Select your country',
    );
    if (picked == null) return;
    setState(() {
      _selectedCountry = picked;
      _countryError = null;
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCountry.isEmpty) {
      setState(() => _countryError = 'Please select your country');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // No UI path can set this to 'admin' anymore — the old "Register as
    // Admin" toggle + invite code has been removed. Whether an account
    // becomes admin is decided entirely by AuthService.register() based
    // on its hardcoded admin-email allowlist, not by anything sent from
    // here.
    final error = await _authService.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim().toLowerCase(),
      password: _passwordCtrl.text.trim().toLowerCase(),
      role: _selectedRole,
      country: _selectedCountry,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = false);
    _showToast('Account created! Please verify your email 📧', isSuccess: true);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
    );
  }

  Future<void> _googleRegister() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });
    _showToast('Opening Google Sign-In…', isSuccess: true);

    final result = await _authService.signInWithGoogle(
      defaultRole: _selectedRole,
      defaultCountry: _selectedCountry,
    );

    if (!mounted) return;

    if (result['error'] != null) {
      setState(() {
        _errorMessage = result['error'];
        _isGoogleLoading = false;
      });
      return;
    }

    setState(() => _isGoogleLoading = false);

    if (result['isNewUser'] == true) {
      _showToast('Welcome! Account created with Google 🎉', isSuccess: true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SetPasswordScreen(role: result['role']),
        ),
      );
      return;
    }

    if (result['securityNotice'] == true) {
      _showToast(
        'For your security we sent a password reset link to your email — '
        'any old password on this account no longer works.',
        isSuccess: true,
      );
    } else {
      _showToast('Google signup successful! Welcome 🎉', isSuccess: true);
    }
    _navigateByRole(result['role']);
  }

  Widget _assetIcon(
    String assetPath, {
    Color? color,
    IconData fallback = Icons.circle_outlined,
    double size = 20,
  }) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      color: color,
      errorBuilder: (_, __, ___) =>
          Icon(fallback, color: color ?? _accentDeep, size: size),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: _accentDeep, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const _AuthLogoMark(
                        assetPath: 'assets/icons/app_logo.png',
                        gradientColors: _brandGradient,
                        size: 92,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Create Account',
                        style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _headingColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Join SmartCare family today',
                        style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            color: _headingColor.withValues(alpha: 0.55)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: Colors.red.shade400, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.poppins(
                                fontSize: 12.5, color: Colors.red.shade700),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _errorMessage = null),
                          child: Icon(Icons.close,
                              color: Colors.red.shade300, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildLabel('I am a'),
                const SizedBox(height: 10),
                Row(
                  children: _roles.map((role) {
                    final isSelected = _selectedRole == role['value'];
                    return Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedRole = role['value']!),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 4),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [
                                      _teal,
                                      Color.fromARGB(255, 20, 154, 69)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isSelected ? null : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? _accent : _lightBorder,
                              width: 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color:
                                          _accentDeep.withValues(alpha: 0.30),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : [],
                          ),
                          child: Column(
                            children: [
                              Image.asset(
                                role['icon']!,
                                width: 28,
                                height: 28,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.person_outline_rounded,
                                  size: 28,
                                  color:
                                      isSelected ? Colors.white : _accentDeep,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                role['label']!,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.15,
                                  color:
                                      isSelected ? Colors.white : _headingColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildLabel('Full Name'),
                const SizedBox(height: 8),
                _fieldShadowWrap(
                  TextFormField(
                    controller: _nameCtrl,
                    cursorColor: _accent,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                    ],
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _inputTextColor,
                        fontWeight: FontWeight.w500),
                    decoration: _inputDecoration(
                      hint: 'Enter your full name',
                      prefixIcon: Icon(Icons.person_outline_rounded,
                          color: _accentDeep, size: 20),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Full name is required';
                      }
                      if (v.trim().length < 3) {
                        return 'Name must be at least 3 characters';
                      }
                      if (RegExp(r'[0-9]').hasMatch(v)) {
                        return 'Name cannot contain numbers';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 18),
                _buildLabel('Email Address'),
                const SizedBox(height: 8),
                _fieldShadowWrap(
                  TextFormField(
                    controller: _emailCtrl,
                    cursorColor: _accent,
                    keyboardType: TextInputType.emailAddress,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _inputTextColor,
                        fontWeight: FontWeight.w500),
                    decoration: _inputDecoration(
                      hint: 'Enter your email',
                      prefixIcon: _assetIcon(
                        _iconEmail,
                        color: _accentDeep,
                        fallback: Icons.mail_outline_rounded,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(v.trim())) {
                        {
                          return 'Enter a valid email address';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 18),
                _buildLabel('Country'),
                const SizedBox(height: 8),
                _fieldShadowWrap(
                  GestureDetector(
                    onTap: _pickCountry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _countryError != null
                              ? Colors.red.shade300
                              : _lightBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _selectedCountry.isEmpty
                                ? '🌍'
                                : countryByName(_selectedCountry).flag,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedCountry.isEmpty
                                  ? 'Select your country'
                                  : _selectedCountry,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _selectedCountry.isEmpty
                                    ? Colors.grey.shade400
                                    : _inputTextColor,
                              ),
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              color: _accentDeep.withValues(alpha: 0.7)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_countryError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _countryError!,
                    style: GoogleFonts.poppins(
                        fontSize: 11.5, color: Colors.red.shade400),
                  ),
                ],
                const SizedBox(height: 18),
                _buildLabel('Password'),
                const SizedBox(height: 8),
                _fieldShadowWrap(
                  TextFormField(
                    controller: _passwordCtrl,
                    cursorColor: _accent,
                    obscureText: _obscurePassword,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _inputTextColor,
                        fontWeight: FontWeight.w500),
                    onChanged: (_) => setState(() {}),
                    decoration: _inputDecoration(
                      hint: 'Min. 6 characters',
                      helperText: _noSpaceHelper,
                      prefixIcon: _assetIcon(
                        _iconLock,
                        color: _accentDeep,
                        fallback: Icons.lock_outline_rounded,
                      ),
                      suffix: IconButton(
                        icon: _assetIcon(
                          _obscurePassword ? _iconEyeOff : _iconEyeOpen,
                          color: _accent.withValues(alpha: 0.85),
                          fallback: _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.contains(' ')) {
                        return "Spaces aren't allowed. Use letters, numbers, or symbols like - _ instead.";
                      }
                      if (v.length < 6) return 'Minimum 6 characters required';
                      if (!RegExp(r'(?=.*[A-Za-z])').hasMatch(v)) {
                        return 'Include at least one letter';
                      }
                      if (!RegExp(r'(?=.*[0-9])').hasMatch(v)) {
                        return 'Include at least one number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 10),
                _buildPasswordStrength(_passwordCtrl.text),
                const SizedBox(height: 18),
                _buildLabel('Confirm Password'),
                const SizedBox(height: 8),
                _fieldShadowWrap(
                  TextFormField(
                    controller: _confirmPasswordCtrl,
                    cursorColor: _accent,
                    obscureText: _obscureConfirm,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _inputTextColor,
                        fontWeight: FontWeight.w500),
                    decoration: _inputDecoration(
                      hint: 'Re-enter your password',
                      prefixIcon: _assetIcon(
                        _iconLock,
                        color: _accentDeep,
                        fallback: Icons.lock_outline_rounded,
                      ),
                      suffix: IconButton(
                        icon: _assetIcon(
                          _obscureConfirm ? _iconEyeOff : _iconEyeOpen,
                          color: _accent.withValues(alpha: 0.85),
                          fallback: _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (v.contains(' ')) {
                        return "Spaces aren't allowed. Use letters, numbers, or symbols like - _ instead.";
                      }
                      if (v.toLowerCase() != _passwordCtrl.text.toLowerCase()) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 28),
                _AuthGradientButton(
                  label: 'Create Account',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _register,
                  gradientColors: const [
                    _teal,
                    Color.fromARGB(255, 20, 149, 67)
                  ],
                  glowColor: _accentDeep,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                        child: Divider(color: _accent.withValues(alpha: 0.30))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _accentDeep.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                        child: Divider(color: _accent.withValues(alpha: 0.30))),
                  ],
                ),
                const SizedBox(height: 16),
                _AuthOutlineButton(
                  accent: _accent,
                  onPressed: _isGoogleLoading ? null : _googleRegister,
                  child: _isGoogleLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: _accentDeep, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/icons/google.png',
                              width: 22,
                              height: 22,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Continue with Google',
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _headingColor),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account? ',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: _headingColor.withValues(alpha: 0.6))),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        ),
                        child: Text(
                          'Sign In',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _accentDeep),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStrength(String password) {
    if (password.isEmpty) return const SizedBox.shrink();

    int strength = 0;
    if (password.length >= 6) strength++;
    if (RegExp(r'(?=.*[A-Za-z])').hasMatch(password)) strength++;
    if (RegExp(r'(?=.*[0-9])').hasMatch(password)) strength++;
    if (RegExp(r'(?=.*[!@#\$&*~])').hasMatch(password)) strength++;

    final labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [
      Colors.transparent,
      Colors.red.shade400,
      Colors.orange.shade400,
      Colors.blue.shade400,
      Colors.green.shade500,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 6),
                height: 4,
                decoration: BoxDecoration(
                  color: i < strength ? colors[strength] : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          'Password strength: ${labels[strength]}',
          style: GoogleFonts.poppins(
              fontSize: 11,
              color: colors[strength],
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600, color: _labelColor));
  }

  Widget _fieldShadowWrap(Widget child) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffix,
    String? helperText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade400),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(14),
        child: prefixIcon,
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      helperText: helperText,
      helperMaxLines: 2,
      helperStyle: GoogleFonts.poppins(
          fontSize: 10.5, color: _labelColor.withValues(alpha: 0.75)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _lightBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accent, width: 1.8)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade300)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
    );
  }
}

class _AuthLogoMark extends StatelessWidget {
  final String assetPath;
  final List<Color> gradientColors;
  final double size;

  const _AuthLogoMark({
    required this.assetPath,
    required this.gradientColors,
    this.size = 92,
  });

  @override
  Widget build(BuildContext context) {
    final borderWidth = size * 0.045;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        padding: EdgeInsets.all(size * 0.16),
        child: ClipOval(
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => Icon(
              Icons.favorite_rounded,
              color: gradientColors.last,
              size: size * 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthGradientButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final List<Color> gradientColors;
  final Color glowColor;

  const _AuthGradientButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    required this.gradientColors,
    required this.glowColor,
  });

  @override
  State<_AuthGradientButton> createState() => _AuthGradientButtonState();
}

class _AuthGradientButtonState extends State<_AuthGradientButton> {
  bool _hover = false;
  bool _pressed = false;

  bool get _active => _hover || _pressed;
  bool get _disabled => widget.onPressed == null;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.97 : (_hover ? 1.02 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: _disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: _disabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: _disabled ? null : () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scaleByDouble(scale, scale, 1.0, 1.0),
          transformAlignment: Alignment.center,
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _disabled
                  ? widget.gradientColors
                      .map((c) => c.withValues(alpha: 0.45))
                      .toList()
                  : widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _disabled
                ? []
                : [
                    BoxShadow(
                      color: widget.glowColor
                          .withValues(alpha: _active ? 0.55 : 0.35),
                      blurRadius: _active ? 26 : 18,
                      offset: const Offset(0, 8),
                      spreadRadius: _active ? 1.5 : 0.5,
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  widget.label,
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
        ),
      ),
    );
  }
}

class _AuthOutlineButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color accent;

  const _AuthOutlineButton({
    required this.child,
    required this.onPressed,
    required this.accent,
  });

  @override
  State<_AuthOutlineButton> createState() => _AuthOutlineButtonState();
}

class _AuthOutlineButtonState extends State<_AuthOutlineButton> {
  bool _hover = false;
  bool _pressed = false;

  bool get _active => _hover || _pressed;
  bool get _disabled => widget.onPressed == null;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.97 : (_hover ? 1.015 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: _disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: _disabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: _disabled ? null : () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scaleByDouble(scale, scale, 1.0, 1.0),
          transformAlignment: Alignment.center,
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.accent.withValues(alpha: _active ? 0.65 : 0.40),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: _active ? 0.25 : 0.14),
                blurRadius: _active ? 20 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}
