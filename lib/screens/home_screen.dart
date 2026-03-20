import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/charging_station.dart';
import '../services/charging_station_service.dart';
import '../services/geocoding_service.dart';
import '../theme/app_theme.dart';

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
  final TextEditingController _searchController = TextEditingController();
  double _currentZoom = 14.0;
  LatLng _center = const LatLng(6.9271, 79.8612);
  bool _isSearching = false;
  bool _isLoadingStations = true;
  final bool _showFilters = true;

  // Filter state
  bool _filterAvailable = true;
  bool _filterFastCharging = false;
  bool _filterGreenEnergy = false;
  bool _filterP2P = false;
  RangeValues _priceRange = const RangeValues(0.0, 2.00);
  Set<String> _selectedSpeeds = {'Fast', 'Medium', 'Slow'};
  String _sortBy = 'distance'; // 'distance' or 'price'
  int _activeFilterCount = 0;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    // Auto-refresh station availability every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadStations(_center.latitude, _center.longitude);
      }
    });
  }

  void _updateActiveFilterCount() {
    int count = 0;
    if (_filterAvailable) count++;
    if (_filterFastCharging) count++;
    if (_filterGreenEnergy) count++;
    if (_filterP2P) count++;
    if (_priceRange.start > 0.0 || _priceRange.end < 2.00) count++;
    if (_selectedSpeeds.length < 3) count++;
    if (_sortBy != 'distance') count++;
    _activeFilterCount = count;
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
    setState(() {
      _isLoadingStations = true;
    });
    final stations = await _stationService.getNearbyStations(lat, lng);
    if (mounted) {
      setState(() {
        _stations = stations;
        _isLoadingStations = false;
      });
    }
  }

  List<ChargingStation> _getFilteredStations() {
    var filtered = _stations.where((s) {
      // Availability filter
      if (_filterAvailable && !s.isAvailable) return false;

      // Fast charging filter
      if (_filterFastCharging && !s.isFastCharging) return false;

      // Green energy filter
      if (_filterGreenEnergy && s.energyType != 'Green Energy') return false;

      // P2P filter
      if (_filterP2P && !s.isP2P) return false;

      // Price range filter
      if (s.pricePerKwh < _priceRange.start || s.pricePerKwh > _priceRange.end) {
        return false;
      }

      // Speed filter
      if (!_selectedSpeeds.contains(s.speedCategory)) return false;

      return true;
    }).toList();

    // Sort
    if (_sortBy == 'price') {
      filtered.sort((a, b) => a.pricePerKwh.compareTo(b.pricePerKwh));
    } else {
      filtered.sort((a, b) => a.distance.compareTo(b.distance));
    }

    return filtered;
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _selectedStation = null;
    });

    try {
      ChargingStation? matchingStation;
      try {
        matchingStation = _stations.firstWhere(
          (station) => station.name.toLowerCase().contains(query.toLowerCase()),
        );
      } catch (e) {
        matchingStation = null;
      }

      if (matchingStation != null) {
        final stationLocation = LatLng(
          matchingStation.latitude,
          matchingStation.longitude,
        );
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

      final location = await _geocodingService.geocodeLocation(query);

      if (location != null) {
        setState(() {
          _center = location;
        });
        _mapController.move(location, _currentZoom);
        await _loadStations(location.latitude, location.longitude);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location not found. Please try a different search.',
              ),
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

  Color _getMarkerColor(ChargingStation station) {
    if (!station.isAvailable) return Colors.red;
    final ratio = station.availableSlots / station.totalSlots;
    if (ratio <= 0.2) return Colors.orange;
    return AppColors.green;
  }

  void _showFilterSheet() {
    // Local copies for the sheet
    bool tempAvailable = _filterAvailable;
    bool tempFast = _filterFastCharging;
    bool tempGreen = _filterGreenEnergy;
    RangeValues tempPrice = _priceRange;
    Set<String> tempSpeeds = Set.from(_selectedSpeeds);
    String tempSort = _sortBy;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempAvailable = true;
                            tempFast = false;
                            tempGreen = false;
                            tempPrice = const RangeValues(0.0, 2.00);
                            tempSpeeds = {'Fast', 'Medium', 'Slow'};
                            tempSort = 'distance';
                          });
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(color: AppColors.primaryBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick toggles
                  const Text(
                    'QUICK FILTERS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _filterChip(
                        'Available',
                        tempAvailable,
                        (v) => setSheetState(() => tempAvailable = v),
                      ),
                      _filterChip(
                        'Fast Charging',
                        tempFast,
                        (v) => setSheetState(() => tempFast = v),
                      ),
                      _filterChip(
                        'Green Energy',
                        tempGreen,
                        (v) => setSheetState(() => tempGreen = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Price range
                  Text(
                    'PRICE RANGE (\$${tempPrice.start.toStringAsFixed(2)} - \$${tempPrice.end.toStringAsFixed(2)}/kWh)',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  RangeSlider(
                    values: tempPrice,
                    min: 0.0,
                    max: 2.00,
                    divisions: 40,
                    activeColor: AppColors.primaryBlue,
                    inactiveColor: Colors.white24,
                    labels: RangeLabels(
                      '\$${tempPrice.start.toStringAsFixed(2)}',
                      '\$${tempPrice.end.toStringAsFixed(2)}',
                    ),
                    onChanged: (values) {
                      setSheetState(() => tempPrice = values);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Charging speed
                  const Text(
                    'CHARGING SPEED',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _filterChip(
                        'Fast (50+ kW)',
                        tempSpeeds.contains('Fast'),
                        (v) {
                          setSheetState(() {
                            if (v) {
                              tempSpeeds.add('Fast');
                            } else {
                              tempSpeeds.remove('Fast');
                            }
                          });
                        },
                      ),
                      _filterChip(
                        'Medium (22-49 kW)',
                        tempSpeeds.contains('Medium'),
                        (v) {
                          setSheetState(() {
                            if (v) {
                              tempSpeeds.add('Medium');
                            } else {
                              tempSpeeds.remove('Medium');
                            }
                          });
                        },
                      ),
                      _filterChip(
                        'Slow (<22 kW)',
                        tempSpeeds.contains('Slow'),
                        (v) {
                          setSheetState(() {
                            if (v) {
                              tempSpeeds.add('Slow');
                            } else {
                              tempSpeeds.remove('Slow');
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Sort by
                  const Text(
                    'SORT BY',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setSheetState(() => tempSort = 'distance'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: tempSort == 'distance'
                                  ? AppColors.primaryBlue
                                  : AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'Distance',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => tempSort = 'price'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: tempSort == 'price'
                                  ? AppColors.primaryBlue
                                  : AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'Price (Low→High)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterAvailable = tempAvailable;
                          _filterFastCharging = tempFast;
                          _filterGreenEnergy = tempGreen;
                          _priceRange = tempPrice;
                          _selectedSpeeds = tempSpeeds;
                          _sortBy = tempSort;
                          _updateActiveFilterCount();
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterChip(
    String label,
    bool selected,
    ValueChanged<bool> onChanged,
  ) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontSize: 12,
        ),
      ),
      selected: selected,
      onSelected: onChanged,
      selectedColor: AppColors.primaryBlue,
      backgroundColor: AppColors.cardBackground,
      checkmarkColor: Colors.white,
      side: BorderSide.none,
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredStations = _getFilteredStations();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _currentZoom,
              onTap: (tapPosition, point) {
                if (_selectedStation != null) {
                  setState(() {
                    _selectedStation = null;
                  });
                }
              },
              onMapEvent: (mapEvent) {
                if (mapEvent is MapEventMoveEnd) {
                  setState(() {
                    _currentZoom = _mapController.camera.zoom;
                    _center = _mapController.camera.center;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.evfinder',
                tileProvider: NetworkTileProvider(),
              ),
              MarkerLayer(
                markers: filteredStations.map((station) {
                  final isP2P = station.isP2P;
                  final markerColor = isP2P
                      ? const Color(0xFF9C27B0)
                      : _getMarkerColor(station);
                  final markerIcon = isP2P ? Icons.home : Icons.ev_station;
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
                          color: markerColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(markerIcon, color: Colors.white, size: 24),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
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
          // Loading overlay
          if (_isLoadingStations)
            Positioned(
              top: _showFilters ? 140 : 90,
              left: 0,
              right: 0,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
                ),
              ),
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
                              color: AppColors.searchBar,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search Location or Station',
                                hintStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                prefixIcon: _isSearching
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.search,
                                        color: Colors.white,
                                      ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear,
                                          color: Colors.white,
                                          size: 20,
                                        ),
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
                              onSubmitted: (value) => _performSearch(value),
                              onChanged: (value) => setState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Filter button with badge
                        Stack(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.filterInactive,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.tune,
                                  color: Colors.white,
                                ),
                                onPressed: _showFilterSheet,
                              ),
                            ),
                            if (_activeFilterCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$_activeFilterCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_searchController.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.search,
                                  color: Colors.white,
                                ),
                                onPressed: () =>
                                    _performSearch(_searchController.text),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Quick filter chips
                  if (_showFilters)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildQuickChip(
                              'Available',
                              _filterAvailable,
                              AppColors.green,
                              () {
                                setState(() {
                                  _filterAvailable = !_filterAvailable;
                                  _updateActiveFilterCount();
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildQuickChip(
                              'Fast',
                              _filterFastCharging,
                              AppColors.primaryBlue,
                              () {
                                setState(() {
                                  _filterFastCharging = !_filterFastCharging;
                                  _updateActiveFilterCount();
                                });
                              },
                              icon: Icons.bolt,
                            ),
                            const SizedBox(width: 8),
                            _buildQuickChip(
                              'Green',
                              _filterGreenEnergy,
                              AppColors.primaryBlue,
                              () {
                                setState(() {
                                  _filterGreenEnergy = !_filterGreenEnergy;
                                  _updateActiveFilterCount();
                                });
                              },
                              icon: Icons.eco,
                            ),
                            const SizedBox(width: 8),
                            _buildQuickChip(
                              'P2P',
                              _filterP2P,
                              const Color(0xFF9C27B0),
                              () {
                                setState(() {
                                  _filterP2P = !_filterP2P;
                                  _updateActiveFilterCount();
                                });
                              },
                              icon: Icons.people,
                            ),
                            const SizedBox(width: 8),
                            _buildQuickChip(
                              _sortBy == 'price' ? 'Price ↑' : 'Distance ↑',
                              _sortBy == 'price',
                              AppColors.primaryBlue,
                              () {
                                setState(() {
                                  _sortBy = _sortBy == 'distance'
                                      ? 'price'
                                      : 'distance';
                                  _updateActiveFilterCount();
                                });
                              },
                              icon: Icons.sort,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Charging Availability Badge
          if (_stations.isNotEmpty && !_isLoadingStations)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: _showFilters ? 140 : 90,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.green,
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
          // List Charger FAB
          Positioned(
            bottom: 16,
            left: 16,
            child: FloatingActionButton.extended(
              heroTag: 'listCharger',
              backgroundColor: const Color(0xFF9C27B0),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'List Charger',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => Navigator.pushNamed(context, '/list-station'),
            ),
          ),
          // Refresh button
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'refresh',
              backgroundColor: AppColors.primaryBlue,
              onPressed: () =>
                  _loadStations(_center.latitude, _center.longitude),
              child: const Icon(Icons.refresh, color: Colors.white),
            ),
          ),
          // Station Detail Card
          if (_selectedStation != null)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: _buildStationCard(_selectedStation!),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(
    String label,
    bool isSelected,
    Color activeColor,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppColors.filterInactive,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 4),
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
          color: AppColors.cardBackground,
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.ev_station,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (station.isP2P)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9C27B0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'P2P',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              station.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${station.distance.toStringAsFixed(1)} Mi',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.local_parking,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${station.availableSlots}/${station.totalSlots} slots',
                              style: TextStyle(
                                color: station.availableSlots > 0
                                    ? AppColors.green
                                    : Colors.red,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (station.energyType == 'Green Energy') ...[
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.eco,
                              color: Colors.green,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '\$${station.pricePerKwh.toStringAsFixed(2)}/kWh',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (station.powerKw > 0) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: station.speedCategory == 'Fast'
                                    ? AppColors.primaryBlue
                                    : station.speedCategory == 'Medium'
                                    ? Colors.orange
                                    : Colors.grey,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${station.powerKw.toInt()} kW',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
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
                      'energyType': station.energyType,
                      'stationId': station.id,
                      'isP2P': station.isP2P,
                      'ownerAddress': station.ownerAddress,
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
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
}
