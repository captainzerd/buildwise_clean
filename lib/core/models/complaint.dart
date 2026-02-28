import 'package:cloud_firestore/cloud_firestore.dart';

class Complaint {
  final String id;
  final String userUid;
  final String? projectId;
  final String? projectTitle;
  final String message;
  final String status; // open, in_progress, closed
  final DateTime createdAt;

  Complaint({
    required this.id,
    required this.userUid,
    required this.projectId,
    this.projectTitle,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'userUid': userUid,
        'projectId': projectId,
        if (projectTitle != null) 'projectTitle': projectTitle,
        'message': message,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  static Complaint fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['createdAt'];
    return Complaint(
      id: doc.id,
      userUid: d['userUid'] ?? '',
      projectId: d['projectId'],
      projectTitle: d['projectTitle'],
      message: d['message'] ?? '',
      status: d['status'] ?? 'open',
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}
