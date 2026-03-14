import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../errors/app_exception.dart';
import '../models/vendor.dart';

class VendorService extends ChangeNotifier {
  final _col = FirebaseFirestore.instance.collection('vendors').withConverter(
        fromFirestore: (snap, _) => Vendor.fromDoc(snap),
        toFirestore: (Vendor v, _) => v.toMap(),
      );

  Stream<List<Vendor>> listAll() {
    return _col
        .orderBy('name')
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  Future<void> create(Vendor vendor) async {
    try {
      await _col.add(vendor);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> delete(String vendorId) async {
    try {
      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(vendorId)
          .delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> update(
    String vendorId, {
    required String name,
    String? category,
    String? phone,
    String? email,
    String? website,
    String? location,
    String? region,
    String? whatsappNumber,
    List<String> trades = const [],
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(vendorId)
          .update({
        'name': name,
        'category': category,
        'phone': phone,
        'email': email,
        'website': website,
        'location': location,
        'region': region,
        'whatsappNumber': whatsappNumber,
        'trades': trades,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Add a star rating (1–5).
  Future<void> rate(String vendorId, int stars) async {
    try {
      final clamped = stars.clamp(1, 5);
      await FirebaseFirestore.instance.collection('vendors').doc(vendorId).set(
        <String, Object>{
          'ratingsCount': FieldValue.increment(1),
          'ratingsSum': FieldValue.increment(clamped),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
