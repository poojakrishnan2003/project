

class BudgetItem {
  final String id;
  final String category; // e.g., 'Food', 'Transport', 'Accommodation'
  final double amount;
  final String currency;
  final String description;

  BudgetItem({
    required this.id,
    required this.category,
    required this.amount,
    this.currency = 'USD', // default
    required this.description,
  });

  factory BudgetItem.fromMap(Map<String, dynamic> map, String id) {
    return BudgetItem(
      id: id,
      category: map['category'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'USD',
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'amount': amount,
      'currency': currency,
      'description': description,
    };
  }
}

class PackingItem {
  final String id;
  final String name;
  final String category; // e.g., 'Clothing', 'Electronics', 'Toiletries'
  final bool isPacked;

  PackingItem({
    required this.id,
    required this.name,
    required this.category,
    this.isPacked = false,
  });

  factory PackingItem.fromMap(Map<String, dynamic> map, String id) {
    return PackingItem(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      isPacked: map['isPacked'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'isPacked': isPacked,
    };
  }

  PackingItem copyWith({
    String? id,
    String? name,
    String? category,
    bool? isPacked,
  }) {
    return PackingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      isPacked: isPacked ?? this.isPacked,
    );
  }
}

class TripHotel {
  final String id;
  final String name;
  final String address;
  final DateTime checkIn;
  final DateTime checkOut;
  final String bookingReference;

  TripHotel({
    required this.id,
    required this.name,
    required this.address,
    required this.checkIn,
    required this.checkOut,
    this.bookingReference = '',
  });

  factory TripHotel.fromMap(Map<String, dynamic> map, String id) {
    return TripHotel(
      id: id,
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      checkIn: map['checkIn']?.toDate() ?? DateTime.now(),
      checkOut: map['checkOut']?.toDate() ?? DateTime.now(),
      bookingReference: map['bookingReference'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'checkIn': checkIn,
      'checkOut': checkOut,
      'bookingReference': bookingReference,
    };
  }
}

class TripLocation {
  final String id; // maps to Place/Location ID
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int sequence; // For ordering
  final String notes;

  TripLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.sequence,
    this.notes = '',
  });

  factory TripLocation.fromMap(Map<String, dynamic> map, String id) {
    return TripLocation(
      id: id,
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      sequence: map['sequence'] ?? 0,
      notes: map['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'sequence': sequence,
      'notes': notes,
    };
  }

  TripLocation copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    int? sequence,
    String? notes,
  }) {
    return TripLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      sequence: sequence ?? this.sequence,
      notes: notes ?? this.notes,
    );
  }
}
