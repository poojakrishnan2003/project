import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:roamly/core/core.dart';
import 'package:roamly/core/services/location_service.dart';
import 'package:roamly/models/location_model.dart';
import 'package:roamly/features/shared/widgets/spot_map_picker.dart';
import 'package:roamly/features/home/widgets/add_spot_dialog.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final _locationService = LocationService();
  List<LocationModel> _pendingLocations = [];
  bool _isLoading = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPendingLocations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingLocations() async {
    setState(() => _isLoading = true);
    final locs = await _locationService.getPendingLocations();
    setState(() {
      _pendingLocations = locs;
      _isLoading = false;
    });
  }

  Future<void> _approveLocation(String id) async {
    await _locationService.updateLocationStatus(id, 'approved');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Spot Approved!'), backgroundColor: Colors.green),
    );
    _loadPendingLocations();
  }

  Future<void> _rejectLocation(String id) async {
    await _locationService.deleteLocation(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Spot Rejected (Deleted)'), backgroundColor: Colors.red),
    );
    _loadPendingLocations();
  }

  Future<void> _handleAddSpot() async {
    final LatLng? selectedLocation = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (context) => const SpotMapPicker()),
    );
    if (selectedLocation == null || !mounted) return;

    final LocationModel? newLocation = await showDialog<LocationModel>(
      context: context,
      builder: (context) => AddSpotDialog(
        currentLat: selectedLocation.latitude,
        currentLng: selectedLocation.longitude,
      ),
    );

    if (newLocation != null) {
      final error = await _locationService.addLocationAsAdmin(newLocation);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Spot added successfully!'),
          backgroundColor: error != null ? Colors.red : Colors.green,
        ),
      );
      _loadPendingLocations();
    }
  }

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: isDark ? const Color(0xFF16213E) : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(),
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.grey[600],
          tabs: const [
            Tab(icon: Icon(Icons.location_on_outlined), text: 'Pending Spots'),
            Tab(icon: Icon(Icons.feedback_outlined), text: 'User Feedback'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingSpotsTab(
            isLoading: _isLoading,
            locations: _pendingLocations,
            onApprove: _approveLocation,
            onReject: _rejectLocation,
          ),
          const _FeedbackTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleAddSpot,
        icon: const Icon(Icons.add_location_alt),
        label: Text('Add New Spot', style: GoogleFonts.poppins()),
      ),
    );
  }
}

// ── Tab 1: Pending Spots ──────────────────────────────────────────────────

class _PendingSpotsTab extends StatelessWidget {
  final bool isLoading;
  final List<LocationModel> locations;
  final Function(String) onApprove;
  final Function(String) onReject;

  const _PendingSpotsTab({
    required this.isLoading,
    required this.locations,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (locations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('No pending approvals!'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final loc = locations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(loc.type.name.toUpperCase()),
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                      labelStyle: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    Text('Rating: ${loc.rating}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(loc.name, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  loc.description ?? 'No description',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Location: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => onReject(loc.id!),
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Reject', style: TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => onApprove(loc.id!),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Tab 2: User Feedback ──────────────────────────────────────────────────

class _FeedbackTab extends StatelessWidget {
  const _FeedbackTab();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _FeedbackSection(
          title: 'Problem Reports',
          icon: Icons.bug_report_outlined,
          iconColor: Colors.orange,
          collection: 'reports',
          isDark: isDark,
          itemBuilder: (data, date) => _ReportCard(data: data, date: date, isDark: isDark),
        ),
        const SizedBox(height: 20),
        _FeedbackSection(
          title: 'App Feedback',
          icon: Icons.star_outline,
          iconColor: Colors.amber,
          collection: 'feedback',
          isDark: isDark,
          itemBuilder: (data, date) => _FeedbackCard(data: data, date: date, isDark: isDark),
        ),
        const SizedBox(height: 20),
        _FeedbackSection(
          title: 'Contact Messages',
          icon: Icons.mail_outline,
          iconColor: Colors.blue,
          collection: 'contact_messages',
          isDark: isDark,
          itemBuilder: (data, date) => _ContactCard(data: data, date: date, isDark: isDark),
        ),
      ],
    );
  }
}

class _FeedbackSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String collection;
  final bool isDark;
  final Widget Function(Map<String, dynamic> data, DateTime? date) itemBuilder;

  const _FeedbackSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.collection,
    required this.isDark,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(collection)
              .orderBy('createdAt', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _EmptyState(isDark: isDark, message: 'No $title yet');
            }
            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final ts = data['createdAt'] as Timestamp?;
                final date = ts?.toDate();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: itemBuilder(data, date),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final DateTime? date;
  final bool isDark;
  const _ReportCard({required this.data, required this.date, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _FbCard(
      isDark: isDark,
      accentColor: Colors.orange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(data['title'] ?? '(No title)', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87))),
            _StatusChip(status: data['status'] ?? 'new'),
          ]),
          const SizedBox(height: 6),
          Text(data['description'] ?? '', style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[700])),
          const SizedBox(height: 8),
          _DateRow(date: date, userId: data['userId'], isDark: isDark),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final DateTime? date;
  final bool isDark;
  const _FeedbackCard({required this.data, required this.date, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final rating = (data['rating'] as int?) ?? 0;
    return _FbCard(
      isDark: isDark,
      accentColor: Colors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: List.generate(5, (i) => Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 20))),
          const SizedBox(height: 8),
          Text(data['message'] ?? '', style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[700])),
          const SizedBox(height: 8),
          _DateRow(date: date, userId: data['userId'], isDark: isDark),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final DateTime? date;
  final bool isDark;
  const _ContactCard({required this.data, required this.date, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _FbCard(
      isDark: isDark,
      accentColor: Colors.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.person_outline, size: 16, color: isDark ? Colors.white54 : Colors.grey[500]),
            const SizedBox(width: 6),
            Text(data['name'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(width: 12),
            Icon(Icons.mail_outline, size: 16, color: isDark ? Colors.white54 : Colors.grey[500]),
            const SizedBox(width: 4),
            Expanded(child: Text(data['email'] ?? '', style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600]), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 8),
          Text(data['message'] ?? '', style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[700])),
          const SizedBox(height: 8),
          _DateRow(date: date, userId: data['userId'], isDark: isDark),
        ],
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────

class _FbCard extends StatelessWidget {
  final bool isDark;
  final Color accentColor;
  final Widget child;
  const _FbCard({required this.isDark, required this.accentColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16213E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'resolved' ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
      child: Text(status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _DateRow extends StatelessWidget {
  final DateTime? date;
  final String? userId;
  final bool isDark;
  const _DateRow({required this.date, required this.userId, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final dateStr = date != null ? DateFormat('MMM d, yyyy · h:mm a').format(date!) : 'Unknown date';
    return Row(children: [
      Icon(Icons.access_time, size: 13, color: isDark ? Colors.white38 : Colors.grey[400]),
      const SizedBox(width: 4),
      Text(dateStr, style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey[500])),
    ]);
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final String message;
  const _EmptyState({required this.isDark, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16213E) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Center(
        child: Text(message, style: GoogleFonts.poppins(color: isDark ? Colors.white38 : Colors.grey[500])),
      ),
    );
  }
}
