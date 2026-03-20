import 'package:flutter/material.dart';
import '../services/energy_trading_service.dart';
import '../services/web3_service.dart';
import '../theme/app_theme.dart';

class CreateEnergyListingScreen extends StatefulWidget {
  const CreateEnergyListingScreen({super.key});

  @override
  State<CreateEnergyListingScreen> createState() => _CreateEnergyListingScreenState();
}

class _CreateEnergyListingScreenState extends State<CreateEnergyListingScreen> {
  final EnergyTradingService _tradingService = EnergyTradingService();
  final Web3Service _web3Service = Web3Service();

  double _energyKwh = 25.0;
  final _priceController = TextEditingController(text: '0.15');
  bool _isSubmitting = false;
  double _myCredits = 0;

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    final address = await _web3Service.getSavedWalletAddress();
    if (address != null) {
      _myCredits = await _tradingService.getMyEnergyCredits(address);
      if (mounted) setState(() {});
    }
  }

  double get _totalPrice {
    final price = double.tryParse(_priceController.text) ?? 0;
    return _energyKwh * price;
  }

  Future<void> _createListing() async {
    final price = double.tryParse(_priceController.text);
    if (price == null || price < 0.01 || price > 10.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price must be between \$0.01 and \$10.00 per kWh'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_energyKwh > _myCredits) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient energy credits'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final address = await _web3Service.getSavedWalletAddress();
      if (address == null) throw Exception('No wallet connected');

      await _tradingService.createListing(
        walletAddress: address,
        energyKwh: _energyKwh,
        pricePerKwh: price,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Energy listed for sale!'), backgroundColor: AppColors.green),
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
        title: const Text('Sell Energy', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Credits info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: AppColors.green, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Available: ${_myCredits.toStringAsFixed(1)} kWh',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (_myCredits <= 0) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primaryBlue, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'You need energy credits to sell',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add Solar Credits from the Trade tab first, then come back here to list them for sale.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/marketplace');
                        },
                        icon: const Icon(Icons.bolt, size: 18, color: AppColors.primaryBlue),
                        label: const Text('Go to Trade → Add Solar Credits', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),

            const Text('ENERGY AMOUNT', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${_energyKwh.toStringAsFixed(0)} kWh',
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
              ),
            ),
            Slider(
              value: _energyKwh.clamp(1, _myCredits > 0 ? _myCredits : 100),
              min: 1,
              max: _myCredits > 0 ? _myCredits : 100,
              divisions: (_myCredits > 1 ? _myCredits.toInt() : 100),
              activeColor: AppColors.green,
              inactiveColor: Colors.white24,
              onChanged: (value) => setState(() => _energyKwh = value),
            ),
            const SizedBox(height: 24),

            const Text('PRICE PER kWh', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(color: Colors.white70, fontSize: 18),
                  suffixText: '/kWh',
                  suffixStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Energy', style: TextStyle(color: Colors.white70)),
                      Text('${_energyKwh.toStringAsFixed(1)} kWh', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Price/kWh', style: TextStyle(color: Colors.white70)),
                      Text('\$${(double.tryParse(_priceController.text) ?? 0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Listing Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('\$${_totalPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _createListing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sell, color: Colors.white),
                          SizedBox(width: 8),
                          Text('List Energy for Sale', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
