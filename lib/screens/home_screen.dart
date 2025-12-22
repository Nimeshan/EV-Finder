import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/charging_station.dart';
import '../services/charging_station_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  final ChargingStationService _stationService = ChargingStationService();
  List<ChargingStation> _stations = [];
  ChargingStation? _selectedStation;
  Position? _currentPosition;
  String _selectedFilter = 'Available';
  final TextEditingController _searchController = TextEditingController();
  String? _mapError;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Use default location if service is not enabled
        _loadStations(6.9271, 79.8612); // Default to Colombo, Sri Lanka
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _loadStations(6.9271, 79.8612);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
      _loadStations(position.latitude, position.longitude);
    } catch (e) {
      _loadStations(6.9271, 79.8612);
    }
  }

  Future<void> _loadStations(double lat, double lng) async {
    final stations = await _stationService.getNearbyStations(lat, lng);
    setState(() {
      _stations = stations;
    });
  }


  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Set<Marker> _buildMarkers() {
    List<ChargingStation> filteredStations = _stations;
    
    // Apply filter
    if (_selectedFilter == 'Fast Charging') {
      filteredStations = _stations.where((s) => s.isFastCharging).toList();
    } else if (_selectedFilter == 'Green') {
      filteredStations = _stations.where((s) => s.energyType == 'Green Energy').toList();
    } else {
      filteredStations = _stations.where((s) => s.isAvailable).toList();
    }
    
    return filteredStations.map((station) {
      return Marker(
        markerId: MarkerId(station.id),
        position: LatLng(station.latitude, station.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        onTap: () {
          setState(() {
            _selectedStation = station;
          });
        },
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final defaultLat = _currentPosition?.latitude ?? 6.9271;
    final defaultLng = _currentPosition?.longitude ?? 79.8612;

    return Scaffold(
      backgroundColor: const Color(0xFF1A2B3A),
      body: Stack(
        children: [
          // Map or Error Message
          if (_mapError != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3B4A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Map Error',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _mapError!,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'To fix this:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1. Get a Google Maps API key from Google Cloud Console',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '2. For Android: Add it to android/app/src/main/AndroidManifest.xml',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '3. For iOS: Add it to ios/Runner/Info.plist',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '4. Replace YOUR_GOOGLE_MAPS_API_KEY with your actual key',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _mapError = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A8FF7),
                      ),
                      child: const Text('Retry', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          else
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(defaultLat, defaultLng),
                zoom: 14,
              ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            style: _darkMapStyle,
              onCameraMoveStarted: () {
                // Clear any previous errors
                if (_mapError != null) {
                  setState(() {
                    _mapError = null;
                  });
                }
              },
              markers: _buildMarkers(),
              mapType: MapType.normal,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              onTap: (LatLng position) {
                // Clear selected station when tapping map
                if (_selectedStation != null) {
                  setState(() {
                    _selectedStation = null;
                  });
                }
              },
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
                              decoration: const InputDecoration(
                                hintText: 'Search Location or Station',
                                hintStyle: TextStyle(color: Colors.white70),
                                prefixIcon: Icon(Icons.search, color: Colors.white),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
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
                            icon: const Icon(Icons.filter_list, color: Colors.white),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Filter Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        _buildFilterButton('Available', true, Colors.green),
                        const SizedBox(width: 8),
                        _buildFilterButton('Fast Charging', false, const Color(0xFF4A8FF7), icon: Icons.timer),
                        const SizedBox(width: 8),
                        _buildFilterButton('Green', false, const Color(0xFF4A8FF7), icon: Icons.eco),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Charging Availability Badge
          if (_stations.isNotEmpty)
            Positioned(
              top: 140,
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
                      '${_stations.first.availableSlots}/${_stations.first.totalSlots}',
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
                  // Handle booking
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

  // Dark map style
  static const String _darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [{"color": "#1a2b3a"}]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#ffffff"}]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [{"color": "#1a2b3a"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{"color": "#2a3b4a"}]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#ffffff"}]
    }
  ]
  ''';
}
