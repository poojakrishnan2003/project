import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

// ── Models ──────────────────────────────────────────────────────────────

class SimpleTrip {
  final String id;
  String name;
  String destination;
  DateTime startDate;
  DateTime endDate;
  String notes;
  List<SimplePlace> places;

  SimpleTrip({
    required this.id,
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    this.notes = '',
    this.places = const [],
  });
}

class SimplePlace {
  final String id;
  final String name;
  final String location;

  SimplePlace({required this.id, required this.name, required this.location});
}

// ── Main Screen ─────────────────────────────────────────────────────────

/// My Trips screen that manages a list of trips and handles CRUD ops locally.
class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  final List<SimpleTrip> _trips = [];
  final _uuid = Uuid();

  // Selected trip to show details for (null = list view)
  SimpleTrip? _selectedTrip;

  @override
  Widget build(BuildContext context) {
    if (_selectedTrip != null) {
      return _TripDetailsView(
        trip: _selectedTrip!,
        onBack: () => setState(() => _selectedTrip = null),
        onUpdate: () => setState(() {}),
      );
    }
    return _TripsListView(
      trips: _trips,
      onCreateTrip: _createNewTrip,
      onViewTrip: (trip) => setState(() => _selectedTrip = trip),
      onEditTrip: _editTrip,
      onDeleteTrip: _deleteTrip,
    );
  }

  void _createNewTrip() {
    _showTripFormModal(context, null).then((newTrip) {
      if (newTrip != null) {
        setState(() => _trips.insert(0, newTrip));
      }
    });
  }

  void _editTrip(SimpleTrip trip) {
    _showTripFormModal(context, trip).then((updatedTrip) {
      if (updatedTrip != null) {
        setState(() {
          final idx = _trips.indexWhere((t) => t.id == updatedTrip.id);
          if (idx != -1) _trips[idx] = updatedTrip;
        });
      }
    });
  }

  void _deleteTrip(SimpleTrip trip) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF16213E) : Colors.white,
          title: Text('Delete Trip?', style: GoogleFonts.poppins(color: Colors.red)),
          content: Text('Are you sure you want to delete "${trip.name}"?', 
            style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black87)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() => _trips.removeWhere((t) => t.id == trip.id));
                Navigator.pop(ctx);
              },
              child: Text('Delete', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  Future<SimpleTrip?> _showTripFormModal(BuildContext context, SimpleTrip? existingTrip) {
    return showModalBottomSheet<SimpleTrip>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TripFormSheet(
        existingTrip: existingTrip,
        onSave: (name, dest, start, end, notes) {
          if (existingTrip == null) {
            return SimpleTrip(
              id: _uuid.v4(),
              name: name,
              destination: dest,
              startDate: start,
              endDate: end,
              notes: notes,
            );
          } else {
            existingTrip.name = name;
            existingTrip.destination = dest;
            existingTrip.startDate = start;
            existingTrip.endDate = end;
            existingTrip.notes = notes;
            return existingTrip;
          }
        },
      ),
    );
  }
}

// ── Trips List View ─────────────────────────────────────────────────────

// ignore: must_be_immutable
class _TripsListView extends StatelessWidget {
  final List<SimpleTrip> trips;
  final VoidCallback onCreateTrip;
  final Function(SimpleTrip) onViewTrip;
  final Function(SimpleTrip) onEditTrip;
  final Function(SimpleTrip) onDeleteTrip;

