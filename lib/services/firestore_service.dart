import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notes_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveNote(String userId, Note note) {
    return _db
        .collection('notes')
        .doc(userId)
        .collection('userNotes')
        .doc(note.id)
        .set(note.toMap());
  }

  Future<void> deleteNote(String userId, String noteId) {
    return _db
        .collection('notes')
        .doc(userId)
        .collection('userNotes')
        .doc(noteId)
        .delete();
  }

  Stream<List<Note>> getNotes(String userId) {
    return _db
        .collection('notes')
        .doc(userId)
        .collection('userNotes')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => Note.fromFirestore(document.data()))
              .toList(),
        );
  }

  Future<void> saveFCMToken(String fcmToken, String userId) async {
    var currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      return _db
          .collection('users')
          .doc(currentUserId)
          .set({'fcmToken': fcmToken});
    }
  }

  Future<String?> getFCMToken(String userId) async {
    var currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      DocumentSnapshot snapshot =
          await _db.collection('users').doc(currentUserId).get();
      return (snapshot.data() as Map<String, dynamic>)['fcmToken'];
    }
    return null;
  }

  Future<void> saveDietProgram(String dietProgram) async {
    var currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      DocumentSnapshot userSnapshot =
      await _db.collection('dietPrograms').doc(currentUserId).get();
      // if userSnapshot exits then update the user write to the db
      if (userSnapshot.exists) {
        return _db
            .collection('dietPrograms')
            .doc(currentUserId)
            .update({'program': dietProgram});
      } else {
        // if userSnapshot does not exist then create a new user
        return _db
            .collection('dietPrograms')
            .doc(currentUserId)
            .set({'program': dietProgram});
      }
    }
  }

  Future<String?> getDietProgram(String userId) async {
    DocumentSnapshot snapshot =
        await _db.collection('dietPrograms').doc(userId).get();
    if (snapshot.exists) {
      var data =
          snapshot.data() as Map<String, dynamic>?; // Adjust the type cast
      if (data != null) {
        return data['program'] as String?;
      }
    }
    return null;
  }

  Future<void> deleteDietProgram(String userId) {
    return _db.collection('dietPrograms').doc(userId).delete();
  }

  Future<void> addPurchaseRecord(String userId, String productID,
      double price,) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('purchases')
        .add({
      'productID': productID,
      'price': price,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

}
