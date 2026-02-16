import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../models/search_result_model.dart';
import 'mapbox_geocoding_service.dart';
import 'location_service.dart';

/// Main search service that combines Mapbox Geocoding and Firestore results
class SearchService {
  final MapboxGeocodingService _mapboxService = MapboxGeocodingService();
  final LocationService _locationService = LocationService();

  /// Maximum number of results to return
  static const int _maxResults = 20;

  /// Perform comprehensive search across all sources
  /// 
  /// [query] - The search query string
  /// [userLocation] - Optional user location for proximity bias
  Future<List<SearchResult>> search(
    String query, {
    LatLng? userLocation,
    double? radiusKm, // Kept for API compatibility, not used
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      // Search both sources in parallel
      final results = await Future.wait([
        _searchMapbox(query, userLocation),
        _searchFirestore(query, userLocation),
      ]);

      final mapboxResults = results[0];
      final firestoreResults = results[1];

      // Combine results - Firestore first, then Mapbox
      final combinedResults = [...firestoreResults, ...mapboxResults];

      // Limit results
      return combinedResults.take(_maxResults).toList();
    } catch (e) {
      debugPrint('Error in search service: $e');
      return [];
    }
  }

  /// Search Mapbox Geocoding API
  Future<List<SearchResult>> _searchMapbox(
    String query,
    LatLng? proximity,
  ) async {
    try {
      return await _mapboxService.searchLocations(
        query,
        proximity: proximity,
        limit: 10, // Get up to 10 results from Mapbox
        useSessionToken: true, // Free autocomplete
      );
    } catch (e) {
      debugPrint('Error searching Mapbox: $e');
      return [];
    }
  }

  /// Search Firestore user-added locations
  Future<List<SearchResult>> _searchFirestore(
    String query,
    LatLng? userLocation,
  ) async {
    try {
      final locations = await _locationService.searchApprovedLocations(
        query,
        userLat: userLocation?.latitude,
        userLng: userLocation?.longitude,
      );
      
      return locations.map((location) {
        return SearchResult.fromFirestore(location, 1.0);
      }).toList();
    } catch (e) {
      debugPrint('Error searching Firestore: $e');
      return [];
    }
  }

  /// Resolve full details for a lazy-loaded result (Mapbox Search Box API)
  Future<SearchResult?> resolveLocation(SearchResult result) async {
    // Only Mapbox results need resolution
    if (result.source != SearchResultSource.mapbox) return result;
    
    // If it already has coordinates, return as is (unless it's a specific requirement to refresh)
    // But Search Box API suggestions come with 0.0, so checking that might be enough if we trust 0.0 is invalid.
    // Better to check mapboxId.
    if (result.mapboxId == null) return result;

    try {
      return await _mapboxService.retrieveLocation(result);
    } catch (e) {
      debugPrint('Error resolving location: $e');
      return null;
    }
  }

  /// Get reverse geocoded address for coordinates
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      return await _mapboxService.reverseGeocode(latitude, longitude);
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
      return null;
    }
  }

  /// Clear session token (call after user selects a result)
  void clearSessionToken() {
    _mapboxService.clearSessionToken();
  }
}
