import 'dart:math';
import 'charging_station.dart';

class P2PStation {
  final int id;
  final String ownerAddress;
  final String name;
  final String locationAddress;
  final double latitude;
  final double longitude;
  final String connectorType;
  final double powerKw;
  final double pricePerKwh;
  final bool isGreenEnergy;
  final bool isActive;
  final DateTime createdAt;
  final double averageRating;
  final int reviewCount;

  P2PStation({
    required this.id,
    required this.ownerAddress,
    required this.name,
    required this.locationAddress,
    required this.latitude,
    required this.longitude,
    required this.connectorType,
    required this.powerKw,
    required this.pricePerKwh,
    required this.isGreenEnergy,
    required this.isActive,
    required this.createdAt,
    this.averageRating = 0,
    this.reviewCount = 0,
  });

  ChargingStation toChargingStation({double distance = 0}) {
    return ChargingStation(
      id: 'p2p_$id',
      name: name,
      latitude: latitude,
      longitude: longitude,
      address: locationAddress,
      distance: distance,
      energyType: isGreenEnergy ? 'Green Energy' : 'Standard',
      pricePerKwh: pricePerKwh,
      availableSlots: 1,
      totalSlots: 1,
      isFastCharging: powerKw >= 50,
      isAvailable: isActive,
      powerKw: powerKw,
      isP2P: true,
      ownerAddress: ownerAddress,
    );
  }

  factory P2PStation.fromContractData(Map<String, dynamic> data) {
    return P2PStation(
      id: data['id'] ?? 0,
      ownerAddress: data['owner'] ?? '',
      name: data['name'] ?? '',
      locationAddress: data['locationAddress'] ?? '',
      latitude: (data['latitude'] ?? 0) / 1e6,
      longitude: (data['longitude'] ?? 0) / 1e6,
      connectorType: data['connectorType'] ?? '',
      powerKw: (data['powerKw'] ?? 0) / 1000.0,
      pricePerKwh: (data['pricePerKwh'] ?? 0) / 100.0,
      isGreenEnergy: data['isGreenEnergy'] ?? false,
      isActive: data['isActive'] ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((data['createdAt'] ?? 0) as int) * 1000,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerAddress': ownerAddress,
      'name': name,
      'locationAddress': locationAddress,
      'latitude': latitude,
      'longitude': longitude,
      'connectorType': connectorType,
      'powerKw': powerKw,
      'pricePerKwh': pricePerKwh,
      'isGreenEnergy': isGreenEnergy,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
    };
  }

  factory P2PStation.fromJson(Map<String, dynamic> json) {
    return P2PStation(
      id: json['id'] ?? 0,
      ownerAddress: json['ownerAddress'] ?? '',
      name: json['name'] ?? '',
      locationAddress: json['locationAddress'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      connectorType: json['connectorType'] ?? '',
      powerKw: (json['powerKw'] ?? 0.0).toDouble(),
      pricePerKwh: (json['pricePerKwh'] ?? 0.0).toDouble(),
      isGreenEnergy: json['isGreenEnergy'] ?? false,
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      averageRating: (json['averageRating'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
    );
  }

  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 3958.8; // miles
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) => degree * pi / 180;
}
