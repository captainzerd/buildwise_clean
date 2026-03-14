// lib/core/services/portfolio_service.dart
//
// CRUD + photo upload for a builder's past-project portfolio.
// Firestore path: pm_profiles/{uid}/portfolio/{itemId}
// Storage path:   portfolio/{uid}/{itemId}/photo_{n}.jpg

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/portfolio_item.dart';

class PortfolioService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('pm_profiles').doc(uid).collection('portfolio');

  /// Live stream of all portfolio items for [uid], newest first.
  Stream<List<PortfolioItem>> portfolioStream(String uid) {
    return _col(uid)
        .orderBy('completedYear', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => PortfolioItem.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Adds a new portfolio item, uploading any [photos] to Firebase Storage
  /// first and embedding their download URLs in [photoUrls].
  Future<PortfolioItem> addItem(
    String uid,
    PortfolioItem item, {
    List<File> photos = const [],
  }) async {
    final docRef = _col(uid).doc(); // Firestore auto-generated ID
    final docId = docRef.id;

    final photoUrls = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final ref = _storage.ref('portfolio/$uid/$docId/photo_$i.jpg');
      await ref.putFile(
        photos[i],
        SettableMetadata(contentType: 'image/jpeg'),
      );
      photoUrls.add(await ref.getDownloadURL());
    }

    final newItem = PortfolioItem(
      id: docId,
      title: item.title,
      projectType: item.projectType,
      region: item.region,
      completedYear: item.completedYear,
      contractValueGhs: item.contractValueGhs,
      description: item.description,
      photoUrls: photoUrls,
      clientName: item.clientName,
      clientVerified: item.clientVerified,
    );

    await docRef.set(newItem.toMap());
    return newItem;
  }

  /// Deletes a portfolio item and its associated Storage photos.
  Future<void> deleteItem(String uid, String itemId) async {
    await _col(uid).doc(itemId).delete();
    try {
      final folderRef = _storage.ref('portfolio/$uid/$itemId');
      final listed = await folderRef.listAll();
      for (final f in listed.items) {
        await f.delete();
      }
    } catch (_) {
      // Silently ignore if storage cleanup fails (photos may not exist)
    }
  }
}
