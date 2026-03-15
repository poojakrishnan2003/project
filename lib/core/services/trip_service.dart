import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:roamly/models/trip_model.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ── Trip CRUD ─────────────────────────────────────────────────────────────

  /// Create a new trip
  Future<TripModel?> createTrip(TripModel trip) async {
    if (currentUserId == null) return null;
    try {
      final docRef = _firestore.collection('trips').doc();
      final newTrip = trip.copyWith(id: docRef.id, ownerId: currentUserId);

      await docRef.set(newTrip.toMap());
      return newTrip;
    } catch (e) {
      debugPrint('Error creating trip: $e');
      return null;
    }
  }

  /// Update an existing trip
  Future<void> updateTrip(TripModel trip) async {
    try {
      await _firestore.collection('trips').doc(trip.id).update(trip.toMap());
    } catch (e) {
      debugPrint('Error updating trip: $e');
      rethrow;
    }
  }

  /// Delete a trip
  Future<void> deleteTrip(String tripId) async {
    try {
      await _firestore.collection('trips').doc(tripId).delete();
    } catch (e) {
      debugPrint('Error deleting trip: $e');
      rethrow;
    }
  }

  // ── Streams ─────────────────────────────────────────────────────────────

  /// Stream of user's trips (owned + invited as companion/editor)
  Stream<List<TripModel>> getUserTrips() {
    if (currentUserId == null) return Stream.value([]);

    // We use a broader query and filter client-side for "OR" 
    // since Firestore "OR" queries have limitations across array-contains.
    return _firestore
        .collection('trips')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs;
      return docs
          .map((doc) => TripModel.fromMap(doc.data(), doc.id))
          .where((trip) =>
              trip.ownerId == currentUserId ||
              trip.companionIds.contains(currentUserId) ||
              trip.editorIds.contains(currentUserId) ||
              trip.pendingCompanionIds.contains(currentUserId) ||
              trip.pendingEditorIds.contains(currentUserId))
          .toList();
    });
  }

  /// Stream a single trip
  Stream<TripModel?> getTripStream(String tripId) {
    return _firestore.collection('trips').doc(tripId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return TripModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  /// Accept a trip invitation
  Future<void> acceptTripInvitation(TripModel trip) async {
    if (currentUserId == null) return;
    
    final updatedTrip = trip.copyWith();
    final companionPending = List<String>.from(trip.pendingCompanionIds);
    final editorPending = List<String>.from(trip.pendingEditorIds);
    final companionsToUpdate = List<String>.from(trip.companionIds);
    final editorsToUpdate = List<String>.from(trip.editorIds);

    if (companionPending.contains(currentUserId)) {
      companionPending.remove(currentUserId);
      companionsToUpdate.add(currentUserId!);
    } else if (editorPending.contains(currentUserId)) {
      editorPending.remove(currentUserId);
      editorsToUpdate.add(currentUserId!);
    } else {
      return; // Use was not pending
    }

    try {
      await updateTrip(
        updatedTrip.copyWith(
          pendingCompanionIds: companionPending,
          pendingEditorIds: editorPending,
          companionIds: companionsToUpdate,
          editorIds: editorsToUpdate,
        )
      );
    } catch (e) {
      debugPrint('Error accepting trip invitation: $e');
    }
  }

  /// Decline a trip invitation
  Future<void> declineTripInvitation(TripModel trip) async {
    if (currentUserId == null) return;
    
    final updatedTrip = trip.copyWith();
    final companionPending = List<String>.from(trip.pendingCompanionIds);
    final editorPending = List<String>.from(trip.pendingEditorIds);

    if (companionPending.contains(currentUserId)) {
      companionPending.remove(currentUserId);
    } else if (editorPending.contains(currentUserId)) {
      editorPending.remove(currentUserId);
    } else {
      return; // Use was not pending
    }

    try {
      await updateTrip(
        updatedTrip.copyWith(
          pendingCompanionIds: companionPending,
          pendingEditorIds: editorPending,
        )
      );
    } catch (e) {
      debugPrint('Error declining trip invitation: $e');
    }
  }
}
