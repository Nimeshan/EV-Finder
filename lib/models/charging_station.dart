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
  final double powerKw; // max charger power in kW
  final bool isP2P;
  final String? ownerAddress; // wallet address of P2P station owner

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
    this.powerKw = 0,
    this.isP2P = false,
    this.ownerAddress,
  });

  String get speedCategory {
    if (powerKw >= 50) return 'Fast';
    if (powerKw >= 22) return 'Medium';
    return 'Slow';
  }

  factory ChargingStation.fromJson(Map<String, dynamic> json) {
    final addressInfo = json['AddressInfo'] as Map<String, dynamic>? ?? {};
    final connections = json['Connections'] as List<dynamic>? ?? [];

    final distanceKm = (json['Distance'] ?? 0.0).toDouble();
    final distanceMiles = distanceKm * 0.621371;

    bool isFast = false;
    double maxPower = 0;
    if (connections.isNotEmpty) {
      for (var conn in connections) {
        final pw = (conn['PowerKW'] ?? 0).toDouble();
        if (pw > maxPower) maxPower = pw;
        if (pw >= 50) isFast = true;
      }
    }

    String energyType = 'Standard';
    final generalComments = (json['GeneralComments'] ?? '').toString().toLowerCase();
    if (generalComments.contains('solar') ||
        generalComments.contains('green') ||
        generalComments.contains('renewable')) {
      energyType = 'Green Energy';
    }

    final numberOfPoints = json['NumberOfPoints'] ?? connections.length ?? 1;

    final usageCost = json['UsageCost'] ?? '';
    double pricePerKwh = 0.25;
    if (usageCost.toString().isNotEmpty) {
      final costMatch = RegExp(r'[\d.]+').firstMatch(usageCost.toString());
      if (costMatch != null) {
        pricePerKwh = double.tryParse(costMatch.group(0) ?? '0.25') ?? 0.25;
      }
    }

    return ChargingStation(
      id: json['ID']?.toString() ?? json['id']?.toString() ?? '',
      name: addressInfo['Title'] ?? json['Name'] ?? 'Unknown Station',
      latitude: (addressInfo['Latitude'] ?? 0.0).toDouble(),
      longitude: (addressInfo['Longitude'] ?? 0.0).toDouble(),
      address: addressInfo['AddressLine1'] ??
               addressInfo['Town'] ??
               addressInfo['StateOrProvince'] ??
               'Unknown Address',
      distance: distanceMiles,
      energyType: energyType,
      pricePerKwh: pricePerKwh,
      availableSlots: numberOfPoints > 0 ? numberOfPoints - 1 : numberOfPoints,
      totalSlots: numberOfPoints,
      isFastCharging: isFast,
      isAvailable: true,
      imageUrl: json['MediaItems']?[0]?['ItemURL'] ?? json['imageUrl'],
      powerKw: maxPower,
    );
  }
}
