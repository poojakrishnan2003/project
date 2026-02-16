import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../../models/location_model.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'locations';

  // Fetch ONLY approved locations for the home screen
  Future<List<LocationModel>> getLocations() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'approved')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Ensure ID is set from document ID
        return LocationModel.fromMap(data);
      }).toList();
    } catch (e) {
      // Simple error logging
      debugPrint('Error fetching locations: $e');
      return [];
    }
  }
  
  // Fetch PENDING locations for Admin Dashboard
  Future<List<LocationModel>> getPendingLocations() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'pending')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return LocationModel.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching pending locations: $e');
      return [];
    }
  }

  // Admin Action: Approve or Reject (Delete) use updateStatus('approved') or delete
  Future<void> updateLocationStatus(String id, String status) async {
    await _firestore.collection(_collection).doc(id).update({'status': status});
  }

  Future<void> deleteLocation(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<String?> addLocation(LocationModel newLocation) async {
    try {
      // Add to Firestore
      // We create a map but ensure 'id' is removed so Firestore generates one
      final data = newLocation.toMap();
      data.remove('id');
      // Force status to pending for new user submissions
      data['status'] = 'pending'; 
      
      // Ensure createdAt is set if not present
      if (data['createdAt'] == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection(_collection).add(data);
      return null; // Success
    } catch (e) {
      return 'Failed to add location: $e';
    }
  }

  // Admin method to add location directly as approved
  Future<String?> addLocationAsAdmin(LocationModel newLocation) async {
    try {
      final data = newLocation.toMap();
      data.remove('id');
      // Admin-added spots are immediately approved
      data['status'] = 'approved';
      
      if (data['createdAt'] == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection(_collection).add(data);
      return null; // Success
    } catch (e) {
      return 'Failed to add location: $e';
    }
  }

  /// Search approved locations with fuzzy matching and proximity sorting
  Future<List<LocationModel>> searchApprovedLocations(
    String query, {
    double? userLat,
    double? userLng,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'approved')
          .get();

      final allLocations = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return LocationModel.fromMap(data);
      }).toList();

      final queryLower = query.toLowerCase();
      
      // Calculate scores for each location
      final scoredLocations = allLocations.map((loc) {
        final nameLower = loc.name.toLowerCase();
        final descLower = (loc.description ?? '').toLowerCase();
        final tagsLower = loc.tags.join(' ').toLowerCase();

        // Check for exact/partial matches (highest score)
        double score = 0.0;
        if (nameLower.contains(queryLower)) score += 1.0;
        if (nameLower.startsWith(queryLower)) score += 0.5;
        if (descLower.contains(queryLower)) score += 0.3;
        if (tagsLower.contains(queryLower)) score += 0.3;

        // Fuzzy match if no direct match
        if (score == 0) {
          final similarity = _calculateSimilarity(nameLower, queryLower);
          if (similarity > 0.4) { // Threshold for fuzzy match
            score = similarity * 0.8;
          }
        }
        
        // Calculate distance if user location is provided
        double distanceKm = 0.0;
        if (userLat != null && userLng != null) {
          distanceKm = _calculateDistance(
            userLat, userLng, 
            loc.latitude, loc.longitude
          );
          
          // Boost score for nearby results (decay factor)
          // 10km or less adds 0.5 to score, 1000km adds 0
          if (distanceKm < 1000) {
            score += (1.0 - (distanceKm / 1000)) * 0.5;
          }
        }

        return MapEntry(loc, score);
      }).toList();

      // Filter by score threshold and sort
      final results = scoredLocations
          .where((entry) => entry.value > 0.3)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return results.map((entry) => entry.key).toList();
    } catch (e) {
      debugPrint('Error searching locations: $e');
      return [];
    }
  }

  // Simple Jaccard/Levenshtein-like similarity helper
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    final distance = _levenshteinDistance(s1, s2);
    final maxLength = s1.length > s2.length ? s1.length : s2.length;
    
    return 1.0 - (distance / maxLength);
  }

  int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < t.length + 1; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < t.length; j++) {
        int cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost
        ].reduce((min, val) => val < min ? val : min);
      }

      for (int j = 0; j < t.length + 1; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[t.length];
  }
  
  // Haversine formula for distance in km
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) *
        (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}

