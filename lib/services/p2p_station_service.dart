import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/p2p_station.dart';
import '../models/charging_station.dart';
import 'web3_service.dart';

class P2PStationService {
  final Web3Service _web3Service = Web3Service();

  Future<List<P2PStation>> getActiveStations() async {
    try {
      await _web3Service.initialize();
      final stationsData = await _web3Service.getAllActiveP2PStations();

      if (stationsData.isNotEmpty) {
        return stationsData.map((data) => P2PStation.fromContractData(data)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching P2P stations from chain: $e');
    }

    // Fallback to local storage
    return _getLocalStations();
  }

  Future<List<P2PStation>> getMyStations(String ownerAddress) async {
    final allStations = await getActiveStations();
    final localStations = await _getLocalStations();

    // Merge: include chain stations + local stations owned by this address
    final Map<int, P2PStation> stationMap = {};
    for (final s in allStations) {
      if (s.ownerAddress.toLowerCase() == ownerAddress.toLowerCase()) {
        stationMap[s.id] = s;
      }
    }
    for (final s in localStations) {
      if (s.ownerAddress.toLowerCase() == ownerAddress.toLowerCase()) {
        stationMap.putIfAbsent(s.id, () => s);
      }
    }

    return stationMap.values.toList();
  }

  Future<P2PStation?> registerStation({
    required String fromAddress,
    required String name,
    required String locationAddress,
    required double latitude,
    required double longitude,
    required String connectorType,
    required double powerKw,
    required double pricePerKwh,
    required bool isGreenEnergy,
  }) async {
    await _web3Service.initialize();

    // Try on-chain registration
    final txHash = await _web3Service.registerStation(
      fromAddress: fromAddress,
      name: name,
      locationAddress: locationAddress,
      latitude: latitude,
      longitude: longitude,
      connectorType: connectorType,
      powerKw: powerKw,
      pricePerKwh: pricePerKwh,
      isGreenEnergy: isGreenEnergy,
    );

    // Use on-chain station id when registration succeeded; otherwise local id for fallback
    int stationId = DateTime.now().millisecondsSinceEpoch;
    if (txHash != null) {
      final counter = await _web3Service.getStationCounter();
      if (counter != null) stationId = counter;
      debugPrint('Station registered on-chain: $txHash (id: $stationId)');
    }

    final station = P2PStation(
      id: stationId,
      ownerAddress: fromAddress,
      name: name,
      locationAddress: locationAddress,
      latitude: latitude,
      longitude: longitude,
      connectorType: connectorType,
      powerKw: powerKw,
      pricePerKwh: pricePerKwh,
      isGreenEnergy: isGreenEnergy,
      isActive: true,
      createdAt: DateTime.now(),
    );

    // Always save locally as fallback / cache
    await _saveStationLocally(station);

    return station;
  }

  Future<void> updateStation(int stationId, {double? pricePerKwh, bool? isActive}) async {
    final stations = await _getLocalStations();
    final index = stations.indexWhere((s) => s.id == stationId);
    if (index == -1) return;

    final old = stations[index];
    final newPrice = pricePerKwh ?? old.pricePerKwh;
    final newActive = isActive ?? old.isActive;

    // Sync to chain when contract is deployed (owner-only; no-op if not deployed or not owner)
    try {
      await _web3Service.initialize();
      final wallet = await _web3Service.getSavedWalletAddress();
      if (wallet != null && wallet.toLowerCase() == old.ownerAddress.toLowerCase()) {
        await _web3Service.updateStationOnChain(
          fromAddress: wallet,
          stationId: stationId,
          pricePerKwh: newPrice,
          isActive: newActive,
        );
      }
    } catch (e) {
      debugPrint('Optional on-chain station update skipped: $e');
    }

    final updated = P2PStation(
      id: old.id,
      ownerAddress: old.ownerAddress,
      name: old.name,
      locationAddress: old.locationAddress,
      latitude: old.latitude,
      longitude: old.longitude,
      connectorType: old.connectorType,
      powerKw: old.powerKw,
      pricePerKwh: newPrice,
      isGreenEnergy: old.isGreenEnergy,
      isActive: newActive,
      createdAt: old.createdAt,
      averageRating: old.averageRating,
      reviewCount: old.reviewCount,
    );

    stations[index] = updated;
    await _saveAllStationsLocally(stations);
  }

  Future<void> deactivateStation(int stationId) async {
    await updateStation(stationId, isActive: false);
  }

  Future<List<ChargingStation>> getStationsForMap(double userLat, double userLng) async {
    final p2pStations = await getActiveStations();
    return p2pStations.where((s) => s.isActive).map((s) {
      final distance = P2PStation.calculateDistance(userLat, userLng, s.latitude, s.longitude);
      return s.toChargingStation(distance: distance);
    }).toList();
  }

  // Local storage helpers
  Future<List<P2PStation>> _getLocalStations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('p2p_stations');
      if (data == null) return [];

      final List<dynamic> jsonList = json.decode(data);
      return jsonList.map((j) => P2PStation.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading local P2P stations: $e');
      return [];
    }
  }

  Future<void> _saveStationLocally(P2PStation station) async {
    final stations = await _getLocalStations();
    stations.add(station);
    await _saveAllStationsLocally(stations);
  }

  Future<void> _saveAllStationsLocally(List<P2PStation> stations) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = stations.map((s) => s.toJson()).toList();
    await prefs.setString('p2p_stations', json.encode(jsonList));
  }
}
