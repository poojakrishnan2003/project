
import 'trip_items_model.dart';

/// Trip model representing a travel itinerary
class TripModel {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final String? destination;
  final List<TripLocation> locations; // Changed to TripLocation for ordering
  final List<TripHotel> hotels;
  final List<BudgetItem> budgetItems;
  final List<PackingItem> packingItems;
  final DateTime startDate;
  final DateTime? endDate;
  final TripStatus status;
  final bool isPublic;
  final List<String> companionIds; // Readers/Viewers
  final List<String> editorIds; // Collaborators
  final List<String> pendingCompanionIds; // Invited Readers/Viewers
  final List<String> pendingEditorIds; // Invited Collaborators
  final DateTime createdAt;
  final DateTime updatedAt;

  const TripModel({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    this.destination,
    this.locations = const [],
    this.hotels = const [],
    this.budgetItems = const [],
    this.packingItems = const [],
    required this.startDate,
    this.endDate,
    this.status = TripStatus.planned,
    this.isPublic = true,
    this.companionIds = const [],
    this.editorIds = const [],
    this.pendingCompanionIds = const [],
    this.pendingEditorIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory TripModel.fromMap(Map<String, dynamic> map, String id) {
    return TripModel(
      id: id,
      ownerId: map['ownerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      destination: map['destination'],
      locations: (map['locations'] as List<dynamic>?)
              ?.map((l) => TripLocation.fromMap(l as Map<String, dynamic>, l['id'] ?? ''))
              .toList() ??
          [],
      hotels: (map['hotels'] as List<dynamic>?)
              ?.map((h) => TripHotel.fromMap(h as Map<String, dynamic>, h['id'] ?? ''))
              .toList() ??
          [],
      budgetItems: (map['budgetItems'] as List<dynamic>?)
              ?.map((b) => BudgetItem.fromMap(b as Map<String, dynamic>, b['id'] ?? ''))
              .toList() ??
          [],
      packingItems: (map['packingItems'] as List<dynamic>?)
              ?.map((p) => PackingItem.fromMap(p as Map<String, dynamic>, p['id'] ?? ''))
              .toList() ??
          [],
      startDate: map['startDate']?.toDate() ?? DateTime.now(),
      endDate: map['endDate']?.toDate(),
      status: TripStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TripStatus.planned,
      ),
      isPublic: map['isPublic'] ?? true,
      companionIds: List<String>.from(map['companionIds'] ?? []),
      editorIds: List<String>.from(map['editorIds'] ?? []),
      pendingCompanionIds: List<String>.from(map['pendingCompanionIds'] ?? []),
      pendingEditorIds: List<String>.from(map['pendingEditorIds'] ?? []),
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'destination': destination,
      'locations': locations.map((l) => l.toMap()..addAll({'id': l.id})).toList(),
      'hotels': hotels.map((h) => h.toMap()..addAll({'id': h.id})).toList(),
      'budgetItems': budgetItems.map((b) => b.toMap()..addAll({'id': b.id})).toList(),
      'packingItems': packingItems.map((p) => p.toMap()..addAll({'id': p.id})).toList(),
      'startDate': startDate,
      'endDate': endDate,
      'status': status.name,
      'isPublic': isPublic,
      'companionIds': companionIds,
      'editorIds': editorIds,
      'pendingCompanionIds': pendingCompanionIds,
      'pendingEditorIds': pendingEditorIds,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  TripModel copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? description,
    String? destination,
    List<TripLocation>? locations,
    List<TripHotel>? hotels,
    List<BudgetItem>? budgetItems,
    List<PackingItem>? packingItems,
    DateTime? startDate,
    DateTime? endDate,
    TripStatus? status,
    bool? isPublic,
    List<String>? companionIds,
    List<String>? editorIds,
    List<String>? pendingCompanionIds,
    List<String>? pendingEditorIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      destination: destination ?? this.destination,
      locations: locations ?? this.locations,
      hotels: hotels ?? this.hotels,
      budgetItems: budgetItems ?? this.budgetItems,
      packingItems: packingItems ?? this.packingItems,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      isPublic: isPublic ?? this.isPublic,
      companionIds: companionIds ?? this.companionIds,
      editorIds: editorIds ?? this.editorIds,
      pendingCompanionIds: pendingCompanionIds ?? this.pendingCompanionIds,
      pendingEditorIds: pendingEditorIds ?? this.pendingEditorIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Trip status enum
enum TripStatus {
  planned,
  active,
  completed,
  cancelled,
}
