// lib/core/services/materials_price_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/materials_price.dart';

class MaterialsPriceService {
  final _db = FirebaseFirestore.instance;

  Stream<MarketPricesSnapshot?> snapshotStream() {
    return _db
        .collection('market_prices')
        .doc('ghana_current')
        .withConverter<MarketPricesSnapshot?>(
          fromFirestore: (snap, _) =>
              snap.exists ? MarketPricesSnapshot.fromDoc(snap) : null,
          toFirestore: (_, __) => {},
        )
        .snapshots()
        .map((s) => s.data());
  }
}
