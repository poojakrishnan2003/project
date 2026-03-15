import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Help & Feedback screen containing FAQ, Report a Problem,
/// Send Feedback, and Contact Support sections.
class HelpFeedbackScreen extends StatefulWidget {
  const HelpFeedbackScreen({super.key});

  @override
  State<HelpFeedbackScreen> createState() => _HelpFeedbackScreenState();
}

class _HelpFeedbackScreenState extends State<HelpFeedbackScreen> {
  // ── FAQ ──────────────────────────────────────────────────────────────
  final List<_FaqItem> _faqs = const [
    _FaqItem(
      question: 'How do I create a trip?',
      answer:
          'Tap "My Trips" from the bottom navigation bar, then press the + button to start a new trip. Give it a name and start adding places!',
    ),
    _FaqItem(
      question: 'How do I add places to My Trips?',
      answer:
          'Open a trip, tap "Add Place", then search or pick a location on the map. You can add notes and photos to each place.',
    ),
    _FaqItem(
      question: 'What are Hidden Gems?',
      answer:
          'Hidden Gems are unique, off-the-beaten-path locations shared by the Roamly community. You can discover them from the drawer menu.',
    ),
    _FaqItem(
      question: 'How can I add a Hidden Gem location?',
      answer:
          'Tap the + FAB on the map screen, choose a location, and mark it as a Hidden Gem while filling out the spot details.',
    ),
    _FaqItem(
      question: 'How do I update my profile?',
      answer:
          'Tap your avatar in the drawer or navigate to Profile from the bottom bar. You can edit your name, phone number, and profile photo.',
    ),
  ];

  // ── Report a Problem ─────────────────────────────────────────────────
  final _reportFormKey = GlobalKey<FormState>();
  final _reportTitleController = TextEditingController();
  final _reportDescController = TextEditingController();
  String? _screenshotFileName;
  bool _isSubmittingReport = false;

  // ── Send Feedback ─────────────────────────────────────────────────────
  final _feedbackFormKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();
  int _starRating = 0;
  bool _isSubmittingFeedback = false;

  // ── Contact Support ───────────────────────────────────────────────────
  final _contactFormKey = GlobalKey<FormState>();
  final _contactNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactMessageController = TextEditingController();
  bool _isSubmittingContact = false;

