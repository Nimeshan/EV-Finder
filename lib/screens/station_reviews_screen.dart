import 'package:flutter/material.dart';
import '../models/review.dart';
import '../services/review_service.dart';
import '../theme/app_theme.dart';
import '../widgets/star_rating.dart';

class StationReviewsScreen extends StatefulWidget {
  final int stationId;
  final String stationName;

  const StationReviewsScreen({
    super.key,
    required this.stationId,
    required this.stationName,
  });

  @override
  State<StationReviewsScreen> createState() => _StationReviewsScreenState();
}

class _StationReviewsScreenState extends State<StationReviewsScreen> {
  final ReviewService _reviewService = ReviewService();
  List<Review> _reviews = [];
  Map<String, dynamic> _rating = {'average': 0.0, 'count': 0};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    try {
      _reviews = await _reviewService.getStationReviews(widget.stationId);
      _rating = await _reviewService.getStationRating(widget.stationId);
    } catch (e) {
      debugPrint('Error loading reviews: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final avg = (_rating['average'] as num).toDouble();
    final count = _rating['count'] as int;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.stationName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue)))
          : RefreshIndicator(
              onRefresh: _loadReviews,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Rating summary
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            avg.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          StarRating(rating: avg, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            '$count ${count == 1 ? 'review' : 'reviews'}',
                            style: const TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_reviews.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: Column(
                          children: [
                            Icon(Icons.rate_review, color: Colors.white38, size: 48),
                            SizedBox(height: 12),
                            Text('No reviews yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
                          ],
                        ),
                      )
                    else
                      ..._reviews.map((review) => _buildReviewCard(review)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: AppColors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.reviewerShort, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    Text(review.formattedDate, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              StarRating(rating: review.rating.toDouble(), size: 16),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(review.comment, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ],
      ),
    );
  }
}
