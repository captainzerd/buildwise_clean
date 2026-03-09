// lib/core/services/drawing_service.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

import '../models/drawing.dart';

class DrawingService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _col(String projectId) =>
      _db.collection('projects').doc(projectId).collection('drawings');

  /// Stream all drawings for a project (newest first).
  Stream<List<Drawing>> drawingsStream(String projectId) {
    return _col(projectId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => Drawing.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Upload a file to Firebase Storage and save the drawing record to Firestore.
  Future<void> uploadDrawing(
    String projectId, {
    required String name,
    required File file,
    required String uploadedByUid,
    required String uploadedByName,
  }) async {
    final ext = p.extension(file.path).toLowerCase().replaceFirst('.', '');
    final fileType =
        {'jpg', 'jpeg', 'png', 'webp'}.contains(ext) ? 'image' : 'pdf';

    final filename =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
    final storageRef = _storage
        .ref()
        .child('projects/$projectId/drawings/$filename');

    await storageRef.putFile(file);
    final downloadUrl = await storageRef.getDownloadURL();

    final drawing = Drawing(
      id: '',
      name: name,
      fileUrl: downloadUrl,
      fileType: fileType,
      uploadedBy: uploadedByUid,
      uploadedByName: uploadedByName,
      uploadedAt: DateTime.now(),
    );

    await _col(projectId).add(drawing.toMap());
  }

  /// Append an annotation to an existing drawing document.
  Future<void> addAnnotation(
    String projectId,
    String drawingId,
    DrawingAnnotation ann,
  ) async {
    await _col(projectId).doc(drawingId).update({
      'annotations': FieldValue.arrayUnion([ann.toMap()]),
    });
  }
}
