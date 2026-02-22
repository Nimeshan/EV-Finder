import 'package:intl/intl.dart';

class Review {
  final int id;
  final String reviewerAddress;
  final int stationId;
  final int bookingId;
  final int rating;
  final String comment;
  final DateTime timestamp;

  Review({
    required this.id,
    required this.reviewerAddress,
    required this.stationId,
    required this.bookingId,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  String get reviewerShort {
    if (reviewerAddress.length < 10) return reviewerAddress;
    return '${reviewerAddress.substring(0, 6)}...${reviewerAddress.substring(reviewerAddress.length - 4)}';
  }

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(timestamp);
  }

  factory Review.fromContractData(Map<String, dynamic> data) {
    return Review(
      id: data['id'] ?? 0,
      reviewerAddress: data['reviewer'] ?? '',
      stationId: data['stationId'] ?? 0,
      bookingId: data['bookingId'] ?? 0,
      rating: data['rating'] ?? 0,
      comment: data['comment'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        ((data['timestamp'] ?? 0) as int) * 1000,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reviewerAddress': reviewerAddress,
      'stationId': stationId,
      'bookingId': bookingId,
      'rating': rating,
      'comment': comment,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] ?? 0,
      reviewerAddress: json['reviewerAddress'] ?? '',
      stationId: json['stationId'] ?? 0,
      bookingId: json['bookingId'] ?? 0,
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
    );
  }
}
