import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roamly/core/services/trip_service.dart';
import 'package:roamly/core/services/user_service.dart';
import 'package:roamly/models/trip_model.dart';
import 'package:roamly/models/trip_items_model.dart';
import 'package:roamly/models/user_profile_model.dart';
import 'package:roamly/core/services/search_service.dart';
import '../widgets/trip_location_map_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripDetailsScreen extends StatefulWidget {
  final String tripId;

  const TripDetailsScreen({super.key, required this.tripId});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> with SingleTickerProviderStateMixin {
  final TripService _tripService = TripService();
  final UserService _userService = UserService();
  final SearchService _searchService = SearchService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return StreamBuilder<TripModel?>(
      stream: _tripService.getTripStream(widget.tripId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text(snapshot.error?.toString() ?? 'Trip not found')),
          );
        }

        final trip = snapshot.data!;
        final canEdit = trip.ownerId == _currentUserId || trip.editorIds.contains(_currentUserId);
        final isOwner = trip.ownerId == _currentUserId;

        return Scaffold(
          appBar: AppBar(
            title: Text(trip.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            backgroundColor: isDark ? const Color(0xFF16213E) : Colors.white,
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: primary,
              labelColor: primary,
              unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Itinerary'),
                Tab(text: 'Companions'),
                Tab(text: 'Budget'),
                Tab(text: 'Packing List'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildItineraryTab(trip, canEdit, isDark, primary),
              _buildCompanionsTab(trip, isOwner, isDark, primary),
              _buildBudgetTab(trip, canEdit, isDark, primary),
              _buildPackingListTab(trip, canEdit, isDark, primary),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItineraryTab(TripModel trip, bool canEdit, bool isDark, Color primary) {
    if (trip.locations.isEmpty && trip.hotels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No itinerary added yet', style: GoogleFonts.poppins(color: isDark ? Colors.white54 : Colors.grey[600])),
            if (canEdit) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showAddLocationDialog(trip),
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Add Location'),
              )
            ]
          ],
        ),
      );
    }

    return Column(
      children: [
        if (canEdit)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showAddLocationDialog(trip),
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Add Location'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showAddHotelDialog(trip),
                  icon: const Icon(Icons.hotel),
                  label: const Text('Add Hotel'),
                ),
                if (trip.destination != null && trip.destination!.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => _showSuggestPlacesSheet(trip),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Suggest Places'),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: trip.locations.length,
            onReorder: canEdit ? (oldIndex, newIndex) {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final locations = List<TripLocation>.from(trip.locations);
              final item = locations.removeAt(oldIndex);
              locations.insert(newIndex, item);
              
              // Update sequence numbers
              for (int i = 0; i < locations.length; i++) {
                locations[i] = locations[i].copyWith(sequence: i);
              }
              
              _tripService.updateTrip(trip.copyWith(locations: locations));
            } : (oldIndex, newIndex) {},
            itemBuilder: (context, index) {
              final loc = trip.locations[index];
              return ListTile(
                key: ValueKey(loc.id),
                leading: CircleAvatar(
                  backgroundColor: primary.withValues(alpha: 0.1),
                  child: Text('${index + 1}', style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
                ),
                title: Text(loc.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text(loc.address, style: GoogleFonts.poppins(fontSize: 12)),
                trailing: canEdit ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        final updatedLocations = List<TripLocation>.from(trip.locations)..removeAt(index);
                        _tripService.updateTrip(trip.copyWith(locations: updatedLocations));
                      },
                    ),
                    const Icon(Icons.drag_handle),
                  ],
                ) : null,
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddLocationDialog(TripModel trip) {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    
    double lat = 0;
    double lng = 0;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF16213E) : Colors.white,
          title: Text('Add Location', style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<TripLocationResult>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TripLocationMapPicker(),
                        ),
                      );
                      if (result != null) {
                        nameCtrl.text = result.name;
                        addressCtrl.text = result.address;
                        lat = result.position.latitude;
                        lng = result.position.longitude;
                      }
                    },
                    icon: const Icon(Icons.map),
                    label: Text('Select from Map', style: GoogleFonts.poppins()),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Location Name')),
                const SizedBox(height: 8),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
                const SizedBox(height: 8),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes (Optional)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty) return;
                
                final newLocation = TripLocation(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  latitude: lat,
                  longitude: lng,
                  sequence: trip.locations.length,
                  notes: notesCtrl.text.trim(),
                );
                
                final updatedLocations = List<TripLocation>.from(trip.locations)..add(newLocation);
                _tripService.updateTrip(trip.copyWith(locations: updatedLocations));
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showAddHotelDialog(TripModel trip) {
    // Basic dialog for Hotel, similar concept
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF16213E) : Colors.white,
          title: Text('Add Hotel', style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Hotel Name')),
                const SizedBox(height: 8),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty) return;
                
                final newHotel = TripHotel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  checkIn: DateTime.now(), // simplify for now, would need date pickers
                  checkOut: DateTime.now().add(const Duration(days: 1)),
                );
                
                final updatedHotels = List<TripHotel>.from(trip.hotels)..add(newHotel);
                _tripService.updateTrip(trip.copyWith(hotels: updatedHotels));
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showSuggestPlacesSheet(TripModel trip) {
    if (trip.destination == null || trip.destination!.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primary = Theme.of(context).colorScheme.primary;
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16213E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Suggested in ${trip.destination}', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder(
                      future: _searchService.search("${trip.destination} tourist attractions"),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Failed to load suggestions', style: GoogleFonts.poppins()));
                        }
                        
                        final results = snapshot.data ?? [];
                        if (results.isEmpty) {
                          return Center(child: Text('No suggestions found for ${trip.destination}', style: GoogleFonts.poppins()));
                        }

                        // Filter out results we already have
                        final existingNames = trip.locations.map((e) => e.name.toLowerCase()).toSet();
                        final suggestions = results.where((r) => !existingNames.contains(r.displayName.toLowerCase())).toList();

                        if (suggestions.isEmpty) {
                           return Center(child: Text('You have added all suggested places!', style: GoogleFonts.poppins()));
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            final result = suggestions[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: primary.withValues(alpha: 0.1),
                                child: Icon(Icons.place, color: primary),
                              ),
                              title: Text(result.displayName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                              subtitle: Text(result.subtitle ?? 'Tourist Attraction', style: GoogleFonts.poppins(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: OutlinedButton(
                                onPressed: () {
                                  final newLoc = TripLocation(
                                    id: DateTime.now().millisecondsSinceEpoch.toString() + index.toString(),
                                    name: result.displayName,
                                    address: result.subtitle ?? trip.destination!,
                                    latitude: result.latitude,
                                    longitude: result.longitude,
                                    sequence: trip.locations.length,
                                  );
                                  final updatedList = List<TripLocation>.from(trip.locations)..add(newLoc);
                                  _tripService.updateTrip(trip.copyWith(locations: updatedList));
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${result.displayName}')));
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Add'),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompanionsTab(TripModel trip, bool isOwner, bool isDark, Color primary) {
    if (trip.companionIds.isEmpty && trip.editorIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No companions yet', style: GoogleFonts.poppins(color: isDark ? Colors.white54 : Colors.grey[600])),
            if (isOwner) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showInviteCompanionDialog(trip),
                icon: const Icon(Icons.person_add),
                label: const Text('Invite Companions'),
              )
            ]
          ],
        ),
      );
    }

    // Temporary mock list of all users involved just by their IDs for now,
    // later this needs to fetch real user details from UserService.
    final allUsers = [...trip.companionIds, ...trip.editorIds, ...trip.pendingCompanionIds, ...trip.pendingEditorIds].toSet().toList();

    return Column(
      children: [
        if (isOwner)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => _showInviteCompanionDialog(trip),
              icon: const Icon(Icons.person_add),
              label: const Text('Invite Companions'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: allUsers.length,
            itemBuilder: (context, index) {
              final userId = allUsers[index];
              final isEditor = trip.editorIds.contains(userId);
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.person),
                ),
                title: Text('User $userId', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  trip.pendingCompanionIds.contains(userId) || trip.pendingEditorIds.contains(userId)
                      ? 'Pending Invite'
                      : isEditor ? 'Can Edit' : 'Can View',
                  style: GoogleFonts.poppins(
                    fontSize: 12, 
                    color: trip.pendingCompanionIds.contains(userId) || trip.pendingEditorIds.contains(userId) ? Colors.orange : null
                  )
                ),
                trailing: isOwner ? PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'remove') {
                      // TODO: Implement remove
                    } else if (val == 'make_editor') {
                      // TODO: Implement role change
                    } else if (val == 'make_viewer') {
                      // TODO: Implement role change
                    }
                  },
                  itemBuilder: (context) => [
                    if (isEditor)
                      const PopupMenuItem(value: 'make_viewer', child: Text('Change to Viewer'))
                    else
                      const PopupMenuItem(value: 'make_editor', child: Text('Change to Editor')),
                    const PopupMenuItem(value: 'remove', child: Text('Remove from Trip', style: TextStyle(color: Colors.red))),
                  ],
                ) : null,
              );
            },
          ),
        ),
      ],
    );
  }

  void _showInviteCompanionDialog(TripModel trip) async {
    // Quick and simple bottom sheet to invite users
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF16213E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return FutureBuilder<UserProfile?>(
          future: _userService.getUserProfile(_currentUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('Could not load friends list.'));
            }
            
            final currentUserProfile = snapshot.data!;
            final connectedIds = currentUserProfile.connectedUserIds;

            if (connectedIds.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text('You have no connected companions to invite. Find companions in the Explore tab!', 
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(),
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Invite Companions', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: FutureBuilder<List<UserProfile>>(
                    future: _userService.getUsers(connectedIds),
                    builder: (context, usersSnapshot) {
                      if (usersSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final users = usersSnapshot.data ?? [];
                      
                      return ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final isAlreadyInvited = trip.companionIds.contains(user.uid) || trip.editorIds.contains(user.uid) || trip.pendingCompanionIds.contains(user.uid) || trip.pendingEditorIds.contains(user.uid);
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty ? NetworkImage(user.photoUrl!) : null,
                              child: (user.photoUrl == null || user.photoUrl!.isEmpty) ? const Icon(Icons.person) : null,
                            ),
                            title: Text(user.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                            trailing: isAlreadyInvited ? const Text('Added/Pending', style: TextStyle(color: Colors.grey)) : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    final updatedPendingViewers = List<String>.from(trip.pendingCompanionIds)..add(user.uid);
                                    _tripService.updateTrip(trip.copyWith(pendingCompanionIds: updatedPendingViewers));
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Viewer'),
                                ),
                                FilledButton.tonal(
                                  onPressed: () {
                                    final updatedPendingEditors = List<String>.from(trip.pendingEditorIds)..add(user.uid);
                                    _tripService.updateTrip(trip.copyWith(pendingEditorIds: updatedPendingEditors));
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Editor'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBudgetTab(TripModel trip, bool canEdit, bool isDark, Color primary) {
    if (trip.budgetItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No budget items yet', style: GoogleFonts.poppins(color: isDark ? Colors.white54 : Colors.grey[600])),
            if (canEdit) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showAddBudgetDialog(trip),
                icon: const Icon(Icons.add),
                label: const Text('Add Expense'),
              )
            ]
          ],
        ),
      );
    }

    double totalSpent = trip.budgetItems.fold(0, (sum, item) => sum + item.amount);
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.8)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Spent', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('\$${totalSpent.toStringAsFixed(2)}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
              if (canEdit)
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.white, size: 32),
                  onPressed: () => _showAddBudgetDialog(trip),
                )
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: trip.budgetItems.length,
            itemBuilder: (context, index) {
              final item = trip.budgetItems[index];
              return Card(
                elevation: 0,
                color: isDark ? const Color(0xFF16213E) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: primary.withValues(alpha: 0.1),
                    child: Icon(Icons.monetization_on, color: primary),
                  ),
                  title: Text(item.description, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  subtitle: Text(item.category, style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600])),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${item.currency} ${item.amount.toStringAsFixed(2)}', 
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (canEdit)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () {
                            final updatedItems = List<BudgetItem>.from(trip.budgetItems)..removeAt(index);
                            _tripService.updateTrip(trip.copyWith(budgetItems: updatedItems));
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddBudgetDialog(TripModel trip) {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'General');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF16213E) : Colors.white,
          title: Text('Add Expense', style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 8),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 8),
                TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (descCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                
                final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amount <= 0) return;

                final newItem = BudgetItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  description: descCtrl.text.trim(),
                  amount: amount,
                  category: categoryCtrl.text.trim(),
                  currency: 'USD',
                );
                
                final updatedItems = List<BudgetItem>.from(trip.budgetItems)..add(newItem);
                _tripService.updateTrip(trip.copyWith(budgetItems: updatedItems));
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPackingListTab(TripModel trip, bool canEdit, bool isDark, Color primary) {
    if (trip.packingItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.luggage_outlined, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Packing list is empty', style: GoogleFonts.poppins(color: isDark ? Colors.white54 : Colors.grey[600])),
            if (canEdit) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showAddPackingItemDialog(trip),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              )
            ]
          ],
        ),
      );
    }

    final packedCount = trip.packingItems.where((i) => i.isPacked).length;
    final progress = trip.packingItems.isEmpty ? 0.0 : packedCount / trip.packingItems.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Packed: $packedCount / ${trip.packingItems.length}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  if (canEdit)
                    TextButton.icon(
                      onPressed: () => _showAddPackingItemDialog(trip),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item'),
                    )
                ],
              ),
              const SizedBox(height: 8),
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
        Expanded(
          child: ListView.builder(
            itemCount: trip.packingItems.length,
            itemBuilder: (context, index) {
              final item = trip.packingItems[index];
              return CheckboxListTile(
                value: item.isPacked,
                activeColor: primary,
                onChanged: canEdit ? (bool? val) {
                  if (val != null) {
                    final items = List<PackingItem>.from(trip.packingItems);
                    items[index] = item.copyWith(isPacked: val);
                    _tripService.updateTrip(trip.copyWith(packingItems: items));
                  }
                } : null,
                title: Text(
                  item.name, 
                  style: GoogleFonts.poppins(
                    decoration: item.isPacked ? TextDecoration.lineThrough : null,
                    color: item.isPacked ? Colors.grey : (isDark ? Colors.white : Colors.black87)
                  )
                ),
                subtitle: Text(item.category, style: GoogleFonts.poppins(fontSize: 12)),
                secondary: canEdit ? IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () {
                    final items = List<PackingItem>.from(trip.packingItems);
                    items.removeAt(index);
                    _tripService.updateTrip(trip.copyWith(packingItems: items));
                  },
                ) : null,
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddPackingItemDialog(TripModel trip) {
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'General');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF16213E) : Colors.white,
          title: Text('Add Item', style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name')),
                const SizedBox(height: 8),
                TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty) return;

                final newItem = PackingItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim(),
                  category: categoryCtrl.text.trim(),
                  isPacked: false,
                );
                
                final updatedItems = List<PackingItem>.from(trip.packingItems)..add(newItem);
                _tripService.updateTrip(trip.copyWith(packingItems: updatedItems));
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
