import 'package:flutter/material.dart';
import '../models/p2p_station.dart';
import '../services/p2p_station_service.dart';
import '../services/web3_service.dart';
import '../theme/app_theme.dart';

class MyStationsScreen extends StatefulWidget {
  const MyStationsScreen({super.key});

  @override
  State<MyStationsScreen> createState() => _MyStationsScreenState();
}

class _MyStationsScreenState extends State<MyStationsScreen> {
  final P2PStationService _p2pService = P2PStationService();
  final Web3Service _web3Service = Web3Service();
  List<P2PStation> _stations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoading = true);
    try {
      final address = await _web3Service.getSavedWalletAddress();
      if (address != null) {
        _stations = await _p2pService.getMyStations(address);
      }
    } catch (e) {
      debugPrint('Error loading my stations: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleStation(P2PStation station) async {
    await _p2pService.updateStation(station.id, isActive: !station.isActive);
    await _loadStations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Stations', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              await Navigator.pushNamed(context, '/list-station');
              _loadStations();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0))))
          : _stations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.ev_station, color: Colors.white38, size: 64),
                      const SizedBox(height: 16),
                      const Text('No stations listed yet', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/list-station');
                          _loadStations();
                        },
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('List Your First Charger', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9C27B0),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStations,
                  color: const Color(0xFF9C27B0),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _stations.length,
                    itemBuilder: (context, index) => _buildStationCard(_stations[index]),
                  ),
                ),
    );
  }

  Widget _buildStationCard(P2PStation station) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.home, color: Color(0xFF9C27B0), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(station.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 1),
                    const SizedBox(height: 4),
                    Text(station.locationAddress, style: const TextStyle(color: Colors.white54, fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 2),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: station.isActive
                      ? AppColors.green.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  station.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: station.isActive ? AppColors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 60),
              Expanded(
                child: Text(
                  '${station.connectorType} • \$${station.pricePerKwh.toStringAsFixed(2)}/kWh',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (station.isGreenEnergy) ...[
                const SizedBox(width: 8),
                const Icon(Icons.eco, color: AppColors.green, size: 14),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _toggleStation(station),
                icon: Icon(
                  station.isActive ? Icons.pause_circle : Icons.play_circle,
                  color: station.isActive ? Colors.orange : AppColors.green,
                  size: 18,
                ),
                label: Text(
                  station.isActive ? 'Deactivate' : 'Activate',
                  style: TextStyle(color: station.isActive ? Colors.orange : AppColors.green, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
