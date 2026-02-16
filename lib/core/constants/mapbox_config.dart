import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Mapbox configuration and API keys
class MapboxConfig {
  /// Mapbox public access token
  static String get accessToken => dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  /// Mapbox tile URL templates for different styles
  /// Using @2x tiles (512px) which work better with flutter_map
  /// Streets style - clean, readable map
  static String get streetStyleUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$accessToken';

  /// Satellite streets style - satellite imagery with labels
  static String get satelliteStyleUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$accessToken';

  /// Outdoors style - optimized for outdoor activities
  static String get outdoorsStyleUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$accessToken';

  /// Mapbox Geocoding API base URL
  static const String geocodingApiUrl =
      'https://api.mapbox.com/geocoding/v5/mapbox.places';

  /// Mapbox Search Box API base URL
  static const String searchBoxApiUrl =
      'https://api.mapbox.com/search/searchbox/v1';

  /// Attribution text (required by Mapbox TOS)
  static const String attribution = '© Mapbox © OpenStreetMap';
}
