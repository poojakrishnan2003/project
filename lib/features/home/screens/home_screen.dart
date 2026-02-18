import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:roamly/core/core.dart';
import 'package:roamly/core/services/location_service.dart';
import 'package:roamly/models/location_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roamly/features/shared/widgets/spot_map_picker.dart';
import '../widgets/add_spot_dialog.dart';
import '../widgets/location_search_delegate.dart';
import 'package:roamly/models/search_result_model.dart';
import 'package:roamly/core/constants/mapbox_config.dart';
import 'package:roamly/features/companions/screens/find_companion_screen.dart';
import 'package:roamly/features/shared/widgets/profile_image_widget.dart';
import 'package:roamly/features/profile/screens/profile_screen.dart';

/// Home screen with map view and mark spot feature
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _locationService = LocationService();
  final _mapController = MapController();
  List<LocationModel> _locations = [];
  final LatLng _center = const LatLng(12.9716, 77.5946); // Default: Bangalore
  LatLng? _currentPosition;
  LatLng? _searchResultLocation; // Marker for selected search result

  @override
  void initState() {
    super.initState();
    _loadLocations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleLocationButton();
    });
  }

  Future<void> _loadLocations() async {
    final locs = await _locationService.getLocations();
    setState(() {
      _locations = locs;
    });
  }

  Future<void> _handleLocationButton() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied, we cannot request permissions.',
            ),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(LatLng(position.latitude, position.longitude), 19);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    }
  }

  Future<void> _handleAddSpot() async {
    // Show dialog to choose location method
    final String? choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Location'),
        content: const Text(
          'How would you like to select the location for your new spot?',
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, 'current'),
            icon: const Icon(Icons.my_location),
            label: const Text('Current Location'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'map'),
            icon: const Icon(Icons.map),
            label: const Text('Pick on Map'),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    LatLng? spotLocation;

    if (choice == 'current') {
      // Use current location
      try {
        final position = await Geolocator.getCurrentPosition();
        spotLocation = LatLng(position.latitude, position.longitude);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not get current location. Try picking on map.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else {
      // Pick on map
      spotLocation = await Navigator.push<LatLng>(
        context,
        MaterialPageRoute(builder: (context) => const SpotMapPicker()),
      );
    }

    if (spotLocation == null || !mounted) return;

    // Use local variable to help Dart's flow analysis
    final selectedLocation = spotLocation;

    final LocationModel? newLocation = await showDialog<LocationModel>(
      context: context,
      builder: (context) => AddSpotDialog(
        currentLat: selectedLocation.latitude,
        currentLng: selectedLocation.longitude,
      ),
    );

    if (newLocation != null) {
      final error = await _locationService.addLocation(newLocation);
      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spot added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadLocations();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final result = await showSearch(
                context: context,
                delegate: LocationSearchDelegate(
                  userLocation: _currentPosition,
                  searchRadiusKm: 50.0,
                ),
              );

              if (result != null && mounted) {
                // Set search result marker location
                setState(() {
                  _searchResultLocation = LatLng(result.latitude, result.longitude);
                });

                // Move map to selected location with moderate zoom
                final location = LatLng(result.latitude, result.longitude);
                _mapController.move(location, 14.0); // Reduced from 16 to show more context

                // Show location details in bottom sheet
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => _SearchResultSheet(result: result),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _center, initialZoom: 19.0),
            children: [
              TileLayer(
                urlTemplate: MapboxConfig.streetStyleUrl,
                additionalOptions: const {
                  'id': 'mapbox.streets',
                },
              ),
              MarkerLayer(
                markers: _locations.map((loc) {
                  return Marker(
                    point: LatLng(loc.latitude, loc.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (ctx) =>
                              _LocationDetailsSheet(location: loc),
                        );
                      },
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.withValues(alpha: 0.3),
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: const Center(
                          child: CircleAvatar(
                            radius: 6,
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              // Marker for selected search result
              if (_searchResultLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _searchResultLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.place,
                        color: Colors.purple,
                        size: 50,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black45,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Quick action FAB
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'location',
                  onPressed: _handleLocationButton,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: Icon(
                    Icons.my_location,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'add',
                  onPressed: _handleAddSpot,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Trips',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _LocationDetailsSheet extends StatelessWidget {
  final LocationModel location;

  const _LocationDetailsSheet({required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(location.name, style: Theme.of(context).textTheme.headlineSmall),
          if (location.rating != null)
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                Text(location.rating.toString()),
              ],
            ),
          const SizedBox(height: 8),
          Text(location.description ?? 'No description'),
          const SizedBox(height: 16),
          if (location.imageUrl != null)
            Image.network(
              location.imageUrl!,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
        ],
      ),
    );
  }
}

/// App drawer for navigation
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = Theme.of(context).colorScheme.primary;
    final textStyle = GoogleFonts.poppins(fontWeight: FontWeight.w500);

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: uid != null
                ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots()
                : const Stream.empty(),
            builder: (context, snapshot) {
              // Get data from Firestore profile (if loaded), fallback to FirebaseAuth
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final displayName = data?['name'] ??
                  ((user?.displayName != null && user!.displayName!.isNotEmpty)
                      ? user.displayName!
                      : 'Rider');
              final firestorePhoto = data?['photoUrl'] as String?;
              final authPhoto = user?.photoURL;
              final photoUrl = firestorePhoto ?? authPhoto;
              final email = data?['email'] ?? user?.email ?? '';

              // Sync photo from FirebaseAuth → Firestore if Firestore is missing it
              if (firestorePhoto == null && authPhoto != null && uid != null && snapshot.hasData) {
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({'photoUrl': authPhoto})
                    .then((_) => debugPrint('Synced photoUrl to Firestore'))
                    .catchError((e) => debugPrint('Failed to sync photoUrl: $e'));
              }

              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                child: DrawerHeader(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF0D1652), const Color(0xFF1A237E)]
                          : [const Color(0xFF1A237E), const Color(0xFF3949AB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Profile picture or fallback avatar
                      ProfileImageWidget(
                        photoUrl: photoUrl,
                        fallbackLetter: displayName[0],
                        size: 64,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Welcome, $displayName!',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.home_outlined, color: iconColor),
            title: Text('Home', style: textStyle),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Icon(Icons.person_outline, color: iconColor),
            title: Text('Profile', style: textStyle),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.route_outlined, color: iconColor),
            title: Text('My Trips', style: textStyle),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to trips
            },
          ),
          ListTile(
            leading: Icon(Icons.people_outline, color: iconColor),
            title: Text('Find Companions', style: textStyle),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FindCompanionScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.star_outline, color: iconColor),
            title: Text('Hidden Gems', style: textStyle),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to hidden gems
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.settings_outlined, color: iconColor),
            title: Text('Settings', style: textStyle),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to settings
            },
          ),
          ListTile(
            leading: Icon(Icons.help_outline, color: iconColor),
            title: Text('Help & Feedback', style: textStyle),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.red)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to display search result details
class _SearchResultSheet extends StatelessWidget {
  final SearchResult result;

  const _SearchResultSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.source == SearchResultSource.userAdded
                    ? Icons.location_on
                    : Icons.map,
                color: result.source == SearchResultSource.userAdded
                    ? Colors.green
                    : Colors.purple, // Purple for Mapbox
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (result.subtitle != null)
            Text(
              result.subtitle!,
              style: TextStyle(color: Colors.grey[600]),
            ),
          const SizedBox(height: 8),
          Text(
            'Source: ${result.source == SearchResultSource.userAdded ? "User-Added Location" : "Mapbox"}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            'Coordinates: ${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          // Show additional details for Firestore locations
          if (result.firestoreLocation != null) ...[
            const SizedBox(height: 16),
            if (result.firestoreLocation!.rating != null)
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(result.firestoreLocation!.rating.toString()),
                ],
              ),
            if (result.firestoreLocation!.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: result.firestoreLocation!.tags.map((tag) {
                  return Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
            if (result.firestoreLocation!.imageUrl != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  result.firestoreLocation!.imageUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
