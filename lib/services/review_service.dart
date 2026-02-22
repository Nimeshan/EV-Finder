import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/review.dart';
import 'web3_service.dart';

class ReviewService {
  final Web3Service _web3Service = Web3Service();

  Future<List<Review>> getStationReviews(int stationId) async {
    try {
      await _web3Service.initialize();
      final reviewsData = await _web3Service.getStationReviews(stationId);

      if (reviewsData.isNotEmpty) {
        return reviewsData.map((data) => Review.fromContractData(data)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching on-chain reviews: $e');
    }

    // Fallback to local
    final all = await _getLocalReviews();
    return all.where((r) => r.stationId == stationId).toList();
  }

  Future<Map<String, dynamic>> getStationRating(int stationId) async {
    try {
      await _web3Service.initialize();
      final rating = await _web3Service.getStationAverageRating(stationId);
      if ((rating['count'] as int) > 0) return rating;
    } catch (e) {
      debugPrint('Error getting on-chain rating: $e');
    }

    // Compute from local reviews
    final reviews = await getStationReviews(stationId);
    if (reviews.isEmpty) return {'average': 0.0, 'count': 0};

    final total = reviews.fold<int>(0, (sum, r) => sum + r.rating);
    return {
      'average': total / reviews.length,
      'count': reviews.length,
    };
  }

  Future<bool> submitReview({
    required String fromAddress,
    required int stationId,
    required int bookingId,
    required int rating,
    required String comment,
  }) async {
    await _web3Service.initialize();

    // Try on-chain
    final txHash = await _web3Service.submitReview(
      fromAddress: fromAddress,
      stationId: stationId,
      bookingId: bookingId,
      rating: rating,
      comment: comment,
    );

    // Always save locally
    final review = Review(
      id: DateTime.now().millisecondsSinceEpoch,
      reviewerAddress: fromAddress,
      stationId: stationId,
      bookingId: bookingId,
      rating: rating,
      comment: comment,
      timestamp: DateTime.now(),
    );

    await _saveReviewLocally(review);

    if (txHash != null) {
      debugPrint('Review submitted on-chain: $txHash');
    }

    return true;
  }

  // Local storage helpers
  Future<List<Review>> _getLocalReviews() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('reviews');
      if (data == null) return [];

      final List<dynamic> jsonList = json.decode(data);
      return jsonList.map((j) => Review.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveReviewLocally(Review review) async {
    final reviews = await _getLocalReviews();
    reviews.add(review);
    final prefs = await SharedPreferences.getInstance();
    final jsonList = reviews.map((r) => r.toJson()).toList();
    await prefs.setString('reviews', json.encode(jsonList));
  }
}
