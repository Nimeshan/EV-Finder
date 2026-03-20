import 'package:flutter/material.dart';
import '../services/p2p_station_service.dart';
import '../services/web3_service.dart';
import '../theme/app_theme.dart';

class ListStationScreen extends StatefulWidget {
  const ListStationScreen({super.key});

  @override
  State<ListStationScreen> createState() => _ListStationScreenState();
}

class _ListStationScreenState extends State<ListStationScreen> {
  final P2PStationService _p2pService = P2PStationService();
  final Web3Service _web3Service = Web3Service();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _priceController = TextEditingController(text: '0.25');

  String _selectedConnector = 'Type 2 7kW';
  double _powerKw = 7;
  bool _isGreenEnergy = false;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _connectorOptions = [
    {'label': 'Type 2 7kW', 'power': 7.0},
    {'label': 'Type 2 22kW', 'power': 22.0},
    {'label': 'CCS2 50kW', 'power': 50.0},
    {'label': 'CHAdeMO 50kW', 'power': 50.0},
    {'label': 'CCS2 150kW', 'power': 150.0},
  ];

  Future<void> _submitStation() async {
    if (_nameController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _latController.text.trim().isEmpty ||
        _lngController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields'), backgroundColor: Colors.red),
      );
      return;
    }

    final stationName = _nameController.text.trim();
    if (stationName.length < 3 || stationName.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Station name must be 3-50 characters'), backgroundColor: Colors.red),
      );
      return;
    }

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final price = double.tryParse(_priceController.text.trim());

    if (lat == null || lng == null || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid number format'), backgroundColor: Colors.red),
      );
      return;
    }

    if (lat < -90 || lat > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latitude must be between -90 and 90'), backgroundColor: Colors.red),
      );
      return;
    }

    if (lng < -180 || lng > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Longitude must be between -180 and 180'), backgroundColor: Colors.red),
      );
      return;
    }

    if (price < 0.01 || price > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price must be between \$0.01 and \$10 per kWh'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final walletAddress = await _web3Service.getSavedWalletAddress();
      if (walletAddress == null) {
        throw Exception('No wallet connected');
      }

      await _p2pService.registerStation(
        fromAddress: walletAddress,
        name: _nameController.text.trim(),
        locationAddress: _addressController.text.trim(),
        latitude: lat,
        longitude: lng,
        connectorType: _selectedConnector,
        powerKw: _powerKw,
        pricePerKwh: price,
        isGreenEnergy: _isGreenEnergy,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Station registered successfully!'), backgroundColor: AppColors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _priceController.dispose();
    super.dispose();
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
        title: const Text('List Your Charger', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // P2P info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF9C27B0), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'List your private charger on the blockchain for other EV drivers to discover and book.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _sectionLabel('STATION DETAILS'),
            const SizedBox(height: 8),
            _buildTextField(_nameController, 'Station Name', Icons.ev_station),
            const SizedBox(height: 12),
            _buildTextField(_addressController, 'Address', Icons.location_on),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _buildTextField(_latController, 'Latitude', Icons.my_location, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField(_lngController, 'Longitude', Icons.my_location, keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 24),

            _sectionLabel('CONNECTOR TYPE'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedConnector,
                  isExpanded: true,
                  dropdownColor: AppColors.cardBackground,
                  style: const TextStyle(color: Colors.white),
                  items: _connectorOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt['label'] as String,
                      child: Text(opt['label'] as String),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      final option = _connectorOptions.firstWhere((o) => o['label'] == value);
                      setState(() {
                        _selectedConnector = value;
                        _powerKw = option['power'] as double;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            _sectionLabel('PRICING'),
            const SizedBox(height: 8),
            _buildTextField(_priceController, 'Price per kWh (\$)', Icons.attach_money, keyboardType: TextInputType.number),
            const SizedBox(height: 24),

            _sectionLabel('ENERGY SOURCE'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.eco, color: _isGreenEnergy ? AppColors.green : Colors.white54, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 0),
                      child: Text(
                        _isGreenEnergy ? 'Green / Renewable Energy' : 'Standard Grid Energy',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _isGreenEnergy,
                    onChanged: (v) => setState(() => _isGreenEnergy = v),
                    activeThumbColor: AppColors.green,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitStation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Register Station on Blockchain', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w600));
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
