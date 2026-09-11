import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:email_validator/email_validator.dart';

import '../../services/help_request_service.dart';

/// Reachable from LoginScreen WITHOUT signing in — for a user who is
/// completely locked out (forgot password + lost the recovery email,
/// or a blocked account) and therefore cannot use the normal in-app
/// Feedback screen (which needs an active session).
///
/// Submits straight to Firestore's `help_requests` collection, whose
/// rules allow an unauthenticated `create` (see firestore_rules.txt).
/// An admin then sees it in AdminHelpRequestsScreen and replies by
/// email, since there is no account to send an in-app reply to.
class NeedHelpScreen extends StatefulWidget {
  const NeedHelpScreen({super.key});

  @override
  State<NeedHelpScreen> createState() => _NeedHelpScreenState();
}

class _NeedHelpScreenState extends State<NeedHelpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  final _helpService = HelpRequestService();

  bool _isSubmitting = false;
  bool _submitted = false;

  static const Color _accent = Color(0xFFE91E8C);
  static const Color _accentDeep = Color(0xFF7A2790);
  static const Color _headingColor = Color(0xFF6A1B9A);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final error = await _helpService.submitHelpRequest(
      name: _nameController.text,
      email: _emailController.text,
      message: _messageController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
      return;
    }

    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _headingColor),
        title: Text('Need Help?',
            style: GoogleFonts.poppins(
                color: _headingColor,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: _submitted ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Icon(Icons.support_agent_rounded, color: _accent, size: 52),
          ),
          const SizedBox(height: 14),
          Text('Can\'t sign in?',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _headingColor)),
          const SizedBox(height: 6),
          Text(
            'Tell us what\'s happening and our team will reply directly '
            'to the email you provide below — no account or password '
            'needed to send this.',
            style: GoogleFonts.poppins(
                fontSize: 13, color: _accentDeep.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 24),
          _label('Your name'),
          _field(
            controller: _nameController,
            hint: 'e.g. Username ',
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter your name'
                : null,
          ),
          const SizedBox(height: 16),
          _label('Email we should reply to'),
          _field(
            controller: _emailController,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!EmailValidator.validate(v.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _label('What\'s the problem?'),
          _field(
            controller: _messageController,
            hint: 'e.g. I forgot my password and can\'t access my old email '
                'either, so I never get the reset link.',
            maxLines: 5,
            validator: (v) => (v == null || v.trim().length < 10)
                ? 'Please describe the problem in a bit more detail'
                : null,
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text('Send Request',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.mark_email_read_rounded,
              color: Color(0xFF2ECC71), size: 64),
          const SizedBox(height: 18),
          Text('Request sent!',
              style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _headingColor)),
          const SizedBox(height: 8),
          Text(
            'Our team will reply to ${_emailController.text.trim()} '
            'as soon as possible.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 13.5, color: _accentDeep.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 26),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Back to Sign In',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _accent)),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _accentDeep)),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF3D1259)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _accent.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _accent, width: 1.5),
        ),
      ),
    );
  }
}
