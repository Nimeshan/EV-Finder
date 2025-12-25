import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/charging_station.dart';
import '../services/charging_station_service.dart';
import '../services/geocoding_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final ChargingStationService _stationService = ChargingStationService();
  final GeocodingService _geocodingService = GeocodingService();
  List<ChargingStation> _stations = [];
  ChargingStation? _selectedStation;
  Position? _currentPosition;
  String _selectedFilter = 'Available';
  final TextEditingController _searchController = TextEditingController();
  double _currentZoom = 14.0;
  LatLng _center = const LatLng(6.9271, 79.8612); // Default to Colombo, Sri Lanka
  bool _isSearching = false;
  bool _showFilters = true; // Initially show filters

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _loadStations(_center.latitude, _center.longitude);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _loadStations(_center.latitude, _center.longitude);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _center = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_center, _currentZoom);
      _loadStations(position.latitude, position.longitude);
    } catch (e) {
      _loadStations(_center.latitude, _center.longitude);
    }
  }

  Future<void> _loadStations(double lat, double lng) async {
    final stations = await _stationService.getNearbyStations(lat, lng);
    setState(() {
      _stations = stations;
    });
  }

  List<ChargingStation> _getFilteredStations() {
    if (_selectedFilter == 'Fast Charging') {
      return _stations.where((s) => s.isFastCharging).toList();
    } else if (_selectedFilter == 'Green') {
      return _stations.where((s) => s.energyType == 'Green Energy').toList();
    } else {
      return _stations.where((s) => s.isAvailable).toList();
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _selectedStation = null;
    });

    try {
      // First, try to find a station by name in the current list
      ChargingStation? matchingStation;
      try {
        matchingStation = _stations.firstWhere(
          (station) => station.name.toLowerCase().contains(query.toLowerCase()),
        );
      } catch (e) {
        // No matching station found
        matchingStation = null;
      }

      if (matchingStation != null) {
        // Found a station, center map on it
        final stationLocation = LatLng(matchingStation.latitude, matchingStation.longitude);
        setState(() {
          _center = stationLocation;
          _selectedStation = matchingStation;
        });
        _mapController.move(stationLocation, _currentZoom);
        setState(() {
          _isSearching = false;
        });
        return;
      }

      // If no station found, try geocoding the location
      final location = await _geocodingService.geocodeLocation(query);
      
      if (location != null) {
        // Found location, center map and load stations
        setState(() {
          _center = location;
        });
        _mapController.move(location, _currentZoom);
        await _loadStations(location.latitude, location.longitude);
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location not found. Please try a different search.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredStations = _getFilteredStations();

    return Scaffold(
      backgroundColor: const Color(0xFF1A2B3A),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _currentZoom,
              onTap: (tapPosition, point) {
                // Clear selected station when tapping map
                if (_selectedStation != null) {
                  setState(() {
                    _selectedStation = null;
                  });
                }
              },
              onMapEvent: (mapEvent) {
                // Update zoom and center when map moves
                if (mapEvent is MapEventMoveEnd) {
                  setState(() {
                    _currentZoom = _mapController.camera.zoom;
                    _center = _mapController.camera.center;
                  });
                }
              },
            ),
            children: [
              // Tile Layer - Using OpenStreetMap (free, no API key needed)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.evfinder',
                tileProvider: NetworkTileProvider(),
              ),
              // Markers Layer
              MarkerLayer(
                markers: filteredStations.map((station) {
                  return Marker(
                    point: LatLng(station.latitude, station.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedStation = station;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.ev_station,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // User Location Marker
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Search Bar and Filters
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A8FF7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search Location or Station',
                                hintStyle: const TextStyle(color: Colors.white70),
                                prefixIcon: _isSearching
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.search, color: Colors.white),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, color: Colors.white, size: 20),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onSubmitted: (value) {
                                _performSearch(value);
                              },
                              onChanged: (value) {
                                setState(() {});
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A3B4A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _showFilters ? Icons.filter_list : Icons.filter_list_off,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _showFilters = !_showFilters;
                              });
                            },
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A8FF7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.search, color: Colors.white),
                                onPressed: () {
                                  _performSearch(_searchController.text);
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Filter Buttons - Show/Hide based on _showFilters
                  if (_showFilters)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          _buildFilterButton('Available', _selectedFilter == 'Available', Colors.green),
                          const SizedBox(width: 8),
                          _buildFilterButton('Fast Charging', _selectedFilter == 'Fast Charging', const Color(0xFF4A8FF7), icon: Icons.timer),
                          const SizedBox(width: 8),
                          _buildFilterButton('Green', _selectedFilter == 'Green', const Color(0xFF4A8FF7), icon: Icons.eco),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Charging Availability Badge - Moves up/down based on filter visibility
          if (_stations.isNotEmpty)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: _showFilters ? 140 : 90, // Moves up when filters hidden, down when shown
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.ev_station, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${filteredStations.length} stations',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Station Detail Card
          if (_selectedStation != null)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: _buildStationCard(_selectedStation!),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 0),
    );
  }

  Widget _buildFilterButton(String label, bool isSelected, Color color, {IconData? icon}) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : const Color(0xFF2A3B4A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationCard(ChargingStation station) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStation = null;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A3B4A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Station Image Placeholder
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.ev_station, color: Colors.white, size: 40),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${station.distance.toStringAsFixed(1)} Mi',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          if (station.energyType == 'Green Energy') ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.eco, color: Colors.green, size: 14),
                            const SizedBox(width: 4),
                            const Text(
                              'Green Energy',
                              style: TextStyle(color: Colors.green, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${station.pricePerKwh.toStringAsFixed(2)}/kWh',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/booking-details',
                    arguments: {
                      'stationName': station.name,
                      'address': station.address,
                      'pricePerKwh': station.pricePerKwh,
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A8FF7),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.ev_station, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Book Charging Slot',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2B3A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/home');
          } else if (index == 1) {
            Navigator.pushReplacementNamed(context, '/wallet');
          } else if (index == 2) {
            Navigator.pushReplacementNamed(context, '/history');
          } else if (index == 3) {
            Navigator.pushReplacementNamed(context, '/profile');
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1A2B3A),
        selectedItemColor: const Color(0xFF4A9EFF),
        unselectedItemColor: Colors.white,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
