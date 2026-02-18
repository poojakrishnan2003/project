import 'package:cloud_firestore/cloud_firestore.dart';

/// User profile model for storing additional user information in Firestore
class UserProfile {
  final String uid;
  final String email;
  final String name;
  final String phoneNumber;
  final String? photoUrl;
  final DateTime createdAt;

  final Map<String, dynamic>? location;
  final bool isDiscoverable;
  final List<String> connectedUserIds;

  UserProfile({
    required this.uid,
    required this.email,
    required this.name,
    required this.phoneNumber,
    this.photoUrl,
    required this.createdAt,
    this.location,
    this.isDiscoverable = false,
    this.connectedUserIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'location': location,
      'isDiscoverable': isDiscoverable,
      'connectedUserIds': connectedUserIds,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      photoUrl: map['photoUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: map['location'],
      isDiscoverable: map['isDiscoverable'] ?? false,
      connectedUserIds: List<String>.from(map['connectedUserIds'] ?? []),
    );
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? name,
    String? phoneNumber,
    String? photoUrl,
    DateTime? createdAt,
    Map<String, dynamic>? location,
    bool? isDiscoverable,
    List<String>? connectedUserIds,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
      isDiscoverable: isDiscoverable ?? this.isDiscoverable,
      connectedUserIds: connectedUserIds ?? this.connectedUserIds,
    );
  }
}
