import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/app_notification_service.dart';
import '../../services/theme_service.dart';

class AdminSendNotificationScreen extends StatefulWidget {
  const AdminSendNotificationScreen({super.key});

  @override
  State<AdminSendNotificationScreen> createState() =>
      _AdminSendNotificationScreenState();
}

class _AdminSendNotificationScreenState
    extends State<AdminSendNotificationScreen> {
  final AppNotificationService _notifService = AppNotificationService();

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  bool _sendToAll = true;
  String? _selectedUid;
  String? _selectedUserLabel;
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickUser(AppThemeColors theme) async {
    final snap = await FirebaseFirestore.instance.collection('users').get();
    if (!mounted) return;

    final selected = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select a user',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: snap.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snap.docs[index];
                      final data = doc.data();
                      final name = data['name'] ?? 'Unknown';
                      final email = data['email'] ?? '';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.accent.withValues(alpha: 0.14),
                          child: Text(
                              name.toString().isNotEmpty
                                  ? name.toString()[0].toUpperCase()
                                  : '?',
                              style: TextStyle(color: theme.accent)),
                        ),
                        title: Text(name,
                            style: GoogleFonts.poppins(
                                fontSize: 14, color: theme.textPrimary)),
                        subtitle: Text(email,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: theme.textSecondary)),
                        onTap: () => Navigator.pop(
                            ctx, {'uid': doc.id, 'label': '$name ($email)'}),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedUid = selected['uid'];
        _selectedUserLabel = selected['label'];
      });
    }
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title and message are required.')));
      return;
    }
    if (!_sendToAll && _selectedUid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a user.')));
      return;
    }

    setState(() => _sending = true);
    try {
      if (_sendToAll) {
        final count = await _notifService.sendToAllUsers(
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Sent to $count user(s).')));
        }
      } else {
        await _notifService.sendToUser(
          userId: _selectedUid!,
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          type: 'admin_message',
          senderName: 'Admin',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notification sent.')));
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
            title: Text('Send Notification',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.accent)),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recipient',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _recipientOption(
                        theme: theme,
                        label: 'All Users',
                        icon: Icons.people_alt_rounded,
                        selected: _sendToAll,
                        onTap: () => setState(() => _sendToAll = true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _recipientOption(
                        theme: theme,
                        label: 'Specific User',
                        icon: Icons.person_rounded,
                        selected: !_sendToAll,
                        onTap: () => setState(() => _sendToAll = false),
                      ),
                    ),
                  ],
                ),
                if (!_sendToAll) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _pickUser(theme),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_search_rounded,
                              color: theme.accent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedUserLabel ?? 'Tap to select a user',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: _selectedUserLabel != null
                                      ? theme.textPrimary
                                      : theme.textSecondary),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: theme.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text('Title',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtrl,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: theme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Scheduled maintenance notice',
                    hintStyle: GoogleFonts.poppins(color: theme.textSecondary),
                    filled: true,
                    fillColor: theme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
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
                const SizedBox(height: 18),
                Text('Message',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _bodyCtrl,
                  maxLines: 5,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: theme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Write your message...',
                    hintStyle: GoogleFonts.poppins(color: theme.textSecondary),
                    filled: true,
                    fillColor: theme.surface,
                    contentPadding: const EdgeInsets.all(16),
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
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_sendToAll ? 'Send to All' : 'Send',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _recipientOption({
    required AppThemeColors theme,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? theme.accent : theme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? theme.accent : theme.border),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? Colors.white : theme.textSecondary, size: 22),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : theme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