  @override
  void dispose() {
    _reportTitleController.dispose();
    _reportDescController.dispose();
    _feedbackController.dispose();
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _contactMessageController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  void _showSuccessSnackBar(String formName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF06D6A0),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Thank you for your $formName. Our team will review it.',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (!_reportFormKey.currentState!.validate()) return;
    setState(() => _isSubmittingReport = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('reports').add({
        'userId': uid,
        'title': _reportTitleController.text.trim(),
        'description': _reportDescController.text.trim(),
        'hasScreenshot': _screenshotFileName != null,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isSubmittingReport = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _isSubmittingReport = false;
      _reportTitleController.clear();
      _reportDescController.clear();
      _screenshotFileName = null;
    });
    _showSuccessSnackBar('report');
  }

  Future<void> _submitFeedback() async {
    if (_starRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a star rating.',
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    if (!_feedbackFormKey.currentState!.validate()) return;
    setState(() => _isSubmittingFeedback = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': uid,
        'rating': _starRating,
        'message': _feedbackController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isSubmittingFeedback = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _isSubmittingFeedback = false;
      _feedbackController.clear();
      _starRating = 0;
    });
    _showSuccessSnackBar('feedback');
  }

  Future<void> _submitContact() async {
    if (!_contactFormKey.currentState!.validate()) return;
    setState(() => _isSubmittingContact = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('contact_messages').add({
        'userId': uid,
        'name': _contactNameController.text.trim(),
        'email': _contactEmailController.text.trim(),
        'message': _contactMessageController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isSubmittingContact = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _isSubmittingContact = false;
      _contactNameController.clear();
      _contactEmailController.clear();
      _contactMessageController.clear();
    });
    _showSuccessSnackBar('message');
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text('Help & Feedback', style: GoogleFonts.poppins()),
        backgroundColor:
            isDark ? const Color(0xFF16213E) : Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          _buildFaqSection(isDark, primary),
          const SizedBox(height: 20),
          _buildReportSection(isDark, primary),
          const SizedBox(height: 20),
          _buildFeedbackSection(isDark, primary),
          const SizedBox(height: 20),
          _buildContactSection(isDark, primary),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Section: FAQ ──────────────────────────────────────────────────────

  Widget _buildFaqSection(bool isDark, Color primary) {
    return _Card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.help_outline_rounded,
            title: 'Frequently Asked Questions',
            isDark: isDark,
            primary: primary,
          ),
          const SizedBox(height: 12),
          ...List.generate(_faqs.length, (i) {
            return _FaqTile(item: _faqs[i], isDark: isDark, primary: primary);
          }),
        ],
      ),
    );
  }

  // ── Section: Report a Problem ─────────────────────────────────────────

  Widget _buildReportSection(bool isDark, Color primary) {
    return _Card(
      isDark: isDark,
      child: Form(
        key: _reportFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.bug_report_outlined,
              title: 'Report a Problem',
              isDark: isDark,
              primary: primary,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _reportTitleController,
              label: 'Issue Title',
              icon: Icons.title,
              isDark: isDark,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 12),
            _buildInputField(
              controller: _reportDescController,
              label: 'Description of the problem',
              icon: Icons.description_outlined,
              isDark: isDark,
              maxLines: 4,
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Please describe the issue'
                      : null,
            ),
            const SizedBox(height: 16),
            // Screenshot upload (simulated)
            GestureDetector(
              onTap: () {
                setState(() => _screenshotFileName = 'screenshot_001.png');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 1.5,
                  ),
                  color: isDark ? const Color(0xFF0D1B2A) : Colors.grey[50],
                ),
                child: Row(
                  children: [
                    Icon(
                      _screenshotFileName != null
                          ? Icons.image_rounded
                          : Icons.attach_file_rounded,
                      color: _screenshotFileName != null
                          ? const Color(0xFF06D6A0)
                          : (isDark ? Colors.white54 : Colors.grey[500]),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _screenshotFileName ?? 'Attach screenshot (optional)',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: _screenshotFileName != null
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.white38 : Colors.grey[500]),
                        ),
                      ),
                    ),
                    if (_screenshotFileName != null)
                      GestureDetector(
                        onTap: () => setState(() => _screenshotFileName = null),
                        child: Icon(Icons.close,
                            size: 18,
                            color: isDark ? Colors.white38 : Colors.grey[500]),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _SubmitButton(
              label: 'Submit Report',
              isLoading: _isSubmittingReport,
              primary: primary,
              onPressed: _submitReport,
            ),
          ],
        ),
      ),
    );
  }

  // ── Section: Send Feedback ────────────────────────────────────────────

  Widget _buildFeedbackSection(bool isDark, Color primary) {
    return _Card(
      isDark: isDark,
      child: Form(
        key: _feedbackFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.rate_review_outlined,
              title: 'Send Feedback',
              isDark: isDark,
              primary: primary,
            ),
            const SizedBox(height: 16),
            Text(
              'How would you rate Roamly?',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 10),
            // Star rating
            Row(
              children: List.generate(5, (i) {
                final starIndex = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _starRating = starIndex),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        starIndex <= _starRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        key: ValueKey('$starIndex-$_starRating'),
                        color: starIndex <= _starRating
                            ? Colors.amber
                            : (isDark ? Colors.white30 : Colors.grey[400]),
                        size: 38,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _feedbackController,
              label: 'Your suggestions or feedback…',
              icon: Icons.edit_note_rounded,
              isDark: isDark,
              maxLines: 4,
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Please enter your feedback'
                      : null,
            ),
            const SizedBox(height: 20),
            _SubmitButton(
              label: 'Send Feedback',
              isLoading: _isSubmittingFeedback,
              primary: primary,
              onPressed: _submitFeedback,
            ),
          ],
        ),
      ),
    );
  }

  // ── Section: Contact Support ──────────────────────────────────────────

  Widget _buildContactSection(bool isDark, Color primary) {
    return _Card(
      isDark: isDark,
      child: Form(
        key: _contactFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.support_agent_rounded,
              title: 'Contact Support',
              isDark: isDark,
              primary: primary,
            ),
            const SizedBox(height: 12),
            // Support email chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: primary.withValues(alpha: 0.1),
                border: Border.all(color: primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.email_outlined, size: 18, color: primary),
                  const SizedBox(width: 8),
                  Text(
                    'support@roamly.app',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildInputField(
              controller: _contactNameController,
              label: 'Your Name',
              icon: Icons.person_outline,
              isDark: isDark,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            _buildInputField(
              controller: _contactEmailController,
              label: 'Your Email',
              icon: Icons.email_outlined,
              isDark: isDark,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildInputField(
              controller: _contactMessageController,
              label: 'Message',
              icon: Icons.message_outlined,
              isDark: isDark,
              maxLines: 4,
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Message cannot be empty'
                      : null,
            ),
            const SizedBox(height: 20),
            _SubmitButton(
              label: 'Send Message',
              isLoading: _isSubmittingContact,
              primary: primary,
              onPressed: _submitContact,
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared: Input field ───────────────────────────────────────────────

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: isDark ? Colors.white54 : Colors.grey[600],
        ),
        prefixIcon: Icon(icon,
            size: 20,
            color: isDark ? Colors.white38 : Colors.grey[500]),
        filled: true,
        fillColor: isDark ? const Color(0xFF0D1B2A) : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14, vertical: maxLines > 1 ? 14 : 0),
      ),
    );
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────────────────

/// Card container matching the Roamly dark-theme design.
class _Card extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _Card({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16213E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }
}

/// Section header with icon and title.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDark;
  final Color primary;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }
}

/// Expandable FAQ tile.
class _FaqTile extends StatefulWidget {
  final _FaqItem item;
  final bool isDark;
  final Color primary;

  const _FaqTile({
    required this.item,
    required this.isDark,
    required this.primary,
  });

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _controller;
  late Animation<double> _rotationAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _rotationAnim = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.question,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RotationTransition(
                  turns: _rotationAnim,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: widget.isDark ? Colors.white54 : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: widget.primary.withValues(alpha: 0.2)),
            ),
            child: Text(
              widget.item.answer,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.6,
                color: widget.isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
        Divider(
          color: widget.isDark ? Colors.grey[800] : Colors.grey[200],
          height: 1,
        ),
      ],
    );
  }
}

/// Full-width submit button with loading state.
class _SubmitButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final Color primary;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.label,
    required this.isLoading,
    required this.primary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

/// Data model for FAQ items.
class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}
