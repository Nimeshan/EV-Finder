import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BookingStatus { pending, confirmed, cancelled, completed }

class Booking {
  final String id;
  final String stationId;
  final String stationName;
  final String address;
  final String connectorType;
  final DateTime startTime;
  final DateTime endTime;
  final double energyKwh;
  final double amountUsd;
  BookingStatus status;
  String? txHash;
  final String? walletAddress;
  /// On-chain booking id (EVFinder contract). Null if booking was not created on chain.
  final int? contractBookingId;

  Booking({
    required this.id,
    required this.stationId,
    required this.stationName,
    required this.address,
    required this.connectorType,
    required this.startTime,
    required this.endTime,
    required this.energyKwh,
    required this.amountUsd,
    this.status = BookingStatus.pending,
    this.txHash,
    this.walletAddress,
    this.contractBookingId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stationId': stationId,
      'stationName': stationName,
      'address': address,
      'connectorType': connectorType,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'energyKwh': energyKwh,
      'amountUsd': amountUsd,
      'status': status.index,
      'txHash': txHash,
      'walletAddress': walletAddress,
      'contractBookingId': contractBookingId,
    };
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      stationId: json['stationId'] as String,
      stationName: json['stationName'] as String,
      address: json['address'] as String,
      connectorType: json['connectorType'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      energyKwh: (json['energyKwh'] as num).toDouble(),
      amountUsd: (json['amountUsd'] as num).toDouble(),
      status: BookingStatus.values[json['status'] as int],
      txHash: json['txHash'] as String?,
      walletAddress: json['walletAddress'] as String?,
      contractBookingId: json['contractBookingId'] as int?,
    );
  }

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bookingDate = DateTime(startTime.year, startTime.month, startTime.day);
    final hour = startTime.hour > 12 ? startTime.hour - 12 : startTime.hour == 0 ? 12 : startTime.hour;
    final period = startTime.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:${startTime.minute.toString().padLeft(2, '0')} $period';

    if (bookingDate == today) {
      return 'Today, $timeStr';
    } else if (bookingDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow, $timeStr';
    } else {
      return '${startTime.day}/${startTime.month}/${startTime.year}, $timeStr';
    }
  }

  String get statusLabel {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.completed:
        return 'Completed';
    }
  }

  int get durationMinutes => endTime.difference(startTime).inMinutes;
}

class BookingService {
  static const String _bookingsKey = 'bookings';

  Future<Booking> createBooking({
    required String stationId,
    required String stationName,
    required String address,
    required String connectorType,
    required DateTime startTime,
    required DateTime endTime,
    required double energyKwh,
    required double amountUsd,
    String? walletAddress,
    int? contractBookingId,
  }) async {
    // Check for conflicts
    final hasConflict = await hasTimeConflict(stationId, startTime, endTime);
    if (hasConflict) {
      throw Exception('Time conflict with existing booking at this station');
    }

    final booking = Booking(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      stationId: stationId,
      stationName: stationName,
      address: address,
      connectorType: connectorType,
      startTime: startTime,
      endTime: endTime,
      energyKwh: energyKwh,
      amountUsd: amountUsd,
      walletAddress: walletAddress,
      contractBookingId: contractBookingId,
    );

    final bookings = await _getBookings();
    bookings.add(booking);
    await _saveBookings(bookings);

    return booking;
  }

  Future<void> cancelBooking(String bookingId) async {
    final bookings = await _getBookings();
    final index = bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      final booking = bookings[index];
      if (booking.status == BookingStatus.pending || booking.status == BookingStatus.confirmed) {
        bookings[index].status = BookingStatus.cancelled;
        await _saveBookings(bookings);
      }
    }
  }

  Future<void> completeBooking(String bookingId, {String? txHash}) async {
    final bookings = await _getBookings();
    final index = bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      bookings[index].status = BookingStatus.completed;
      bookings[index].txHash = txHash;
      await _saveBookings(bookings);
    }
  }

  Future<bool> hasTimeConflict(String stationId, DateTime startTime, DateTime endTime) async {
    final bookings = await getBookingsForStation(stationId);
    for (final booking in bookings) {
      if (booking.status == BookingStatus.cancelled || booking.status == BookingStatus.completed) {
        continue;
      }
      if (startTime.isBefore(booking.endTime) && endTime.isAfter(booking.startTime)) {
        return true;
      }
    }
    return false;
  }

  Future<List<Booking>> getBookingsForStation(String stationId) async {
    final bookings = await _getBookings();
    return bookings.where((b) => b.stationId == stationId).toList();
  }

  Future<List<Booking>> getUserBookings({String? walletAddress}) async {
    final bookings = await _getBookings();
    if (walletAddress != null) {
      return bookings.where((b) => b.walletAddress == walletAddress).toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));
    }
    return bookings..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  Future<List<Booking>> _getBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_bookingsKey);
    if (jsonString == null) return [];

    try {
      final jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList.map((j) => Booking.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      return [];
    }
  }

  Future<void> _saveBookings(List<Booking> bookings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = bookings.map((b) => b.toJson()).toList();
    await prefs.setString(_bookingsKey, json.encode(jsonList));
  }
}
