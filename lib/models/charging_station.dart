class ChargingStation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final double distance; // in miles
  final String energyType; // "Green Energy" or regular
  final double pricePerKwh;
  final int availableSlots;
  final int totalSlots;
  final bool isFastCharging;
  final bool isAvailable;
  final String? imageUrl;

  ChargingStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.distance,
    required this.energyType,
    required this.pricePerKwh,
    required this.availableSlots,
    required this.totalSlots,
    required this.isFastCharging,
    required this.isAvailable,
    this.imageUrl,
  });

  factory ChargingStation.fromJson(Map<String, dynamic> json) {
    return ChargingStation(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Station',
      latitude: (json['latitude'] ?? json['AddressInfo']?['Latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? json['AddressInfo']?['Longitude'] ?? 0.0).toDouble(),
      address: json['address'] ?? json['AddressInfo']?['AddressLine1'] ?? 'Unknown Address',
      distance: (json['distance'] ?? 0.0).toDouble(),
      energyType: json['energyType'] ?? 'Standard',
      pricePerKwh: (json['pricePerKwh'] ?? json['UsageCost'] ?? 0.25).toDouble(),
      availableSlots: json['availableSlots'] ?? json['NumberOfPoints'] ?? 7,
      totalSlots: json['totalSlots'] ?? json['NumberOfPoints'] ?? 12,
      isFastCharging: json['isFastCharging'] ?? false,
      isAvailable: json['isAvailable'] ?? true,
      imageUrl: json['imageUrl'],
    );
  }
}

