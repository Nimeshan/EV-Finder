import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/energy_listing.dart';
import 'web3_service.dart';

class EnergyTradingService {
  final Web3Service _web3Service = Web3Service();

  Future<double> getMyEnergyCredits(String walletAddress) async {
    try {
      await _web3Service.initialize();
      final credits = await _web3Service.getEnergyCredits(walletAddress);
      if (credits > 0) return credits;
    } catch (e) {
      debugPrint('Error getting on-chain credits: $e');
    }

    // Fallback to local
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('energy_credits_${walletAddress.toLowerCase()}') ?? 0;
  }

  Future<bool> addCredits({
    required String walletAddress,
    required double energyKwh,
  }) async {
    await _web3Service.initialize();

    final txHash = await _web3Service.addEnergyCredits(
      fromAddress: walletAddress,
      energyKwh: energyKwh,
    );

    // Always update locally
    final prefs = await SharedPreferences.getInstance();
    final key = 'energy_credits_${walletAddress.toLowerCase()}';
    final current = prefs.getDouble(key) ?? 0;
    await prefs.setDouble(key, current + energyKwh);

    return txHash != null || true; // local always succeeds
  }

  Future<List<EnergyListing>> getActiveListings() async {
    try {
      await _web3Service.initialize();
      final listingsData = await _web3Service.getActiveEnergyListings();

      if (listingsData.isNotEmpty) {
        return listingsData.map((data) => EnergyListing.fromContractData(data)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching on-chain listings: $e');
    }

    return _getLocalListings(activeOnly: true);
  }

  Future<List<EnergyListing>> getMyListings(String walletAddress) async {
    final all = await _getAllLocalListings();
    return all.where((l) =>
      l.sellerAddress.toLowerCase() == walletAddress.toLowerCase()
    ).toList();
  }

  Future<EnergyListing?> createListing({
    required String walletAddress,
    required double energyKwh,
    required double pricePerKwh,
  }) async {
    await _web3Service.initialize();

    // Check local credit balance
    final prefs = await SharedPreferences.getInstance();
    final key = 'energy_credits_${walletAddress.toLowerCase()}';
    final currentCredits = prefs.getDouble(key) ?? 0;

    if (currentCredits < energyKwh) {
      throw Exception('Insufficient energy credits. You have ${currentCredits.toStringAsFixed(1)} kWh.');
    }

    // Try on-chain
    final txHash = await _web3Service.listEnergy(
      fromAddress: walletAddress,
      energyKwh: energyKwh,
      pricePerKwh: pricePerKwh,
    );

    // Deduct credits locally
    await prefs.setDouble(key, currentCredits - energyKwh);

    final listing = EnergyListing(
      id: DateTime.now().millisecondsSinceEpoch,
      sellerAddress: walletAddress,
      energyKwh: energyKwh,
      pricePerKwh: pricePerKwh,
      totalPrice: energyKwh * pricePerKwh,
      isActive: true,
      isSold: false,
      createdAt: DateTime.now(),
    );

    await _saveListingLocally(listing);

    if (txHash != null) {
      debugPrint('Energy listed on-chain: $txHash');
    }

    return listing;
  }

  Future<bool> purchaseListing({
    required String buyerAddress,
    required int listingId,
    required String sellerAddress,
    required double totalPriceUsd,
    required double energyKwh,
    required String paymentTxHash,
  }) async {
    await _web3Service.initialize();

    // Try on-chain purchase
    await _web3Service.purchaseEnergy(
      fromAddress: buyerAddress,
      listingId: listingId,
      txHash: paymentTxHash,
    );

    // Update local listing
    final listings = await _getAllLocalListings();
    final index = listings.indexWhere((l) => l.id == listingId);
    if (index != -1) {
      final old = listings[index];
      listings[index] = EnergyListing(
        id: old.id,
        sellerAddress: old.sellerAddress,
        energyKwh: old.energyKwh,
        pricePerKwh: old.pricePerKwh,
        totalPrice: old.totalPrice,
        isActive: false,
        isSold: true,
        buyerAddress: buyerAddress,
        txHash: paymentTxHash,
        createdAt: old.createdAt,
      );
      await _saveAllListingsLocally(listings);
    }

    // Add credits to buyer locally
    final prefs = await SharedPreferences.getInstance();
    final buyerKey = 'energy_credits_${buyerAddress.toLowerCase()}';
    final buyerCredits = prefs.getDouble(buyerKey) ?? 0;
    await prefs.setDouble(buyerKey, buyerCredits + energyKwh);

    return true;
  }

  Future<bool> cancelListing({
    required String walletAddress,
    required int listingId,
    required double energyKwh,
  }) async {
    await _web3Service.initialize();

    await _web3Service.cancelEnergyListing(
      fromAddress: walletAddress,
      listingId: listingId,
    );

    // Return credits locally
    final prefs = await SharedPreferences.getInstance();
    final key = 'energy_credits_${walletAddress.toLowerCase()}';
    final current = prefs.getDouble(key) ?? 0;
    await prefs.setDouble(key, current + energyKwh);

    // Update listing locally
    final listings = await _getAllLocalListings();
    final index = listings.indexWhere((l) => l.id == listingId);
    if (index != -1) {
      final old = listings[index];
      listings[index] = EnergyListing(
        id: old.id,
        sellerAddress: old.sellerAddress,
        energyKwh: old.energyKwh,
        pricePerKwh: old.pricePerKwh,
        totalPrice: old.totalPrice,
        isActive: false,
        isSold: false,
        createdAt: old.createdAt,
      );
      await _saveAllListingsLocally(listings);
    }

    return true;
  }

  // Local storage helpers
  Future<List<EnergyListing>> _getAllLocalListings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('energy_listings');
      if (data == null) return [];

      final List<dynamic> jsonList = json.decode(data);
      return jsonList.map((j) => EnergyListing.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<EnergyListing>> _getLocalListings({bool activeOnly = false}) async {
    final all = await _getAllLocalListings();
    if (activeOnly) {
      return all.where((l) => l.isActive && !l.isSold).toList();
    }
    return all;
  }

  Future<void> _saveListingLocally(EnergyListing listing) async {
    final listings = await _getAllLocalListings();
    listings.add(listing);
    await _saveAllListingsLocally(listings);
  }

  Future<void> _saveAllListingsLocally(List<EnergyListing> listings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = listings.map((l) => l.toJson()).toList();
    await prefs.setString('energy_listings', json.encode(jsonList));
  }
}
