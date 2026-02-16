import 'location_model.dart';

/// Unified search result model for both OpenStreetMap and Firestore results
class SearchResult {
  final String displayName;
  final String? subtitle; // Address or description
  final double latitude;
  final double longitude;
  final SearchResultSource source;
  final double matchScore; // Fuzzy match score (0.0 - 1.0)
  final LocationModel? firestoreLocation; // If from Firestore
  final Map<String, dynamic>? osmData; // If from OSM
  final String? mapboxId; // For Mapbox Search Box API lazy loading

  const SearchResult({
    required this.displayName,
    this.subtitle,
    required this.latitude,
    required this.longitude,
    required this.source,
    this.matchScore = 1.0,
    this.firestoreLocation,
    this.osmData,
    this.mapboxId,
  });

  /// Create from OpenStreetMap result
  factory SearchResult.fromOSM(
    Map<String, dynamic> osmData,
    double matchScore,
  ) {
    return SearchResult(
      displayName: osmData['display_name']?.toString().split(',').first ?? 'Unknown',
      subtitle: osmData['display_name']?.toString() ?? '',
      latitude: double.tryParse(osmData['lat']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(osmData['lon']?.toString() ?? '0') ?? 0.0,
      source: SearchResultSource.openStreetMap,
      matchScore: matchScore,
      osmData: osmData,
    );
  }

  /// Create from Firestore LocationModel
  factory SearchResult.fromFirestore(
    LocationModel location,
    double matchScore,
  ) {
    return SearchResult(
      displayName: location.name,
      subtitle: location.description ?? location.address,
      latitude: location.latitude,
      longitude: location.longitude,
      source: SearchResultSource.userAdded,
      matchScore: matchScore,
      firestoreLocation: location,
    );
  }

  /// Create from Mapbox Geocoding API result
  factory SearchResult.fromMapbox(
    Map<String, dynamic> mapboxFeature,
    double matchScore,
  ) {
    final geometry = mapboxFeature['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;
    
    return SearchResult(
      displayName: mapboxFeature['text']?.toString() ?? 'Unknown',
      subtitle: mapboxFeature['place_name']?.toString(),
      latitude: coordinates != null && coordinates.length >= 2
          ? (coordinates[1] as num).toDouble()
          : 0.0,
      longitude: coordinates != null && coordinates.length >= 2
          ? (coordinates[0] as num).toDouble()
          : 0.0,
      source: SearchResultSource.mapbox,
      matchScore: matchScore,
      osmData: mapboxFeature, // Store for reference
    );
  }

  /// Create from Mapbox Search Box API suggestion
  factory SearchResult.fromMapboxSuggestion(
    Map<String, dynamic> suggestion,
    double matchScore,
  ) {
    return SearchResult(
      displayName: suggestion['name']?.toString() ?? 'Unknown',
      subtitle: suggestion['context'] != null 
          ? (suggestion['context'] as Map<String, dynamic>)['address']?.toString() 
              ?? suggestion['place_formatted']?.toString()
          : suggestion['place_formatted']?.toString(),
      latitude: 0.0, // Lazy loaded
      longitude: 0.0, // Lazy loaded
      source: SearchResultSource.mapbox,
      matchScore: matchScore,
      mapboxId: suggestion['mapbox_id']?.toString(),
      osmData: suggestion, 
    );
  }
}

/// Source of the search result
enum SearchResultSource {
  openStreetMap, // Legacy, will be removed
  mapbox,
  userAdded,
}
