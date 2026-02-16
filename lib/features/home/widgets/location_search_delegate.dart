import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/search_service.dart';
import '../../../models/search_result_model.dart';

/// Search delegate for smart location search
class LocationSearchDelegate extends SearchDelegate<SearchResult?> {
  final SearchService _searchService = SearchService();
  final LatLng? userLocation;
  final double? searchRadiusKm;

  // Debouncing
  Timer? _debounceTimer;
  String _lastQuery = '';
  List<SearchResult> _lastResults = [];

  LocationSearchDelegate({
    this.userLocation,
    this.searchRadiusKm = 50.0, // Default 50km radius
  }) : super(
          searchFieldLabel: 'Search locations...',
          searchFieldStyle: const TextStyle(fontSize: 16),
        );

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            _lastResults = [];
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Show recent searches when query is empty
    if (query.isEmpty) {
      return _buildRecentSearches(context);
    }

    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text('Start typing to search locations'),
      );
    }

    return FutureBuilder<List<SearchResult>>(
      future: _performSearch(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final results = snapshot.data ?? [];

        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No results found'),
                const SizedBox(height: 8),
                Text(
                  'Try a different search term',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Separate results by source
        final userResults = results
            .where((r) => r.source == SearchResultSource.userAdded)
            .toList();
        final mapboxResults = results
            .where((r) => r.source == SearchResultSource.mapbox)
            .toList();

        return ListView(
          children: [
            if (userResults.isNotEmpty) ...[
              _buildSectionHeader('User-Added Locations', Icons.person_pin_circle),
              ...userResults.map((result) => _buildResultTile(context, result)),
              const Divider(),
            ],
            if (mapboxResults.isNotEmpty) ...[
              _buildSectionHeader('Mapbox', Icons.map),
              ...mapboxResults.map((result) => _buildResultTile(context, result)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile(BuildContext context, SearchResult result) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: result.source == SearchResultSource.userAdded
            ? Colors.green[100]
            : Colors.purple[100],
        child: Icon(
          result.source == SearchResultSource.userAdded
              ? Icons.location_on
              : Icons.map,
          color: result.source == SearchResultSource.userAdded
              ? Colors.green[700]
              : Colors.purple[700],
        ),
      ),
      title: Text(
        result.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: result.subtitle != null
          ? Text(
              result.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            )
          : null,
      trailing: _buildMatchScoreIndicator(result.matchScore),
      onTap: () async {
        // Show loading indicator if resolution is needed
        if (result.source == SearchResultSource.mapbox && result.mapboxId != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );

          try {
            final resolvedResult = await _searchService.resolveLocation(result);
            Navigator.pop(context); // Dismiss loading

            if (resolvedResult != null) {
              await _saveRecentSearch(resolvedResult.displayName);
              close(context, resolvedResult);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not get location details')),
              );
            }
          } catch (e) {
            Navigator.pop(context); // Dismiss loading
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error resolving location')),
            );
          }
        } else {
          // Firestore results/legacy results
          await _saveRecentSearch(result.displayName);
          close(context, result);
        }
      },
    );
  }

  Widget _buildMatchScoreIndicator(double score) {
    // Show match quality indicator for fuzzy matches
    if (score >= 0.95) {
      return const SizedBox.shrink(); // Perfect match, no indicator needed
    }

    Color color;
    if (score >= 0.8) {
      color = Colors.green;
    } else if (score >= 0.7) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${(score * 100).toInt()}%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildRecentSearches(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _getRecentSearches(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Search for locations'),
                SizedBox(height: 8),
                Text(
                  'Try searching for places, restaurants, or landmarks',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final recentSearches = snapshot.data!;

        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Searches',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _clearRecentSearches(),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            ...recentSearches.map((search) {
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(search),
                onTap: () {
                  query = search;
                  showResults(context);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => _removeRecentSearch(search),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  /// Perform search with debouncing
  Future<List<SearchResult>> _performSearch(String searchQuery) async {
    // Use cached results if query hasn't changed
    if (searchQuery == _lastQuery && _lastResults.isNotEmpty) {
      return _lastResults;
    }

    // Create a new completer for this search
    final completer = Completer<List<SearchResult>>();

    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    // Set up new debounce timer (300ms delay)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        LatLng? searchLocation = userLocation;

        // If user location is not provided, try to get it
        if (searchLocation == null) {
          try {
            // Check if service is enabled and permission granted before fetching
            // We use a small timeout to avoid blocking search too long
            final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
            if (serviceEnabled) {
              LocationPermission permission = await Geolocator.checkPermission();
              if (permission == LocationPermission.denied) {
                permission = await Geolocator.requestPermission();
              }
              
              if (permission == LocationPermission.whileInUse || 
                  permission == LocationPermission.always) {
                 final position = await Geolocator.getCurrentPosition(
                   timeLimit: const Duration(seconds: 2),
                 );
                 searchLocation = LatLng(position.latitude, position.longitude);
              }
            }
          } catch (e) {
            debugPrint('Error fetching location for search: $e');
            // Continue without location
          }
        }

        final results = await _searchService.search(
          searchQuery,
          userLocation: searchLocation,
          radiusKm: searchRadiusKm,
        );
        _lastQuery = searchQuery;
        _lastResults = results;
        completer.complete(results);
      } catch (e) {
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  /// Get recent searches from SharedPreferences
  Future<List<String>> _getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('recent_searches') ?? [];
  }

  /// Save a search to recent searches
  Future<void> _saveRecentSearch(String search) async {
    final prefs = await SharedPreferences.getInstance();
    final recentSearches = prefs.getStringList('recent_searches') ?? [];
    
    // Remove if already exists (to move to top)
    recentSearches.remove(search);
    
    // Add to beginning
    recentSearches.insert(0, search);
    
    // Keep only last 10 searches
    if (recentSearches.length > 10) {
      recentSearches.removeRange(10, recentSearches.length);
    }
    
    await prefs.setStringList('recent_searches', recentSearches);
  }

  /// Clear all recent searches
  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
  }

  /// Remove a specific recent search
  Future<void> _removeRecentSearch(String search) async {
    final prefs = await SharedPreferences.getInstance();
    final recentSearches = prefs.getStringList('recent_searches') ?? [];
    recentSearches.remove(search);
    await prefs.setStringList('recent_searches', recentSearches);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
