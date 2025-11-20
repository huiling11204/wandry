// ============================================
// FEEDBACK CONTROLLER
// ============================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/feedback_model.dart';

class FeedbackController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user email
  String? getCurrentUserEmail() {
    return _auth.currentUser?.email;
  }

  // Submit new feedback
  Future<Map<String, dynamic>> submitFeedback({
    required int rating,
    required String comment,
  }) async {
    try {
      final userEmail = getCurrentUserEmail();
      if (userEmail == null) {
        return {
          'success': false,
          'message': 'User not authenticated. Please log in again.',
        };
      }

      if (rating < 1 || rating > 5) {
        return {
          'success': false,
          'message': 'Please select a star rating between 1 and 5.',
        };
      }

      final feedback = FeedbackModel(
        userEmail: userEmail,
        rating: rating,
        comment: comment.trim(),
        createdAt: DateTime.now(),
      );

      await _firestore.collection('feedback').add(feedback.toFirestore());

      return {
        'success': true,
        'message': 'Thank you for your rating and feedback!',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Submission failed. Please try again later.',
      };
    }
  }

  // Get all feedback for current user
  Stream<List<FeedbackModel>> getUserFeedback() {
    final userEmail = getCurrentUserEmail();
    if (userEmail == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('feedback')
        .where('userEmail', isEqualTo: userEmail)
        .snapshots()
        .map((snapshot) {
      // Sort in memory instead of in query to avoid index requirement
      final feedbackList = snapshot.docs
          .map((doc) => FeedbackModel.fromFirestore(doc))
          .toList();

      // Sort by createdAt descending (most recent first)
      feedbackList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return feedbackList;
    });
  }

  // Edit existing feedback (only within 5 days)
  Future<Map<String, dynamic>> editFeedback({
    required String feedbackId,
    required int rating,
    required String comment,
  }) async {
    try {
      final userEmail = getCurrentUserEmail();
      if (userEmail == null) {
        return {
          'success': false,
          'message': 'User not authenticated. Please log in again.',
        };
      }

      // Get the feedback document
      final doc = await _firestore.collection('feedback').doc(feedbackId).get();
      if (!doc.exists) {
        return {
          'success': false,
          'message': 'Feedback not found.',
        };
      }

      final feedback = FeedbackModel.fromFirestore(doc);

      // Check if user owns this feedback
      if (feedback.userEmail != userEmail) {
        return {
          'success': false,
          'message': 'You can only edit your own feedback.',
        };
      }

      // Check if still within 5 days
      if (!feedback.canEdit()) {
        return {
          'success': false,
          'message': 'Edit period has expired. You can only edit feedback within 5 days of submission.',
        };
      }

      if (rating < 1 || rating > 5) {
        return {
          'success': false,
          'message': 'Please select a star rating between 1 and 5.',
        };
      }

      // Update the feedback
      await _firestore.collection('feedback').doc(feedbackId).update({
        'rating': rating,
        'comment': comment.trim(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return {
        'success': true,
        'message': 'Your feedback has been updated successfully!',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Update failed. Please try again later.',
      };
    }
  }

  // Delete feedback
  Future<Map<String, dynamic>> deleteFeedback(String feedbackId) async {
    try {
      final userEmail = getCurrentUserEmail();
      if (userEmail == null) {
        return {
          'success': false,
          'message': 'User not authenticated. Please log in again.',
        };
      }

      // Get the feedback document to verify ownership
      final doc = await _firestore.collection('feedback').doc(feedbackId).get();
      if (!doc.exists) {
        return {
          'success': false,
          'message': 'Feedback not found.',
        };
      }

      final feedback = FeedbackModel.fromFirestore(doc);

      // Check if user owns this feedback
      if (feedback.userEmail != userEmail) {
        return {
          'success': false,
          'message': 'You can only delete your own feedback.',
        };
      }

      // Delete the feedback
      await _firestore.collection('feedback').doc(feedbackId).delete();

      return {
        'success': true,
        'message': 'Your feedback has been deleted successfully!',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Deletion failed. Please try again later.',
      };
    }
  }

  // Get average rating for the application (optional - for analytics)
  Future<double> getAverageRating() async {
    try {
      final snapshot = await _firestore.collection('feedback').get();
      if (snapshot.docs.isEmpty) return 0.0;

      final totalRating = snapshot.docs.fold<int>(
        0,
            (sum, doc) => sum + (doc.data()['rating'] as int? ?? 0),
      );

      return totalRating / snapshot.docs.length;
    } catch (e) {
      return 0.0;
    }
  }

  // Get total feedback count (optional - for analytics)
  Future<int> getTotalFeedbackCount() async {
    try {
      final snapshot = await _firestore.collection('feedback').get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}