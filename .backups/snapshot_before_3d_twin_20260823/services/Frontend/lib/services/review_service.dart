import 'package:in_app_review/in_app_review.dart';

class ReviewService {
  static final ReviewService instance = ReviewService._();
  ReviewService._();

  final InAppReview _inAppReview = InAppReview.instance;

  Future<void> requestReviewIfAppropriate() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      }
    } catch (e) {
      // ignore
    }
  }
}
