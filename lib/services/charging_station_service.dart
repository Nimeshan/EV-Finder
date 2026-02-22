import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/charging_station.dart';
import 'p2p_station_service.dart';

class ChargingStationService {
  static const String demoModeKey = 'demo_mode';
  static const String baseUrl = 'https://api.openchargemap.io/v3/poi';
  static const String apiKey = '667483b3-7855-46a3-a3cf-8593b5e70a48';
  final P2PStationService _p2pService = P2PStationService();

  /// Simulation / testing: when true, map uses only mock stations (no API call).
  static Future<bool> isDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(demoModeKey) ?? false;
  }

  static Future<void> setDemoMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(demoModeKey, value);
  }

  Future<List<ChargingStation>> getNearbyStations(
    double latitude,
    double longitude, {
    double radiusKm = 10,
  }) async {
    if (await isDemoMode()) {
      return _getMockStations(latitude, longitude);
    }
    final results = await Future.wait([
      _fetchFromOpenChargeMap(latitude, longitude, radiusKm),
      _p2pService.getStationsForMap(latitude, longitude),
    ]);
    final apiStations = results[0];
    final p2pStations = results[1];
    final allStations = [...apiStations, ...p2pStations];
    allStations.sort((a, b) => a.distance.compareTo(b.distance));
    return allStations;
  }

  Future<List<ChargingStation>> _fetchFromOpenChargeMap(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    try {
      final url = Uri.parse(
        '$baseUrl/?key=$apiKey&output=json&latitude=$latitude&longitude=$longitude&distance=$radiusKm&distanceunit=KM&maxresults=20&compact=true&verbose=false',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final stations = data
              .map((json) => ChargingStation.fromJson(json))
              .toList();
          stations.sort((a, b) => a.distance.compareTo(b.distance));
          return stations;
        } else {
          debugPrint('No stations found in area, using mock data');
          return _getMockStations(latitude, longitude);
        }
      } else {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        return _getMockStations(latitude, longitude);
      }
    } catch (e) {
      debugPrint('Error fetching stations: $e');
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
        powerKw: 150,
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
        powerKw: 7,
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
        powerKw: 50,
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
        powerKw: 100,
      ),
    ];
  }
}
