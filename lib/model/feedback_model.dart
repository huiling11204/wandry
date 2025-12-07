import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  final String? id;
  final String userEmail;
  final int rating; // 1-5 stars
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  FeedbackModel({
    this.id,
    required this.userEmail,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert Firestore document to FeedbackModel
  factory FeedbackModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return FeedbackModel(
      id: doc.id,
      userEmail: data['userEmail'] ?? '',
      rating: data['rating'] ?? 0,
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Convert FeedbackModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userEmail': userEmail,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Check if feedback can still be edited (within 5 days)
  bool canEdit() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inDays < 5;
  }

  // Get days remaining for edit
  int daysRemainingForEdit() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    final remaining = 5 - difference.inDays;
    return remaining > 0 ? remaining : 0;
  }
}