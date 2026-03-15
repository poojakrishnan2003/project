/// Location model representing a point of interest
class LocationModel {
  final String? id;
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final String? address;
  final LocationType type;
  final List<String> tags;
  final String? imageUrl;
  final String? addedBy;
  final int likesCount;
  final double? rating;
  final DateTime? createdAt;
  final String status; // 'pending' or 'approved'

  const LocationModel({
    this.id,
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    this.address,
    this.type = LocationType.poi,
    this.tags = const [],
    this.imageUrl,
    this.addedBy,
    this.likesCount = 0,
    this.rating,
    this.createdAt,
    this.status = 'pending',
  });

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      id: map['id'],
      name: map['name'] ?? '',
      description: map['description'],
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'],
      type: LocationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => LocationType.poi,
      ),
      tags: List<String>.from(map['tags'] ?? []),
      imageUrl: map['imageUrl'],
      addedBy: map['addedBy'],
      likesCount: map['likesCount'] ?? 0,
      rating: (map['rating'] as num?)?.toDouble(),
      createdAt: map['createdAt']?.toDate(),
      status: map['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'type': type.name,
      'tags': tags,
      'imageUrl': imageUrl,
      'addedBy': addedBy,
      'likesCount': likesCount,
      'rating': rating,
      'createdAt': createdAt,
      'status': status,
    };
  }

  LocationModel copyWith({
    String? id,
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    LocationType? type,
    List<String>? tags,
    String? imageUrl,
    String? addedBy,
    int? likesCount,
    double? rating,
    DateTime? createdAt,
    String? status,
  }) {
    return LocationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      type: type ?? this.type,
      tags: tags ?? this.tags,
      imageUrl: imageUrl ?? this.imageUrl,
      addedBy: addedBy ?? this.addedBy,
      likesCount: likesCount ?? this.likesCount,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}

/// Location type categories
enum LocationType {
  poi, // Point of interest
  restaurant,
  cafe,
  scenic,
  adventure,
  cultural,
  generated, // Community discovered spots
  campsite,
  restStop,
  favorite,
  visited,
}
