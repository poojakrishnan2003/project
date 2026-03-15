import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:roamly/core/constants/mapbox_config.dart';
import 'package:roamly/core/services/search_service.dart';
import 'package:roamly/features/home/widgets/location_search_delegate.dart';
import 'package:roamly/models/search_result_model.dart';
import 'package:google_fonts/google_fonts.dart';

class TripLocationResult {
  final LatLng position;
  final String name;
  final String address;

  TripLocationResult({required this.position, required this.name, required this.address});
}

class TripLocationMapPicker extends StatefulWidget {
  final LatLng? initialPosition;
  
  const TripLocationMapPicker({super.key, this.initialPosition});

  @override
  State<TripLocationMapPicker> createState() => _TripLocationMapPickerState();
}

class _TripLocationMapPickerState extends State<TripLocationMapPicker> {
  final MapController _mapController = MapController();
  final SearchService _searchService = SearchService();
  late LatLng _selectedPosition;
  bool _isLoading = true;
  bool _isReversing = false;
  
  String _locationName = 'Selected Location';
  String _locationAddress = '';

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition ?? const LatLng(12.9716, 77.5946); // Default
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    if (widget.initialPosition != null) {
      setState(() => _isLoading = false);
      _updateLocationDetails(_selectedPosition);
      return;
    }

    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoading = false);
        return;
      } 

      final position = await Geolocator.getCurrentPosition();
      
      if (mounted) {
        setState(() {
          _selectedPosition = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        _updateLocationDetails(_selectedPosition);
        Future.delayed(const Duration(milliseconds: 500), () {
           _mapController.move(_selectedPosition, 15.0);
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLocationDetails(LatLng position, {String? defaultName, String? defaultAddress}) async {
    if (!mounted) return;
    setState(() {
      _isReversing = true;
      _locationName = defaultName ?? 'Resolving name...';
      _locationAddress = defaultAddress ?? 'Resolving address...';
    });

    try {
      final address = await _searchService.reverseGeocode(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          if (defaultName != null) {
            _locationName = defaultName;
            _locationAddress = defaultAddress ?? address ?? '';
          } else {
            if (address != null && address.isNotEmpty) {
               final parts = address.split(', ');
               _locationName = parts.first;
               _locationAddress = parts.length > 1 ? parts.sublist(1).join(', ') : address;
            } else {
               _locationName = 'Unknown Location';
               _locationAddress = '';
            }
          }
          _isReversing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationName = defaultName ?? 'Unknown Location';
          _locationAddress = defaultAddress ?? '';
          _isReversing = false;
        });
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng position) {
    setState(() {
      _selectedPosition = position;
    });
    _updateLocationDetails(position);
  }

  void _openSearch() async {
    final result = await showSearch<SearchResult?>(
      context: context,
      delegate: LocationSearchDelegate(userLocation: _selectedPosition),
    );

    if (result != null) {
      final newPos = LatLng(result.latitude, result.longitude);
      setState(() {
        _selectedPosition = newPos;
        _locationName = result.displayName;
        _locationAddress = result.subtitle ?? '';
        _isReversing = false;
      });
      _mapController.move(newPos, 15.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Location', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
            tooltip: 'Search for a place',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition,
              initialZoom: 13.0,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: MapboxConfig.streetStyleUrl,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPosition,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 50,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black12,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: isDark ? const Color(0xFF16213E) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.touch_app, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Tap map to pinpoint or use search to find places', style: GoogleFonts.poppins(fontSize: 12))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isReversing)
                       Text('Resolving location details...', style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic))
                    else
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(_locationName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                           if (_locationAddress.isNotEmpty)
                             Text(_locationAddress, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                         ],
                       )
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  context, 
                  TripLocationResult(position: _selectedPosition, name: _locationName, address: _locationAddress)
                );
              },
              icon: const Icon(Icons.check),
              label: Text('Confirm Location', style: GoogleFonts.poppins()),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
