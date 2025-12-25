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
    // Open Charge Map API structure
    final addressInfo = json['AddressInfo'] as Map<String, dynamic>? ?? {};
    final connections = json['Connections'] as List<dynamic>? ?? [];
    
    // Calculate distance in miles (API returns in KM)
    final distanceKm = (json['Distance'] ?? 0.0).toDouble();
    final distanceMiles = distanceKm * 0.621371;
    
    // Determine if fast charging (check connection types)
    bool isFast = false;
    if (connections.isNotEmpty) {
      for (var conn in connections) {
        final powerKw = (conn['PowerKW'] ?? 0).toDouble();
        if (powerKw >= 50) {
          isFast = true;
          break;
        }
      }
    }
    
    // Check for green energy (solar/wind indicators)
    String energyType = 'Standard';
    final generalComments = (json['GeneralComments'] ?? '').toString().toLowerCase();
    if (generalComments.contains('solar') || 
        generalComments.contains('green') || 
        generalComments.contains('renewable')) {
      energyType = 'Green Energy';
    }
    
    // Get number of charging points
    final numberOfPoints = json['NumberOfPoints'] ?? connections.length ?? 1;
    
    // Get usage cost if available
    final usageCost = json['UsageCost'] ?? '';
    double pricePerKwh = 0.25; // Default
    if (usageCost.toString().isNotEmpty) {
      // Try to extract price from usage cost string
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
      availableSlots: numberOfPoints > 0 ? numberOfPoints - 1 : numberOfPoints, // Estimate available
      totalSlots: numberOfPoints,
      isFastCharging: isFast,
      isAvailable: true, // Assume available unless status indicates otherwise
      imageUrl: json['MediaItems']?[0]?['ItemURL'] ?? json['imageUrl'],
    );
  }
}

