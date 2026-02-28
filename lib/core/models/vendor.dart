import 'package:cloud_firestore/cloud_firestore.dart';

class Vendor {
  final String id;
  final String name;
  final String? category;
  final String? phone;
  final String? email;
  final String? website;
  final String? location;
  final String? region;
  final String? whatsappNumber;
  final List<String> trades;

  // rating = ratingsSum / ratingsCount (computed on read)
  final int ratingsCount;
  final int ratingsSum;
  double get rating => ratingsCount == 0 ? 0 : ratingsSum / ratingsCount;

  Vendor({
    required this.id,
    required this.name,
    this.category,
    this.phone,
    this.email,
    this.website,
    this.location,
    this.region,
    this.whatsappNumber,
    this.trades = const [],
    required this.ratingsCount,
    required this.ratingsSum,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'phone': phone,
        'email': email,
        'website': website,
        'location': location,
        'region': region,
        'whatsappNumber': whatsappNumber,
        'trades': trades,
        'ratingsCount': ratingsCount,
        'ratingsSum': ratingsSum,
      };

  static Vendor fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Vendor(
      id: doc.id,
      name: d['name'] as String? ?? '',
      category: d['category'] as String?,
      phone: d['phone'] as String?,
      email: d['email'] as String?,
      website: d['website'] as String?,
      location: d['location'] as String?,
      region: d['region'] as String?,
      whatsappNumber: d['whatsappNumber'] as String?,
      trades: (d['trades'] as List?)?.cast<String>() ?? const [],
      ratingsCount: (d['ratingsCount'] ?? 0) as int,
      ratingsSum: (d['ratingsSum'] ?? 0) as int,
    );
  }
}
