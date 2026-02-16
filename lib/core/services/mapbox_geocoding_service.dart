import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../models/search_result_model.dart';
import '../constants/mapbox_config.dart';

/// Service for Mapbox Geocoding API
/// Provides forward geocoding (address → coordinates) and reverse geocoding
class MapboxGeocodingService {
  // Rate limiting
  DateTime? _lastRequestTime;
  
  /// Session token for autocomplete (reduces costs)
  String? _sessionToken;
  
  /// Forward geocoding: search for locations by query
  /// 
  /// [query] - The search query (e.g., "Federal Bank Kochi")
  /// [proximity] - Optional coordinates to bias results towards
  /// [limit] - Maximum number of results (default: 5)
  /// [useSessionToken] - Use session token for autocomplete (default: true)
  /// Get search suggestions from Mapbox Search Box API
  Future<List<SearchResult>> getSuggestions(
    String query, {
    LatLng? proximity,
    int limit = 5,
    bool useSessionToken = true,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      await _enforceRateLimit();

      if (useSessionToken) {
        _sessionToken ??= _generateSessionToken();
      }

      final encodedQuery = Uri.encodeComponent(query);
      final params = <String, String>{
        'access_token': MapboxConfig.accessToken,
        'limit': limit.toString(),
        'types': 'poi,address', // Focus on POIs and addresses
        'language': 'en',
      };

      if (useSessionToken && _sessionToken != null) {
        params['session_token'] = _sessionToken!;
      }

      if (proximity != null) {
        params['proximity'] = '${proximity.longitude},${proximity.latitude}';
      }

      final uri = Uri.parse('${MapboxConfig.searchBoxApiUrl}/suggest')
          .replace(queryParameters: {'q': query, ...params});

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final suggestions = data['suggestions'] as List<dynamic>;

        return suggestions.map((suggestion) {
          return SearchResult.fromMapboxSuggestion(
            suggestion as Map<String, dynamic>,
            1.0,
          );
        }).toList();
      } else {
        debugPrint('Mapbox Search Box API error: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error getting Mapbox suggestions: $e');
      return [];
    }
  }

  /// Retrieve full location details (coordinates) for a result
  Future<SearchResult?> retrieveLocation(SearchResult result) async {
    if (result.mapboxId == null) return result;

    try {
      await _enforceRateLimit();

      final params = <String, String>{
        'access_token': MapboxConfig.accessToken,
        'session_token': _sessionToken ?? '',
      };

      final uri = Uri.parse('${MapboxConfig.searchBoxApiUrl}/retrieve/${result.mapboxId}')
          .replace(queryParameters: params);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>;
        
        if (features.isNotEmpty) {
          final feature = features[0] as Map<String, dynamic>;
          // Update the existing result with coordinates
          final geometry = feature['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List<dynamic>?;
          
          if (coordinates != null && coordinates.length >= 2) {
             return SearchResult(
              displayName: result.displayName,
              subtitle: result.subtitle,
              latitude: (coordinates[1] as num).toDouble(),
              longitude: (coordinates[0] as num).toDouble(),
              source: result.source,
              matchScore: result.matchScore,
              mapboxId: result.mapboxId,
              osmData: feature,
            );
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error retrieving Mapbox location: $e');
      return null;
    }
  }

  /// Forward geocoding: search for locations by query
  /// NOW WRAPS getSuggestions for backward compatibility
  Future<List<SearchResult>> searchLocations(
    String query, {
    LatLng? proximity,
    int limit = 5,
    bool useSessionToken = true,
  }) async {
    return getSuggestions(
      query,
      proximity: proximity,
      limit: limit,
      useSessionToken: useSessionToken,
    );
  }

  /// Reverse geocoding: get location details from coordinates
  Future<String?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      await _enforceRateLimit();

      final params = {
        'access_token': MapboxConfig.accessToken,
      };

      final uri = Uri.parse(
        '${MapboxConfig.geocodingApiUrl}/$longitude,$latitude.json',
      ).replace(queryParameters: params);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>;
        
        if (features.isNotEmpty) {
          return features[0]['place_name'] as String?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
      return null;
    }
  }

  /// Clear session token (call after user selects a result)
  void clearSessionToken() {
    _sessionToken = null;
  }

  /// Enforce rate limiting (min 100ms between requests)
  Future<void> _enforceRateLimit() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      const minInterval = Duration(milliseconds: 100);
      
      if (elapsed < minInterval) {
        await Future.delayed(minInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  /// Generate a random session token
  String _generateSessionToken() {
    final random = Random();
    return List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }
}
