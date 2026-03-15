import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roamly/features/profile/screens/settings_screen.dart';
import 'package:roamly/features/shared/widgets/profile_image_widget.dart';

/// Screen for viewing and editing user profile details with a modern card layout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ── State variables ───────────────────────────────────────────────────
  String _name = '';
  String _email = '';
  String _phone = '';
  String? _photoUrl;
  String _bio = '';
  List<String> _preferences = [];

  bool _isLoading = true;

  // Available preferences for selection
  final List<String> _allPreferences = [
    'Adventure', 'Food', 'Nature', 'Culture', 'Photography', 'Nightlife', 'Relaxation'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && mounted) {
      final data = doc.data()!;
      setState(() {
        _name = data['name'] ?? user.displayName ?? '';
        _phone = data['phoneNumber'] ?? '';
        _photoUrl = data['photoUrl'] ?? user.photoURL;
        _email = data['email'] ?? user.email ?? '';
        _bio = data['bio'] ?? '';
        _preferences = List<String>.from(data['preferences'] ?? []);
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _name = user.displayName ?? '';
        _email = user.email ?? '';
        _photoUrl = user.photoURL;
        _isLoading = false;
      });
    }
  }

  void _showEditProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EditProfileSheet(
          initialName: _name,
          initialPhone: _phone,
          initialBio: _bio,
          currentPhotoUrl: _photoUrl,
          onSave: (newName, newPhone, newBio, newPhotoUrl) {
            setState(() {
              _name = newName;
              _phone = newPhone;
              _bio = newBio;
              if (newPhotoUrl != null) _photoUrl = newPhotoUrl;
            });
          },
        );
      },
    );
  }

  Future<void> _togglePreference(String pref) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final updatedPrefs = List<String>.from(_preferences);
    if (updatedPrefs.contains(pref)) {
      updatedPrefs.remove(pref);
    } else {
      updatedPrefs.add(pref);
    }

    // Optimistic UI update
    setState(() => _preferences = updatedPrefs);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'preferences': updatedPrefs});
    } catch (e) {
      // Revert if failed
      if (mounted) {
        setState(() => _preferences = List.from(_preferences)..remove(pref));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update preferences'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bgColor = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF4F6FB);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('My Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: isDark ? const Color(0xFF16213E) : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            _buildHeader(isDark, primaryColor),
            const SizedBox(height: 24),
            _buildTravelStatsCard(isDark, primaryColor),
            const SizedBox(height: 24),
            _buildPreferencesSection(isDark, primaryColor),
            const SizedBox(height: 24),
            _buildSavedPlacesSection(isDark, primaryColor),
            const SizedBox(height: 24),
            _buildAccountActions(isDark, primaryColor),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Section 1: Header ─────────────────────────────────────────────────

  Widget _buildHeader(bool isDark, Color primaryColor) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 3),
              ),
              child: ProfileImageWidget(
                photoUrl: _photoUrl,
                fallbackLetter: _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                size: 100,
              ),
            ),
            GestureDetector(
              onTap: _showEditProfileModal,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? const Color(0xFF1A1A2E) : Colors.white, width: 2),
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _name.isEmpty ? 'Roamly User' : _name,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        if (_email.isNotEmpty)
          Text(
            _email,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _showEditProfileModal,
          icon: const Icon(Icons.person_outline, size: 18),
          label: Text('Edit Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: BorderSide(color: primaryColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
        ),
        if (_bio.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            _bio,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ],
      ],
    );
  }

  // ── Section 2: Travel Stats ───────────────────────────────────────────

  Widget _buildTravelStatsCard(bool isDark, Color primaryColor) {
    return _SectionCard(
      isDark: isDark,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(value: '12', label: 'Trips\nCreated', icon: Icons.map_outlined, isDark: isDark, primary: primaryColor),
          _StatItem(value: '48', label: 'Places\nVisited', icon: Icons.place_outlined, isDark: isDark, primary: primaryColor),
          _StatItem(value: '7', label: 'Gems\nDiscovered', icon: Icons.star_outline, isDark: isDark, primary: primaryColor),
        ],
      ),
    );
  }

  // ── Section 3: Preferences ────────────────────────────────────────────

  Widget _buildPreferencesSection(bool isDark, Color primaryColor) {
    return _SectionCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Travel Preferences',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(
            'Select what you love to get better recommendations.',
            style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _allPreferences.map((pref) {
              final isSelected = _preferences.contains(pref);
              return GestureDetector(
                onTap: () => _togglePreference(pref),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : (isDark ? const Color(0xFF0D1B2A) : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? primaryColor : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
                    ),
                  ),
                  child: Text(
                    pref,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey[700]),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Section 4: Saved Places ───────────────────────────────────────────

  Widget _buildSavedPlacesSection(bool isDark, Color primaryColor) {
    // Mock list of saved places
    final mockPlaces = [
      {'name': 'Golden Gate Bridge', 'loc': 'San Francisco', 'img': 'https://images.unsplash.com/photo-1501594907352-04cda38ebc29?auto=format&fit=crop&w=400&q=80'},
      {'name': 'Eiffel Tower', 'loc': 'Paris', 'img': 'https://images.unsplash.com/photo-1511739001486-6bfe10ce785f?auto=format&fit=crop&w=400&q=80'},
      {'name': 'Machu Picchu', 'loc': 'Peru', 'img': 'https://images.unsplash.com/photo-1587595431973-160d0d94add1?auto=format&fit=crop&w=400&q=80'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saved Places',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
              ),
              TextButton(
                onPressed: () {},
                child: Text('See All', style: GoogleFonts.poppins(color: primaryColor, fontWeight: FontWeight.w500)),
              )
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: mockPlaces.length,
            itemBuilder: (context, index) {
              final place = mockPlaces[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? const Color(0xFF16213E) : Colors.white,
                  boxShadow: isDark ? [] : [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        place['img']!,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place['name']!,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 12, color: primaryColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  place['loc']!,
                                  style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Section 5: Account Actions ────────────────────────────────────────

  Widget _buildAccountActions(bool isDark, Color primaryColor) {
    return _SectionCard(
      isDark: isDark,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.lock_outline, color: primaryColor),
            title: Text('Change Password', style: GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.grey[400]),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent (Simulated)')));
            },
          ),
          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.orange),
            title: Text('Logout', style: GoogleFonts.poppins(fontSize: 14, color: Colors.orange)),
            onTap: _handleLogout,
          ),
          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text('Delete Account', style: GoogleFonts.poppins(fontSize: 14, color: Colors.red)),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: isDark ? const Color(0xFF16213E) : Colors.white,
                  title: Text('Delete Account?', style: GoogleFonts.poppins(color: Colors.red)),
                  content: Text('This action cannot be undone. All your trips will be lost.', style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black54))),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleLogout(); // Simulate delete
                      },
                      child: Text('Delete', style: GoogleFonts.poppins()),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// ── Modal & Helper Widgets ──────────────────────────────────────────────
// ────────────────────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final String initialBio;
  final String? currentPhotoUrl;
  final Function(String name, String phone, String bio, String? photoUrl) onSave;

  const _EditProfileSheet({
    required this.initialName,
    required this.initialPhone,
    required this.initialBio,
    this.currentPhotoUrl,
    required this.onSave,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _bioCtrl;
  final _formKey = GlobalKey<FormState>();

  String? _photoUrl;
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
    _bioCtrl = TextEditingController(text: widget.initialBio);
    _photoUrl = widget.currentPhotoUrl;
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last;
      final ref = FirebaseStorage.instance.ref().child('profile_images').child('$uid.$ext');

      await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
      final downloadUrl = await ref.getDownloadURL();

      setState(() {
        _photoUrl = downloadUrl;
        _isUploading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': _nameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        if (_photoUrl != null) 'photoUrl': _photoUrl,
      });

      widget.onSave(_nameCtrl.text.trim(), _phoneCtrl.text.trim(), _bioCtrl.text.trim(), _photoUrl);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: 60, bottom: keyboardHeight),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16213E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bump
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text('Edit Profile', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 24),

              // Avatar edit
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                    child: _photoUrl == null ? Icon(Icons.person, size: 40, color: primaryColor) : null,
                  ),
                  if (_isUploading)
                    const Positioned.fill(child: Center(child: CircularProgressIndicator())),
                  GestureDetector(
                    onTap: _isUploading ? null : _pickAndUploadPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFF16213E) : Colors.white, width: 2)),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              _Input(ctrl: _nameCtrl, label: 'Name', icon: Icons.person_outline, isDark: isDark, validator: (v) => v!.isEmpty ? 'Name required' : null),
              const SizedBox(height: 16),
              _Input(ctrl: _phoneCtrl, label: 'Phone', icon: Icons.phone_outlined, isDark: isDark, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _Input(ctrl: _bioCtrl, label: 'Bio (Optional)', icon: Icons.edit_note, isDark: isDark, maxLines: 3),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text('Save Changes', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool isDark;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final int maxLines;

  const _Input({required this.ctrl, required this.label, required this.icon, required this.isDark, this.validator, this.keyboardType = TextInputType.text, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 13),
        prefixIcon: Icon(icon, color: isDark ? Colors.white38 : Colors.grey[500], size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF0D1B2A) : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines > 1 ? 16 : 0),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard({required this.isDark, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16213E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool isDark;
  final Color primary;

  const _StatItem({required this.value, required this.label, required this.icon, required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: primary.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, color: primary, size: 22),
        ),
        const SizedBox(height: 10),
        Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        Text(label, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[600], height: 1.2)),
      ],
    );
  }
}
