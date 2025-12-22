import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/charging_station.dart';

class ChargingStationService {
  // Using Open Charge Map API (free and open source)
  static const String baseUrl = 'https://api.openchargemap.io/v3/poi';
  
  // For demo purposes, we'll use mock data that matches the UI
  // In production, replace this with actual API calls
  Future<List<ChargingStation>> getNearbyStations(
    double latitude,
    double longitude,
    {double radiusKm = 10}
  ) async {
    try {
      // Try to fetch from Open Charge Map API
      final url = Uri.parse(
        '$baseUrl/?output=json&latitude=$latitude&longitude=$longitude&distance=$radiusKm&distanceunit=KM&maxresults=20'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ChargingStation.fromJson(json)).toList();
      } else {
        // Fallback to mock data if API fails
        return _getMockStations(latitude, longitude);
      }
    } catch (e) {
      // Return mock data on error
      return _getMockStations(latitude, longitude);
    }
  }

  // Mock data for demonstration
  List<ChargingStation> _getMockStations(double latitude, double longitude) {
    return [
      ChargingStation(
        id: '1',
        name: 'Fast Charging Center Rajagiriya Town',
        latitude: latitude + 0.01,
        longitude: longitude + 0.01,
        address: 'Rajagiriya, Sri Lanka',
        distance: 1.5,
        energyType: 'Green Energy',
        pricePerKwh: 0.25,
        availableSlots: 7,
        totalSlots: 12,
        isFastCharging: true,
        isAvailable: true,
      ),
      ChargingStation(
        id: '2',
        name: 'EV Station Union Street',
        latitude: latitude - 0.008,
        longitude: longitude + 0.015,
        address: 'Union Street, Lower Vailsburg',
        distance: 2.3,
        energyType: 'Standard',
        pricePerKwh: 0.30,
        availableSlots: 3,
        totalSlots: 8,
        isFastCharging: false,
        isAvailable: true,
      ),
      ChargingStation(
        id: '3',
        name: 'Solar Powered Charging Hub',
        latitude: latitude + 0.012,
        longitude: longitude - 0.01,
        address: 'Main Road, City Center',
        distance: 1.8,
        energyType: 'Green Energy',
        pricePerKwh: 0.22,
        availableSlots: 5,
        totalSlots: 10,
        isFastCharging: true,
        isAvailable: true,
      ),
      ChargingStation(
        id: '4',
        name: 'Quick Charge Station',
        latitude: latitude - 0.015,
        longitude: longitude - 0.008,
        address: 'Highway Exit 5',
        distance: 3.1,
        energyType: 'Standard',
        pricePerKwh: 0.28,
        availableSlots: 2,
        totalSlots: 6,
        isFastCharging: true,
        isAvailable: true,
      ),
    ];
  }
}