  _TripsListView({
    required this.trips,
    required this.onCreateTrip,
    required this.onViewTrip,
    required this.onEditTrip,
    required this.onDeleteTrip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final bgColor = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF4F6FB);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('My Trips', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: isDark ? const Color(0xFF16213E) : Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: FilledButton.icon(
              onPressed: onCreateTrip,
              style: FilledButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.add, size: 18),
              label: Text('New Trip', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: trips.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length,
              itemBuilder: (ctx, i) => _TripCard(
                trip: trips[i],
                isDark: isDark,
                primary: primary,
                onView: () => onViewTrip(trips[i]),
                onEdit: () => onEditTrip(trips[i]),
                onDelete: () => onDeleteTrip(trips[i]),
              ),
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight_takeoff_rounded, size: 80, color: isDark ? Colors.white24 : Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              'No trips yet',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              'You have no trips yet. Start planning your next adventure!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.white54 : Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              width: 200,
              child: FilledButton(
                onPressed: onCreateTrip,
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text('Create New Trip', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: must_be_immutable
class _TripCard extends StatelessWidget {
  final SimpleTrip trip;
  final bool isDark;
  final Color primary;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  _TripCard({
    required this.trip,
    required this.isDark,
    required this.primary,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final dateString = '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16213E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        trip.name,
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: Text('${trip.places.length} places', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: isDark ? Colors.white54 : Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(trip.destination, style: GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey[700])),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 16, color: isDark ? Colors.white54 : Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(dateString, style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                  label: const Text('View'),
                  style: TextButton.styleFrom(foregroundColor: primary, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              Container(width: 1, height: 24, color: isDark ? Colors.grey[800] : Colors.grey[200]),
              Expanded(
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(foregroundColor: isDark ? Colors.white70 : Colors.grey[700], padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              Container(width: 1, height: 24, color: isDark ? Colors.grey[800] : Colors.grey[200]),
              Expanded(
                child: TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Trip Details View ───────────────────────────────────────────────────

// ignore: must_be_immutable
class _TripDetailsView extends StatelessWidget {
  final SimpleTrip trip;
  final VoidCallback onBack;
  final VoidCallback onUpdate;
  final _uuid = Uuid();

  _TripDetailsView({required this.trip, required this.onBack, required this.onUpdate});

  void _addMockPlace(BuildContext context) {
    // Generate a mock place and add to trip
    final newPlace = SimplePlace(
      id: _uuid.v4(),
      name: 'Eiffel Tower Tour ${trip.places.length + 1}',
      location: trip.destination,
    );
    trip.places.add(newPlace);
    onUpdate();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added place to trip'), backgroundColor: Color(0xFF06D6A0)),
    );
  }

  void _removePlace(BuildContext context, String placeId) {
    trip.places.removeWhere((p) => p.id == placeId);
    onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final bgColor = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF4F6FB);
    final dateFormat = DateFormat('MMMM d, yyyy');
    
    // Calculate mock progress (max 5 or current length + 2)
    final totalExpected = trip.places.length < 5 ? 5 : trip.places.length + 2;
    final visitedCount = trip.places.length;
    final progress = visitedCount / totalExpected;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Trip Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: isDark ? const Color(0xFF16213E) : Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trip.name, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(trip.destination, style: GoogleFonts.poppins(fontSize: 15, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text('${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Progress Card
          _SectionCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trip Progress', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Visited: $visitedCount / $totalExpected places', style: GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey[700])),
                    Text('${(progress * 100).toInt()}%', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: primary)),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Notes
          if (trip.notes.isNotEmpty) ...[
            _SectionCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 12),
                  Text(trip.notes, style: GoogleFonts.poppins(fontSize: 14, height: 1.5, color: isDark ? Colors.white70 : Colors.grey[700])),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Places List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Places to Visit', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              TextButton.icon(
                onPressed: () => _addMockPlace(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Place'),
                style: TextButton.styleFrom(foregroundColor: primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (trip.places.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text('No places added yet.', style: GoogleFonts.poppins(color: isDark ? Colors.white54 : Colors.grey[500])),
              ),
            )
          else
            ...trip.places.map((place) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF16213E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.place, color: primary),
                    ),
                    title: Text(place.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                    subtitle: Text(place.location, style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600])),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () => _removePlace(context, place.id),
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

// ── Shared Widgets ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _SectionCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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

// ── Create/Edit Form Bottom Sheet ───────────────────────────────────────

// ignore: must_be_immutable
class _TripFormSheet extends StatefulWidget {
  final SimpleTrip? existingTrip;
  final SimpleTrip Function(String name, String dest, DateTime start, DateTime end, String notes) onSave;

  _TripFormSheet({this.existingTrip, required this.onSave});

  @override
  State<_TripFormSheet> createState() => _TripFormSheetState();
}

class _TripFormSheetState extends State<_TripFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _destCtrl;
  late TextEditingController _notesCtrl;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existingTrip?.name ?? '');
    _destCtrl = TextEditingController(text: widget.existingTrip?.destination ?? '');
    _notesCtrl = TextEditingController(text: widget.existingTrip?.notes ?? '');
    _startDate = widget.existingTrip?.startDate;
    _endDate = widget.existingTrip?.endDate;
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (ctx, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(primary: Theme.of(context).colorScheme.primary, surface: const Color(0xFF16213E))
                : ColorScheme.light(primary: Theme.of(context).colorScheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select dates'), backgroundColor: Colors.orange));
      return;
    }

    final savedTrip = widget.onSave(_nameCtrl.text.trim(), _destCtrl.text.trim(), _startDate!, _endDate!, _notesCtrl.text.trim());
    Navigator.pop(context, savedTrip);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.existingTrip != null;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      margin: EdgeInsets.only(top: 80, bottom: keyboardHeight),
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
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text(isEditing ? 'Edit Trip' : 'Create New Trip', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 24),

              // Inputs
              _Input(ctrl: _nameCtrl, label: 'Trip Name', icon: Icons.map, isDark: isDark, validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              _Input(ctrl: _destCtrl, label: 'Destination', icon: Icons.location_city, isDark: isDark, validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              
              // Date picker
              InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1B2A) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month, color: isDark ? Colors.white38 : Colors.grey[500], size: 20),
                      const SizedBox(width: 16),
                      Text(
                        _startDate != null && _endDate != null
                            ? '${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)}'
                            : 'Select Dates',
                        style: GoogleFonts.poppins(color: _startDate != null ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white54 : Colors.grey[600]), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _Input(ctrl: _notesCtrl, label: 'Notes (Optional)', icon: Icons.notes, isDark: isDark, maxLines: 3),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text('Save Trip', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
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
  final int maxLines;

  const _Input({required this.ctrl, required this.label, required this.icon, required this.isDark, this.validator, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
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
